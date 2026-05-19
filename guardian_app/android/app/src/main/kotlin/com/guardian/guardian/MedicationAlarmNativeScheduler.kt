package com.guardian.guardian

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.content.getSystemService
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

object MedicationAlarmNativeScheduler {
    private const val localDbName = "guardian_local.db"
    private const val level3DelayMs = 30L * 60L * 1000L
    private const val doseEventStatusPending = "pending"
    private const val doseEventEscalationLevel1 = 1
    private val weekdayCodeToIso = mapOf(
        "mon" to 1,
        "tue" to 2,
        "wed" to 3,
        "thu" to 4,
        "fri" to 5,
        "sat" to 6,
        "sun" to 7,
    )

    fun scheduleTrigger(
        context: Context,
        occurrenceId: String,
        triggerId: String,
        stage: String,
        triggerAtMs: Long,
        medicationName: String,
        dosage: String,
        note: String,
    ) {
        val alarmManager = context.getSystemService<AlarmManager>() ?: return
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            triggerId.hashCode(),
            Intent(context, MedicationAlarmReceiver::class.java).apply {
                action = MedicationAlarmReceiver.ACTION_MEDICATION_TRIGGER
                putExtra(MedicationAlarmReceiver.EXTRA_OCCURRENCE_ID, occurrenceId)
                putExtra(MedicationAlarmReceiver.EXTRA_TRIGGER_ID, triggerId)
                putExtra(MedicationAlarmReceiver.EXTRA_STAGE, stage)
                putExtra(MedicationAlarmReceiver.EXTRA_TRIGGER_AT_MS, triggerAtMs)
                putExtra(MedicationAlarmReceiver.EXTRA_MEDICATION_NAME, medicationName)
                putExtra(MedicationAlarmReceiver.EXTRA_DOSAGE, dosage)
                putExtra(MedicationAlarmReceiver.EXTRA_NOTE, note)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (MedicationAlarmSchedulingStrategy.shouldUseWindowFallback(Build.MANUFACTURER)) {
            alarmManager.setWindow(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                MedicationAlarmSchedulingStrategy.fallbackWindowLengthMs,
                pendingIntent,
            )
            return
        }

        try {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                pendingIntent,
            )
        } catch (_: SecurityException) {
            alarmManager.setWindow(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                MedicationAlarmSchedulingStrategy.fallbackWindowLengthMs,
                pendingIntent,
            )
        }
    }

