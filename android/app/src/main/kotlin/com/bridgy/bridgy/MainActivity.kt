package com.bridgy.bridgy

import android.app.SearchManager
import android.content.Intent
import android.os.Build
import android.util.DisplayMetrics
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter to on-device shell execution.
 *
 * Primary backend: Termux `RUN_COMMAND` (requires Termux + android-tools + wireless ADB paired).
 * Commands are sent as `bash -c "<command>"`; when [raw] is false the string is prefixed with
 * `adb shell` because Termux owns the adb client, not the app.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.bridgy.app/adb"
    private val goalsChannelName = "com.bridgy.app/goals"
    private val goalsEventChannelName = "com.bridgy.app/goals/stream"
    private var pendingText: String? = null
    private var pendingGoal: String? = null
    private var goalSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingText = extractText(intent)
        pendingGoal = extractGoal(intent)
        AccessibilityBridge.attach(flutterEngine, applicationContext)
        registerGoalChannels(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTermuxInstalled" -> result.success(isTermuxInstalled())
                    "runCommand" -> {
                        val command = call.argument<String>("command").orEmpty()
                        val raw = call.argument<Boolean>("raw") ?: false
                        if (command.isBlank()) {
                            result.error("EMPTY_COMMAND", "command is empty", null)
                            return@setMethodCallHandler
                        }
                        val error = runViaTermux(command, raw)
                        if (error == null) result.success(true) else result.error("NO_TERMUX", error, null)
                    }
                    "readScreenDump" -> result.success(readScreenDump())
                    "screenSize" -> result.success(screenSize())
                    "launchText" -> {
                        result.success(pendingText)
                        pendingText = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Cold-start goal read plus a stream for warm-start intents. */
    private fun registerGoalChannels(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, goalsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunchGoal" -> {
                        result.success(pendingGoal)
                        pendingGoal = null
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, goalsEventChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        goalSink = events
                        val pending = pendingGoal
                        if (pending != null) {
                            pendingGoal = null
                            events?.success(pending)
                        }
                    }

                    override fun onCancel(arguments: Any?) {
                        goalSink = null
                    }
                },
            )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingText = extractText(intent) ?: pendingText
        val goal = extractGoal(intent)
        if (goal != null) {
            val sink = goalSink
            if (sink != null) {
                pendingGoal = null
                sink.success(goal)
            } else {
                pendingGoal = goal
            }
        }
    }

    private fun extractGoal(intent: Intent?): String? {
        if (intent == null) return null
        val goal = intent.getStringExtra(EXTRA_GOAL)
            ?: intent.getStringExtra(SearchManager.QUERY)
            ?: intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra("query")
        return goal?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun extractText(intent: Intent?): String? {
        if (intent == null) return null
        return intent.getStringExtra(SearchManager.QUERY)
            ?: intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra("query")
    }

    private fun isTermuxInstalled(): Boolean = try {
        packageManager.getPackageInfo(TERMUX_PACKAGE, 0)
        true
    } catch (_: Exception) {
        false
    }

    /** Returns null on success, or a human-readable error. */
    private fun runViaTermux(command: String, raw: Boolean): String? {
        if (!isTermuxInstalled()) return "Termux is not installed"
        val script = if (raw) command else "adb shell $command"
        return try {
            val intent = Intent().apply {
                setClassName(TERMUX_PACKAGE, "$TERMUX_PACKAGE.app.RunCommandService")
                action = "com.termux.RUN_COMMAND"
                putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/$TERMUX_PACKAGE/files/usr/bin/bash")
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script))
                putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/$TERMUX_PACKAGE/files/home")
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
            }
            startService(intent)
            null
        } catch (e: Exception) {
            "Termux rejected command: ${e.message}"
        }
    }

    private fun readScreenDump(): String? {
        for (path in DUMP_PATHS) {
            val file = File(path)
            if (file.exists() && file.length() > 0) return file.readText()
        }
        return null
    }

    private fun screenSize(): String {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)
        val w = metrics.widthPixels
        val h = metrics.heightPixels
        return "${w}x${h}"
    }

    companion object {
        const val EXTRA_GOAL = "com.bridgy.bridgy.AGENT_GOAL"
        const val TERMUX_PACKAGE = "com.termux"
        val DUMP_PATHS = listOf(
            "/sdcard/window_dump.xml",
            "/storage/emulated/0/window_dump.xml",
            "/data/local/tmp/window_dump.xml",
        )
        @Suppress("unused")
        const val MIN_SDK_FOR_SPECIAL_USE = Build.VERSION_CODES.UPSIDE_DOWN_CAKE
    }
}
