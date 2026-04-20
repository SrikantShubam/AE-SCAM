package com.guardian.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScamNotificationExtractorTest {
    @Test
    fun `filters messaging package list and skips own package`() {
        assertTrue(
            ScamNotificationExtractor.shouldProcessPackage(
                sourcePackage = "com.whatsapp",
                appPackageName = "com.guardian.guardian",
            ),
        )
        assertFalse(
            ScamNotificationExtractor.shouldProcessPackage(
                sourcePackage = "com.guardian.guardian",
                appPackageName = "com.guardian.guardian",
            ),
        )
        assertFalse(
            ScamNotificationExtractor.shouldProcessPackage(
                sourcePackage = "com.random.app",
                appPackageName = "com.guardian.guardian",
            ),
        )
    }

    @Test
    fun `prefers bigText over text and trims whitespace`() {
        val payload = ScamNotificationExtractor.toPayloadOrNull(
            sourcePackage = "com.whatsapp",
            appPackageName = "com.guardian.guardian",
            sender = " BANK-ALERT ",
            text = "fallback text",
            bigText = "  detailed message body  ",
            receivedAtMs = 123L,
        )

        assertNotNull(payload)
        assertEquals("com.whatsapp", payload!!.sourcePackage)
        assertEquals("BANK-ALERT", payload.sender)
        assertEquals("detailed message body", payload.messageBody)
        assertEquals(123L, payload.receivedAtMs)
    }

    @Test
    fun `falls back to text when bigText is missing`() {
        val payload = ScamNotificationExtractor.toPayloadOrNull(
            sourcePackage = "com.android.mms",
            appPackageName = "com.guardian.guardian",
            sender = null,
            text = "  otp code 123456  ",
            bigText = null,
            receivedAtMs = 456L,
        )

        assertNotNull(payload)
        assertEquals("otp code 123456", payload!!.messageBody)
        assertNull(payload.sender)
    }
}
