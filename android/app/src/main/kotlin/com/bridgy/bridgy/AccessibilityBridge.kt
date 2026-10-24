package com.bridgy.bridgy

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter to [AgentAccessibilityService].
 *
 * Kept separate from MainActivity so the Termux/ADB channel stays untouched.
 */
object AccessibilityBridge {
    const val CHANNEL = "com.bridgy.bridgy/accessibility"
    private const val EVENT_CHANNEL = "com.bridgy.bridgy/accessibility_events"

    fun attach(flutterEngine: FlutterEngine, context: Context) {
        var eventSink: EventChannel.EventSink? = null

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        eventSink = events
                        AgentAccessibilityService.eventListener = { eventMap ->
                            eventSink?.success(eventMap)
                        }
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                        AgentAccessibilityService.eventListener = null
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val service = AgentAccessibilityService.instance
                when (call.method) {
                    "ping" -> result.success(true)

                    "logToNative" -> {
                        android.util.Log.d("BridgyDart", call.argument<String>("message") ?: "")
                        result.success(true)
                    }

                    "isServiceRunning" -> result.success(AgentAccessibilityService.isRunning())

                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    }

                    "dumpScreen" -> withService(result, service) { result.success(it.dumpScreen()) }

                    "takeScreenshot" -> withService(result, service) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            it.takeScreenshot { base64 ->
                                if (base64 != null) {
                                    result.success(base64)
                                } else {
                                    result.error("SCREENSHOT_FAILED", "Failed to capture screenshot", null)
                                }
                            }
                        } else {
                            result.error(
                                "UNSUPPORTED_VERSION",
                                "Screenshot requires Android 11 (API 30) or higher",
                                null,
                            )
                        }
                    }

                    "clickByText" -> withService(result, service) {
                        result.success(it.clickByText(call.argument<String>("text") ?: ""))
                    }

                    "clickAt" -> withService(result, service) {
                        result.success(
                            it.clickAtCoordinates(
                                call.argument<Double>("x")?.toFloat() ?: 0f,
                                call.argument<Double>("y")?.toFloat() ?: 0f,
                            ),
                        )
                    }

                    "typeText" -> withService(result, service) {
                        result.success(
                            it.typeText(
                                call.argument<String>("text") ?: "",
                                call.argument<String>("fieldHint"),
                            ),
                        )
                    }

                    "pressEnter" -> withService(result, service) { result.success(it.pressEnter()) }

                    "scroll" -> withService(result, service) {
                        result.success(
                            it.scroll(
                                call.argument<String>("direction") ?: "down",
                                call.argument<String>("target"),
                            ),
                        )
                    }

                    "swipe" -> withService(result, service) {
                        result.success(
                            it.swipe(
                                call.argument<Double>("startX")?.toFloat() ?: 0f,
                                call.argument<Double>("startY")?.toFloat() ?: 0f,
                                call.argument<Double>("endX")?.toFloat() ?: 0f,
                                call.argument<Double>("endY")?.toFloat() ?: 0f,
                            ),
                        )
                    }

                    "pressBack" -> withService(result, service) { result.success(it.pressBack()) }

                    "pressHome" -> withService(result, service) { result.success(it.pressHome()) }

                    "openNotifications" -> withService(result, service) {
                        result.success(it.openNotifications())
                    }

                    "getCurrentPackage" -> withService(result, service) {
                        result.success(it.getCurrentPackage())
                    }

                    "showToast" -> {
                        Toast.makeText(
                            context,
                            call.argument<String>("message") ?: "",
                            Toast.LENGTH_SHORT,
                        ).show()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private inline fun withService(
        result: MethodChannel.Result,
        service: AgentAccessibilityService?,
        block: (AgentAccessibilityService) -> Unit,
    ) {
        if (service == null) {
            result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
            return
        }
        block(service)
    }
}
