package com.vectorveda.guardian

import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MedicationAlarmNativeSchedulerTest {
    @Test
    fun `schedule loader uses no selection when schema has no is_active column`() {
        assertNull(
            MedicationAlarmNativeScheduler.activeScheduleSelection(
                columnNames = setOf("id", "name", "dosage", "dose_times", "active_days"),
            ),
        )
    }

    @Test
    fun `schedule loader parses current schema rows and skips invalid entries`() {
        val valid = MedicationAlarmNativeScheduler.parseScheduleRow(
            idRaw = "med-1",
            nameRaw = "Aspirin",
            dosageRaw = "1 tablet",
            doseTimesRaw = "08:00,20:30",
            activeDaysRaw = "mon,wed",
        )
        val blankId = MedicationAlarmNativeScheduler.parseScheduleRow(
            idRaw = " ",
            nameRaw = "Blank Id",
            dosageRaw = "1",
            doseTimesRaw = "08:00",
            activeDaysRaw = "mon",
        )
        val badTimes = MedicationAlarmNativeScheduler.parseScheduleRow(
            idRaw = "med-2",
            nameRaw = "Bad Time",
            dosageRaw = "1",
            doseTimesRaw = "not-a-time",
            activeDaysRaw = "mon",
        )
        val badDays = MedicationAlarmNativeScheduler.parseScheduleRow(
            idRaw = "med-3",
            nameRaw = "Bad Days",
            dosageRaw = "1",
            doseTimesRaw = "08:00",
            activeDaysRaw = "noday",
        )

        requireNotNull(valid)
        assertEquals("med-1", valid.id)
        assertEquals("Aspirin", valid.name)
        assertEquals("1 tablet", valid.dosage)
        assertEquals(listOf(LocalTime.of(8, 0), LocalTime.of(20, 30)), valid.clockTimes)
        assertEquals(setOf(1, 3), valid.activeIsoWeekdays)
        assertNull(blankId)
        assertNull(badTimes)
        assertNull(badDays)
    }

    @Test
    fun `primeWindowCore creates dose-event entries and schedules level1 plus level3 alarms`() {
        val zone = ZoneId.of("UTC")
        val scheduledAtMs = LocalDateTime.of(2024, 3, 11, 8, 0)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()
        val fromMs = scheduledAtMs - (60L * 60L * 1000L)
        val untilMs = scheduledAtMs + (60L * 60L * 1000L)

        val createdEvents = mutableListOf<Pair<String, Long>>()
        val triggers = mutableListOf<Map<String, Any>>()

        MedicationAlarmNativeScheduler.primeWindowCore(
            fromEpochMs = fromMs,
            untilEpochMs = untilMs,
            zoneId = zone,
            schedules = listOf(
                MedicationAlarmNativeScheduler.ScheduleRow(
                    id = "med-1",
                    name = "Aspirin",
                    dosage = "1 tablet",
                    clockTimes = listOf(LocalTime.of(8, 0)),
                    activeIsoWeekdays = setOf(1),
                ),
            ),
            createDoseEventIfMissing = { scheduleId, eventAtMs ->
                createdEvents.add(scheduleId to eventAtMs)
            },
            scheduleTrigger = { occurrenceId, triggerId, stage, triggerAtMs, medicationName, dosage, note ->
                triggers.add(
                    mapOf(
                        "occurrenceId" to occurrenceId,
                        "triggerId" to triggerId,
                        "stage" to stage,
                        "triggerAtMs" to triggerAtMs,
                        "medicationName" to medicationName,
                        "dosage" to dosage,
                        "note" to note,
                    ),
                )
            },
        )

        assertEquals(listOf("med-1" to scheduledAtMs), createdEvents)
        assertEquals(2, triggers.size)
        assertEquals("med-1-$scheduledAtMs-level1", triggers[0]["triggerId"])
        assertEquals("level1InAppReminder", triggers[0]["stage"])
        assertEquals(scheduledAtMs, triggers[0]["triggerAtMs"])
        assertEquals("med-1-$scheduledAtMs-level3", triggers[1]["triggerId"])
        assertEquals("level3Alarm", triggers[1]["stage"])
        assertEquals(scheduledAtMs + (30L * 60L * 1000L), triggers[1]["triggerAtMs"])
    }

    @Test
    fun `primeWindowCore skips times outside window and wrong weekday`() {
        val zone = ZoneId.of("UTC")
        val mondayNoonMs = LocalDateTime.of(2024, 3, 11, 12, 0)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()
        val fromMs = mondayNoonMs
        val untilMs = mondayNoonMs + (30L * 60L * 1000L)

        val createdEvents = mutableListOf<Pair<String, Long>>()
        var triggerCount = 0

        MedicationAlarmNativeScheduler.primeWindowCore(
            fromEpochMs = fromMs,
            untilEpochMs = untilMs,
            zoneId = zone,
            schedules = listOf(
                MedicationAlarmNativeScheduler.ScheduleRow(
                    id = "med-early",
                    name = "Vitamin C",
                    dosage = "500mg",
                    clockTimes = listOf(LocalTime.of(11, 0)),
                    activeIsoWeekdays = setOf(1),
                ),
                MedicationAlarmNativeScheduler.ScheduleRow(
                    id = "med-wrong-day",
                    name = "Calcium",
                    dosage = "1 tablet",
                    clockTimes = listOf(LocalTime.of(12, 0)),
                    activeIsoWeekdays = setOf(2),
                ),
            ),
            createDoseEventIfMissing = { scheduleId, eventAtMs ->
                createdEvents.add(scheduleId to eventAtMs)
            },
            scheduleTrigger = { _, _, _, _, _, _, _ -> triggerCount += 1 },
        )

        assertEquals(emptyList<Pair<String, Long>>(), createdEvents)
        assertEquals(0, triggerCount)
    }

    @Test
    fun `primeWindowCore skips schedules after stop date`() {
        val zone = ZoneId.of("UTC")
        val mondayMorningMs = LocalDateTime.of(2024, 3, 11, 8, 0)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()
        val sundayStopDateMs = LocalDateTime.of(2024, 3, 10, 0, 0)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()

        val createdEvents = mutableListOf<Pair<String, Long>>()
        var triggerCount = 0

        MedicationAlarmNativeScheduler.primeWindowCore(
            fromEpochMs = mondayMorningMs - (60L * 60L * 1000L),
            untilEpochMs = mondayMorningMs + (60L * 60L * 1000L),
            zoneId = zone,
            schedules = listOf(
                MedicationAlarmNativeScheduler.ScheduleRow(
                    id = "med-expired",
                    name = "Expired",
                    dosage = "1 tablet",
                    clockTimes = listOf(LocalTime.of(8, 0)),
                    activeIsoWeekdays = setOf(1),
                    stopDateEpochMs = sundayStopDateMs,
                ),
            ),
            createDoseEventIfMissing = { scheduleId, eventAtMs ->
                createdEvents.add(scheduleId to eventAtMs)
            },
            scheduleTrigger = { _, _, _, _, _, _, _ -> triggerCount += 1 },
        )

        assertEquals(emptyList<Pair<String, Long>>(), createdEvents)
        assertEquals(0, triggerCount)
    }
}

