package com.guardian.guardian

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UrlReputationStoreTest {
    @Test
    fun `normalizes urls consistently`() {
        assertEquals(
            "https://example.com/",
            UrlReputationStore.normalizeUrl("example.com"),
        )
        assertEquals(
            "https://example.com/pay?x=1",
            UrlReputationStore.normalizeUrl("https://EXAMPLE.com/pay?x=1"),
        )
        assertNull(UrlReputationStore.normalizeUrl("  "))
    }

    @Test
    fun `hash prefix is deterministic and 32-bit hex`() {
        val normalized = UrlReputationStore.normalizeUrl("https://phish.test/pay")!!
        val prefixA = UrlReputationStore.sha256Prefix32(normalized)
        val prefixB = UrlReputationStore.sha256Prefix32(normalized)
        assertEquals(
            8,
            prefixA.length,
        )
        assertEquals(
            prefixA,
            prefixB,
        )
    }
}
