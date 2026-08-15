package com.example.map_app.map_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.map_app.map_app.audio.AlarmAudioEngine
import com.example.map_app.map_app.services.LocationForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var alarmAudioEngine: AlarmAudioEngine
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val TAG = "MainActivity"
        private const val METHOD_CHANNEL = "com.example.map_app/native_bridge"
        private const val EVENT_CHANNEL = "com.example.map_app/location_events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmAudioEngine = AlarmAudioEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        val destinationName = call.argument<String>("destinationName") ?: "Destination"
                        val destinationLat = call.argument<Double>("destinationLat") ?: 0.0
                        val destinationLng = call.argument<Double>("destinationLng") ?: 0.0
                        val radiusMeters = call.argument<Double>("radiusMeters") ?: 0.0
                        startForegroundService(destinationName, destinationLat, destinationLng, radiusMeters)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopService(Intent(this, LocationForegroundService::class.java))
                        result.success(true)
                    }
                    "scheduleNextCheck" -> {
                        val timestampMs = call.argument<Long>("timestampMs") ?: 0L
                        val journeyId = call.argument<Int>("journeyId") ?: -1
                        scheduleNextCheck(timestampMs, journeyId)
                        result.success(true)
                    }
                    "cancelScheduledChecks" -> {
                        cancelScheduledChecks()
                        result.success(true)
                    }
                    "launchAlarmActivity" -> {
                        val destinationName = call.argument<String>("destinationName") ?: "Destination"
                        launchAlarmActivity(destinationName)
                        result.success(true)
                    }
                    "startAlarmAudio" -> {
                        alarmAudioEngine.start()
                        result.success(true)
                    }
                    "stopAlarmAudio" -> {
                        alarmAudioEngine.stop()
                        result.success(true)
                    }
                    "firePreAlertNotification" -> {
                        val destinationName = call.argument<String>("destinationName") ?: "Destination"
                        val distanceKm = call.argument<Double>("distanceKm") ?: 0.0
                        firePreAlertNotification(destinationName, distanceKm)
                        result.success(true)
                    }
                    "isBatteryOptimizationIgnored" -> {
                        result.success(isBatteryOptimizationIgnored())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    LocationForegroundService.onLocationUpdate = { latitude, longitude, accuracy, timestampMs ->
                        val payload = mapOf(
                            "latitude" to latitude,
                            "longitude" to longitude,
                            "accuracy" to accuracy,
                            "timestampMs" to timestampMs
                        )
                        eventSink?.success(payload)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    LocationForegroundService.onLocationUpdate = null
                }
            })
    }

    private fun startForegroundService(
        destinationName: String,
        destinationLat: Double,
        destinationLng: Double,
        radiusMeters: Double,
    ) {
        val intent = Intent(this, LocationForegroundService::class.java).apply {
            putExtra("destinationName", destinationName)
            putExtra("destinationLat", destinationLat)
            putExtra("destinationLng", destinationLng)
            putExtra("radiusMeters", radiusMeters)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun scheduleNextCheck(timestampMs: Long, journeyId: Int) {
        if (timestampMs <= 0L) return

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.example.map_app.ALARM_CHECK"
            putExtra("journeyId", journeyId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            journeyId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
        }
    }

    private fun cancelScheduledChecks() {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.example.map_app.ALARM_CHECK"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent != null) {
            val alarmManager = getSystemService(AlarmManager::class.java)
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun launchAlarmActivity(destinationName: String) {
        val intent = Intent(this, AlarmActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("destinationName", destinationName)
        }
        startActivity(intent)
    }

    private fun firePreAlertNotification(destinationName: String, distanceKm: Double) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE)
        if (notificationManager !is android.app.NotificationManager) return

        val channelId = "com.example.map_app.pre_alert"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                "Trip pre-alert",
                android.app.NotificationManager.IMPORTANCE_DEFAULT
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Approaching $destinationName")
            .setContentText("About ${"%.1f".format(distanceKm)} km remaining")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(101, notification)
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        val powerManager = getSystemService(PowerManager::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}
