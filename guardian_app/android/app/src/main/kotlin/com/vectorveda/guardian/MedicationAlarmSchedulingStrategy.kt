package com.vectorveda.guardian

object MedicationAlarmSchedulingStrategy {
    private val fallbackManufacturers = setOf(
        "xiaomi",
        "redmi",
        "poco",
        "oppo",
        "realme",
        "vivo",
    )

    const val fallbackWindowLengthMs: Long = 15 * 60 * 1000L

    fun shouldUseWindowFallback(manufacturer: String?): Boolean {
        val normalized = manufacturer?.trim()?.lowercase().orEmpty()
        return normalized in fallbackManufacturers
    }
}

