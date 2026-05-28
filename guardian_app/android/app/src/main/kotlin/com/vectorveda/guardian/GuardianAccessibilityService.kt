package com.vectorveda.guardian

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
import org.json.JSONArray
import org.json.JSONObject

internal object PaymentProtectionStore {
    const val PREFS_NAME = "guardian_payment_protection"
    const val LIST_SEPARATOR = "\u001F"
    private const val MAP_ENTRY_SEPARATOR = "\u001E"
    private const val MAP_KEY_VALUE_SEPARATOR = "\u001D"
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
    const val KEY_RECIPIENT_CLEAN_INTERACTION_COUNTS = "recipient_clean_interaction_counts"
    const val KEY_RECIPIENT_RECENT_OUTCOMES = "recipient_recent_outcomes"
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
    const val KEY_ACCESSIBILITY_EVENT_SUMMARIES = "accessibility_event_summaries"
    const val KEY_HEALTH_ACCESSIBILITY_ENABLED = "health_accessibility_enabled"
    const val KEY_HEALTH_WAS_ACCESSIBILITY_ENABLED = "health_was_accessibility_enabled"
    const val KEY_HEALTH_DISABLED_STREAK_START_MS = "health_disabled_streak_start_ms"
    const val KEY_HEALTH_DISABLED_NOTIFICATION_AT_MS = "health_disabled_notification_at_ms"
    const val KEY_EMERGENCY_DISABLED = "emergency_disabled"
    const val MAX_APPROVED_RECIPIENTS = 8
    const val PROMOTION_REQUIRED_CLEAN_INTERACTIONS = 3
    const val RECENT_OUTCOME_WINDOW = 3

    val MONITORED_APPS = linkedMapOf(
        "com.google.android.apps.nbu.paisa.user" to "Google Pay",
        "com.phonepe.app" to "PhonePe",
        "net.one97.paytm" to "Paytm",
        "in.org.npci.upiapp" to "BHIM",
        "com.dreamplug.androidapp" to "CRED",
        "in.amazon.mShop.android.shopping" to "Amazon Pay",
        "com.whatsapp" to "WhatsApp",
        "com.mobikwik_new" to "MobiKwik",
        "com.slice.android" to "Slice",
    )

    fun encodeList(values: List<String>): String = values.joinToString(LIST_SEPARATOR)

    fun decodeList(raw: String?): List<String> {
        return raw
            ?.split(LIST_SEPARATOR)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
    }

    fun normalizeRecipientKey(upiIdHint: String?, recipientHint: String?): String? {
        return when {
            !upiIdHint.isNullOrBlank() -> {
                upiIdHint.trim().lowercase(Locale.US)
            }
            !recipientHint.isNullOrBlank() -> {
                recipientHint
                    .trim()
                    .lowercase(Locale.US)
                    .replace("\\s+".toRegex(), " ")
            }
            else -> null
        }
    }

    fun encodeIntMap(values: Map<String, Int>): String? {
        if (values.isEmpty()) {
            return null
        }
        return values.entries.joinToString(MAP_ENTRY_SEPARATOR) { entry ->
            "${entry.key}$MAP_KEY_VALUE_SEPARATOR${entry.value}"
        }
    }

    fun decodeIntMap(raw: String?): LinkedHashMap<String, Int> {
        val map = linkedMapOf<String, Int>()
        if (raw.isNullOrBlank()) {
            return map
        }
        raw.split(MAP_ENTRY_SEPARATOR).forEach { encoded ->
            val parts = encoded.split(MAP_KEY_VALUE_SEPARATOR, limit = 2)
            if (parts.size != 2) {
                return@forEach
            }
            val key = parts[0].trim()
            val value = parts[1].trim().toIntOrNull()
            if (key.isNotEmpty() && value != null) {
                map[key] = value
            }
        }
        return map
    }

    fun encodeOutcomeMap(values: Map<String, List<Boolean>>): String? {
        if (values.isEmpty()) {
            return null
        }
        return values.entries.joinToString(MAP_ENTRY_SEPARATOR) { entry ->
            val encodedOutcomes = entry.value.joinToString("") { if (it) "1" else "0" }
            "${entry.key}$MAP_KEY_VALUE_SEPARATOR$encodedOutcomes"
        }
    }

    fun decodeOutcomeMap(raw: String?): LinkedHashMap<String, List<Boolean>> {
        val map = linkedMapOf<String, List<Boolean>>()
        if (raw.isNullOrBlank()) {
            return map
        }
        raw.split(MAP_ENTRY_SEPARATOR).forEach { encoded ->
            val parts = encoded.split(MAP_KEY_VALUE_SEPARATOR, limit = 2)
            if (parts.size != 2) {
                return@forEach
            }
            val key = parts[0].trim()
            val value = parts[1].trim()
            if (key.isEmpty()) {
                return@forEach
            }
            val outcomes = value.mapNotNull { marker ->
                when (marker) {
                    '1' -> true
                    '0' -> false
                    else -> null
                }
            }.takeLast(RECENT_OUTCOME_WINDOW)
            if (outcomes.isNotEmpty()) {
                map[key] = outcomes
            }
        }
        return map
    }

