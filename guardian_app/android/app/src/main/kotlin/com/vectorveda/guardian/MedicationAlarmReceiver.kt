package com.vectorveda.guardian

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class MedicationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_MEDICATION_TRIGGER) {
            return
        }
        val prefs = context.getSharedPreferences(
            PaymentProtectionStore.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        if (prefs.getBoolean(PaymentProtectionStore.KEY_EMERGENCY_DISABLED, false)) {
            return
        }

        val occurrenceId = intent.getStringExtra(EXTRA_OCCURRENCE_ID) ?: return
        val triggerId = intent.getStringExtra(EXTRA_TRIGGER_ID) ?: return
        val stage = intent.getStringExtra(EXTRA_STAGE).orEmpty()
        val triggerAtMs = intent.getLongExtra(EXTRA_TRIGGER_AT_MS, 0L)
        val medicationName = intent.getStringExtra(EXTRA_MEDICATION_NAME).orEmpty()
        val dosage = intent.getStringExtra(EXTRA_DOSAGE).orEmpty()
        val note = intent.getStringExtra(EXTRA_NOTE).orEmpty()
        val scheduledDeltaMinutes = if (triggerAtMs > 0L) {
            (System.currentTimeMillis() - triggerAtMs) / 60_000L
        } else {
            0L
        }
        GuardianTelemetry.logMedicationAlarmFired(scheduledDeltaMinutes)

        ensureNotificationChannel(context)

        val title = when (stage) {
            "level3Alarm" -> context.getString(R.string.medication_alarm_title)
            else -> context.getString(R.string.medication_reminder_title)
        }
        val body = when (stage) {
            "level3Alarm" -> "$medicationName $dosage is overdue. Please take action now."
            else -> "$medicationName $dosage - time to take your medicine."
        }

        val contentIntent = PendingIntent.getActivity(
            context,
            triggerId.hashCode(),
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setPriority(
                if (stage == "level3Alarm") {
                    NotificationCompat.PRIORITY_MAX
                } else {
                    NotificationCompat.PRIORITY_HIGH
                },
            )
            .setCategory(
                if (stage == "level3Alarm") {
                    NotificationCompat.CATEGORY_ALARM
                } else {
                    NotificationCompat.CATEGORY_REMINDER
                },
            )
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (stage == "level3Alarm") {
            val (scheduleId, scheduledAtMs) = parseOccurrenceMetadata(occurrenceId)
            val fullScreenIntent = PendingIntent.getActivity(
                context,
                triggerId.hashCode(),
                Intent(context, MedicationAlarmActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(EXTRA_MEDICATION_NAME, medicationName)
                    putExtra(EXTRA_DOSAGE, dosage)
                    putExtra(EXTRA_OCCURRENCE_ID, occurrenceId)
                    putExtra(EXTRA_NOTE, note)
                    putExtra(EXTRA_SCHEDULE_ID, scheduleId)
                    putExtra(EXTRA_SCHEDULED_AT_MS, scheduledAtMs)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.setFullScreenIntent(fullScreenIntent, true)
        }

        NotificationManagerCompat.from(context).notify(
            occurrenceId.hashCode(),
            builder.build(),
        )
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.medication_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.medication_channel_description)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            setSound(soundUri, audioAttributes)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_MEDICATION_TRIGGER = "com.vectorveda.guardian.MEDICATION_TRIGGER"
        const val EXTRA_OCCURRENCE_ID = "occurrence_id"
        const val EXTRA_TRIGGER_ID = "trigger_id"
        const val EXTRA_STAGE = "stage"
        const val EXTRA_TRIGGER_AT_MS = "trigger_at_ms"
        const val EXTRA_MEDICATION_NAME = "medication_name"
        const val EXTRA_DOSAGE = "dosage"
        const val EXTRA_NOTE = "note"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_SCHEDULED_AT_MS = "scheduled_at_ms"
        private const val CHANNEL_ID = "medication_reminder"
    }

    private fun parseOccurrenceMetadata(occurrenceId: String): Pair<String, Long> {
        val separator = occurrenceId.lastIndexOf('-')
        if (separator <= 0 || separator >= occurrenceId.length - 1) {
            return Pair("", 0L)
        }
        val scheduleId = occurrenceId.substring(0, separator).trim()
        val scheduledAtMs = occurrenceId.substring(separator + 1).toLongOrNull() ?: 0L
        return Pair(scheduleId, scheduledAtMs)
    }
}

