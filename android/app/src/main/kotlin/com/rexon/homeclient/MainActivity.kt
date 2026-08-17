package com.rexon.homeclient

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val PIP_CHANNEL = "com.rexon.homeclient/pip"
    private val PIP_EVENT_CHANNEL = "com.rexon.homeclient/pip_events"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPip") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val aspectRatio = Rational(16, 9)
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(aspectRatio)
                        .build()
                    enterPictureInPictureMode(params)
                    result.success(true)
                } else {
                    result.error("NOT_SUPPORTED", "PiP not supported", null)
                }
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        eventSink?.success(isInPictureInPictureMode)
    }
}