    data class RecipientApprovalUpdate(
        val approvedRecipients: List<String>,
        val cleanInteractionCounts: Map<String, Int>,
        val recentOutcomes: Map<String, List<Boolean>>,
    )

    fun updateRecipientApprovalOnContinue(
        state: String,
        recipientKey: String,
        approvedRecipients: List<String>,
        cleanInteractionCounts: Map<String, Int>,
        recentOutcomes: Map<String, List<Boolean>>,
    ): RecipientApprovalUpdate {
        val normalizedState = state.trim().lowercase(Locale.US)
        val updatedApproved = approvedRecipients.toMutableList()
        val updatedCounts = cleanInteractionCounts.toMutableMap()
        val updatedOutcomes = recentOutcomes.toMutableMap()

        fun addApprovedRecipient() {
            updatedApproved.removeAll { it.equals(recipientKey, ignoreCase = true) }
            updatedApproved.add(0, recipientKey)
            while (updatedApproved.size > MAX_APPROVED_RECIPIENTS) {
                updatedApproved.removeAt(updatedApproved.lastIndex)
            }
        }

        fun appendOutcome(isClean: Boolean): List<Boolean> {
            val current = updatedOutcomes[recipientKey].orEmpty()
            val next = (current + isClean).takeLast(RECENT_OUTCOME_WINDOW)
            updatedOutcomes[recipientKey] = next
            return next
        }

        if (normalizedState == "red") {
            updatedCounts[recipientKey] = 0
            appendOutcome(isClean = false)
            return RecipientApprovalUpdate(
                approvedRecipients = updatedApproved,
                cleanInteractionCounts = updatedCounts,
                recentOutcomes = updatedOutcomes,
            )
        }

        val hasRedHistory = updatedCounts.containsKey(recipientKey) ||
            updatedOutcomes.containsKey(recipientKey)
        if (!hasRedHistory) {
            addApprovedRecipient()
            return RecipientApprovalUpdate(
                approvedRecipients = updatedApproved,
                cleanInteractionCounts = updatedCounts,
                recentOutcomes = updatedOutcomes,
            )
        }

        val nextCount = (updatedCounts[recipientKey] ?: 0) + 1
        updatedCounts[recipientKey] = nextCount
        val recent = appendOutcome(isClean = true)
        if (
            nextCount >= PROMOTION_REQUIRED_CLEAN_INTERACTIONS &&
            recent.size == RECENT_OUTCOME_WINDOW &&
            recent.all { it }
        ) {
            addApprovedRecipient()
            updatedCounts.remove(recipientKey)
            updatedOutcomes.remove(recipientKey)
        }

        return RecipientApprovalUpdate(
            approvedRecipients = updatedApproved,
            cleanInteractionCounts = updatedCounts,
            recentOutcomes = updatedOutcomes,
        )
    }
}

private fun PaymentIntervention.isOverlayCandidate(): Boolean {
    return paymentContextDetected && (state == "amber" || state == "red")
}

class GuardianAccessibilityService : AccessibilityService() {
    private lateinit var overlayController: PaymentInterventionOverlayController
    private val classifier = PaymentInterventionClassifier()
    private val urlReputationStore by lazy { UrlReputationStore(this) }
    private val urlThreatCache = LinkedHashMap<String, String>(32, 0.75f, true)

