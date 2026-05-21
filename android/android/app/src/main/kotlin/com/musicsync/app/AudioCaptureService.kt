package com.musicsync.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.concurrent.thread
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.PI

class AudioCaptureService : Service() {

    companion object {
        const val ACTION_START = "musicsync.audio.START"
        const val ACTION_STOP  = "musicsync.audio.STOP"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA        = "data"

        private const val NOTIF_CHANNEL = "musicsync_audio"
        private const val NOTIF_ID = 7311

        private const val SAMPLE_RATE = 44100
        private const val FRAMES = 1024
    }

    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    @Volatile private var running = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startCapture(intent)
            ACTION_STOP  -> { stopCapture(); stopSelf() }
        }
        return START_NOT_STICKY
    }

    private fun ensureNotification(): Notification {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(NOTIF_CHANNEL) == null) {
            val ch = NotificationChannel(NOTIF_CHANNEL, "MusicSync Audio", NotificationManager.IMPORTANCE_LOW)
            mgr.createNotificationChannel(ch)
        }
        return NotificationCompat.Builder(this, NOTIF_CHANNEL)
            .setContentTitle("MusicSync audio sync")
            .setContentText("Capturing system audio")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }

    private fun startCapture(intent: Intent) {
        if (running) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, ensureNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIF_ID, ensureNotification())
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)
        if (data == null) {
            AudioBus.emitError("missing projection data")
            stopSelf()
            return
        }

        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val proj = mgr.getMediaProjection(resultCode, data)
        if (proj == null) {
            AudioBus.emitError("failed to get MediaProjection")
            stopSelf()
            return
        }
        projection = proj

        val config = AudioPlaybackCaptureConfiguration.Builder(proj)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
            .build()

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_STEREO,
            AudioFormat.ENCODING_PCM_FLOAT
        )
        val bufBytes = max(minBuf, FRAMES * 2 * 4 * 4)

        val rec = AudioRecord.Builder()
            .setAudioFormat(format)
            .setBufferSizeInBytes(bufBytes)
            .setAudioPlaybackCaptureConfig(config)
            .build()
        record = rec

        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            AudioBus.emitError("AudioRecord init failed")
            stopSelf()
            return
        }

        rec.startRecording()
        running = true

        thread(name = "musicsync-capture", isDaemon = true) {
            captureLoop(rec)
        }
    }

    private fun captureLoop(rec: AudioRecord) {
        val readBuf = FloatArray(FRAMES * 2)
        val mono    = FloatArray(FRAMES)
        val window  = DoubleArray(FRAMES) { i -> 0.5 * (1.0 - cos(2.0 * PI * i / (FRAMES - 1))) }

        val re = DoubleArray(FRAMES)
        val im = DoubleArray(FRAMES)
        val binCount = FRAMES / 2 + 1
        val freqs = DoubleArray(binCount) { i -> i.toDouble() * SAMPLE_RATE / FRAMES }
        val bassIdx = (0 until binCount).filter { freqs[it] in 20.0..200.0 }
        val midIdx  = (0 until binCount).filter { freqs[it] in 200.0..2000.0 }
        val highIdx = (0 until binCount).filter { freqs[it] in 2000.0..8000.0 }

        var peak         = 1e-6
        var smoothLevel  = 0.0
        var bassBaseline = 0.0
        val emitEvery    = 2  // ~50ms between Flutter events
        var emitCounter  = 0

        while (running) {
            val want = readBuf.size
            var got = 0
            while (got < want && running) {
                val r = rec.read(readBuf, got, want - got, AudioRecord.READ_BLOCKING)
                if (r <= 0) break
                got += r
            }
            if (!running) break

            for (i in 0 until FRAMES) {
                mono[i] = (readBuf[i * 2] + readBuf[i * 2 + 1]) * 0.5f
            }

            for (i in 0 until FRAMES) {
                re[i] = mono[i].toDouble() * window[i]
                im[i] = 0.0
            }
            fftRadix2(re, im)

            fun bandMag(idxs: List<Int>): Double {
                if (idxs.isEmpty()) return 0.0
                var s = 0.0
                for (i in idxs) s += hypot(re[i], im[i])
                return s / idxs.size
            }
            val bass = bandMag(bassIdx)
            val mid  = bandMag(midIdx)
            val high = bandMag(highIdx)
            val level = bass + mid + high

            peak = max(peak * 0.9995, level)
            val normLevel = if (peak > 0) level / peak else 0.0
            smoothLevel = 0.35 * smoothLevel + 0.65 * normLevel

            val bassNorm = if (peak > 0) bass / peak else 0.0
            bassBaseline = 0.92 * bassBaseline + 0.08 * bassNorm
            val beatStrength = bassNorm - bassBaseline
            val beat = beatStrength > 0.12

            emitCounter++
            if (emitCounter >= emitEvery) {
                emitCounter = 0
                AudioBus.emitLevel(
                    bassNorm,
                    if (peak > 0) mid / peak else 0.0,
                    if (peak > 0) high / peak else 0.0,
                    smoothLevel,
                    beat
                )
            }
        }
    }

    private fun stopCapture() {
        running = false
        try { record?.stop() } catch (_: Throwable) {}
        try { record?.release() } catch (_: Throwable) {}
        record = null
        try { projection?.stop() } catch (_: Throwable) {}
        projection = null
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }

    // ---- Radix-2 in-place FFT (Cooley-Tukey) ----
    private fun fftRadix2(re: DoubleArray, im: DoubleArray) {
        val n = re.size
        // bit reverse
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit
            if (i < j) {
                val tr = re[i]; re[i] = re[j]; re[j] = tr
                val ti = im[i]; im[i] = im[j]; im[j] = ti
            }
        }
        var len = 2
        while (len <= n) {
            val ang = -2.0 * PI / len
            val wlr = cos(ang)
            val wli = kotlin.math.sin(ang)
            var i = 0
            while (i < n) {
                var wr = 1.0; var wi = 0.0
                for (k in 0 until len / 2) {
                    val xr = re[i + k]
                    val xi = im[i + k]
                    val yr = re[i + k + len / 2] * wr - im[i + k + len / 2] * wi
                    val yi = re[i + k + len / 2] * wi + im[i + k + len / 2] * wr
                    re[i + k] = xr + yr
                    im[i + k] = xi + yi
                    re[i + k + len / 2] = xr - yr
                    im[i + k + len / 2] = xi - yi
                    val nwr = wr * wlr - wi * wli
                    val nwi = wr * wli + wi * wlr
                    wr = nwr; wi = nwi
                }
                i += len
            }
            len = len shl 1
        }
        // suppress unused-import-style warnings
        val _u = min(1.0, ln(1.0))
    }
}
