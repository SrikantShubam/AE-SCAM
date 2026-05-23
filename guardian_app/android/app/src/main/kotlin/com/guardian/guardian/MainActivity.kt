package com.guardian.guardian

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val SETTINGS_CHANNEL = "com.guardian/settings"
        private const val MEDICATION_ALARM_CHANNEL = "com.guardian/medication_alarm"
        private const val URL_REPUTATION_CHANNEL = "com.guardian/url_reputation"
        private const val SHARE_INTENT_CHANNEL = "com.guardian/scam_share_intent"
        private const val SCAM_NOTIFICATION_CHANNEL = "com.guardian/scam_notification_listener"
        private const val SCAM_NOTIFICATION_PREFS = "scam_notification_listener"
        private const val SCAM_NOTIFICATION_PENDING_KEY = "pending_payload_queue_json"
        private const val SCAM_NOTIFICATION_LEGACY_PENDING_KEY = "pending_payload_json"
        private const val TAG = "MainActivity"
        const val EXTRA_NAVIGATION_ROUTE = "guardian_navigation_route"
    }

    private var pendingSharedText: String? = null
    private var pendingNavigationRoute: String? = null
    private lateinit var urlReputationStore: UrlReputationStore
    private var shareIntentChannel: MethodChannel? = null
    private var scamNotificationChannel: MethodChannel? = null
    private val scamNotificationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ScamNotificationListener.ACTION_SCAM_NOTIFICATION_PAYLOAD_AVAILABLE) {
                return
            }
            scamNotificationChannel?.invokeMethod("notificationPayloadAvailable", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        urlReputationStore = UrlReputationStore(this)
        if (!isEmergencyDisabled()) {
            MedicationPrimeWorkScheduler.ensurePeriodic(this)
        }
        ServiceHealthWorkScheduler.ensurePeriodic(this)
        registerScamNotificationReceiver()
        captureNavigationRouteFromIntent(intent)
        captureShareTextFromIntent(intent)
    }

    override fun onDestroy() {
        unregisterReceiver(scamNotificationReceiver)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNavigationRouteFromIntent(intent)
        if (captureShareTextFromIntent(intent)) {
            shareIntentChannel?.invokeMethod("sharedTextAvailable", null)
        }
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

                "openBatteryOptimizationSettings" -> {
                    result.success(
                        BatteryOptimizationSettingsNavigator.open(this),
                    )
                }

                "getPaymentProtectionSnapshot" -> {
                    result.success(getPaymentProtectionSnapshot())
                }
                "getDiagnosticsSnapshot" -> {
                    result.success(getDiagnosticsSnapshot())
                }

                "consumePendingNavigationRoute" -> {
                    val route = pendingNavigationRoute
                    pendingNavigationRoute = null
                    result.success(route)
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
                    val note = call.argument<String>("note").orEmpty()

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

                    scheduleMedicationTrigger(
                        occurrenceId = occurrenceId,
                        triggerId = triggerId,
                        stage = stage,
                        triggerAtMs = triggerAtMs,
                        medicationName = medicationName,
                        dosage = dosage,
                        note = note,
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
            URL_REPUTATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUrlThreat" -> {
                    val url = call.argument<String>("url").orEmpty()
                    if (url.isBlank()) {
                        result.success(UrlReputationStore.THREAT_UNKNOWN)
                        return@setMethodCallHandler
                    }
                    result.success(urlReputationStore.checkUrl(url))
                }

                else -> result.notImplemented()
            }
        }

        shareIntentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_INTENT_CHANNEL,
        )
        shareIntentChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingSharedText" -> {
                    val shared = pendingSharedText
                    pendingSharedText = null
                    result.success(shared)
                }

                else -> result.notImplemented()
            }
        }

        scamNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCAM_NOTIFICATION_CHANNEL,
        )
        scamNotificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingNotificationPayloadJson" -> {
                    result.success(consumePendingScamNotificationPayloadJson())
                }

                "consumePendingNotificationPayloadJsonList" -> {
                    result.success(consumePendingScamNotificationPayloadJsonList())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getDiagnosticsSnapshot(): Map<String, Any> {
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        val safeBrowsingRefreshes = urlReputationStore.recentRefreshTimestamps()
        val payload = mutableMapOf<String, Any>(
            "accessibilityEnabled" to isAccessibilityServiceEnabled(),
            "notificationListenerEnabled" to isNotificationListenerEnabled(),
            "safeBrowsingHitCount" to urlReputationStore.hitCount(),
            "safeBrowsingRefreshesMs" to safeBrowsingRefreshes,
            "accessibilityEvents" to decodeJsonObjectList(
                prefs.getString(PaymentProtectionStore.KEY_ACCESSIBILITY_EVENT_SUMMARIES, null),
            ),
            "emergencyDisabled" to prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false),
        )

        prefs.getString("pair_id", null)?.let { payload["pairId"] = it }
        prefs.getString("last_fcm_token", null)?.let { payload["lastFcmToken"] = it }
        return payload
    }

    private fun registerScamNotificationReceiver() {
        val filter = IntentFilter(ScamNotificationListener.ACTION_SCAM_NOTIFICATION_PAYLOAD_AVAILABLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scamNotificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(scamNotificationReceiver, filter)
        }
    }

    private fun isExactAlarmPermissionGranted(): Boolean {
        // WO-MED-02 migrated scheduling to inexact alarms; no exact-alarm permission gate.
        return true
    }

    private fun openExactAlarmSettings() {
        // WO-MED-02: no exact alarm permission prompt is required.
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS))
    }

    private fun scheduleMedicationTrigger(
        occurrenceId: String,
        triggerId: String,
        stage: String,
        triggerAtMs: Long,
        medicationName: String,
        dosage: String,
        note: String,
    ) {
        if (isEmergencyDisabled()) {
            return
        }
        MedicationAlarmNativeScheduler.scheduleTrigger(
            context = this,
            occurrenceId = occurrenceId,
            triggerId = triggerId,
            stage = stage,
            triggerAtMs = triggerAtMs,
            medicationName = medicationName,
            dosage = dosage,
            note = note,
        )
    }

    private fun cancelMedicationOccurrence(occurrenceId: String) {
        MedicationAlarmNativeScheduler.cancelOccurrence(this, occurrenceId)
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

    private fun isNotificationListenerEnabled(): Boolean {
        val expectedId = "$packageName/${ScamNotificationListener::class.java.name}"
        val enabledSetting = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
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

    private fun decodeJsonObjectList(raw: String?): List<Map<String, Any>> {
        if (raw.isNullOrBlank()) {
            return emptyList()
        }
        return runCatching {
            val array = JSONArray(raw)
            val list = mutableListOf<Map<String, Any>>()
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val map = mutableMapOf<String, Any>()
                val keys = item.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = item.opt(key)
                    if (value != null && value != JSONObject.NULL) {
                        map[key] = value
                    }
                }
                list.add(map)
            }
            list
        }.getOrDefault(emptyList())
    }

    private fun getPaymentProtectionSnapshot(): Map<String, Any> {
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        val serviceEnabled = isAccessibilityServiceEnabled()
        val emergencyDisabled = prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)
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
            emergencyDisabled -> "inactive"
            !serviceEnabled -> "inactive"
            !isRecent -> "monitoring"
            storedState == "red" -> "red"
            storedState == "amber" -> "amber"
            else -> "monitoring"
        }

        val reasons = when {
            emergencyDisabled -> listOf("Protection paused by caregiver.")
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
            "accessibilityHealthEnabled" to prefs.getBoolean(
                PaymentProtectionStore.KEY_HEALTH_ACCESSIBILITY_ENABLED,
                serviceEnabled,
            ),
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
            "emergencyDisabled" to emergencyDisabled,
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

    private fun isEmergencyDisabled(): Boolean {
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)
    }

    private fun consumePendingScamNotificationPayloadJson(): String? {
        val all = consumePendingScamNotificationPayloadJsonList()
        return all.firstOrNull()
    }

    private fun consumePendingScamNotificationPayloadJsonList(): List<String> {
        val prefs = getSharedPreferences(SCAM_NOTIFICATION_PREFS, Context.MODE_PRIVATE)
        val queued = prefs.getString(SCAM_NOTIFICATION_PENDING_KEY, null)
        val legacy = prefs.getString(SCAM_NOTIFICATION_LEGACY_PENDING_KEY, null)
        val payloads = ScamNotificationPayloadQueueCodec.consumeAll(queued) +
            ScamNotificationPayloadQueueCodec.consumeAll(legacy)
        if (queued != null || legacy != null) {
            prefs.edit()
                .remove(SCAM_NOTIFICATION_PENDING_KEY)
                .remove(SCAM_NOTIFICATION_LEGACY_PENDING_KEY)
                .apply()
        }
        return payloads
    }

    private fun captureShareTextFromIntent(sourceIntent: Intent?): Boolean {
        val intent = sourceIntent ?: return false
        val action = intent.action ?: return false
        val type = intent.type ?: return false

        if (type != "text/plain") {
            return false
        }

        val extracted = when (action) {
            Intent.ACTION_SEND -> extractSingleSharedText(intent)
            Intent.ACTION_SEND_MULTIPLE -> extractMultipleSharedText(intent)
            else -> null
        }?.trim()

        if (extracted.isNullOrEmpty()) {
            return false
        }

        pendingSharedText = extracted
        Log.d(TAG, "Captured shared text for scam verdict flow.")
        return true
    }

    private fun captureNavigationRouteFromIntent(sourceIntent: Intent?) {
        val intent = sourceIntent ?: return
        val route = intent.getStringExtra(EXTRA_NAVIGATION_ROUTE)?.trim()
        if (route.isNullOrEmpty()) {
            return
        }
        pendingNavigationRoute = route
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
