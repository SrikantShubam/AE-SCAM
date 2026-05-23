package com.guardian.guardian

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class MedicationPrimeWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        if (prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)) {
            return Result.success()
        }
        return executePrimeWindow(
            nowEpochMs = System.currentTimeMillis(),
            runPrime = { fromEpochMs, untilEpochMs ->
                MedicationAlarmNativeScheduler.primeWindow(
                    context = applicationContext,
                    fromEpochMs = fromEpochMs,
                    untilEpochMs = untilEpochMs,
                )
            },
        )
    }

    companion object {
        internal const val windowDurationMs = 48L * 60L * 60L * 1000L

        internal fun executePrimeWindow(
            nowEpochMs: Long,
            runPrime: (fromEpochMs: Long, untilEpochMs: Long) -> Unit,
        ): Result {
            return try {
                runPrime(nowEpochMs, nowEpochMs + windowDurationMs)
                Result.success()
            } catch (_: Exception) {
                Result.retry()
            }
        }
    }
}
