package com.vectorveda.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ScamNotificationPayloadQueueCodecTest {
    @Test
    fun `append stores payloads as ordered queue`() {
        val first = """{"message_body":"one"}"""
        val second = """{"message_body":"two"}"""

        val queuedOnce = ScamNotificationPayloadQueueCodec.appendPayload(null, first)
        val queuedTwice = ScamNotificationPayloadQueueCodec.appendPayload(queuedOnce, second)
        val consumed = ScamNotificationPayloadQueueCodec.consumeAll(queuedTwice)

        assertEquals(listOf(first, second), consumed)
    }

    @Test
    fun `consume supports legacy single payload string`() {
        val legacy = """{"message_body":"legacy"}"""
        val consumed = ScamNotificationPayloadQueueCodec.consumeAll(legacy)

        assertEquals(listOf(legacy), consumed)
    }

    @Test
    fun `consume returns empty list for blank input`() {
        assertTrue(ScamNotificationPayloadQueueCodec.consumeAll(null).isEmpty())
        assertTrue(ScamNotificationPayloadQueueCodec.consumeAll("   ").isEmpty())
    }
}

