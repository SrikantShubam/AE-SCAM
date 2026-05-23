package com.guardian.guardian

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Locale

class UrlReputationStore(context: Context) : SQLiteOpenHelper(
    context,
    DATABASE_NAME,
    null,
    DATABASE_VERSION,
) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE url_hash_prefixes (
              hash_prefix TEXT PRIMARY KEY,
              threat_type TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE url_store_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
            """.trimIndent(),
        )
        setMeta(db, KEY_LAST_REFRESH_MS, "0")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS url_store_meta (
                  key TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                )
                """.trimIndent(),
            )
            setMeta(db, KEY_LAST_REFRESH_MS, "0")
        }
    }

    fun checkUrl(url: String): String {
        val normalized = normalizeUrl(url) ?: return THREAT_UNKNOWN
        val prefix = sha256Prefix32(normalized)
        incrementHitCount()
        val db = readableDatabase
        val cursor = db.query(
            "url_hash_prefixes",
            arrayOf("threat_type"),
            "hash_prefix = ?",
            arrayOf(prefix),
            null,
            null,
            null,
            "1",
        )
        cursor.use { c ->
            if (!c.moveToFirst()) {
                return THREAT_SAFE
            }
            val raw = c.getString(0)?.trim()?.lowercase(Locale.US).orEmpty()
            return when (raw) {
                THREAT_PHISHING,
                THREAT_MALWARE,
                THREAT_UNWANTED,
                THREAT_SAFE,
                -> raw

                else -> THREAT_UNKNOWN
            }
        }
    }

    fun upsertThreatPrefix(hashPrefix: String, threatType: String) {
        val normalizedPrefix = hashPrefix.trim().lowercase(Locale.US)
        if (normalizedPrefix.length != 8) {
            return
        }
        val normalizedThreat = threatType.trim().lowercase(Locale.US)
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("hash_prefix", normalizedPrefix)
            put("threat_type", normalizedThreat)
            put("updated_at_ms", now)
        }
        writableDatabase.insertWithOnConflict(
            "url_hash_prefixes",
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun markRefreshAttempt(nowMs: Long = System.currentTimeMillis()) {
        setMeta(writableDatabase, KEY_LAST_REFRESH_MS, nowMs.toString())
        val existing = recentRefreshTimestamps().toMutableList()
        existing.add(0, nowMs)
        while (existing.size > MAX_REFRESH_HISTORY) {
            existing.removeAt(existing.lastIndex)
        }
        setMeta(writableDatabase, KEY_RECENT_REFRESHES_MS, existing.joinToString(","))
    }

    fun lastRefreshMs(): Long {
        val db = readableDatabase
        val cursor = db.query(
            "url_store_meta",
            arrayOf("value"),
            "key = ?",
            arrayOf(KEY_LAST_REFRESH_MS),
            null,
            null,
            null,
            "1",
        )
        cursor.use { c ->
            if (!c.moveToFirst()) {
                return 0L
            }
            return c.getString(0)?.toLongOrNull() ?: 0L
        }
    }

    fun hitCount(): Int {
        val db = readableDatabase
        val cursor = db.query(
            "url_store_meta",
            arrayOf("value"),
            "key = ?",
            arrayOf(KEY_HIT_COUNT),
            null,
            null,
            null,
            "1",
        )
        cursor.use { c ->
            if (!c.moveToFirst()) {
                return 0
            }
            return c.getString(0)?.toIntOrNull() ?: 0
        }
    }

    fun recentRefreshTimestamps(): List<Long> {
        val db = readableDatabase
        val cursor = db.query(
            "url_store_meta",
            arrayOf("value"),
            "key = ?",
            arrayOf(KEY_RECENT_REFRESHES_MS),
            null,
            null,
            null,
            "1",
        )
        cursor.use { c ->
            if (!c.moveToFirst()) {
                return emptyList()
            }
            val raw = c.getString(0).orEmpty()
            return raw.split(',')
                .mapNotNull { it.trim().toLongOrNull() }
                .take(MAX_REFRESH_HISTORY)
        }
    }

    private fun incrementHitCount() {
        val next = hitCount() + 1
        setMeta(writableDatabase, KEY_HIT_COUNT, next.toString())
    }

    private fun setMeta(db: SQLiteDatabase, key: String, value: String) {
        val values = ContentValues().apply {
            put("key", key)
            put("value", value)
        }
        db.insertWithOnConflict(
            "url_store_meta",
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    companion object {
        private const val DATABASE_NAME = "guardian_url_reputation.db"
        private const val DATABASE_VERSION = 2
        private const val KEY_LAST_REFRESH_MS = "last_refresh_ms"
        private const val KEY_HIT_COUNT = "hit_count"
        private const val KEY_RECENT_REFRESHES_MS = "recent_refreshes_ms"
        private const val MAX_REFRESH_HISTORY = 20

        const val THREAT_UNKNOWN = "unknown"
        const val THREAT_SAFE = "safe"
        const val THREAT_PHISHING = "phishing"
        const val THREAT_MALWARE = "malware"
        const val THREAT_UNWANTED = "unwanted"

        internal fun normalizeUrl(raw: String): String? {
            val trimmed = raw.trim()
            if (trimmed.isEmpty()) {
                return null
            }
            val withScheme = if (trimmed.contains("://")) trimmed else "https://$trimmed"
            val uri = runCatching { java.net.URI(withScheme) }.getOrNull() ?: return null
            val host = uri.host?.lowercase(Locale.US)?.trim().orEmpty()
            if (host.isEmpty()) {
                return null
            }
            val path = uri.rawPath?.ifBlank { "/" } ?: "/"
            val query = uri.rawQuery?.let { "?$it" }.orEmpty()
            return "https://$host$path$query"
        }

        internal fun sha256Prefix32(normalizedUrl: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(normalizedUrl.toByteArray(StandardCharsets.UTF_8))
            return digest.copyOfRange(0, 4).joinToString("") { byte ->
                "%02x".format(Locale.US, byte.toInt() and 0xff)
            }
        }
    }
}
