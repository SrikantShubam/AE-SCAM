package com.guardian.guardian

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

class ServiceHealthWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val nowMs = System.currentTimeMillis()
        val prefs = applicationContext.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val wasEnabled = prefs.getBoolean(
            PaymentProtectionStore.KEY_HEALTH_WAS_ACCESSIBILITY_ENABLED,
            false,
        )
        val disabledStreakStartMs = prefs.getLong(
            PaymentProtectionStore.KEY_HEALTH_DISABLED_STREAK_START_MS,
            0L,
        )
        val lastNotificationAtMs = prefs.getLong(
            PaymentProtectionStore.KEY_HEALTH_DISABLED_NOTIFICATION_AT_MS,
            0L,
        )
        val isEnabled = isAccessibilityEnabled(applicationContext)
        val transition = evaluateTransition(
            nowMs = nowMs,
            isEnabled = isEnabled,
            wasEnabled = wasEnabled,
            disabledStreakStartMs = disabledStreakStartMs,
            lastNotificationAtMs = lastNotificationAtMs,
        )

        prefs.edit()
            .putBoolean(PaymentProtectionStore.KEY_HEALTH_ACCESSIBILITY_ENABLED, isEnabled)
            .putBoolean(
                PaymentProtectionStore.KEY_HEALTH_WAS_ACCESSIBILITY_ENABLED,
                transition.nextWasEnabled,
            )
            .putLong(
                PaymentProtectionStore.KEY_HEALTH_DISABLED_STREAK_START_MS,
                transition.nextDisabledStreakStartMs,
            )
            .putLong(
                PaymentProtectionStore.KEY_HEALTH_DISABLED_NOTIFICATION_AT_MS,
                transition.nextLastNotificationAtMs,
            )
            .apply()

        if (transition.shouldNotify) {
            postDisabledNotification()
        }

        val writeSucceeded = writeHealthToFirestore(
            prefs = prefs,
            accessibilityEnabled = isEnabled,
            nowMs = nowMs,
        )
        if (!writeSucceeded) {
            return Result.retry()
        }
        return Result.success()
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val expectedId = ComponentName(
            context,
            GuardianAccessibilityService::class.java,
        ).flattenToString()
        val enabledSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledSetting)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expectedId, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun postDisabledNotification() {
        ensureNotificationChannel()
        val openParentHomeIntent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_NAVIGATION_ROUTE, "/home/parent")
        }
        val contentIntent = PendingIntent.getActivity(
            applicationContext,
            NotificationConfig.notificationId,
            openParentHomeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val pausedTitle = "Guardian payment protection paused ${0x2014.toChar()} tap to re-enable"
        val notification = NotificationCompat.Builder(
            applicationContext,
            NotificationConfig.channelId,
        )
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(pausedTitle)
            .setContentText("Open Guardian to turn payment protection back on.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        NotificationManagerCompat.from(applicationContext).notify(
            NotificationConfig.notificationId,
            notification,
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = applicationContext.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(NotificationConfig.channelId)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            NotificationConfig.channelId,
            "Guardian protection health",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when Guardian payment protection is paused."
        }
        manager.createNotificationChannel(channel)
    }

    private fun writeHealthToFirestore(
        prefs: android.content.SharedPreferences,
        accessibilityEnabled: Boolean,
        nowMs: Long,
    ): Boolean {
        val pairId = prefs.getString("pair_id", null)
            ?: prefs.getString("guardian_family_id", null)
            ?: return true
        if (pairId.isBlank()) {
            return true
        }
        return try {
            val app = FirebaseApp.getApps(applicationContext).firstOrNull()
                ?: FirebaseApp.initializeApp(applicationContext)
                ?: return false
            val firestore = FirebaseFirestore.getInstance(app)
            Tasks.await(
                firestore.collection("pairs")
                    .document(pairId)
                    .set(
                        mapOf(
                            "health" to mapOf(
                                "accessibility_enabled" to accessibilityEnabled,
                                "updated_at_ms" to nowMs,
                            ),
                        ),
                        SetOptions.merge(),
                    ),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    data class TransitionResult(
        val shouldNotify: Boolean,
        val nextWasEnabled: Boolean,
        val nextDisabledStreakStartMs: Long,
        val nextLastNotificationAtMs: Long,
    )

    companion object {
        internal const val disabledDedupWindowMs = 6L * 60L * 60L * 1000L

        internal fun evaluateTransition(
            nowMs: Long,
            isEnabled: Boolean,
            wasEnabled: Boolean,
            disabledStreakStartMs: Long,
            lastNotificationAtMs: Long,
        ): TransitionResult {
            if (isEnabled) {
                return TransitionResult(
                    shouldNotify = false,
                    nextWasEnabled = true,
                    nextDisabledStreakStartMs = 0L,
                    nextLastNotificationAtMs = 0L,
                )
            }

            val streakStart = when {
                wasEnabled -> nowMs
                disabledStreakStartMs > 0L -> disabledStreakStartMs
                else -> 0L
            }
            val shouldNotify = when {
                wasEnabled -> true
                streakStart <= 0L -> false
                lastNotificationAtMs <= 0L -> true
                nowMs - lastNotificationAtMs >= disabledDedupWindowMs -> true
                else -> false
            }
            val nextLastNotificationAtMs = if (shouldNotify) nowMs else lastNotificationAtMs
            return TransitionResult(
                shouldNotify = shouldNotify,
                nextWasEnabled = false,
                nextDisabledStreakStartMs = streakStart,
                nextLastNotificationAtMs = nextLastNotificationAtMs,
            )
        }
    }
}

private object NotificationConfig {
    const val channelId = "guardian_payment_protection_health"
    const val notificationId = 4404
}
