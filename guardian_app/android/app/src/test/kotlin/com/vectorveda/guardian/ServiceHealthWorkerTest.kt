package com.vectorveda.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ServiceHealthWorkerTest {
    @Test
    fun `transition from enabled to disabled triggers notification and starts streak`() {
        val nowMs = 1_000_000L
        val result = ServiceHealthWorker.evaluateTransition(
            nowMs = nowMs,
            isEnabled = false,
            wasEnabled = true,
            disabledStreakStartMs = 0L,
            lastNotificationAtMs = 0L,
        )

        assertTrue(result.shouldNotify)
        assertFalse(result.nextWasEnabled)
        assertEquals(nowMs, result.nextDisabledStreakStartMs)
        assertEquals(nowMs, result.nextLastNotificationAtMs)
    }

    @Test
    fun `disabled streak suppresses notification before dedupe window`() {
        val streakStart = 1_000_000L
        val notifiedAt = 1_050_000L
        val result = ServiceHealthWorker.evaluateTransition(
            nowMs = notifiedAt + ServiceHealthWorker.disabledDedupWindowMs - 1L,
            isEnabled = false,
            wasEnabled = false,
            disabledStreakStartMs = streakStart,
            lastNotificationAtMs = notifiedAt,
        )

        assertFalse(result.shouldNotify)
        assertEquals(streakStart, result.nextDisabledStreakStartMs)
        assertEquals(notifiedAt, result.nextLastNotificationAtMs)
    }

    @Test
    fun `disabled streak allows notification after dedupe window`() {
        val streakStart = 1_000_000L
        val notifiedAt = 1_050_000L
        val nowMs = notifiedAt + ServiceHealthWorker.disabledDedupWindowMs
        val result = ServiceHealthWorker.evaluateTransition(
            nowMs = nowMs,
            isEnabled = false,
            wasEnabled = false,
            disabledStreakStartMs = streakStart,
            lastNotificationAtMs = notifiedAt,
        )

        assertTrue(result.shouldNotify)
        assertEquals(streakStart, result.nextDisabledStreakStartMs)
        assertEquals(nowMs, result.nextLastNotificationAtMs)
    }

    @Test
    fun `re-enabled service clears streak and notification tracking`() {
        val result = ServiceHealthWorker.evaluateTransition(
            nowMs = 2_000_000L,
            isEnabled = true,
            wasEnabled = false,
            disabledStreakStartMs = 1_000_000L,
            lastNotificationAtMs = 1_500_000L,
        )

        assertFalse(result.shouldNotify)
        assertTrue(result.nextWasEnabled)
        assertEquals(0L, result.nextDisabledStreakStartMs)
        assertEquals(0L, result.nextLastNotificationAtMs)
    }
}

