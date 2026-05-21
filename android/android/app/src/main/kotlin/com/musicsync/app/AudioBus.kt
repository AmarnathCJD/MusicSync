package com.musicsync.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object AudioBus {
    @Volatile var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun emitLevel(bass: Double, mid: Double, high: Double, level: Double, beat: Boolean) {
        val s = sink ?: return
        val payload = mapOf(
            "bass" to bass,
            "mid" to mid,
            "high" to high,
            "level" to level,
            "beat" to beat
        )
        mainHandler.post { s.success(payload) }
    }

    fun emitError(msg: String) {
        val s = sink ?: return
        mainHandler.post { s.error("audio", msg, null) }
    }
}
