package com.guardian.guardian

import java.util.Locale
import java.util.regex.Pattern

internal data class PaymentIntervention(
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

internal class PaymentInterventionClassifier {
    private data class ScreenSignal(
        val id: String,
        val reason: String,
    )

    fun analyze(
        appLabel: String,
        screenChunks: List<String>,
        approvedRecipients: List<String>,
        previousRecipientHint: String?,
        previousUpiIdHint: String?,
        visibleUrlThreat: String? = null,
    ): PaymentIntervention {
        val baseIntervention = analyzeScreen(
            appLabel = appLabel,
            screenChunks = screenChunks,
        )
        val urlAdjustedIntervention = maybePromoteForFlaggedUrl(
            intervention = baseIntervention,
            appLabel = appLabel,
            visibleUrlThreat = visibleUrlThreat,
        )
        val adjustedIntervention = maybePromoteForRecipientChange(
            intervention = urlAdjustedIntervention,
            appLabel = appLabel,
            previousRecipientHint = previousRecipientHint,
            previousUpiIdHint = previousUpiIdHint,
        )
        return applyRecipientHistoryAndEscalation(
            intervention = adjustedIntervention,
            appLabel = appLabel,
            approvedRecipients = approvedRecipients,
        )
    }

    private fun maybePromoteForFlaggedUrl(
        intervention: PaymentIntervention,
        appLabel: String,
        visibleUrlThreat: String?,
    ): PaymentIntervention {
        if (!intervention.paymentContextDetected || !isFlaggedUrlThreat(visibleUrlThreat)) {
            return intervention
        }

        val updatedSignals = intervention.matchedSignals.toMutableList()
        if (!updatedSignals.contains("url_reputation_flagged")) {
            updatedSignals.add("url_reputation_flagged")
        }

        val updatedReasons = intervention.reasons.toMutableList()
        if (!updatedReasons.contains(KNOWN_PHISHING_REASON)) {
            updatedReasons.add(KNOWN_PHISHING_REASON)
        }

        val updatedReviewTitle = buildReviewTitle(
            appLabel = appLabel,
            amountHint = intervention.detectedAmountHint,
            recipientHint = intervention.detectedRecipientHint,
            upiIdHint = intervention.detectedUpiIdHint,
            isRed = true,
            hasHighAmount = intervention.hasHighAmount,
            hasSuspiciousLanguage = intervention.hasSuspiciousLanguage,
            recipientRecentlyChanged = intervention.recipientRecentlyChanged,
            recipientKnown = intervention.recipientKnown,
        )
        val baseReviewBody = buildReviewBody(
            appLabel = appLabel,
            amountHint = intervention.detectedAmountHint,
            recipientHint = intervention.detectedRecipientHint,
            upiIdHint = intervention.detectedUpiIdHint,
            isRed = true,
            hasHighAmount = intervention.hasHighAmount,
            hasSuspiciousLanguage = intervention.hasSuspiciousLanguage,
            recipientRecentlyChanged = intervention.recipientRecentlyChanged,
            recipientKnown = intervention.recipientKnown,
        )
        val updatedReviewBody = if (baseReviewBody.contains(KNOWN_PHISHING_REASON)) {
            baseReviewBody
        } else {
            "$baseReviewBody $KNOWN_PHISHING_REASON"
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
        )
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

    private fun normalizeWhitespace(value: String): String {
        return value.replace("\\s+".toRegex(), " ").trim()
    }

    private fun isFlaggedUrlThreat(visibleUrlThreat: String?): Boolean {
        return when (visibleUrlThreat?.trim()?.lowercase(Locale.US)) {
            UrlReputationStore.THREAT_PHISHING,
            UrlReputationStore.THREAT_MALWARE,
            UrlReputationStore.THREAT_UNWANTED,
            -> true

            else -> false
        }
    }

    companion object {
        private const val KNOWN_PHISHING_REASON = "This link appears on a known phishing list."

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
}
