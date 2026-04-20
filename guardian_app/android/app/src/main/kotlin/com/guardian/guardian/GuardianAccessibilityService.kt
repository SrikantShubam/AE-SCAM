package com.guardian.guardian

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale
import java.util.regex.Pattern

internal object PaymentProtectionStore {
    const val PREFS_NAME = "guardian_payment_protection"
    const val LIST_SEPARATOR = "\u001F"
    const val WARNING_WINDOW_MS = 75_000L
    const val AMBER_COOLDOWN_SECONDS = 8
    const val RED_COOLDOWN_SECONDS = 30
    const val HIGH_AMOUNT_THRESHOLD = 10_000.0

    const val KEY_LAST_PACKAGE = "last_monitored_package_name"
    const val KEY_LAST_LABEL = "last_monitored_app_label"
    const val KEY_LAST_SEEN_AT_MS = "last_monitored_at_ms"
    const val KEY_STATE = "state"
    const val KEY_PAYMENT_CONTEXT = "payment_context_detected"
    const val KEY_MATCHED_SIGNALS = "matched_signals"
    const val KEY_REASONS = "reasons"
    const val KEY_DETECTED_AMOUNT = "detected_amount_hint"
    const val KEY_DETECTED_RECIPIENT = "detected_recipient_hint"
    const val KEY_DETECTED_UPI_ID = "detected_upi_id_hint"
    const val KEY_REVIEW_TITLE = "review_title"
    const val KEY_REVIEW_BODY = "review_body"
    const val KEY_COOLDOWN_SECONDS = "cooldown_seconds"
    const val KEY_PROCEED_LABEL = "proceed_label"
    const val KEY_SAFE_EXIT_LABEL = "safe_exit_label"
    const val KEY_HAS_HIGH_AMOUNT = "has_high_amount"
    const val KEY_HAS_SUSPICIOUS_LANGUAGE = "has_suspicious_language"
    const val KEY_RECIPIENT_RECENTLY_CHANGED = "recipient_recently_changed"
    const val KEY_RECIPIENT_KNOWN = "recipient_known"
    const val KEY_ESCALATION_RECOMMENDED = "escalation_recommended"
    const val KEY_ESCALATION_REASON = "escalation_reason"
    const val KEY_APPROVED_RECIPIENTS = "approved_recipients"
    const val KEY_LAST_ESCALATION_ID = "last_escalation_id"
    const val KEY_LAST_ESCALATION_SIGNATURE = "last_escalation_signature"
    const val KEY_LAST_ESCALATION_AT_MS = "last_escalation_at_ms"
    const val KEY_LAST_ESCALATION_APP_LABEL = "last_escalation_app_label"
    const val KEY_LAST_ESCALATION_TITLE = "last_escalation_title"
    const val KEY_LAST_ESCALATION_BODY = "last_escalation_body"
    const val KEY_LAST_ESCALATION_AMOUNT = "last_escalation_amount"
    const val KEY_LAST_ESCALATION_RECIPIENT = "last_escalation_recipient"
    const val KEY_LAST_ESCALATION_UPI_ID = "last_escalation_upi_id"
    const val KEY_LAST_ESCALATION_PENDING = "last_escalation_pending"
    const val MAX_APPROVED_RECIPIENTS = 8

    val MONITORED_APPS = linkedMapOf(
        "com.google.android.apps.nbu.paisa.user" to "Google Pay",
        "com.phonepe.app" to "PhonePe",
        "net.one97.paytm" to "Paytm",
        "in.org.npci.upiapp" to "BHIM",
        "com.dreamplug.androidapp" to "CRED",
    )

    fun encodeList(values: List<String>): String = values.joinToString(LIST_SEPARATOR)

    fun decodeList(raw: String?): List<String> {
        return raw
            ?.split(LIST_SEPARATOR)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
    }
}

private data class ScreenSignal(
    val id: String,
    val reason: String,
)

private data class PaymentIntervention(
    val state: String,
    val paymentContextDetected: Boolean,
    val matchedSignals: List<String>,
    val reasons: List<String>,
    val detectedAmountHint: String?,
    val detectedRecipientHint: String?,
    val detectedUpiIdHint: String?,
    val reviewTitle: String?,
    val reviewBody: String?,
    val cooldownSeconds: Int,
    val proceedLabel: String?,
    val safeExitLabel: String?,
    val hasHighAmount: Boolean,
    val hasSuspiciousLanguage: Boolean,
    val recipientRecentlyChanged: Boolean,
    val recipientKnown: Boolean,
    val escalationRecommended: Boolean,
    val escalationReason: String?,
)

private fun PaymentIntervention.isOverlayCandidate(): Boolean {
    return paymentContextDetected && (state == "amber" || state == "red")
}

class GuardianAccessibilityService : AccessibilityService() {
    private lateinit var overlayController: PaymentInterventionOverlayController

