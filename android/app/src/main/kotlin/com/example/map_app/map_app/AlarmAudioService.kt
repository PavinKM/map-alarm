package com.example.map_app.map_app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.example.map_app.map_app.audio.AlarmAudioEngine

class AlarmAudioService : Service() {
    private lateinit var audioEngine: AlarmAudioEngine

    override fun onCreate() {
        super.onCreate()
        audioEngine = AlarmAudioEngine(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        audioEngine.start()
        return START_STICKY
    }

    override fun onDestroy() {
        audioEngine.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
