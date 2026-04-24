package com.guardian.guardian

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object ServiceHealthWorkScheduler {
    private const val periodicWorkName = "guardian_service_health_periodic"

    fun ensurePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<ServiceHealthWorker>(15, TimeUnit.MINUTES)
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
