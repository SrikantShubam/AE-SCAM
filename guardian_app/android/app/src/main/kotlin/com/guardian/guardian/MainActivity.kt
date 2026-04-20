package com.guardian.guardian

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SETTINGS_CHANNEL = "com.guardian/settings"
        private const val MEDICATION_ALARM_CHANNEL = "com.guardian/medication_alarm"
        private const val SHARE_INTENT_CHANNEL = "com.guardian/scam_share_intent"
        private const val SCAM_NOTIFICATION_CHANNEL = "com.guardian/scam_notification_listener"
        private const val SCAM_NOTIFICATION_PREFS = "scam_notification_listener"
        private const val SCAM_NOTIFICATION_PENDING_KEY = "pending_payload_json"
        private const val TAG = "MainActivity"
    }

    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureShareTextFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShareTextFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }

                "getPaymentProtectionSnapshot" -> {
                    result.success(getPaymentProtectionSnapshot())
                }

                "markEscalationHandled" -> {
                    val eventId = call.argument<String>("eventId")
                    result.success(markEscalationHandled(eventId))
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDICATION_ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isExactAlarmPermissionGranted" -> {
                    result.success(isExactAlarmPermissionGranted())
                }

                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(true)
                }

                "scheduleMedicationTrigger" -> {
                    val occurrenceId = call.argument<String>("occurrenceId")
                    val triggerId = call.argument<String>("triggerId")
                    val stage = call.argument<String>("stage")
                    val triggerAtMs = call.argument<Number>("triggerAtMs")?.toLong()
                    val medicationName = call.argument<String>("medicationName").orEmpty()
                    val dosage = call.argument<String>("dosage").orEmpty()

                    if (
                        occurrenceId.isNullOrBlank() ||
                        triggerId.isNullOrBlank() ||
                        stage.isNullOrBlank() ||
                        triggerAtMs == null
                    ) {
                        result.error(
                            "invalid_args",
                            "Missing required medication trigger arguments.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    if (!isExactAlarmPermissionGranted()) {
                        result.error(
                            "exact_alarm_not_allowed",
                            "Exact alarm permission is not granted.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    scheduleMedicationTrigger(
                        occurrenceId = occurrenceId,
                        triggerId = triggerId,
                        stage = stage,
                        triggerAtMs = triggerAtMs,
                        medicationName = medicationName,
                        dosage = dosage,
                    )
                    result.success(true)
                }

                "cancelMedicationOccurrence" -> {
                    val occurrenceId = call.argument<String>("occurrenceId")
                    if (occurrenceId.isNullOrBlank()) {
                        result.error(
                            "invalid_args",
                            "Missing occurrenceId for cancellation.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    cancelMedicationOccurrence(occurrenceId)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_INTENT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSharedText" -> {
                    val shared = pendingSharedText
                    pendingSharedText = null
                    result.success(shared)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCAM_NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingNotificationPayloadJson" -> {
                    result.success(consumePendingScamNotificationPayloadJson())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isExactAlarmPermissionGranted(): Boolean {
        val alarmManager = getSystemService<AlarmManager>() ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
            return
        }
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })
    }

    private fun scheduleMedicationTrigger(
        occurrenceId: String,
        triggerId: String,
        stage: String,
        triggerAtMs: Long,
        medicationName: String,
        dosage: String,
    ) {
        val alarmManager = getSystemService<AlarmManager>() ?: return
        val requestCode = triggerId.hashCode()
        val intent = Intent(this, MedicationAlarmReceiver::class.java).apply {
            action = MedicationAlarmReceiver.ACTION_MEDICATION_TRIGGER
            putExtra(MedicationAlarmReceiver.EXTRA_OCCURRENCE_ID, occurrenceId)
            putExtra(MedicationAlarmReceiver.EXTRA_TRIGGER_ID, triggerId)
            putExtra(MedicationAlarmReceiver.EXTRA_STAGE, stage)
            putExtra(MedicationAlarmReceiver.EXTRA_TRIGGER_AT_MS, triggerAtMs)
            putExtra(MedicationAlarmReceiver.EXTRA_MEDICATION_NAME, medicationName)
            putExtra(MedicationAlarmReceiver.EXTRA_DOSAGE, dosage)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMs,
            pendingIntent,
        )
    }

    private fun cancelMedicationOccurrence(occurrenceId: String) {
        val alarmManager = getSystemService<AlarmManager>() ?: return
        val triggerIds = listOf(
            "$occurrenceId-level1",
            "$occurrenceId-level3",
            "$occurrenceId-level3-now",
        )

        triggerIds.forEach { triggerId ->
            val requestCode = triggerId.hashCode()
            val intent = Intent(this, MedicationAlarmReceiver::class.java).apply {
                action = MedicationAlarmReceiver.ACTION_MEDICATION_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService<AccessibilityManager>() ?: return false
        val expectedId = "$packageName/${GuardianAccessibilityService::class.java.name}"

        val enabledServices = accessibilityManager
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .mapNotNull { it.resolveInfo?.serviceInfo }
            .map { "${it.packageName}/${it.name}" }

        if (enabledServices.contains(expectedId)) {
            return true
        }

        val enabledSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledSetting)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expectedId, ignoreCase = true)) {
                return true
            }
        }

        return false
    }

    private fun getPaymentProtectionSnapshot(): Map<String, Any> {
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        val serviceEnabled = isAccessibilityServiceEnabled()
        val lastPackageName = prefs.getString(PaymentProtectionStore.KEY_LAST_PACKAGE, null)
        val lastLabel = prefs.getString(PaymentProtectionStore.KEY_LAST_LABEL, null)
        val lastSeenAtMs = prefs.getLong(PaymentProtectionStore.KEY_LAST_SEEN_AT_MS, 0L)
        val storedState = prefs.getString(PaymentProtectionStore.KEY_STATE, "monitoring")
        val matchedSignals = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_MATCHED_SIGNALS, null),
        )
        val storedReasons = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_REASONS, null),
        )
        val detectedAmountHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_AMOUNT, null)
        val detectedRecipientHint = prefs.getString(
            PaymentProtectionStore.KEY_DETECTED_RECIPIENT,
            null,
        )
        val detectedUpiIdHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_UPI_ID, null)
        val reviewTitle = prefs.getString(PaymentProtectionStore.KEY_REVIEW_TITLE, null)
        val reviewBody = prefs.getString(PaymentProtectionStore.KEY_REVIEW_BODY, null)
        val cooldownSeconds = prefs.getInt(PaymentProtectionStore.KEY_COOLDOWN_SECONDS, 0)
        val proceedLabel = prefs.getString(PaymentProtectionStore.KEY_PROCEED_LABEL, null)
        val safeExitLabel = prefs.getString(PaymentProtectionStore.KEY_SAFE_EXIT_LABEL, null)
        val hasHighAmount = prefs.getBoolean(PaymentProtectionStore.KEY_HAS_HIGH_AMOUNT, false)
        val hasSuspiciousLanguage = prefs.getBoolean(
            PaymentProtectionStore.KEY_HAS_SUSPICIOUS_LANGUAGE,
            false,
        )
        val recipientRecentlyChanged = prefs.getBoolean(
            PaymentProtectionStore.KEY_RECIPIENT_RECENTLY_CHANGED,
            false,
        )
        val recipientKnown = prefs.getBoolean(
            PaymentProtectionStore.KEY_RECIPIENT_KNOWN,
            false,
        )
        val escalationRecommended = prefs.getBoolean(
            PaymentProtectionStore.KEY_ESCALATION_RECOMMENDED,
            false,
        )
        val escalationReason = prefs.getString(
            PaymentProtectionStore.KEY_ESCALATION_REASON,
            null,
        )
        val lastEscalationId = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_ID,
            null,
        )
        val lastEscalationAtMs = prefs.getLong(
            PaymentProtectionStore.KEY_LAST_ESCALATION_AT_MS,
            0L,
        )
        val lastEscalationAppLabel = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_APP_LABEL,
            null,
        )
        val lastEscalationTitle = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_TITLE,
            null,
        )
        val lastEscalationBody = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_BODY,
            null,
        )
        val lastEscalationAmount = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_AMOUNT,
            null,
        )
        val lastEscalationRecipient = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_RECIPIENT,
            null,
        )
        val lastEscalationUpiId = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_UPI_ID,
            null,
        )
        val lastEscalationPending = prefs.getBoolean(
            PaymentProtectionStore.KEY_LAST_ESCALATION_PENDING,
            false,
        )

        val now = System.currentTimeMillis()
        val isRecent = serviceEnabled &&
            lastSeenAtMs > 0L &&
            now - lastSeenAtMs <= PaymentProtectionStore.WARNING_WINDOW_MS

        val state = when {
            !serviceEnabled -> "inactive"
            !isRecent -> "monitoring"
            storedState == "red" -> "red"
            storedState == "amber" -> "amber"
            else -> "monitoring"
        }

        val reasons = when {
            !serviceEnabled -> listOf("Live payment protection is off.")
            storedReasons.isNotEmpty() && isRecent -> storedReasons
            lastLabel != null -> listOf(
                "Guardian last monitored $lastLabel and is ready for the next payment screen.",
            )
            else -> listOf(
                "Live payment protection is on.",
                "Waiting for a monitored UPI app to show a send-money screen.",
            )
        }

        val payload = mutableMapOf<String, Any>(
            "state" to state,
            "serviceEnabled" to serviceEnabled,
            "paymentContextDetected" to (
                isRecent &&
                    prefs.getBoolean(PaymentProtectionStore.KEY_PAYMENT_CONTEXT, false)
                ),
            "matchedSignals" to if (isRecent) matchedSignals else emptyList<String>(),
            "reasons" to reasons,
            "cooldownSeconds" to if (state == "amber" || state == "red") {
                cooldownSeconds
            } else {
                0
            },
            "warningWindowMs" to PaymentProtectionStore.WARNING_WINDOW_MS,
        )

        if (lastPackageName != null) {
            payload["lastMonitoredPackageName"] = lastPackageName
        }
        if (lastLabel != null) {
            payload["lastMonitoredAppLabel"] = lastLabel
        }
        if (lastSeenAtMs > 0L) {
            payload["lastMonitoredAtMs"] = lastSeenAtMs
        }
        if (lastEscalationId != null) {
            payload["lastEscalationEventId"] = lastEscalationId
        }
        if (lastEscalationAtMs > 0L) {
            payload["lastEscalationAtMs"] = lastEscalationAtMs
        }
        if (lastEscalationAppLabel != null) {
            payload["lastEscalationAppLabel"] = lastEscalationAppLabel
        }
        if (lastEscalationTitle != null) {
            payload["lastEscalationTitle"] = lastEscalationTitle
        }
        if (lastEscalationBody != null) {
            payload["lastEscalationBody"] = lastEscalationBody
        }
        if (lastEscalationAmount != null) {
            payload["lastEscalationAmountHint"] = lastEscalationAmount
        }
        if (lastEscalationRecipient != null) {
            payload["lastEscalationRecipientHint"] = lastEscalationRecipient
        }
        if (lastEscalationUpiId != null) {
            payload["lastEscalationUpiIdHint"] = lastEscalationUpiId
        }
        if (escalationReason != null) {
            payload["escalationReason"] = escalationReason
        }
        payload["lastEscalationPending"] = lastEscalationPending
        if (isRecent) {
            if (detectedAmountHint != null) {
                payload["detectedAmountHint"] = detectedAmountHint
            }
            if (detectedRecipientHint != null) {
                payload["detectedRecipientHint"] = detectedRecipientHint
            }
            if (detectedUpiIdHint != null) {
                payload["detectedUpiIdHint"] = detectedUpiIdHint
            }
            if (reviewTitle != null) {
                payload["reviewTitle"] = reviewTitle
            }
            if (reviewBody != null) {
                payload["reviewBody"] = reviewBody
            }
            if (proceedLabel != null && (state == "amber" || state == "red")) {
                payload["proceedLabel"] = proceedLabel
            }
            if (safeExitLabel != null && (state == "amber" || state == "red")) {
                payload["safeExitLabel"] = safeExitLabel
            }
            payload["hasHighAmount"] = hasHighAmount
            payload["hasSuspiciousLanguage"] = hasSuspiciousLanguage
            payload["recipientRecentlyChanged"] = recipientRecentlyChanged
            payload["recipientKnown"] = recipientKnown
            payload["escalationRecommended"] = escalationRecommended
        }

        return payload
    }

    private fun markEscalationHandled(eventId: String?): Boolean {
        if (eventId.isNullOrBlank()) {
            return false
        }

        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        val currentEventId = prefs.getString(PaymentProtectionStore.KEY_LAST_ESCALATION_ID, null)
        if (!eventId.equals(currentEventId, ignoreCase = false)) {
            return false
        }

        prefs.edit()
            .putBoolean(PaymentProtectionStore.KEY_LAST_ESCALATION_PENDING, false)
            .apply()
        return true
    }

    private fun consumePendingScamNotificationPayloadJson(): String? {
        val prefs = getSharedPreferences(SCAM_NOTIFICATION_PREFS, Context.MODE_PRIVATE)
        val payload = prefs.getString(SCAM_NOTIFICATION_PENDING_KEY, null)
        if (payload != null) {
            prefs.edit().remove(SCAM_NOTIFICATION_PENDING_KEY).apply()
        }
        return payload
    }

    private fun captureShareTextFromIntent(sourceIntent: Intent?) {
        val intent = sourceIntent ?: return
        val action = intent.action ?: return
        val type = intent.type ?: return

        if (type != "text/plain") {
            return
        }

        val extracted = when (action) {
            Intent.ACTION_SEND -> extractSingleSharedText(intent)
            Intent.ACTION_SEND_MULTIPLE -> extractMultipleSharedText(intent)
            else -> null
        }?.trim()

        if (extracted.isNullOrEmpty()) {
            return
        }

        pendingSharedText = extracted
        Log.d(TAG, "Captured shared text for scam verdict flow.")
    }

    private fun extractSingleSharedText(intent: Intent): String? {
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        return text?.trim()
    }

    private fun extractMultipleSharedText(intent: Intent): String? {
        val segments = mutableListOf<String>()
        val list = intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)
        if (!list.isNullOrEmpty()) {
            list.forEach { value ->
                val item = value?.toString()?.trim()
                if (!item.isNullOrEmpty()) {
                    segments.add(item)
                }
            }
        }

        val fallback = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        if (!fallback.isNullOrBlank()) {
            segments.add(fallback.trim())
        }

        if (segments.isEmpty()) {
            return null
        }
        return segments.joinToString(separator = "\n\n")
    }
}
