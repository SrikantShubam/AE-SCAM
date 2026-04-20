package com.guardian.guardian

import java.util.Locale

internal object GuardianTelemetry {
    private const val CRASHLYTICS_CLASS = "com.google.firebase.crashlytics.FirebaseCrashlytics"
    private const val KEY_PREFIX = "obs_"
    private const val LOG_PREFIX = "guardian_obs"

    private val accessibilityDisabledReasons = setOf(
        "user_toggled",
        "os_killed_detected_via_watchdog",
    )
    private val overlayStates = setOf("amber", "red")
    private val overlayDismissReasons = setOf("safe_exit", "continue", "app_backgrounded")

    fun logAccessibilityServiceDisabled(reason: String) {
        logEvent(
            eventName = "accessibility_service_disabled",
            fields = mapOf(
                "reason" to normalizeEnum(reason, accessibilityDisabledReasons, "user_toggled"),
            ),
        )
    }

    fun logMedicationAlarmFired(scheduledAtDeltaMinutes: Long) {
        val boundedDelta = scheduledAtDeltaMinutes.coerceIn(-1_440L, 1_440L)
        logEvent(
            eventName = "medication_alarm_fired",
            fields = mapOf("scheduled_at_delta_minutes" to boundedDelta.toString()),
        )
    }

    fun logPaymentOverlayShown(state: String, signalCount: Int) {
        val safeState = normalizeEnum(state, overlayStates, "amber")
        val safeSignalCount = signalCount.coerceIn(0, 50)
        logEvent(
            eventName = "payment_overlay_shown",
            fields = mapOf(
                "state" to safeState,
                "signal_count" to safeSignalCount.toString(),
            ),
        )
    }

    fun logPaymentOverlayDismissed(via: String) {
        val safeVia = normalizeEnum(via, overlayDismissReasons, "app_backgrounded")
        logEvent(
            eventName = "payment_overlay_dismissed",
            fields = mapOf("via" to safeVia),
        )
    }

    private fun logEvent(eventName: String, fields: Map<String, String>) {
        val crashlytics = getCrashlyticsInstance() ?: return
        runCatching {
            val crashlyticsClass = crashlytics.javaClass
            val setCustomKey = crashlyticsClass.getMethod(
                "setCustomKey",
                String::class.java,
                String::class.java,
            )
            val logMethod = crashlyticsClass.getMethod("log", String::class.java)

            val safeEventName = normalizeToken(eventName, maxLength = 64)
            setCustomKey.invoke(crashlytics, "${KEY_PREFIX}event_name", safeEventName)
            fields.forEach { (key, value) ->
                val safeKey = normalizeToken(key, maxLength = 64)
                val safeValue = normalizeToken(value, maxLength = 64)
                setCustomKey.invoke(crashlytics, "$KEY_PREFIX$safeKey", safeValue)
            }

            val details = fields.entries
                .joinToString(" ") { (key, value) ->
                    "${normalizeToken(key, 32)}=${normalizeToken(value, 32)}"
                }
            val logLine = if (details.isBlank()) {
                "$LOG_PREFIX:$safeEventName"
            } else {
                "$LOG_PREFIX:$safeEventName $details"
            }
            logMethod.invoke(crashlytics, logLine)
        }
    }

    private fun getCrashlyticsInstance(): Any? {
        return runCatching {
            val clazz = Class.forName(CRASHLYTICS_CLASS)
            val getInstance = clazz.getMethod("getInstance")
            getInstance.invoke(null)
        }.getOrNull()
    }

    private fun normalizeEnum(
        value: String,
        allowed: Set<String>,
        fallback: String,
    ): String {
        val normalized = value.trim().lowercase(Locale.US)
        return if (allowed.contains(normalized)) normalized else fallback
    }

    private fun normalizeToken(
        value: String,
        maxLength: Int,
    ): String {
        val normalized = value
            .trim()
            .lowercase(Locale.US)
            .replace(Regex("[^a-z0-9_\\-]"), "_")
            .replace(Regex("_+"), "_")
            .trim('_')
            .ifEmpty { "na" }
        return normalized.take(maxLength)
    }
}
