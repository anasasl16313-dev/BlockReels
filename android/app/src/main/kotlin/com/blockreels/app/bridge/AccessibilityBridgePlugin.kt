package com.blockreels.app.bridge

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import com.blockreels.app.BlockReelsAccessibilityService
import com.blockreels.app.MonitoringForegroundService
import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import com.blockreels.app.state.NativeStateStore
import com.blockreels.app.state.PendingBlockEventStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.CopyOnWriteArrayList

private val androidPackage = Regex("[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*")

private fun validPackage(value: Any?): String {
    require(value is String && value.length <= 255 && androidPackage.matches(value)) { "Invalid package" }
    return value
}

private fun integer(value: Any?, range: IntRange): Int {
    require(value is Int || value is Long) { "Expected an integer" }
    val number = (value as Number).toLong()
    require(number in range.first.toLong()..range.last.toLong()) { "Integer outside supported range" }
    return number.toInt()
}

internal fun validatedRecords(arguments: Any?, key: String): List<Map<String, Any>> {
    val list = if (arguments is Map<*, *>) arguments[key] else arguments
    require(list is List<*> && list.size <= 4096) { "Invalid record list" }
    val ids = mutableSetOf<String>()
    return list.map { entry ->
        require(entry is Map<*, *>) { "Invalid record" }
        if (key == "rules") {
            val pkg = validPackage(entry["packageName"])
            val enabled = entry["isEnabled"]
            require(ids.add(pkg) && enabled is Boolean)
            mapOf(
                "packageName" to pkg,
                "isEnabled" to enabled,
                "interventionMode" to parseMode(entry["interventionMode"] ?: entry["mode"] ?: "AUTO_BACK").name,
                "holdDurationSeconds" to integer(entry["holdDurationSeconds"] ?: 7, 1..3600)
            )
        } else {
            require(key == "schedules")
            val id = entry["id"]
            val title = entry["title"] ?: entry["name"] ?: "Schedule"
            val active = entry["isActive"]
            require(id is String && id.isNotBlank() && id.length <= 4096 && ids.add(id))
            require(title is String && title.length <= 4096 && active is Boolean)
            val days = entry["daysOfWeek"]
            require(days is List<*> && days.size <= 7)
            val isoDays = days.map { integer(it, 1..7) }
            require(isoDays.distinct().size == isoDays.size)
            val packages = entry["enabledPackages"] ?: entry["enabledPackageNames"] ?: entry["enabledApps"] ?: entry["targetPackageNames"]
            require(packages is List<*> && packages.size <= 4096)
            mapOf(
                "id" to id, "title" to title, "isActive" to active, "daysOfWeek" to isoDays,
                "startHour" to integer(entry["startHour"], 0..23),
                "endHour" to integer(entry["endHour"], 0..23),
                "startMinute" to integer(entry["startMinute"], 0..59),
                "endMinute" to integer(entry["endMinute"], 0..59),
                "enabledPackages" to packages.map(::validPackage).distinct()
            )
        }
    }
}

private fun parseMode(value: Any?): InterventionMode = when ((value as? String)?.uppercase()?.replace("_", "")) {
    "IMMEDIATEBACK", "AUTOBACK" -> InterventionMode.AUTO_BACK
    "MINDFULPAUSE", "MINDFUL" -> InterventionMode.MINDFUL_PAUSE
    "STRICTBLOCK", "STRICT" -> InterventionMode.STRICT_BLOCK
    else -> throw IllegalArgumentException("Unknown intervention mode")
}

private fun validatedConfig(arguments: Any?, fallbackSound: Boolean): InterventionConfig {
    require(arguments is Map<*, *>)
    val mode = parseMode(arguments["mode"] ?: arguments["defaultMode"])
    val holdSeconds = integer(arguments["holdDurationSeconds"], 5..30)
    val message = arguments["customMessage"] ?: "Take a deep breath."
    val sound = arguments["soundEnabled"] ?: fallbackSound
    val haptics = arguments["hapticsEnabled"] ?: true
    val pinProtected = arguments["pinProtected"] ?: false
    require(message is String && message.length <= 4096)
    require(sound is Boolean && haptics is Boolean && pinProtected is Boolean)
    return InterventionConfig(mode, holdSeconds, message, sound, haptics, pinProtected)
}

internal class NativePersistenceException(cause: Exception) :
    Exception("Could not persist native state. Please retry.", cause) {
    companion object {
        const val CODE = "PERSISTENCE_ERROR"
    }
}

