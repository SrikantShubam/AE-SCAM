package com.guardian.guardian

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MedicationAlarmSchedulingStrategyTest {
    @Test
    fun `uses setWindow fallback for known OEMs`() {
        assertTrue(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback("xiaomi"))
        assertTrue(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback("Realme"))
        assertTrue(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback("VIVO"))
    }

    @Test
    fun `does not force fallback for non-listed OEMs`() {
        assertFalse(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback("google"))
        assertFalse(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback("samsung"))
        assertFalse(MedicationAlarmSchedulingStrategy.shouldUseWindowFallback(null))
    }

    @Test
    fun `fallback window length is 15 minutes`() {
        assertTrue(MedicationAlarmSchedulingStrategy.fallbackWindowLengthMs == 15 * 60 * 1000L)
    }
}