    companion object {
        private val PAYMENT_ACTION_PATTERNS = linkedMapOf(
            "payment_action" to listOf(
                "pay",
                "pay now",
                "send money",
                "transfer money",
                "bank transfer",
                "proceed to pay",
                "review payment",
                "confirm payment",
                "enter upi pin",
                "enter pin",
            ),
            "recipient_step" to listOf(
                "to",
                "pay to",
                "recipient",
                "receiver",
                "beneficiary",
                "paying",
            ),
            "amount_step" to listOf(
                "amount",
                "total",
                "enter amount",
                "you pay",
                "send amount",
                "transfer amount",
            ),
            "upi_step" to listOf(
                "upi",
                "upi id",
                "vpa",
                "@oksbi",
                "@okaxis",
                "@okhdfcbank",
                "@ybl",
                "@ibl",
                "@paytm",
            ),
        )

        private val SUSPICIOUS_SCREEN_PATTERNS = linkedMapOf(
            ScreenSignal(
                id = "collect_request_language",
                reason = "Visible text looks like a collect-request or receive-money trick.",
            ) to listOf(
                "collect request",
                "request money",
                "approve request",
                "receive money",
                "accept to receive",
                "claim reward",
                "claim cashback",
            ),
            ScreenSignal(
                id = "urgent_language",
                reason = "Visible text is pushing urgency or immediate action.",
            ) to listOf(
                "urgent",
                "immediately",
                "right now",
                "last chance",
                "within 10 minutes",
                "verify now",
                "account blocked",
            ),
            ScreenSignal(
                id = "scam_keyword_language",
                reason = "Visible text includes keywords often seen in scam payment requests.",
            ) to listOf(
                "customer care",
                "support",
                "helpline",
                "refund",
                "reward",
                "lottery",
                "prize",
                "kyc",
                "otp",
                "investment",
                "crypto",
                "police",
                "courier",
                "remote access",
            ),
        )
        private val SUSPICIOUS_SIGNAL_IDS: Set<String> = SUSPICIOUS_SCREEN_PATTERNS
            .keys
            .map { it.id }
            .toSet()

        private val AMOUNT_REGEXES = listOf(
            Regex("""(?i)(?:\u20B9|rs\.?|inr)\s*([0-9][0-9,]*(?:\.\d{1,2})?)"""),
            Regex("""(?i)(?:amount|total|you pay|paying|send amount|transfer amount)\s*[:\-]?\s*([0-9][0-9,]*(?:\.\d{1,2})?)"""),
        )
        private val UPI_ID_REGEX = Regex("""(?i)\b[a-z0-9._-]{2,}@[a-z][a-z0-9.-]{2,}\b""")
        private val RECIPIENT_INLINE_REGEXES = listOf(
            Regex("""(?i)(?:pay(?:ing)?\s+to|recipient|receiver|beneficiary|to)\s*[:\-]?\s*([a-z][a-z .]{2,40})"""),
            Regex("""(?i)(?:name)\s*[:\-]?\s*([a-z][a-z .]{2,40})"""),
        )
        private val GENERIC_RECIPIENT_PATTERNS = listOf(
            Regex("""(?i)\b(?:recipient|receiver|beneficiary|contact|upi id|bank account|mobile number|new payment|payee|merchant)\b"""),
        )
        private val AMOUNT_VALUE_REGEX = Pattern.compile("""([0-9][0-9,]*(?:\.\d{1,2})?)""")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        overlayController = PaymentInterventionOverlayController(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) {
            return
        }

        if (
            event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val packageName = event.packageName?.toString()?.trim().orEmpty()
        if (packageName.isEmpty()) {
            if (::overlayController.isInitialized) {
                overlayController.hide(via = "app_backgrounded")
            }
            return
        }

        val appLabel = PaymentProtectionStore.MONITORED_APPS[packageName]
        if (appLabel == null) {
            if (::overlayController.isInitialized) {
                overlayController.hide(via = "app_backgrounded")
            }
            return
        }
        val root = rootInActiveWindow
        val screenChunks = try {
            buildScreenChunks(event, root)
        } finally {
            root?.recycle()
        }
        val intervention = analyzeScreen(
            appLabel = appLabel,
            screenChunks = screenChunks,
        )

        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        val previousRecipientHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_RECIPIENT, null)
        val previousUpiIdHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_UPI_ID, null)
        val approvedRecipients = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_APPROVED_RECIPIENTS, null),
        )
        val adjustedIntervention = maybePromoteForRecipientChange(
            intervention = intervention,
            appLabel = appLabel,
            previousRecipientHint = previousRecipientHint,
            previousUpiIdHint = previousUpiIdHint,
        )
        val enrichedIntervention = applyRecipientHistoryAndEscalation(
            intervention = adjustedIntervention,
            appLabel = appLabel,
            approvedRecipients = approvedRecipients,
        )

        prefs.edit()
            .putString(PaymentProtectionStore.KEY_LAST_PACKAGE, packageName)
            .putString(PaymentProtectionStore.KEY_LAST_LABEL, appLabel)
            .putLong(PaymentProtectionStore.KEY_LAST_SEEN_AT_MS, System.currentTimeMillis())
            .putString(PaymentProtectionStore.KEY_STATE, enrichedIntervention.state)
            .putBoolean(
                PaymentProtectionStore.KEY_PAYMENT_CONTEXT,
                enrichedIntervention.paymentContextDetected,
            )
            .putString(
                PaymentProtectionStore.KEY_MATCHED_SIGNALS,
                PaymentProtectionStore.encodeList(enrichedIntervention.matchedSignals),
            )
            .putString(
                PaymentProtectionStore.KEY_REASONS,
                PaymentProtectionStore.encodeList(enrichedIntervention.reasons),
            )
            .putString(
                PaymentProtectionStore.KEY_DETECTED_AMOUNT,
                enrichedIntervention.detectedAmountHint,
            )
            .putString(
                PaymentProtectionStore.KEY_DETECTED_RECIPIENT,
                enrichedIntervention.detectedRecipientHint,
            )
            .putString(
                PaymentProtectionStore.KEY_DETECTED_UPI_ID,
                enrichedIntervention.detectedUpiIdHint,
            )
            .putString(PaymentProtectionStore.KEY_REVIEW_TITLE, enrichedIntervention.reviewTitle)
            .putString(PaymentProtectionStore.KEY_REVIEW_BODY, enrichedIntervention.reviewBody)
            .putInt(
                PaymentProtectionStore.KEY_COOLDOWN_SECONDS,
                enrichedIntervention.cooldownSeconds,
            )
            .putString(PaymentProtectionStore.KEY_PROCEED_LABEL, enrichedIntervention.proceedLabel)
            .putString(
                PaymentProtectionStore.KEY_SAFE_EXIT_LABEL,
                enrichedIntervention.safeExitLabel,
            )
            .putBoolean(
                PaymentProtectionStore.KEY_HAS_HIGH_AMOUNT,
                enrichedIntervention.hasHighAmount,
            )
            .putBoolean(
                PaymentProtectionStore.KEY_HAS_SUSPICIOUS_LANGUAGE,
                enrichedIntervention.hasSuspiciousLanguage,
            )
            .putBoolean(
                PaymentProtectionStore.KEY_RECIPIENT_RECENTLY_CHANGED,
                enrichedIntervention.recipientRecentlyChanged,
            )
            .putBoolean(
                PaymentProtectionStore.KEY_RECIPIENT_KNOWN,
                enrichedIntervention.recipientKnown,
            )
            .putBoolean(
                PaymentProtectionStore.KEY_ESCALATION_RECOMMENDED,
                enrichedIntervention.escalationRecommended,
            )
            .putString(
                PaymentProtectionStore.KEY_ESCALATION_REASON,
                enrichedIntervention.escalationReason,
            )
            .apply()

        if (::overlayController.isInitialized) {
            if (enrichedIntervention.isOverlayCandidate()) {
                overlayController.show(
                    appLabel = appLabel,
                    intervention = enrichedIntervention,
                )
            } else {
                overlayController.hide(via = "app_backgrounded")
            }
        }
    }

    override fun onInterrupt() {
        if (::overlayController.isInitialized) {
            overlayController.hide(via = "app_backgrounded")
        }
    }

    override fun onDestroy() {
        logAccessibilityServiceDisabled()
        if (::overlayController.isInitialized) {
            overlayController.hide(via = "app_backgrounded")
        }
        super.onDestroy()
    }

    private fun logAccessibilityServiceDisabled() {
        val expectedId = "$packageName/${GuardianAccessibilityService::class.java.name}"
        val enabledSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        )
        val stillEnabled = if (enabledSetting.isNullOrBlank()) {
            false
        } else {
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(enabledSetting)
            var found = false
            while (splitter.hasNext()) {
                if (splitter.next().equals(expectedId, ignoreCase = true)) {
                    found = true
                    break
                }
            }
            found
        }
        val reason = if (stillEnabled) {
            "os_killed_detected_via_watchdog"
        } else {
            "user_toggled"
        }
        GuardianTelemetry.logAccessibilityServiceDisabled(reason)
    }

    private fun analyzeScreen(
        appLabel: String,
        screenChunks: List<String>,
    ): PaymentIntervention {
        val screenText = normalizeWhitespace(screenChunks.joinToString(" "))
        val lowerText = screenText.lowercase(Locale.US)
        val matchedSignals = linkedSetOf<String>()
        val reasons = mutableListOf<String>()

        val actionMatches = PAYMENT_ACTION_PATTERNS
            .filterValues { phrases -> phrases.any { phrase -> lowerText.contains(phrase) } }
            .keys

        if (actionMatches.isNotEmpty()) {
            matchedSignals.addAll(actionMatches)
        }

        val amountHint = extractAmountHint(screenText)
        if (amountHint != null) {
            matchedSignals.add("amount_visible")
            reasons.add("Amount details are visible on the payment screen ($amountHint).")
        }

        val upiIdHint = extractUpiIdHint(screenText)
        if (upiIdHint != null) {
            matchedSignals.add("upi_id_visible")
            reasons.add("A UPI ID is visible on the payment screen ($upiIdHint).")
        }

        val recipientHint = extractRecipientHint(screenChunks, screenText, upiIdHint)
        if (recipientHint != null) {
            matchedSignals.add("recipient_visible")
            reasons.add("Recipient details are visible on the payment screen ($recipientHint).")
        }

        val paymentContextDetected =
            actionMatches.isNotEmpty() &&
                (amountHint != null || recipientHint != null || upiIdHint != null)

        if (!paymentContextDetected) {
            val monitoringReasons = mutableListOf(
                "Guardian is monitoring $appLabel for a send-money or pay screen.",
            )
            if (actionMatches.isNotEmpty()) {
                monitoringReasons.add(
                    "The app is active, but Guardian has not seen enough visible payment details yet.",
                )
            } else {
                monitoringReasons.add(
                    "Waiting for amount, recipient, or UPI details before showing a payment review.",
                )
            }
            return PaymentIntervention(
                state = "monitoring",
                paymentContextDetected = false,
                matchedSignals = matchedSignals.toList(),
                reasons = monitoringReasons,
                detectedAmountHint = amountHint,
                detectedRecipientHint = recipientHint,
                detectedUpiIdHint = upiIdHint,
                reviewTitle = null,
                reviewBody = null,
                cooldownSeconds = 0,
                proceedLabel = null,
                safeExitLabel = null,
                hasHighAmount = false,
                hasSuspiciousLanguage = false,
                recipientRecentlyChanged = false,
                recipientKnown = false,
                escalationRecommended = false,
                escalationReason = null,
            )
        }

        matchedSignals.add("payment_flow")
        reasons.add("A send-money or pay step is visible in $appLabel.")

        val suspiciousSignals = SUSPICIOUS_SCREEN_PATTERNS
            .filterKeys { signal ->
                SUSPICIOUS_SCREEN_PATTERNS[signal]
                    ?.any { phrase -> lowerText.contains(phrase) }
                    ?: false
            }
            .keys

        suspiciousSignals.forEach { signal ->
            matchedSignals.add(signal.id)
            reasons.add(signal.reason)
        }

        val amountValue = parseAmountValue(amountHint)
        val hasHighAmount = amountValue != null &&
            amountValue >= PaymentProtectionStore.HIGH_AMOUNT_THRESHOLD

        if (hasHighAmount) {
            matchedSignals.add("high_amount")
            reasons.add(
                "The visible amount crosses the high-value threshold of Rs 10,000.",
            )
        }

        val rawUpiRecipient = upiIdHint != null &&
            (recipientHint == null ||
                recipientHint.equals(upiIdHint, ignoreCase = true) ||
                isGenericRecipientHint(recipientHint))
        if (rawUpiRecipient) {
            matchedSignals.add("raw_upi_recipient")
            reasons.add("Guardian could only see a raw UPI ID or a generic recipient label.")
        }

        val hasSuspiciousLanguage = suspiciousSignals.isNotEmpty()

        val shouldUseRed =
            suspiciousSignals.any { it.id == "collect_request_language" } ||
                (suspiciousSignals.size >= 2) ||
                ((rawUpiRecipient || hasHighAmount) && hasSuspiciousLanguage)

        val state = if (shouldUseRed) "red" else "amber"
        val reviewTitle = buildReviewTitle(
            appLabel = appLabel,
            amountHint = amountHint,
            recipientHint = recipientHint,
            upiIdHint = upiIdHint,
            isRed = shouldUseRed,
            hasHighAmount = hasHighAmount,
            hasSuspiciousLanguage = hasSuspiciousLanguage,
            recipientRecentlyChanged = false,
            recipientKnown = false,
        )
        val reviewBody = buildReviewBody(
            appLabel = appLabel,
            amountHint = amountHint,
            recipientHint = recipientHint,
            upiIdHint = upiIdHint,
            isRed = shouldUseRed,
            hasHighAmount = hasHighAmount,
            hasSuspiciousLanguage = hasSuspiciousLanguage,
            recipientRecentlyChanged = false,
            recipientKnown = false,
        )

        return PaymentIntervention(
            state = state,
            paymentContextDetected = true,
            matchedSignals = matchedSignals.toList(),
            reasons = reasons.distinct(),
            detectedAmountHint = amountHint,
            detectedRecipientHint = recipientHint,
            detectedUpiIdHint = upiIdHint,
            reviewTitle = reviewTitle,
            reviewBody = reviewBody,
            cooldownSeconds = if (shouldUseRed) {
                PaymentProtectionStore.RED_COOLDOWN_SECONDS
            } else {
                PaymentProtectionStore.AMBER_COOLDOWN_SECONDS
            },
            proceedLabel = if (shouldUseRed) {
                "Yes, continue after cooldown"
            } else {
                "Yes, continue"
            },
            safeExitLabel = if (shouldUseRed) {
                "No, go back to safety"
            } else {
                "No, review again"
            },
            hasHighAmount = hasHighAmount,
            hasSuspiciousLanguage = hasSuspiciousLanguage,
            recipientRecentlyChanged = false,
            recipientKnown = false,
            escalationRecommended = false,
            escalationReason = null,
        )
    }

    private fun maybePromoteForRecipientChange(
        intervention: PaymentIntervention,
        appLabel: String,
        previousRecipientHint: String?,
        previousUpiIdHint: String?,
    ): PaymentIntervention {
        if (!intervention.paymentContextDetected) {
            return intervention
        }

        val recipientChanged = hasMeaningfulChange(
            newValue = intervention.detectedRecipientHint,
            oldValue = previousRecipientHint,
        ) || hasMeaningfulChange(
            newValue = intervention.detectedUpiIdHint,
            oldValue = previousUpiIdHint,
        )

        if (!recipientChanged) {
            return intervention
        }

        val updatedSignals = intervention.matchedSignals.toMutableList()
        if (!updatedSignals.contains("recipient_changed")) {
            updatedSignals.add("recipient_changed")
        }

        val updatedReasons = intervention.reasons.toMutableList()
        updatedReasons.add(
            "This recipient differs from the last payment flow Guardian monitored in $appLabel.",
        )

        val updatedHasSuspiciousLanguage = intervention.hasSuspiciousLanguage ||
            hasSuspiciousScreenSignals(updatedSignals)

        val updatedReviewTitle = buildReviewTitle(
            appLabel = appLabel,
            amountHint = intervention.detectedAmountHint,
            recipientHint = intervention.detectedRecipientHint,
            upiIdHint = intervention.detectedUpiIdHint,
            isRed = true,
            hasHighAmount = intervention.hasHighAmount,
            hasSuspiciousLanguage = updatedHasSuspiciousLanguage,
            recipientRecentlyChanged = true,
            recipientKnown = intervention.recipientKnown,
        )
        val updatedReviewBody = buildReviewBody(
            appLabel = appLabel,
            amountHint = intervention.detectedAmountHint,
            recipientHint = intervention.detectedRecipientHint,
            upiIdHint = intervention.detectedUpiIdHint,
            isRed = true,
            hasHighAmount = intervention.hasHighAmount,
            hasSuspiciousLanguage = updatedHasSuspiciousLanguage,
            recipientRecentlyChanged = true,
            recipientKnown = intervention.recipientKnown,
        )

        if (intervention.state == "red") {
            return intervention.copy(
                matchedSignals = updatedSignals.distinct(),
                reasons = updatedReasons.distinct(),
                reviewTitle = updatedReviewTitle,
                reviewBody = updatedReviewBody,
                recipientRecentlyChanged = true,
                hasSuspiciousLanguage = updatedHasSuspiciousLanguage,
                escalationRecommended = intervention.escalationRecommended,
                escalationReason = intervention.escalationReason,
            )
        }

        return intervention.copy(
            state = "red",
            matchedSignals = updatedSignals.distinct(),
            reasons = updatedReasons.distinct(),
            reviewTitle = updatedReviewTitle,
            reviewBody = updatedReviewBody,
            cooldownSeconds = PaymentProtectionStore.RED_COOLDOWN_SECONDS,
            proceedLabel = "Yes, continue after cooldown",
            safeExitLabel = "No, go back to safety",
            hasHighAmount = intervention.hasHighAmount,
            hasSuspiciousLanguage = updatedHasSuspiciousLanguage,
            recipientRecentlyChanged = true,
            recipientKnown = intervention.recipientKnown,
            escalationRecommended = intervention.escalationRecommended,
            escalationReason = intervention.escalationReason,
        )
    }

    private fun applyRecipientHistoryAndEscalation(
        intervention: PaymentIntervention,
        appLabel: String,
        approvedRecipients: List<String>,
    ): PaymentIntervention {
        if (!intervention.paymentContextDetected) {
            return intervention
        }

        val recipientKey = buildRecipientKey(
            recipientHint = intervention.detectedRecipientHint,
            upiIdHint = intervention.detectedUpiIdHint,
        )
        val recipientKnown = recipientKey != null &&
            approvedRecipients.any { it.equals(recipientKey, ignoreCase = true) }

        var updated = intervention.copy(
            recipientKnown = recipientKnown,
        )

        if (recipientKey != null && !recipientKnown) {
            val updatedSignals = updated.matchedSignals.toMutableList()
            if (!updatedSignals.contains("new_recipient")) {
                updatedSignals.add("new_recipient")
            }
            val updatedReasons = updated.reasons.toMutableList()
            updatedReasons.add(
                "Guardian has not seen this recipient confirmed before in $appLabel.",
            )

            val shouldPromote = updated.state == "red" ||
                updated.hasHighAmount ||
                updated.hasSuspiciousLanguage ||
                updated.recipientRecentlyChanged

            updated = updated.copy(
                state = if (shouldPromote) "red" else updated.state,
                matchedSignals = updatedSignals.distinct(),
                reasons = updatedReasons.distinct(),
                cooldownSeconds = if (shouldPromote) {
                    PaymentProtectionStore.RED_COOLDOWN_SECONDS
                } else {
                    updated.cooldownSeconds
                },
                proceedLabel = if (shouldPromote) {
                    "Yes, continue after cooldown"
                } else {
                    updated.proceedLabel
                },
                safeExitLabel = if (shouldPromote) {
                    "No, go back to safety"
                } else {
                    updated.safeExitLabel
                },
            )
            updated = updated.copy(
                reviewTitle = buildReviewTitle(
                    appLabel = appLabel,
                    amountHint = updated.detectedAmountHint,
                    recipientHint = updated.detectedRecipientHint,
                    upiIdHint = updated.detectedUpiIdHint,
                    isRed = updated.state == "red",
                    hasHighAmount = updated.hasHighAmount,
                    hasSuspiciousLanguage = updated.hasSuspiciousLanguage,
                    recipientRecentlyChanged = updated.recipientRecentlyChanged,
                    recipientKnown = updated.recipientKnown,
                ),
                reviewBody = buildReviewBody(
                    appLabel = appLabel,
                    amountHint = updated.detectedAmountHint,
                    recipientHint = updated.detectedRecipientHint,
                    upiIdHint = updated.detectedUpiIdHint,
                    isRed = updated.state == "red",
                    hasHighAmount = updated.hasHighAmount,
                    hasSuspiciousLanguage = updated.hasSuspiciousLanguage,
                    recipientRecentlyChanged = updated.recipientRecentlyChanged,
                    recipientKnown = updated.recipientKnown,
                ),
            )
        }

        val shouldEscalate = updated.state == "red" &&
            (updated.hasSuspiciousLanguage ||
                updated.recipientRecentlyChanged ||
                !updated.recipientKnown ||
                updated.hasHighAmount)

        val escalationReason = if (!shouldEscalate) {
            null
        } else if (!updated.recipientKnown) {
            "Ask a family member before paying a recipient Guardian has not seen confirmed before."
        } else if (updated.recipientRecentlyChanged) {
            "Ask a family member before paying because the recipient changed from the last payment flow."
        } else if (updated.hasSuspiciousLanguage) {
            "Ask a family member before paying because the screen includes wording often used in scam payment requests."
        } else {
            "Ask a family member before paying because the amount is unusually high."
        }

        return updated.copy(
            escalationRecommended = shouldEscalate,
            escalationReason = escalationReason,
            safeExitLabel = if (shouldEscalate) {
                "No, ask family first"
            } else {
                updated.safeExitLabel
            },
        )
    }

    private fun buildReviewTitle(
        appLabel: String,
        amountHint: String?,
        recipientHint: String?,
        upiIdHint: String?,
        isRed: Boolean,
        hasHighAmount: Boolean,
        hasSuspiciousLanguage: Boolean,
        recipientRecentlyChanged: Boolean,
        recipientKnown: Boolean,
    ): String {
        val hasAmount = !amountHint.isNullOrBlank()
        val hasRecipient = !recipientHint.isNullOrBlank()
        val hasUpi = !upiIdHint.isNullOrBlank()

        val keyDetails = when {
            hasAmount && hasRecipient -> "$amountHint to $recipientHint"
            hasAmount && hasUpi && !hasRecipient -> "$amountHint to $upiIdHint"
            hasAmount -> amountHint!!
            hasRecipient -> "payment to $recipientHint"
            hasUpi -> "payment to $upiIdHint"
            else -> "this payment in $appLabel"
        }

        if (isRed) {
            val needsEmphasis = hasHighAmount || hasSuspiciousLanguage || recipientRecentlyChanged
            return if (!recipientKnown && (hasRecipient || hasUpi)) {
                "Stop and verify this new payment recipient"
            } else if (needsEmphasis) {
                "Stop and check $keyDetails carefully"
            } else if (hasAmount || hasRecipient || hasUpi) {
                "Stop and double-check $keyDetails"
            } else {
                "Stop and double-check this payment"
            }
        }

        return if (hasAmount || hasRecipient || hasUpi) {
            "Review $keyDetails before you continue"
        } else {
            "Review this payment before you continue"
        }
    }

    private fun buildReviewBody(
        appLabel: String,
        amountHint: String?,
        recipientHint: String?,
        upiIdHint: String?,
        isRed: Boolean,
        hasHighAmount: Boolean,
        hasSuspiciousLanguage: Boolean,
        recipientRecentlyChanged: Boolean,
        recipientKnown: Boolean,
    ): String {
        val details = mutableListOf<String>()
        if (!recipientHint.isNullOrBlank()) {
            details.add("recipient $recipientHint")
        }
        if (!upiIdHint.isNullOrBlank()) {
            details.add("UPI ID $upiIdHint")
        }
        if (!amountHint.isNullOrBlank()) {
            details.add("amount $amountHint")
        }

        val detailText = if (details.isEmpty()) {
            "with visible payment details"
        } else {
            "showing ${details.joinToString(", ")}"
        }
        val riskFragments = mutableListOf<String>()
        if (hasHighAmount) {
            riskFragments.add(
                "The visible amount looks higher than a typical UPI transfer.",
            )
        }
        if (hasSuspiciousLanguage) {
            riskFragments.add(
                "Some on-screen text looks like it could be part of a scam or collect-request message.",
            )
        }
        if (recipientRecentlyChanged) {
            riskFragments.add(
                "This recipient looks different from the last payment Guardian saw in $appLabel.",
            )
        }
        if (!recipientKnown && (!recipientHint.isNullOrBlank() || !upiIdHint.isNullOrBlank())) {
            riskFragments.add(
                "Guardian has not seen this recipient confirmed before.",
            )
        }

        val riskText = if (riskFragments.isEmpty()) {
            ""
        } else {
            " " + riskFragments.joinToString(" ")
        }

        return if (isRed) {
            "Guardian noticed a higher-risk payment flow in $appLabel $detailText.$riskText Pause, verify who asked for this payment, and only continue if the details are fully expected."
        } else {
            "Guardian noticed a payment flow in $appLabel $detailText.$riskText Please confirm who asked for the payment before you continue."
        }
    }

    private fun hasMeaningfulChange(newValue: String?, oldValue: String?): Boolean {
        if (newValue.isNullOrBlank() || oldValue.isNullOrBlank()) {
            return false
        }
        return !newValue.equals(oldValue, ignoreCase = true)
    }

    private fun extractAmountHint(screenText: String): String? {
        for (regex in AMOUNT_REGEXES) {
            val match = regex.find(screenText) ?: continue
            val numericPart = match.groupValues.getOrNull(1)?.trim().orEmpty()
            if (numericPart.isNotEmpty()) {
                return "Rs $numericPart"
            }
            val fullMatch = match.value.trim()
            if (fullMatch.isNotEmpty()) {
                return normalizeWhitespace(fullMatch)
            }
        }
        return null
    }

    private fun parseAmountValue(amountHint: String?): Double? {
        if (amountHint.isNullOrBlank()) {
            return null
        }

        val matcher = AMOUNT_VALUE_REGEX.matcher(amountHint)
        if (!matcher.find()) {
            return null
        }

        return matcher.group(1)
            ?.replace(",", "")
            ?.toDoubleOrNull()
    }

    private fun extractUpiIdHint(screenText: String): String? {
        return UPI_ID_REGEX.find(screenText)?.value
    }

    private fun extractRecipientHint(
        screenChunks: List<String>,
        screenText: String,
        upiIdHint: String?,
    ): String? {
        for (index in screenChunks.indices) {
            val chunk = normalizeWhitespace(screenChunks[index])
            if (chunk.isBlank()) {
                continue
            }

            val lowerChunk = chunk.lowercase(Locale.US)
            if (
                lowerChunk == "to" ||
                lowerChunk == "pay to" ||
                lowerChunk == "recipient" ||
                lowerChunk == "receiver" ||
                lowerChunk == "beneficiary" ||
                lowerChunk == "name"
            ) {
                val nextChunk = screenChunks.getOrNull(index + 1)
                val candidate = sanitizeRecipientCandidate(nextChunk, upiIdHint)
                if (candidate != null) {
                    return candidate
                }
            }

            for (regex in RECIPIENT_INLINE_REGEXES) {
                val inlineMatch = regex.find(chunk) ?: continue
                val candidate = sanitizeRecipientCandidate(
                    inlineMatch.groupValues.getOrNull(1),
                    upiIdHint,
                )
                if (candidate != null) {
                    return candidate
                }
            }
        }

        for (regex in RECIPIENT_INLINE_REGEXES) {
            val inlineMatch = regex.find(screenText) ?: continue
            val candidate = sanitizeRecipientCandidate(
                inlineMatch.groupValues.getOrNull(1),
                upiIdHint,
            )
            if (candidate != null) {
                return candidate
            }
        }

        return upiIdHint
    }

    private fun sanitizeRecipientCandidate(
        candidate: String?,
        upiIdHint: String?,
    ): String? {
        val normalized = normalizeWhitespace(candidate.orEmpty())
            .trim(':', '-', '.', ',', ' ')

        if (normalized.length < 2) {
            return null
        }
        if (normalized.equals(upiIdHint, ignoreCase = true)) {
            return normalized
        }
        if (normalized.any { it.isDigit() } && !normalized.contains(" ")) {
            return null
        }
        if (UPI_ID_REGEX.matches(normalized)) {
            return normalized
        }
        return normalized
    }

    private fun isGenericRecipientHint(recipientHint: String): Boolean {
        return GENERIC_RECIPIENT_PATTERNS.any { it.containsMatchIn(recipientHint) }
    }

    private fun hasSuspiciousScreenSignals(matchedSignals: List<String>): Boolean {
        if (matchedSignals.isEmpty()) {
            return false
        }
        return matchedSignals.any { SUSPICIOUS_SIGNAL_IDS.contains(it) }
    }

    private fun buildRecipientKey(
        recipientHint: String?,
        upiIdHint: String?,
    ): String? {
        if (!upiIdHint.isNullOrBlank()) {
            return upiIdHint.trim().lowercase(Locale.US)
        }
        if (recipientHint.isNullOrBlank()) {
            return null
        }
        return recipientHint
            .trim()
            .lowercase(Locale.US)
            .replace("\\s+".toRegex(), " ")
    }

    private fun buildScreenChunks(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): List<String> {
        val chunks = linkedSetOf<String>()

        event.text
            ?.map { normalizeWhitespace(it?.toString().orEmpty()) }
            ?.filter { it.isNotEmpty() }
            ?.forEach { chunks.add(it) }

        event.contentDescription
            ?.toString()
            ?.let(::normalizeWhitespace)
            ?.takeIf { it.isNotEmpty() }
            ?.let { chunks.add(it) }

        collectNodeText(root, chunks, depth = 0)
        return chunks.toList()
    }

    private fun collectNodeText(
        node: AccessibilityNodeInfo?,
        chunks: MutableSet<String>,
        depth: Int,
    ) {
        if (node == null || depth > 6 || chunks.size >= 120) {
            return
        }

        node.text
            ?.toString()
            ?.let(::normalizeWhitespace)
            ?.takeIf { it.isNotEmpty() }
            ?.let { chunks.add(it) }

        node.contentDescription
            ?.toString()
            ?.let(::normalizeWhitespace)
            ?.takeIf { it.isNotEmpty() }
            ?.let { chunks.add(it) }

        node.viewIdResourceName
            ?.let(::normalizeWhitespace)
            ?.takeIf { it.isNotEmpty() }
            ?.let { chunks.add(it) }

        val hintText = node.hintText?.toString()
        if (!hintText.isNullOrBlank()) {
            chunks.add(normalizeWhitespace(hintText))
        }

        for (index in 0 until node.childCount) {
            val child = node.getChild(index)
            try {
                collectNodeText(child, chunks, depth + 1)
            } finally {
                child?.recycle()
            }
        }
    }

    private fun normalizeWhitespace(value: String): String {
        return value.replace("\\s+".toRegex(), " ").trim()
    }
}

