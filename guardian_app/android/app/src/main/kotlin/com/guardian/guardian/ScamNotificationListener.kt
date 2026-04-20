package com.guardian.guardian

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject

class ScamNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "ScamNotificationListener"
        private const val SCAM_NOTIFICATION_PREFS = "scam_notification_listener"
        private const val SCAM_NOTIFICATION_PENDING_KEY = "pending_payload_json"
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

        val payloadJson = JSONObject()
            .put("source_package", payload.sourcePackage)
            .put("sender", payload.sender ?: "")
            .put("message_body", payload.messageBody)
            .put("received_at_ms", payload.receivedAtMs)
            .toString()

        val prefs = getSharedPreferences(SCAM_NOTIFICATION_PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(SCAM_NOTIFICATION_PENDING_KEY, payloadJson).apply()
        Log.d(TAG, "Queued notification payload from $sourcePackage for scam matching.")
    }
}
