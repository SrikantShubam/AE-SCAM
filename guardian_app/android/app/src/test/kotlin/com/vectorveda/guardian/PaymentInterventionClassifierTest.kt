package com.vectorveda.guardian

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentInterventionClassifierTest {
    private val classifier = PaymentInterventionClassifier()

    @Test
    fun `flagged visible url forces red state and phishing reason`() {
        val result = classifier.analyze(
            appLabel = "Google Pay",
            screenChunks = listOf(
                "Pay now",
                "To",
                "Anita Stores",
                "Amount",
                "Rs 500",
                "https://bonus-pay.test/claim",
            ),
            approvedRecipients = listOf("anita stores"),
            previousRecipientHint = "Anita Stores",
            previousUpiIdHint = null,
            visibleUrlThreat = UrlReputationStore.THREAT_PHISHING,
        )

        assertEquals("red", result.state)
        assertTrue(result.matchedSignals.contains("url_reputation_flagged"))
        assertTrue(result.reasons.contains("This link appears on a known phishing list."))
        assertTrue(result.reviewBody.orEmpty().contains("This link appears on a known phishing list."))
    }

    @Test
    fun `fixture corpus validates expected state and flags`() {
        val fixtures = listOf(
            "01_gpay_legit_known_recipient.json",
            "02_gpay_amber_new_recipient.json",
            "03_gpay_red_collect_request.json",
            "04_phonepe_legit_known_upi.json",
            "05_phonepe_red_high_amount_suspicious.json",
            "06_paytm_legit_known_recipient.json",
            "07_paytm_amber_new_recipient.json",
            "08_bhim_legit_known_recipient.json",
            "09_bhim_red_recipient_changed_mid_flow.json",
            "10_cred_legit_known_recipient.json",
            "11_whatsapp_pay_legit_known_recipient.json",
            "12_monitoring_only.json",
        )
        assertTrue("fixture corpus must include at least 12 fixtures", fixtures.size >= 12)

        fixtures.forEach { fixtureName ->
            val fixture = loadFixture(fixtureName)
            val result = classifier.analyze(
                appLabel = fixture.appLabel,
                screenChunks = fixture.screenChunks,
                approvedRecipients = fixture.approvedRecipients,
                previousRecipientHint = fixture.previousRecipientHint,
                previousUpiIdHint = fixture.previousUpiHint,
            )

            assertEquals("$fixtureName state", fixture.expectedState, result.state)
            assertEquals(
                "$fixtureName payment_context_detected",
                fixture.expectedFlags.paymentContextDetected,
                result.paymentContextDetected,
            )
            assertEquals(
                "$fixtureName has_high_amount",
                fixture.expectedFlags.hasHighAmount,
                result.hasHighAmount,
            )
            assertEquals(
                "$fixtureName has_suspicious_language",
                fixture.expectedFlags.hasSuspiciousLanguage,
                result.hasSuspiciousLanguage,
            )
            assertEquals(
                "$fixtureName recipient_recently_changed",
                fixture.expectedFlags.recipientRecentlyChanged,
                result.recipientRecentlyChanged,
            )
            assertEquals(
                "$fixtureName recipient_known",
                fixture.expectedFlags.recipientKnown,
                result.recipientKnown,
            )
            assertEquals(
                "$fixtureName escalation_recommended",
                fixture.expectedFlags.escalationRecommended,
                result.escalationRecommended,
            )

            fixture.expectedFlags.matchedSignalsContains.forEach { expectedSignal ->
                assertTrue(
                    "$fixtureName expected matched signal: $expectedSignal",
                    result.matchedSignals.contains(expectedSignal),
                )
            }
        }
    }

    private fun loadFixture(fileName: String): Fixture {
        val resourceName = "payment_fixtures/$fileName"
        val loader = requireNotNull(javaClass.classLoader) {
            "missing classloader for fixture lookup"
        }
        val url = loader.getResource(resourceName)
            ?: error("missing fixture resource: $resourceName")
        val rawJson = url.openStream().bufferedReader().use { it.readText() }
        val root = JsonParser.parseString(rawJson).asJsonObject
        val flags = root.getAsObjectOrNull("expected_flags")
            ?: error("fixture missing expected_flags: $fileName")
        val appLabel = root.optionalString("app_label").orEmpty()
        if (appLabel.isEmpty()) {
            error("fixture missing app_label: $fileName")
        }
        val screenChunks = root.getAsArrayOrNull("screen_chunks")
            ?: error("fixture missing screen_chunks: $fileName")
        val approvedRecipients = root.getAsArrayOrNull("approved_recipients")
            ?: error("fixture missing approved_recipients: $fileName")
        val expectedState = root.optionalString("expected_state").orEmpty()
        if (expectedState.isEmpty()) {
            error("fixture missing expected_state: $fileName")
        }
        return Fixture(
            appLabel = appLabel,
            screenChunks = screenChunks.toStringList(),
            approvedRecipients = approvedRecipients.toStringList(),
            previousRecipientHint = root.optionalString("previous_recipient_hint"),
            previousUpiHint = root.optionalString("previous_upi_hint"),
            expectedState = expectedState,
            expectedFlags = ExpectedFlags(
                paymentContextDetected = flags.get("payment_context_detected").asBoolean,
                hasHighAmount = flags.get("has_high_amount").asBoolean,
                hasSuspiciousLanguage = flags.get("has_suspicious_language").asBoolean,
                recipientRecentlyChanged = flags.get("recipient_recently_changed").asBoolean,
                recipientKnown = flags.get("recipient_known").asBoolean,
                escalationRecommended = flags.get("escalation_recommended").asBoolean,
                matchedSignalsContains = flags.getAsArrayOrNull("matched_signals_contains")
                    ?.toStringList()
                    ?: emptyList(),
            ),
        )
    }

    private data class Fixture(
        val appLabel: String,
        val screenChunks: List<String>,
        val approvedRecipients: List<String>,
        val previousRecipientHint: String?,
        val previousUpiHint: String?,
        val expectedState: String,
        val expectedFlags: ExpectedFlags,
    )

    private data class ExpectedFlags(
        val paymentContextDetected: Boolean,
        val hasHighAmount: Boolean,
        val hasSuspiciousLanguage: Boolean,
        val recipientRecentlyChanged: Boolean,
        val recipientKnown: Boolean,
        val escalationRecommended: Boolean,
        val matchedSignalsContains: List<String>,
    )

    private fun JsonArray.toStringList(): List<String> {
        val list = ArrayList<String>(size())
        for (index in 0 until size()) {
            list.add(get(index).asString)
        }
        return list
    }

    private fun JsonObject.optionalString(key: String): String? {
        val value = get(key)
        if (value == null || value.isJsonNull) {
            return null
        }
        val normalized = value.asString.trim()
        return normalized.ifEmpty { null }
    }

    private fun JsonObject.getAsObjectOrNull(key: String): JsonObject? {
        val value = get(key) ?: return null
        if (!value.isJsonObject) {
            return null
        }
        return value.asJsonObject
    }

    private fun JsonObject.getAsArrayOrNull(key: String): JsonArray? {
        val value = get(key) ?: return null
        if (!value.isJsonArray) {
            return null
        }
        return value.asJsonArray
    }
}

