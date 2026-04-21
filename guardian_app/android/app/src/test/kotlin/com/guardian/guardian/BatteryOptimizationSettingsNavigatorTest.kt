package com.guardian.guardian

import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BatteryOptimizationSettingsNavigatorTest {
    @Test
    fun `maps xiaomi manufacturer to MIUI power action`() {
        val target = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("Xiaomi")

        assertEquals("miui.intent.action.POWER_HIDE_MODE_APP_LIST", target.action)
        assertNull(target.componentPackage)
        assertNull(target.componentClass)
        assertTrue(!target.requiresPackageUri)
    }

    @Test
    fun `maps oppo and realme manufacturers to ColorOS component`() {
        val oppoTarget = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("OPPO")
        val realmeTarget = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("realme")

        assertNotNull(oppoTarget.componentPackage)
        assertNotNull(oppoTarget.componentClass)
        assertNotNull(realmeTarget.componentPackage)
        assertNotNull(realmeTarget.componentClass)
        assertEquals("com.coloros.oppoguardelf", oppoTarget.componentPackage)
        assertEquals("com.coloros.oppoguardelf.MainActivity", oppoTarget.componentClass)
        assertEquals("com.coloros.oppoguardelf", realmeTarget.componentPackage)
        assertEquals("com.coloros.oppoguardelf.MainActivity", realmeTarget.componentClass)
    }

    @Test
    fun `maps vivo and samsung manufacturers to declared components`() {
        val vivoTarget = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("vivo")
        val samsungTarget = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("Samsung")

        assertEquals("com.vivo.permissionmanager", vivoTarget.componentPackage)
        assertEquals(
            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            vivoTarget.componentClass,
        )
        assertEquals("com.samsung.android.lool", samsungTarget.componentPackage)
        assertEquals(
            "com.samsung.android.lool.ui.battery.BatteryActivity",
            samsungTarget.componentClass,
        )
    }

    @Test
    fun `falls back to request ignore battery optimization action`() {
        val target = BatteryOptimizationSettingsNavigator.targetIntentForManufacturer("google")

        assertEquals(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, target.action)
        assertNull(target.componentPackage)
        assertNull(target.componentClass)
        assertTrue(target.requiresPackageUri)
    }
}
