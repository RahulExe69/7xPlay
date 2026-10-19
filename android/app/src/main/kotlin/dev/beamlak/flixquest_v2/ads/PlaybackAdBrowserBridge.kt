package dev.beamlak.flixquest_v2.ads

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class PlaybackAdBrowserBridge(activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "dev.beamlak.flixquest/playback_ad_browser")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "openChrome") {
                result.notImplemented()
            } else {
                val url = (call.arguments as? String)?.let(Uri::parse)
                if (url == null || url.scheme !in setOf("http", "https") || url.host.isNullOrBlank()) {
                    result.success(false)
                } else {
                    try {
                        activity.startActivity(
                            Intent(Intent.ACTION_VIEW, url)
                                .addCategory(Intent.CATEGORY_BROWSABLE)
                                .setPackage("com.android.chrome"),
                        )
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    } catch (_: SecurityException) {
                        result.success(false)
                    }
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
