package com.guardian.guardian

data class ScamNotificationPayload(
    val sourcePackage: String,
    val sender: String?,
    val messageBody: String,
    val receivedAtMs: Long,
)

object ScamNotificationExtractor {
    val monitoredMessagingPackages = setOf(
        "com.google.android.apps.messaging",
        "com.whatsapp",
        "com.whatsapp.w4b",
        "com.samsung.android.messaging",
        "com.android.mms",
    )

    fun shouldProcessPackage(
        sourcePackage: String,
        appPackageName: String,
    ): Boolean {
        if (sourcePackage == appPackageName) {
            return false
        }
        return sourcePackage in monitoredMessagingPackages
    }

    fun extractMessageBody(text: String?, bigText: String?): String? {
        val normalizedBigText = bigText?.trim()
        if (!normalizedBigText.isNullOrEmpty()) {
            return normalizedBigText
        }
        val normalizedText = text?.trim()
        if (!normalizedText.isNullOrEmpty()) {
            return normalizedText
        }
        return null
    }

    fun toPayloadOrNull(
        sourcePackage: String,
        appPackageName: String,
        sender: String?,
        text: String?,
        bigText: String?,
        receivedAtMs: Long,
    ): ScamNotificationPayload? {
        if (!shouldProcessPackage(sourcePackage, appPackageName)) {
            return null
        }

        val messageBody = extractMessageBody(text, bigText) ?: return null
        val normalizedSender = sender?.trim()?.takeIf { it.isNotEmpty() }
        return ScamNotificationPayload(
            sourcePackage = sourcePackage,
            sender = normalizedSender,
            messageBody = messageBody,
            receivedAtMs = receivedAtMs,
        )
    }
}
