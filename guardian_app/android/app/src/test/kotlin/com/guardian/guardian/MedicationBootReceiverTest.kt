package com.guardian.guardian

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MedicationBootReceiverTest {
    @Test
    fun `accepts required boot and clock actions`() {
        assertTrue(MedicationBootReceiver.shouldHandleAction("android.intent.action.BOOT_COMPLETED"))
        assertTrue(MedicationBootReceiver.shouldHandleAction("android.intent.action.MY_PACKAGE_REPLACED"))
        assertTrue(MedicationBootReceiver.shouldHandleAction("android.intent.action.PACKAGE_REPLACED"))
        assertTrue(MedicationBootReceiver.shouldHandleAction("android.intent.action.TIME_SET"))
        assertTrue(MedicationBootReceiver.shouldHandleAction("android.intent.action.TIMEZONE_CHANGED"))
    }

    @Test
    fun `ignores unrelated actions`() {
        assertFalse(MedicationBootReceiver.shouldHandleAction("android.intent.action.USER_PRESENT"))
        assertFalse(MedicationBootReceiver.shouldHandleAction(null))
    }

    @Test
    fun `handleAction enqueues one-shot and periodic work for supported action`() {
        var oneShotCalls = 0
        var periodicCalls = 0

        MedicationBootReceiver.handleAction(
            action = "android.intent.action.BOOT_COMPLETED",
            enqueueOneTime = { oneShotCalls += 1 },
            ensurePeriodic = { periodicCalls += 1 },
        )

        assertTrue(oneShotCalls == 1)
        assertTrue(periodicCalls == 1)
    }

    @Test
    fun `handleAction ignores unsupported action`() {
        var oneShotCalls = 0
        var periodicCalls = 0

        MedicationBootReceiver.handleAction(
            action = "android.intent.action.USER_PRESENT",
            enqueueOneTime = { oneShotCalls += 1 },
            ensurePeriodic = { periodicCalls += 1 },
        )

        assertTrue(oneShotCalls == 0)
        assertTrue(periodicCalls == 0)
    }
}
