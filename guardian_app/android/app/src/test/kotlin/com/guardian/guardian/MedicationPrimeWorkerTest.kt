package com.guardian.guardian

import androidx.work.ListenableWorker
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MedicationPrimeWorkerTest {
    @Test
    fun `executePrimeWindow schedules 48h window and returns success`() {
        var capturedFrom: Long? = null
        var capturedUntil: Long? = null

        val result = MedicationPrimeWorker.executePrimeWindow(
            nowEpochMs = 1_700_000_000_000L,
            runPrime = { fromEpochMs, untilEpochMs ->
                capturedFrom = fromEpochMs
                capturedUntil = untilEpochMs
            },
        )

        assertEquals(1_700_000_000_000L, capturedFrom)
        assertEquals(1_700_000_000_000L + MedicationPrimeWorker.windowDurationMs, capturedUntil)
        assertTrue(result is ListenableWorker.Result.Success)
    }

    @Test
    fun `executePrimeWindow returns retry when native prime throws`() {
        val result = MedicationPrimeWorker.executePrimeWindow(
            nowEpochMs = 1_700_000_000_000L,
            runPrime = { _, _ -> throw IllegalStateException("db unavailable") },
        )

        assertTrue(result is ListenableWorker.Result.Retry)
    }
}
