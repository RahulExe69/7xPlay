package dev.beamlak.flixquest_v2.playback

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class StreamingDndBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val controller = StreamingDndController(activity)
    private val channel = MethodChannel(messenger, "dev.beamlak.flixquest/streaming_dnd")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(mapOf(
                    "supported" to controller.supported,
                    "accessGranted" to controller.accessGranted,
                ))
                "requestAccess" -> {
                    if (!controller.supported) {
                        result.success(false)
                    } else {
                        try {
                            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                            result.success(true)
                        } catch (error: RuntimeException) {
                            result.success(false)
                        }
                    }
                }
                "setSessionActive" -> {
                    val id = call.argument<Int>("sessionId")
                    val active = call.argument<Boolean>("active")
                    if (id == null || active == null) {
                        result.error("invalid_session", "A session ID and active flag are required", null)
                    } else {
                        controller.setSessionActive(id, active)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun setForeground(value: Boolean) = controller.setForeground(value)

    fun dispose() {
        controller.dispose()
        channel.setMethodCallHandler(null)
    }
}
