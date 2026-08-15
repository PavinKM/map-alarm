package com.example.map_app.map_app

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class AlarmActivity : Activity() {
    private var destinationName: String = "Destination"
    private var dragState = 0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        destinationName = intent.getStringExtra("destinationName") ?: "Destination"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "STOP"
            textSize = 42f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = "You are near $destinationName"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 32)
        }

        val hint = TextView(this).apply {
            text = "Slide to stop alarm"
            textSize = 18f
            setTextColor(Color.parseColor("#D0D0D0"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }

        val slideBar = View(this).apply {
            setBackgroundColor(Color.argb(255, 80, 80, 80))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                12,
            ).apply {
                topMargin = 20
                bottomMargin = 20
            }
        }

        val actionButton = Button(this).apply {
            text = "Stop Alarm"
            setBackgroundColor(Color.RED)
            setTextColor(Color.WHITE)
            setOnClickListener {
                stopAlarmAndFinish()
            }
        }

        layout.addView(title)
        layout.addView(subtitle)
        layout.addView(hint)
        layout.addView(slideBar)
        layout.addView(actionButton)
        setContentView(layout)

        window.decorView.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragState = event.x
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (event.x > dragState + 240f) {
                        stopAlarmAndFinish()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun stopAlarmAndFinish() {
        val intent = Intent().apply {
            action = "com.example.map_app.STOP_ALARM"
        }
        sendBroadcast(intent)
        finish()
    }
}
