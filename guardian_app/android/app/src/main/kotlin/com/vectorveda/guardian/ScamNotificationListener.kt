package com.vectorveda.guardian

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.Locale
import org.json.JSONObject

class ScamNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "ScamNotificationListener"
        private const val SCAM_NOTIFICATION_PREFS = "scam_notification_listener"
        private const val SCAM_NOTIFICATION_PENDING_KEY = "pending_payload_queue_json"
        const val ACTION_SCAM_NOTIFICATION_PAYLOAD_AVAILABLE =
            "com.vectorveda.guardian.SCAM_NOTIFICATION_PAYLOAD_AVAILABLE"

        internal fun handleAcceptedPayload(
            sourcePackage: String,
            payload: ScamNotificationPayload,
            languageTag: String,
            existingQueueJson: String?,
            serializePayload: (ScamNotificationPayload) -> String = { accepted ->
                JSONObject()
                    .put("source_package", accepted.sourcePackage)
                    .put("sender", accepted.sender ?: "")
                    .put("message_body", accepted.messageBody)
                    .put("received_at_ms", accepted.receivedAtMs)
                    .toString()
            },
            emitTelemetry: (String, String) -> Unit = { category, language ->
                GuardianTelemetry.logScamNotificationPosted(
                    category = category,
                    language = language,
                )
            },
        ): String {
            emitTelemetry(sourcePackage, languageTag)
            val payloadJson = serializePayload(payload)
            return ScamNotificationPayloadQueueCodec.appendPayload(
                existingQueueJson = existingQueueJson,
                payloadJson = payloadJson,
            )
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) {
            return
        }
        val sourcePackage = sbn.packageName ?: return

        val notification = sbn.notification ?: return
        val sender = notification.extras
            ?.getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()
        val text = notification.extras
            ?.getCharSequence(Notification.EXTRA_TEXT)
            ?.toString()
        val bigText = notification.extras
            ?.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?.toString()

        val payload = ScamNotificationExtractor.toPayloadOrNull(
            sourcePackage = sourcePackage,
            appPackageName = packageName,
            sender = sender,
            text = text,
            bigText = bigText,
            receivedAtMs = sbn.postTime,
        ) ?: return
        val prefs = getSharedPreferences(SCAM_NOTIFICATION_PREFS, Context.MODE_PRIVATE)
        val languageTag = Locale.getDefault().toLanguageTag()
            .ifBlank { Locale.getDefault().language.ifBlank { "en" } }
        val queued = handleAcceptedPayload(
            sourcePackage = sourcePackage,
            payload = payload,
            languageTag = languageTag,
            existingQueueJson = prefs.getString(SCAM_NOTIFICATION_PENDING_KEY, null),
        )
        prefs.edit().putString(SCAM_NOTIFICATION_PENDING_KEY, queued).apply()
        sendBroadcast(
            Intent(ACTION_SCAM_NOTIFICATION_PAYLOAD_AVAILABLE).setPackage(packageName),
        )
        Log.d(TAG, "Queued notification payload from $sourcePackage for scam matching.")
    }

}

