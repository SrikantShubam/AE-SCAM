package com.vectorveda.guardian

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

object BatteryOptimizationSettingsNavigator {
    private const val xiaomiAction = "miui.intent.action.POWER_HIDE_MODE_APP_LIST"
    private const val oppoRealmePackage = "com.coloros.oppoguardelf"
    private const val oppoRealmeClass = "com.coloros.oppoguardelf.MainActivity"
    private const val vivoPackage = "com.vivo.permissionmanager"
    private const val vivoClass = "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
    private const val samsungPackage = "com.samsung.android.lool"
    private const val samsungClass = "com.samsung.android.lool.ui.battery.BatteryActivity"

    internal data class TargetIntent(
        val action: String? = null,
        val componentPackage: String? = null,
        val componentClass: String? = null,
        val requiresPackageUri: Boolean = false,
    )

    internal fun targetIntentForManufacturer(manufacturerRaw: String?): TargetIntent {
        val manufacturer = manufacturerRaw?.trim()?.lowercase().orEmpty()
        return when {
            manufacturer.contains("xiaomi") -> TargetIntent(action = xiaomiAction)
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                TargetIntent(
                    componentPackage = oppoRealmePackage,
                    componentClass = oppoRealmeClass,
                )
            }
            manufacturer.contains("vivo") -> {
                TargetIntent(
                    componentPackage = vivoPackage,
                    componentClass = vivoClass,
                )
            }
            manufacturer.contains("samsung") -> {
                TargetIntent(
                    componentPackage = samsungPackage,
                    componentClass = samsungClass,
                )
            }
            else -> TargetIntent(
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                requiresPackageUri = true,
            )
        }
    }

    internal fun navigationTargetsForManufacturer(manufacturerRaw: String?): List<TargetIntent> {
        val oemTarget = targetIntentForManufacturer(manufacturerRaw)
        val genericTarget = TargetIntent(
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            requiresPackageUri = true,
        )

        return if (oemTarget == genericTarget) {
            listOf(genericTarget)
        } else {
            listOf(oemTarget, genericTarget)
        }
    }

    private fun intentForTarget(context: Context, target: TargetIntent): Intent {
        return Intent().apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            if (target.componentPackage != null && target.componentClass != null) {
                component = ComponentName(target.componentPackage, target.componentClass)
            } else if (target.action != null) {
                action = target.action
            }
            if (target.requiresPackageUri) {
                data = Uri.parse("package:${context.packageName}")
            }
        }
    }

    fun open(context: Context): Boolean {
        val targets = navigationTargetsForManufacturer(Build.MANUFACTURER)
        for (target in targets) {
            try {
                context.startActivity(intentForTarget(context, target))
                return true
            } catch (_: ActivityNotFoundException) {
                // Try the next fallback target.
            } catch (_: SecurityException) {
                // Try the next fallback target.
            }
        }

        // Last-resort fallback to app details page.
        val fallback = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"),
        ).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        return try {
            context.startActivity(fallback)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}

