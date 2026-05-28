package com.vectorveda.guardian

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object MedicationPrimeWorkScheduler {
    private const val oneTimeWorkName = "guardian_medication_prime_once"
    private const val periodicWorkName = "guardian_medication_prime_periodic"

    fun enqueueOneTime(context: Context) {
        val request = OneTimeWorkRequestBuilder<MedicationPrimeWorker>()
            .setConstraints(
                Constraints.Builder().build(),
            )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            oneTimeWorkName,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun ensurePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<MedicationPrimeWorker>(12, TimeUnit.HOURS)
            .setConstraints(
                Constraints.Builder().build(),
            )
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            periodicWorkName,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }
}