private class PaymentInterventionOverlayController(
    private val service: GuardianAccessibilityService,
) {
    private val windowManager =
        service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())

    private var overlayRoot: FrameLayout? = null
    private var titleView: TextView? = null
    private var bodyView: TextView? = null
    private var detailsView: TextView? = null
    private var flagsView: TextView? = null
    private var safeButton: Button? = null
    private var continueButton: Button? = null
    private var currentSignature: String? = null
    private var suppressedSignature: String? = null
    private var suppressedUntilMs: Long = 0L
    private var countdownEndsAtMs: Long = 0L
    private var countdownRunnable: Runnable? = null

    fun show(
        appLabel: String,
        intervention: PaymentIntervention,
    ) {
        handler.post {
            val signature = buildSignature(appLabel, intervention)
            val now = System.currentTimeMillis()
            if (signature == suppressedSignature && now < suppressedUntilMs) {
                return@post
            }

            ensureOverlay()
            bindContent(appLabel, intervention, signature)
        }
    }

    fun hide(via: String = "app_backgrounded") {
        handler.post {
            val hadOverlay = overlayRoot?.parent != null
            cancelCountdown()
            currentSignature = null
            overlayRoot?.let { root ->
                if (root.parent != null) {
                    windowManager.removeView(root)
                }
            }
            overlayRoot = null
            titleView = null
            bodyView = null
            detailsView = null
            flagsView = null
            safeButton = null
            continueButton = null
            if (hadOverlay) {
                GuardianTelemetry.logPaymentOverlayDismissed(via)
            }
        }
    }

    private fun ensureOverlay() {
        if (overlayRoot != null) {
            return
        }

        val root = FrameLayout(service).apply {
            setBackgroundColor(Color.parseColor("#7A09151A"))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(28).toFloat()
            }
            elevation = dp(12).toFloat()
        }

        val badge = TextView(service).apply {
            text = "Guardian payment check"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#0E5E6D"))
                cornerRadius = dp(999).toFloat()
            }
        }

        titleView = TextView(service).apply {
            setTextColor(Color.parseColor("#0F1A1D"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            setTypeface(typeface, Typeface.BOLD)
        }

        bodyView = TextView(service).apply {
            setTextColor(Color.parseColor("#243338"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setLineSpacing(0f, 1.15f)
        }

        detailsView = TextView(service).apply {
            setTextColor(Color.parseColor("#42535A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            visibility = View.GONE
        }

        flagsView = TextView(service).apply {
            setTextColor(Color.parseColor("#7A2A19"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            visibility = View.GONE
        }

        safeButton = Button(service).apply {
            isAllCaps = false
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#0E5E6D"))
                cornerRadius = dp(18).toFloat()
            }
        }

        continueButton = Button(service).apply {
            isAllCaps = false
            setTextColor(Color.parseColor("#0F1A1D"))
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E8EEF0"))
                cornerRadius = dp(18).toFloat()
            }
        }

        card.addView(badge)
        card.addView(space())
        card.addView(titleView)
        card.addView(space(12))
        card.addView(bodyView)
        card.addView(space(12))
        card.addView(detailsView)
        card.addView(space(12))
        card.addView(flagsView)
        card.addView(space(20))
        card.addView(safeButton)
        card.addView(space(12))
        card.addView(continueButton)

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                setMargins(dp(16), dp(16), dp(16), dp(24))
            },
        )

        windowManager.addView(
            root,
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ),
        )

        overlayRoot = root
    }

    private fun bindContent(
        appLabel: String,
        intervention: PaymentIntervention,
        signature: String,
    ) {
        val title = intervention.reviewTitle ?: "Review this payment"
        val body = intervention.reviewBody
            ?: "Guardian noticed a payment screen in $appLabel and wants you to pause."

        titleView?.text = title
        bodyView?.text = body

        val details = mutableListOf<String>()
        intervention.detectedRecipientHint?.takeIf { it.isNotBlank() }?.let {
            details.add("Recipient: $it")
        }
        intervention.detectedUpiIdHint?.takeIf { it.isNotBlank() }?.let {
            details.add("UPI ID: $it")
        }
        intervention.detectedAmountHint?.takeIf { it.isNotBlank() }?.let {
            details.add("Amount: $it")
        }
        detailsView?.apply {
            if (details.isEmpty()) {
                visibility = View.GONE
                text = ""
            } else {
                visibility = View.VISIBLE
                text = details.joinToString("\n")
            }
        }

        val flags = mutableListOf<String>()
        if (intervention.hasHighAmount) {
            flags.add("High amount")
        }
        if (intervention.hasSuspiciousLanguage) {
            flags.add("Suspicious wording")
        }
        if (intervention.recipientRecentlyChanged) {
            flags.add("Recipient changed")
        }
        if (!intervention.recipientKnown) {
            flags.add("New recipient")
        }
        flagsView?.apply {
            if (flags.isEmpty()) {
                visibility = View.GONE
                text = ""
            } else {
                visibility = View.VISIBLE
                text = "Why Guardian paused: ${flags.joinToString(" • ")}"
            }
        }

        if (intervention.escalationRecommended && intervention.escalationReason != null) {
            val currentBody = bodyView?.text?.toString().orEmpty()
            bodyView?.text = "$currentBody\n\n${intervention.escalationReason}"
        }

        safeButton?.apply {
            text = intervention.safeExitLabel ?: "Go back to safety"
            setOnClickListener {
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                hide(via = "safe_exit")
            }
        }

        if (signature != currentSignature) {
            currentSignature = signature
            GuardianTelemetry.logPaymentOverlayShown(
                state = intervention.state,
                signalCount = intervention.matchedSignals.size,
            )
            countdownEndsAtMs = if (intervention.state == "red" && intervention.cooldownSeconds > 0) {
                System.currentTimeMillis() + (intervention.cooldownSeconds * 1000L)
            } else {
                0L
            }
            if (intervention.escalationRecommended) {
                recordEscalationEvent(appLabel, intervention, signature)
            }
        }

        continueButton?.setOnClickListener {
            storeApprovedRecipient(intervention)
            suppressedSignature = signature
            suppressedUntilMs = System.currentTimeMillis() + 15_000L
            hide(via = "continue")
        }
        updateContinueButton(intervention)
    }

    private fun updateContinueButton(intervention: PaymentIntervention) {
        val button = continueButton ?: return
        cancelCountdown()

        val applyLabel = {
            val remaining = if (countdownEndsAtMs <= 0L) {
                0
            } else {
                ((countdownEndsAtMs - System.currentTimeMillis()) / 1000L).toInt().coerceAtLeast(0)
            }
            if (intervention.state == "red" && remaining > 0) {
                button.isEnabled = false
                button.text = "Continue in ${remaining + 1}s"
            } else {
                button.isEnabled = true
                button.text = intervention.proceedLabel ?: "Yes, continue"
            }
        }

        applyLabel()
        if (intervention.state == "red" && countdownEndsAtMs > System.currentTimeMillis()) {
            countdownRunnable = object : Runnable {
                override fun run() {
                    applyLabel()
                    if (countdownEndsAtMs > System.currentTimeMillis()) {
                        handler.postDelayed(this, 500L)
                    }
                }
            }.also { handler.post(it) }
        }
    }

    private fun cancelCountdown() {
        countdownRunnable?.let(handler::removeCallbacks)
        countdownRunnable = null
    }

    private fun buildSignature(
        appLabel: String,
        intervention: PaymentIntervention,
    ): String {
        return listOf(
            appLabel,
            intervention.state,
            intervention.reviewTitle.orEmpty(),
            intervention.reviewBody.orEmpty(),
            intervention.detectedAmountHint.orEmpty(),
            intervention.detectedRecipientHint.orEmpty(),
            intervention.detectedUpiIdHint.orEmpty(),
        ).joinToString("|")
    }

    private fun storeApprovedRecipient(intervention: PaymentIntervention) {
        val recipientKey = when {
            !intervention.detectedUpiIdHint.isNullOrBlank() -> {
                intervention.detectedUpiIdHint.trim().lowercase(Locale.US)
            }
            !intervention.detectedRecipientHint.isNullOrBlank() -> {
                intervention.detectedRecipientHint
                    .trim()
                    .lowercase(Locale.US)
                    .replace("\\s+".toRegex(), " ")
            }
            else -> null
        } ?: return

        val prefs = service.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val current = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_APPROVED_RECIPIENTS, null),
        ).toMutableList()

        current.removeAll { it.equals(recipientKey, ignoreCase = true) }
        current.add(0, recipientKey)
        while (current.size > PaymentProtectionStore.MAX_APPROVED_RECIPIENTS) {
            current.removeAt(current.lastIndex)
        }

        prefs.edit()
            .putString(
                PaymentProtectionStore.KEY_APPROVED_RECIPIENTS,
                PaymentProtectionStore.encodeList(current),
            )
            .apply()
    }

    private fun recordEscalationEvent(
        appLabel: String,
        intervention: PaymentIntervention,
        signature: String,
    ) {
        val prefs = service.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val previousSignature = prefs.getString(
            PaymentProtectionStore.KEY_LAST_ESCALATION_SIGNATURE,
            null,
        )
        if (previousSignature == signature) {
            return
        }

        val now = System.currentTimeMillis()
        val eventId = "escalation-$now"
        prefs.edit()
            .putString(PaymentProtectionStore.KEY_LAST_ESCALATION_ID, eventId)
            .putString(PaymentProtectionStore.KEY_LAST_ESCALATION_SIGNATURE, signature)
            .putLong(PaymentProtectionStore.KEY_LAST_ESCALATION_AT_MS, now)
            .putString(PaymentProtectionStore.KEY_LAST_ESCALATION_APP_LABEL, appLabel)
            .putString(PaymentProtectionStore.KEY_LAST_ESCALATION_TITLE, intervention.reviewTitle)
            .putString(PaymentProtectionStore.KEY_LAST_ESCALATION_BODY, intervention.reviewBody)
            .putString(
                PaymentProtectionStore.KEY_LAST_ESCALATION_AMOUNT,
                intervention.detectedAmountHint,
            )
            .putString(
                PaymentProtectionStore.KEY_LAST_ESCALATION_RECIPIENT,
                intervention.detectedRecipientHint,
            )
            .putString(
                PaymentProtectionStore.KEY_LAST_ESCALATION_UPI_ID,
                intervention.detectedUpiIdHint,
            )
            .putBoolean(PaymentProtectionStore.KEY_LAST_ESCALATION_PENDING, true)
            .apply()
    }

    private fun space(heightDp: Int = 16): View {
        return View(service).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(heightDp),
            )
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            service.resources.displayMetrics,
        ).toInt()
    }
}
