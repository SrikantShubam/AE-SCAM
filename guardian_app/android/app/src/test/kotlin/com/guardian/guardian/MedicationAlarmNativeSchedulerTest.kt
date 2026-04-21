package com.guardian.guardian

import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

class MedicationAlarmNativeSchedulerTest {
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
            scheduleTrigger = { occurrenceId, triggerId, stage, triggerAtMs, medicationName, dosage ->
                triggers.add(
                    mapOf(
                        "occurrenceId" to occurrenceId,
                        "triggerId" to triggerId,
                        "stage" to stage,
                        "triggerAtMs" to triggerAtMs,
                        "medicationName" to medicationName,
                        "dosage" to dosage,
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
            scheduleTrigger = { _, _, _, _, _, _ -> triggerCount += 1 },
        )

        assertEquals(emptyList<Pair<String, Long>>(), createdEvents)
        assertEquals(0, triggerCount)
    }
}
