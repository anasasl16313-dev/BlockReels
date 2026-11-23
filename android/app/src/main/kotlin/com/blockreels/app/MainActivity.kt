package com.blockreels.app

import android.content.Intent
import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.blockreels.app.bridge.AccessibilityBridgePlugin
import com.blockreels.app.bridge.NativePersistenceException
import com.blockreels.app.state.NativeStateStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    // BlockReels exposes a launcher only. Flutter must not interpret caller-supplied
    // routes, shell flags, entrypoints or cached engine identifiers.
    private fun launcherIntent() = Intent(this, MainActivity::class.java)
        .setAction(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

    override fun onCreate(savedInstanceState: Bundle?) {
        intent = launcherIntent()
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(launcherIntent())
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
    }

    private val bridgePlugin by lazy { AccessibilityBridgePlugin.getInstance(context) }
    private val bridgeScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var pendingForegroundServiceResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeStateStore.initialize(applicationContext)

        // Setup MethodChannel for RPC calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AccessibilityBridgePlugin.CHANNEL_METHOD_PRIMARY)
            .setMethodCallHandler { call, result ->
                if (call.method == "startForegroundService" &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    pendingForegroundServiceResult?.success(false)
                    pendingForegroundServiceResult = result
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        NOTIFICATION_PERMISSION_REQUEST
                    )
                    return@setMethodCallHandler
                }

                dispatchMethod(call.method, call.arguments, result)
            }

        // Setup EventChannel for streaming events (Block events, service status)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AccessibilityBridgePlugin.CHANNEL_EVENT_PRIMARY)
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var listener: ((Map<String, Any>) -> Unit)? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    listener?.let { bridgePlugin.removeEventListener(it) }
                    listener = { eventData ->
                        runOnUiThread {
                            events?.success(eventData)
                        }
                    }
                    listener?.let { bridgePlugin.addEventListener(it) }
                    // Drain again after listener attachment to close the subscribe/read race.
                    events?.success(mapOf(
                        "eventType" to "BLOCK_EVENTS_CONNECTED",
                        "timestamp" to System.currentTimeMillis()
                    ))
                }

                override fun onCancel(arguments: Any?) {
                    listener?.let { bridgePlugin.removeEventListener(it) }
                    listener = null
                }
            })
    }

    private fun dispatchMethod(method: String, arguments: Any?, result: MethodChannel.Result) {
        bridgeScope.launch {
            try {
                result.success(bridgePlugin.handleMethodCall(method, arguments))
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: NativePersistenceException) {
                result.error(NativePersistenceException.CODE, failure.message, null)
            } catch (failure: Exception) {
                result.error("ERROR", failure.message, null)
            }
        }
    }

    override fun onDestroy() {
        bridgeScope.cancel()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            val result = pendingForegroundServiceResult
            pendingForegroundServiceResult = null

            if (granted) {
                result?.let { dispatchMethod("startForegroundService", null, it) }
            } else {
                result?.success(false)
            }
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
