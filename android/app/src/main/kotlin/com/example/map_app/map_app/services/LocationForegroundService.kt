package com.example.map_app.map_app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import com.example.map_app.map_app.MainActivity

class LocationForegroundService : Service(), LocationListener {
    private var locationManager: LocationManager? = null
    private var isTracking = false

    private var destinationName: String = ""
    private var destinationLat: Double = 0.0
    private var destinationLng: Double = 0.0
    private var radiusMeters: Double = 0.0

    companion object {
        const val CHANNEL_ID = "com.example.map_app.monitoring"
        const val NOTIFICATION_ID = 42

        // Static callback to stream location updates directly to MainActivity
        var onLocationUpdate: ((Double, Double, Double, Long) -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            destinationName = it.getStringExtra("destinationName") ?: ""
            destinationLat = it.getDoubleExtra("destinationLat", 0.0)
            destinationLng = it.getDoubleExtra("destinationLng", 0.0)
            radiusMeters = it.getDoubleExtra("radiusMeters", 0.0)
        }

        // Start Foreground Service with correct system type tags for Android 14+
        val notification = buildNotification("Starting location monitoring...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startTracking()
        return START_NOT_STICKY
    }

    private fun startTracking() {
        if (isTracking) return
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        
        try {
            // Register updates from both GPS and Network providers for maximum reliability
            if (locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    10000L, // 10 seconds
                    5f,     // 5 meters
                    this
                )
            }
            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    10000L,
                    5f,
                    this
                )
            }
            isTracking = true
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun stopTracking() {
        if (!isTracking) return
        locationManager?.removeUpdates(this)
        isTracking = false
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- LocationListener Overrides ---

    override fun onLocationChanged(location: Location) {
        val destLoc = Location("").apply {
            latitude = destinationLat
            longitude = destinationLng
        }

        val distanceMeters = location.distanceTo(destLoc)
        val distanceKm = distanceMeters / 1000.0

        // Update Foreground Notification content with real-time distance
        val contentText = "Monitoring trip to $destinationName — ${"%.2f".format(distanceKm)} km remaining"
        updateNotification(contentText)

        // Dispatch back to Flutter layer
        onLocationUpdate?.invoke(
            location.latitude,
            location.longitude,
            location.accuracy.toDouble(),
            location.time
        )
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}

    // --- Notification Helpers ---

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Trip Monitoring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress coordinates of active stop alarms"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(contentText: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Travel Stop Monitoring")
                .setContentText(contentText)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Travel Stop Monitoring")
                .setContentText(contentText)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = buildNotification(contentText)
        manager.notify(NOTIFICATION_ID, notification)
    }
}
