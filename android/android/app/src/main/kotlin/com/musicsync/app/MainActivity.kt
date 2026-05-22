package com.musicsync.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "musicsync/audio"
    private val eventChannelName  = "musicsync/audio/events"

    private var pendingResult: MethodChannel.Result? = null
    private var pendingMicResult: MethodChannel.Result? = null
    private val REQ_PROJECTION = 7301
    private val REQ_MIC        = 7302

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
                    "requestMic" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this, Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            startMicService()
                            result.success(true)
                        } else {
                            pendingMicResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_MIC,
                            )
                        }
                    }
                    "requestIdleForeground" -> {
                        // Spin up the foreground service without opening
                        // AudioRecord — keeps the app process alive while
                        // we stream locally-rendered preset frames via UDP.
                        val svc = Intent(this, AudioCaptureService::class.java)
                        svc.action = AudioCaptureService.ACTION_START_IDLE
                        startForegroundService(svc)
                        result.success(true)
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MIC) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                startMicService()
                pendingMicResult?.success(true)
            } else {
                pendingMicResult?.success(false)
            }
            pendingMicResult = null
        }
    }

    private fun startMicService() {
        val svc = Intent(this, AudioCaptureService::class.java)
        svc.action = AudioCaptureService.ACTION_START_MIC
        startForegroundService(svc)
    }
}
