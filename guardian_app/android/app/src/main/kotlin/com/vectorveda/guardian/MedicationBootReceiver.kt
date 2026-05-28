package com.vectorveda.guardian

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MedicationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        handleAction(
            action = intent?.action,
            enqueueOneTime = { MedicationPrimeWorkScheduler.enqueueOneTime(context) },
            ensurePeriodic = { MedicationPrimeWorkScheduler.ensurePeriodic(context) },
        )
    }

    companion object {
        private val supportedActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )

        fun shouldHandleAction(action: String?): Boolean = action in supportedActions

        internal fun handleAction(
            action: String?,
            enqueueOneTime: () -> Unit,
            ensurePeriodic: () -> Unit,
        ) {
            if (!shouldHandleAction(action)) {
                return
            }
            enqueueOneTime()
            ensurePeriodic()
        }
    }
}