    override fun onServiceConnected() {
        super.onServiceConnected()
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)) {
            return
        }
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
        val prefs = getSharedPreferences(PaymentProtectionStore.PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)) {
            if (::overlayController.isInitialized) {
                overlayController.hide(via = "app_backgrounded")
            }
            return
        }
        val previousRecipientHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_RECIPIENT, null)
        val previousUpiIdHint = prefs.getString(PaymentProtectionStore.KEY_DETECTED_UPI_ID, null)
        val approvedRecipients = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_APPROVED_RECIPIENTS, null),
        )
        val visibleUrlThreat = lookupVisibleUrlThreat(extractVisibleUrl(screenChunks))
        val enrichedIntervention = classifier.analyze(
            appLabel = appLabel,
            screenChunks = screenChunks,
            approvedRecipients = approvedRecipients,
            previousRecipientHint = previousRecipientHint,
            previousUpiIdHint = previousUpiIdHint,
            visibleUrlThreat = visibleUrlThreat,
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
        appendAccessibilityEventSummary(
            prefs = prefs,
            packageName = packageName,
            appLabel = appLabel,
            intervention = enrichedIntervention,
        )

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

    private fun extractVisibleUrl(screenChunks: List<String>): String? {
        for (chunk in screenChunks) {
            val match = URL_PATTERN.find(chunk) ?: continue
            val candidate = match.value.trim().trimEnd('.', ',', ';', ':', ')', ']')
            if (candidate.isNotEmpty()) {
                return candidate
            }
        }
        return null
    }

    private fun lookupVisibleUrlThreat(visibleUrl: String?): String? {
        val raw = visibleUrl?.trim()
        if (raw.isNullOrEmpty()) {
            return null
        }
        val normalizedUrl = UrlReputationStore.normalizeUrl(raw) ?: raw.lowercase(Locale.US)
        val cached = synchronized(urlThreatCache) { urlThreatCache[normalizedUrl] }
        if (cached != null) {
            return cached
        }
        val verdict = urlReputationStore.checkUrl(normalizedUrl)
        synchronized(urlThreatCache) {
            urlThreatCache[normalizedUrl] = verdict
            while (urlThreatCache.size > MAX_URL_THREAT_CACHE_SIZE) {
                val eldest = urlThreatCache.entries.iterator().next()
                urlThreatCache.remove(eldest.key)
            }
        }
        return verdict
    }

    private fun appendAccessibilityEventSummary(
        prefs: android.content.SharedPreferences,
        packageName: String,
        appLabel: String,
        intervention: PaymentIntervention,
    ) {
        val array = runCatching {
            JSONArray(
                prefs.getString(PaymentProtectionStore.KEY_ACCESSIBILITY_EVENT_SUMMARIES, "[]"),
            )
        }.getOrElse { JSONArray() }

        val updated = JSONArray()
        updated.put(
            JSONObject()
                .put("timestampMs", System.currentTimeMillis())
                .put("packageName", packageName)
                .put("appLabel", appLabel)
                .put("amountHint", intervention.detectedAmountHint ?: "")
                .put("recipientHint", intervention.detectedRecipientHint ?: "")
                .put("upiIdHint", intervention.detectedUpiIdHint ?: "")
                .put("classifierState", intervention.state)
                .put("signals", JSONArray(intervention.matchedSignals)),
        )

        var copied = 0
        var index = 0
        while (index < array.length() && copied < MAX_ACCESSIBILITY_SUMMARIES - 1) {
            val existing = array.optJSONObject(index)
            if (existing != null) {
                updated.put(existing)
                copied += 1
            }
            index += 1
        }

        prefs.edit()
            .putString(PaymentProtectionStore.KEY_ACCESSIBILITY_EVENT_SUMMARIES, updated.toString())
            .apply()
    }

    companion object {
        private const val MAX_ACCESSIBILITY_SUMMARIES = 20
        private const val MAX_URL_THREAT_CACHE_SIZE = 32
        private val URL_PATTERN = Regex(
            """(?i)\b(?:https?://)?(?:www\.)?[a-z0-9][a-z0-9-]{0,62}(?:\.[a-z0-9][a-z0-9-]{0,62})+(?:/[^\s]*)?""",
        )
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
        val recipientKey = PaymentProtectionStore.normalizeRecipientKey(
            upiIdHint = intervention.detectedUpiIdHint,
            recipientHint = intervention.detectedRecipientHint,
        ) ?: return

        val prefs = service.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val currentApproved = PaymentProtectionStore.decodeList(
            prefs.getString(PaymentProtectionStore.KEY_APPROVED_RECIPIENTS, null),
        )
        val currentCleanCounts = PaymentProtectionStore.decodeIntMap(
            prefs.getString(PaymentProtectionStore.KEY_RECIPIENT_CLEAN_INTERACTION_COUNTS, null),
        )
        val currentRecentOutcomes = PaymentProtectionStore.decodeOutcomeMap(
            prefs.getString(PaymentProtectionStore.KEY_RECIPIENT_RECENT_OUTCOMES, null),
        )
        val updated = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = intervention.state,
            recipientKey = recipientKey,
            approvedRecipients = currentApproved,
            cleanInteractionCounts = currentCleanCounts,
            recentOutcomes = currentRecentOutcomes,
        )

        prefs.edit()
            .putString(
                PaymentProtectionStore.KEY_APPROVED_RECIPIENTS,
                PaymentProtectionStore.encodeList(updated.approvedRecipients),
            )
            .putString(
                PaymentProtectionStore.KEY_RECIPIENT_CLEAN_INTERACTION_COUNTS,
                PaymentProtectionStore.encodeIntMap(updated.cleanInteractionCounts),
            )
            .putString(
                PaymentProtectionStore.KEY_RECIPIENT_RECENT_OUTCOMES,
                PaymentProtectionStore.encodeOutcomeMap(updated.recentOutcomes),
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

