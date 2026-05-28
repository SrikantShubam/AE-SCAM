package com.vectorveda.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GuardianTelemetryTest {
    @Test
    fun `scam notification telemetry normalizes category and language`() {
        var capturedEventName: String? = null
        var capturedFields: Map<String, String>? = null
        GuardianTelemetry.testEventSink = { eventName, fields ->
            capturedEventName = eventName
            capturedFields = fields
        }

        try {
            GuardianTelemetry.logScamNotificationPosted(
                category = "com.whatsapp",
                language = "EN-IN",
            )
        } finally {
            GuardianTelemetry.testEventSink = null
        }

        assertEquals("scam_notification_posted", capturedEventName)
        val fields = capturedFields
        assertNotNull(fields)
        assertEquals("com_whatsapp", fields!!["category"])
        assertEquals("en-in", fields["language"])
        assertTrue(fields.keys.containsAll(setOf("category", "language")))
    }
}
