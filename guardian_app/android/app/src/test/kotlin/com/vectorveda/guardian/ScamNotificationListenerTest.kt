package com.vectorveda.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ScamNotificationListenerTest {
    @Test
    fun `accepted monitored notification emits telemetry through listener path`() {
        val payload = ScamNotificationExtractor.toPayloadOrNull(
            sourcePackage = "com.whatsapp",
            appPackageName = "com.vectorveda.guardian",
            sender = "BANK",
            text = "click this link now",
            bigText = null,
            receivedAtMs = 123L,
        )
        requireNotNull(payload)

        var capturedCategory: String? = null
        var capturedLanguage: String? = null
        val serializedPayload =
            """{"source_package":"com.whatsapp","sender":"BANK","message_body":"click this link now","received_at_ms":123}"""
        val queued = ScamNotificationListener.handleAcceptedPayload(
            sourcePackage = "com.whatsapp",
            payload = payload,
            languageTag = "en-IN",
            existingQueueJson = null,
            serializePayload = { serializedPayload },
            emitTelemetry = { category, language ->
                capturedCategory = category
                capturedLanguage = language
            },
        )

        assertEquals("com.whatsapp", capturedCategory)
        assertEquals("en-IN", capturedLanguage)

        val consumed = ScamNotificationPayloadQueueCodec.consumeAll(queued)
        assertEquals(1, consumed.size)
        assertEquals(serializedPayload, consumed.single())
        assertTrue(consumed.isNotEmpty())
    }
}