internal suspend fun acknowledgePersistence(write: suspend () -> Unit): Boolean {
    try {
        write()
        return true
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (failure: Exception) {
        throw NativePersistenceException(failure)
    }
}

/**
 * Platform bridge handler for communication between UI layers (Flutter / Compose) and native services.
 * Implements full bidirectional RPC dispatch and event streaming.
 */
class AccessibilityBridgePlugin(
    private val context: Context
) {
    companion object {
        const val CHANNEL_METHOD_PRIMARY = "com.blockreels.app/platform"
        const val CHANNEL_METHOD_ALIAS = "com.blockreels/accessibility_control"
        const val CHANNEL_EVENT_PRIMARY = "com.blockreels.app/events"
        const val CHANNEL_EVENT_ALIAS = "com.blockreels/accessibility_events"

        @Volatile
        private var defaultInstance: AccessibilityBridgePlugin? = null

        fun getInstance(context: Context): AccessibilityBridgePlugin {
            return defaultInstance ?: synchronized(this) {
                defaultInstance ?: AccessibilityBridgePlugin(context.applicationContext).also {
                    defaultInstance = it
                }
            }
        }

        fun emitEvent(eventData: Map<String, Any>) {
            defaultInstance?.broadcastEvent(eventData)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val eventListeners = CopyOnWriteArrayList<(Map<String, Any>) -> Unit>()

    init {
        defaultInstance = this
        NativeStateStore.initialize(context)
        NativeStateStore.eventBroadcaster = { eventMap ->
            broadcastEvent(eventMap)
        }
    }

    fun addEventListener(listener: (Map<String, Any>) -> Unit) {
        eventListeners.add(listener)
    }

    fun removeEventListener(listener: (Map<String, Any>) -> Unit) {
        eventListeners.remove(listener)
    }

    fun broadcastEvent(eventData: Map<String, Any>) {
        mainHandler.post {
            for (listener in eventListeners) {
                try {
                    listener(eventData)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    /**
     * Synchronously/Asynchronously dispatches a method call by name with arguments.
     */
    suspend fun handleMethodCall(method: String, arguments: Any?): Any? {
        return when (method) {
            "isAccessibilityServiceEnabled" -> {
                isAccessibilityServiceEnabled()
            }
            "openAccessibilitySettings", "requestAccessibilityPermission" -> {
                openAccessibilitySettings()
            }
            "isBatteryOptimizationIgnored", "isBatteryOptimizationDisabled" -> {
                isBatteryOptimizationIgnored()
            }
            "requestIgnoreBatteryOptimization", "requestDisableBatteryOptimization" -> {
                requestIgnoreBatteryOptimization()
            }
            "isOverlayPermissionGranted" -> {
                isOverlayPermissionGranted()
            }
            "requestOverlayPermission" -> {
                requestOverlayPermission()
            }
            "isUsageStatsPermissionGranted" -> {
                isUsageStatsPermissionGranted()
            }
            "requestUsageStatsPermission" -> {
                requestUsageStatsPermission()
            }
            "syncAppToggles" -> {
                require(arguments is Map<*, *> && arguments.size <= 4096)
                val toggles = arguments.entries.associate { (key, value) ->
                    require(value is Boolean)
                    validPackage(key) to value
                }
                acknowledgePersistence { NativeStateStore.setAppToggles(context, toggles) }
            }
            "syncInterventionConfig" -> {
                val config = validatedConfig(arguments, NativeStateStore.getInterventionConfig().soundEnabled)
                acknowledgePersistence {
                    NativeStateStore.setInterventionConfig(
                        context,
                        config.mode,
                        config.holdDurationSeconds,
                        config.customMessage,
                        config.soundEnabled,
                        config.hapticsEnabled,
                        config.pinProtected
                    )
                }
            }
            "syncRestoredProtection" -> {
                require(arguments is Map<*, *>)
                val enabled = arguments["isMasterEnabled"]
                require(enabled is Boolean)
                val rules = validatedRecords(arguments, "rules")
                val schedules = validatedRecords(arguments, "schedules")
                val config = validatedConfig(arguments["config"], fallbackSound = true)
                acknowledgePersistence {
                    NativeStateStore.applyRestoredProtection(context, rules, schedules, config, enabled)
                }
            }
            "syncSchedules" -> {
                val schedules = validatedRecords(arguments, "schedules")
                acknowledgePersistence { NativeStateStore.setSchedules(context, schedules) }
            }
            "syncRules" -> {
                val rules = validatedRecords(arguments, "rules")
                acknowledgePersistence { NativeStateStore.setRules(context, rules) }
            }
            "updateSettings" -> {
                val enabled = (arguments as? Map<*, *>)?.get("isMasterEnabled")
                require(enabled is Boolean)
                acknowledgePersistence { NativeStateStore.updateSettings(context, mapOf("isMasterEnabled" to enabled)) }
            }
            "grantTemporaryAllowance" -> {
                require(arguments is Map<*, *>)
                val pkg = validPackage(arguments["packageName"])
                require(com.blockreels.app.detection.AppPlatform.fromPackageName(pkg) != null)
                val seconds = integer(arguments["durationSeconds"] ?: 300, 1..300)
                BlockReelsAccessibilityService.grantTemporaryAllowance(pkg, seconds * 1000L)
            }
            "getInstalledApps" -> getInstalledTargetApps()
            "startForegroundService" -> MonitoringForegroundService.start(context)
            "stopForegroundService" -> { MonitoringForegroundService.stop(context); true }
            "isForegroundServiceRunning" -> MonitoringForegroundService.isRunning()
            "getRealtimeMetrics" -> NativeStateStore.getMetricsSnapshot()
            "clearPendingBlockEvents" -> acknowledgePersistence {
                withContext(Dispatchers.IO) { PendingBlockEventStore.getInstance(context).clearPending() }
            }
            "readPendingBlockEvents" -> {
                val limit = integer((arguments as? Map<*, *>)?.get("limit") ?: 100, 1..100)
                withContext(Dispatchers.IO) {
                    PendingBlockEventStore.getInstance(context).readPending(limit)
                }
            }
            "acknowledgeBlockEvents" -> {
                val values = (arguments as? Map<*, *>)?.get("ids")
                require(values is List<*> && values.size <= 100)
                val ids = values.map { id ->
                    require(id is String && id.isNotBlank() && id.length <= 128)
                    id
                }
                acknowledgePersistence {
                    withContext(Dispatchers.IO) {
                        PendingBlockEventStore.getInstance(context).acknowledge(ids)
                    }
                }
            }
            else -> {
                null
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Helper Implementations
    // ---------------------------------------------------------------------------

    fun isAccessibilityServiceEnabled(): Boolean {
        val expectedServiceName = "${context.packageName}/${BlockReelsAccessibilityService::class.java.canonicalName}"
        val enabledServices = try {
            Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
        } catch (_: Exception) {
            null
        } ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedServiceName, ignoreCase = true) ||
                componentName.contains(BlockReelsAccessibilityService::class.java.simpleName)
            ) {
                return true
            }
        }
        return false
    }

    fun openAccessibilitySettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isBatteryOptimizationIgnored(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
    }

    fun requestIgnoreBatteryOptimization(): Boolean {
        return try {
            if (isBatteryOptimizationIgnored()) return true
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Settings.canDrawOverlays(context)
            } catch (_: Exception) {
                true
            }
        } else {
            true
        }
    }

    fun requestOverlayPermission(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } else {
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    fun isUsageStatsPermissionGranted(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } catch (_: Exception) {
                AppOpsManager.MODE_ALLOWED
            }
        } else {
            try {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } catch (_: Exception) {
                AppOpsManager.MODE_ALLOWED
            }
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun requestUsageStatsPermission(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun getInstalledTargetApps(): List<Map<String, Any>> {
        val targetPackages = listOf(
            "com.instagram.android" to "Instagram",
            "com.google.android.youtube" to "YouTube",
            "com.facebook.katana" to "Facebook",
            "com.facebook.lite" to "Facebook Lite",
            "com.zhiliaoapp.musically" to "TikTok",
            "com.ss.android.ugc.trill" to "TikTok",
            "com.ss.android.ugc.aweme" to "Douyin",
            "com.ss.android.ugc.aweme.lite" to "TikTok Lite"
        )

        val pm = context.packageManager
        val result = mutableListOf<Map<String, Any>>()

        for ((pkg, defaultName) in targetPackages) {
            try {
                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    pm.getApplicationInfo(pkg, 0)
                }
                val label = pm.getApplicationLabel(appInfo).toString()
                result.add(
                    mapOf(
                        "packageName" to pkg,
                        "appName" to label,
                        "isInstalled" to true
                    )
                )
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed on device, but known target
                result.add(
                    mapOf(
                        "packageName" to pkg,
                        "appName" to defaultName,
                        "isInstalled" to false
                    )
                )
            } catch (_: Exception) {
                // Ignore
            }
        }
        return result
    }
}