    fun cancelOccurrence(context: Context, occurrenceId: String) {
        val alarmManager = context.getSystemService<AlarmManager>() ?: return
        val triggerIds = listOf(
            "$occurrenceId-level1",
            "$occurrenceId-level3",
            "$occurrenceId-level3-now",
        )

        triggerIds.forEach { triggerId ->
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                triggerId.hashCode(),
                Intent(context, MedicationAlarmReceiver::class.java).apply {
                    action = MedicationAlarmReceiver.ACTION_MEDICATION_TRIGGER
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun primeWindow(context: Context, fromEpochMs: Long, untilEpochMs: Long) {
        if (untilEpochMs <= fromEpochMs) {
            return
        }

        val dbPath = context.getDatabasePath(localDbName)
        if (!dbPath.exists()) {
            return
        }

        val db = SQLiteDatabase.openDatabase(
            dbPath.path,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        )
        db.use { database ->
            val schedules = loadActiveSchedules(database)
            if (schedules.isEmpty()) {
                return
            }

            primeWindowCore(
                fromEpochMs = fromEpochMs,
                untilEpochMs = untilEpochMs,
                zoneId = ZoneId.systemDefault(),
                schedules = schedules,
                createDoseEventIfMissing = { scheduleId, scheduledAtMs ->
                    insertDoseEventIfMissing(
                        database = database,
                        scheduleId = scheduleId,
                        scheduledAtMs = scheduledAtMs,
                    )
                },
                scheduleTrigger = { occurrenceId, triggerId, stage, triggerAtMs, medicationName, dosage, note ->
                    scheduleTrigger(
                        context = context,
                        occurrenceId = occurrenceId,
                        triggerId = triggerId,
                        stage = stage,
                        triggerAtMs = triggerAtMs,
                        medicationName = medicationName,
                        dosage = dosage,
                        note = note,
                    )
                },
            )
        }
    }

    internal fun primeWindowCore(
        fromEpochMs: Long,
        untilEpochMs: Long,
        zoneId: ZoneId,
        schedules: List<ScheduleRow>,
        createDoseEventIfMissing: (scheduleId: String, scheduledAtMs: Long) -> Unit,
        scheduleTrigger: (
            occurrenceId: String,
            triggerId: String,
            stage: String,
            triggerAtMs: Long,
            medicationName: String,
            dosage: String,
            note: String,
        ) -> Unit,
    ) {
        val fromLocal = Instant.ofEpochMilli(fromEpochMs).atZone(zoneId).toLocalDateTime()
        val untilLocal = Instant.ofEpochMilli(untilEpochMs).atZone(zoneId).toLocalDateTime()
        var dateCursor = fromLocal.toLocalDate()
        val endDate = untilLocal.toLocalDate()

        while (!dateCursor.isAfter(endDate)) {
            val isoWeekday = dateCursor.dayOfWeek.value
            schedules.forEach { schedule ->
                if (!schedule.activeIsoWeekdays.contains(isoWeekday)) {
                    return@forEach
                }
                val stopDate = schedule.stopDateEpochMs?.let {
                    Instant.ofEpochMilli(it).atZone(zoneId).toLocalDate()
                }
                if (stopDate != null && dateCursor.isAfter(stopDate)) {
                    return@forEach
                }

                schedule.clockTimes.forEach { clock ->
                    val scheduledAt = LocalDateTime.of(dateCursor, clock)
                    val scheduledAtMs = scheduledAt.atZone(zoneId).toInstant().toEpochMilli()
                    if (scheduledAtMs < fromEpochMs || scheduledAtMs > untilEpochMs) {
                        return@forEach
                    }

                    createDoseEventIfMissing(schedule.id, scheduledAtMs)
                    val occurrenceId = "${schedule.id}-$scheduledAtMs"
                    scheduleTrigger(
                        occurrenceId,
                        "$occurrenceId-level1",
                        "level1InAppReminder",
                        scheduledAtMs,
                        schedule.name,
                        schedule.dosage,
                        schedule.note.orEmpty(),
                    )
                    scheduleTrigger(
                        occurrenceId,
                        "$occurrenceId-level3",
                        "level3Alarm",
                        scheduledAtMs + level3DelayMs,
                        schedule.name,
                        schedule.dosage,
                        schedule.note.orEmpty(),
                    )
                }
            }
            dateCursor = dateCursor.plusDays(1)
        }
    }

    private fun insertDoseEventIfMissing(
        database: SQLiteDatabase,
        scheduleId: String,
        scheduledAtMs: Long,
    ) {
        val nowEpochMs = System.currentTimeMillis()
        val row = ContentValues().apply {
            put("id", buildDoseEventId(scheduleId, scheduledAtMs))
            put("schedule_id", scheduleId)
            put("scheduled_at", scheduledAtMs)
            put("status", doseEventStatusPending)
            put("escalation_level", doseEventEscalationLevel1)
            putNull("reminder_sent_at")
            putNull("acted_at")
            put("created_at", nowEpochMs)
            put("updated_at", nowEpochMs)
        }
        database.insertWithOnConflict(
            "medication_dose_events",
            null,
            row,
            SQLiteDatabase.CONFLICT_IGNORE,
        )
    }

    private fun buildDoseEventId(scheduleId: String, scheduledAtMs: Long): String {
        return "dose-$scheduleId-$scheduledAtMs"
    }

    private fun loadActiveSchedules(database: SQLiteDatabase): List<ScheduleRow> {
        val selection = activeScheduleSelection(loadMedicationScheduleColumnNames(database))
        val cursor = database.query(
            "medication_schedules",
                arrayOf("id", "name", "dosage", "dose_times", "active_days", "stop_date", "note"),
            selection,
            null,
            null,
            null,
            null,
        )
        cursor.use { c ->
            return readScheduleRowsFromCursor(c)
        }
    }

    private fun loadMedicationScheduleColumnNames(database: SQLiteDatabase): Set<String> {
        val cursor = database.rawQuery("PRAGMA table_info(medication_schedules)", null)
        cursor.use { c ->
            val names = mutableSetOf<String>()
            while (c.moveToNext()) {
                c.getStringByName("name")?.trim()?.lowercase()?.let { columnName ->
                    if (columnName.isNotEmpty()) {
                        names.add(columnName)
                    }
                }
            }
            return names
        }
    }

    internal fun activeScheduleSelection(columnNames: Set<String>): String? {
        return if (columnNames.contains("is_active")) "is_active = 1" else null
    }

    internal fun readScheduleRowsFromCursor(cursor: Cursor): List<ScheduleRow> {
        val rows = mutableListOf<ScheduleRow>()
        while (cursor.moveToNext()) {
            parseScheduleRow(
                idRaw = cursor.getStringByName("id"),
                nameRaw = cursor.getStringByName("name"),
                dosageRaw = cursor.getStringByName("dosage"),
                doseTimesRaw = cursor.getStringByName("dose_times"),
                activeDaysRaw = cursor.getStringByName("active_days"),
                stopDateEpochMs = cursor.getLongByName("stop_date"),
                noteRaw = cursor.getStringByName("note"),
            )?.let(rows::add)
        }
        return rows
    }

    internal fun parseScheduleRow(
        idRaw: String?,
        nameRaw: String?,
        dosageRaw: String?,
        doseTimesRaw: String?,
        activeDaysRaw: String?,
        stopDateEpochMs: Long? = null,
        noteRaw: String? = null,
    ): ScheduleRow? {
        val id = idRaw?.trim().orEmpty()
        if (id.isEmpty()) {
            return null
        }
        val name = nameRaw?.trim().orEmpty()
        val dosage = dosageRaw?.trim().orEmpty()
        val times = parseClockTimes(doseTimesRaw)
        val weekdays = parseIsoWeekdays(activeDaysRaw)
        if (times.isEmpty() || weekdays.isEmpty()) {
            return null
        }
        return ScheduleRow(
            id = id,
            name = name,
            dosage = dosage,
            clockTimes = times,
            activeIsoWeekdays = weekdays,
            stopDateEpochMs = stopDateEpochMs,
            note = noteRaw?.trim()?.ifEmpty { null },
        )
    }

    private fun parseClockTimes(raw: String?): List<LocalTime> {
        if (raw.isNullOrBlank()) {
            return emptyList()
        }
        return raw.split(',')
            .mapNotNull { entry ->
                val trimmed = entry.trim()
                if (trimmed.isEmpty()) {
                    return@mapNotNull null
                }
                val parts = trimmed.split(':')
                if (parts.size != 2) {
                    return@mapNotNull null
                }
                val hour = parts[0].toIntOrNull() ?: return@mapNotNull null
                val minute = parts[1].toIntOrNull() ?: return@mapNotNull null
                if (hour !in 0..23 || minute !in 0..59) {
                    return@mapNotNull null
                }
                LocalTime.of(hour, minute)
            }
    }

    private fun parseIsoWeekdays(raw: String?): Set<Int> {
        if (raw.isNullOrBlank()) {
            return emptySet()
        }
        return raw.split(',')
            .mapNotNull { entry ->
                val code = entry.trim().lowercase()
                weekdayCodeToIso[code]
            }
            .toSet()
    }

    private fun Cursor.getStringByName(name: String): String? {
        val index = getColumnIndex(name)
        if (index < 0 || isNull(index)) {
            return null
        }
        return getString(index)
    }

    private fun Cursor.getLongByName(name: String): Long? {
        val index = getColumnIndex(name)
        if (index < 0 || isNull(index)) {
            return null
        }
        return getLong(index)
    }

    internal data class ScheduleRow(
        val id: String,
        val name: String,
        val dosage: String,
        val clockTimes: List<LocalTime>,
        val activeIsoWeekdays: Set<Int>,
        val stopDateEpochMs: Long? = null,
        val note: String? = null,
    )
}
