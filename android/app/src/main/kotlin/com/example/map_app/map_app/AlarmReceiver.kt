package com.example.map_app.map_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Received alarm event: ${intent.action}")

        when (intent.action) {
            "com.example.map_app.ALARM_CHECK" -> {
                val journeyId = intent.getIntExtra("journeyId", -1)
                Log.d("AlarmReceiver", "Scheduled check fired for journeyId=$journeyId")
            }
            "com.example.map_app.STOP_ALARM" -> {
                val audioService = Intent(context, AlarmAudioService::class.java)
                context.stopService(audioService)
            }
            else -> {
                val appIntent = Intent(context, AlarmActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("destinationName", intent.getStringExtra("destinationName") ?: "Destination")
                }
                context.startActivity(appIntent)
            }
        }
    }
}
