package com.guardian.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentProtectionStoreTest {
    @Test
    fun `amber recipient without red history is approved immediately`() {
        val updated = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = "anita@upi",
            approvedRecipients = emptyList(),
            cleanInteractionCounts = emptyMap(),
            recentOutcomes = emptyMap(),
        )

        assertEquals(listOf("anita@upi"), updated.approvedRecipients)
        assertTrue(updated.cleanInteractionCounts.isEmpty())
        assertTrue(updated.recentOutcomes.isEmpty())
    }

    @Test
    fun `red bypass does not auto-approve and starts probation tracking`() {
        val updated = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "red",
            recipientKey = "unknown@upi",
            approvedRecipients = emptyList(),
            cleanInteractionCounts = emptyMap(),
            recentOutcomes = emptyMap(),
        )

        assertTrue(updated.approvedRecipients.isEmpty())
        assertEquals(0, updated.cleanInteractionCounts["unknown@upi"])
        assertEquals(listOf(false), updated.recentOutcomes["unknown@upi"])
    }

    @Test
    fun `recipient from red history is promoted after three consecutive non-red interactions`() {
        val key = "risky@upi"
        val afterRed = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "red",
            recipientKey = key,
            approvedRecipients = emptyList(),
            cleanInteractionCounts = emptyMap(),
            recentOutcomes = emptyMap(),
        )
        val afterFirstAmber = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterRed.approvedRecipients,
            cleanInteractionCounts = afterRed.cleanInteractionCounts,
            recentOutcomes = afterRed.recentOutcomes,
        )
        val afterSecondAmber = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterFirstAmber.approvedRecipients,
            cleanInteractionCounts = afterFirstAmber.cleanInteractionCounts,
            recentOutcomes = afterFirstAmber.recentOutcomes,
        )
        val afterThirdAmber = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterSecondAmber.approvedRecipients,
            cleanInteractionCounts = afterSecondAmber.cleanInteractionCounts,
            recentOutcomes = afterSecondAmber.recentOutcomes,
        )

        assertTrue(afterSecondAmber.approvedRecipients.isEmpty())
        assertEquals(listOf(key), afterThirdAmber.approvedRecipients)
        assertFalse(afterThirdAmber.cleanInteractionCounts.containsKey(key))
        assertFalse(afterThirdAmber.recentOutcomes.containsKey(key))
    }

    @Test
    fun `new red event resets clean streak and requires three new clean interactions`() {
        val key = "reset@upi"
        val afterRed = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "red",
            recipientKey = key,
            approvedRecipients = emptyList(),
            cleanInteractionCounts = emptyMap(),
            recentOutcomes = emptyMap(),
        )
        val afterAmber = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterRed.approvedRecipients,
            cleanInteractionCounts = afterRed.cleanInteractionCounts,
            recentOutcomes = afterRed.recentOutcomes,
        )
        val afterSecondRed = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "red",
            recipientKey = key,
            approvedRecipients = afterAmber.approvedRecipients,
            cleanInteractionCounts = afterAmber.cleanInteractionCounts,
            recentOutcomes = afterAmber.recentOutcomes,
        )
        val afterCleanOne = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterSecondRed.approvedRecipients,
            cleanInteractionCounts = afterSecondRed.cleanInteractionCounts,
            recentOutcomes = afterSecondRed.recentOutcomes,
        )
        val afterCleanTwo = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterCleanOne.approvedRecipients,
            cleanInteractionCounts = afterCleanOne.cleanInteractionCounts,
            recentOutcomes = afterCleanOne.recentOutcomes,
        )
        val afterCleanThree = PaymentProtectionStore.updateRecipientApprovalOnContinue(
            state = "amber",
            recipientKey = key,
            approvedRecipients = afterCleanTwo.approvedRecipients,
            cleanInteractionCounts = afterCleanTwo.cleanInteractionCounts,
            recentOutcomes = afterCleanTwo.recentOutcomes,
        )

        assertTrue(afterCleanTwo.approvedRecipients.isEmpty())
        assertEquals(listOf(key), afterCleanThree.approvedRecipients)
    }
}
