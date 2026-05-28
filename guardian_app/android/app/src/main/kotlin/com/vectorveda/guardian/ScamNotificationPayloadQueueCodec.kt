package com.vectorveda.guardian

import java.nio.charset.StandardCharsets
import java.util.Base64

object ScamNotificationPayloadQueueCodec {
    fun appendPayload(existingQueueJson: String?, payloadJson: String): String {
        val queue = parseQueue(existingQueueJson).toMutableList()
        queue.add(payloadJson)
        return queue.joinToString(separator = "\n") { payload ->
            Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(payload.toByteArray(StandardCharsets.UTF_8))
        }
    }

    fun consumeAll(existingQueueJson: String?): List<String> {
        return parseQueue(existingQueueJson)
    }

    private fun parseQueue(existingQueueJson: String?): List<String> {
        if (existingQueueJson.isNullOrBlank()) {
            return emptyList()
        }
        val trimmed = existingQueueJson.trim()
        if (trimmed.startsWith("{")) {
            return listOf(trimmed)
        }

        return trimmed.lines().mapNotNull { line ->
            val encoded = line.trim()
            if (encoded.isEmpty()) {
                return@mapNotNull null
            }
            try {
                String(
                    Base64.getUrlDecoder().decode(encoded),
                    StandardCharsets.UTF_8,
                ).trim().takeIf { it.isNotEmpty() }
            } catch (_: IllegalArgumentException) {
                encoded
            }
        }
    }
}

