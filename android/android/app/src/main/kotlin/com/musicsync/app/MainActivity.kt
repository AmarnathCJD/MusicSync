package com.musicsync.app

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "musicsync/audio"
    private val eventChannelName  = "musicsync/audio/events"

    private var pendingResult: MethodChannel.Result? = null
    private val REQ_PROJECTION = 7301

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestCapture" -> {
                        pendingResult = result
                        val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        startActivityForResult(mgr.createScreenCaptureIntent(), REQ_PROJECTION)
                    }
                    "stopCapture" -> {
                        val i = Intent(this, AudioCaptureService::class.java)
                        i.action = AudioCaptureService.ACTION_STOP
                        startService(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    AudioBus.sink = sink
                }
                override fun onCancel(args: Any?) {
                    AudioBus.sink = null
                }
            })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val svc = Intent(this, AudioCaptureService::class.java)
                svc.action = AudioCaptureService.ACTION_START
                svc.putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
                svc.putExtra(AudioCaptureService.EXTRA_DATA, data)
                startForegroundService(svc)
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }
}
