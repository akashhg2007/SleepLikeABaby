package com.sleeplikeababy.sleep_like_a_baby

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val TRIP_METHOD_CHANNEL = "com.sleeplikeababy/trip_service"
    private val LOCATION_EVENT_CHANNEL = "com.sleeplikeababy/location_stream"
    private val ALARM_EVENT_CHANNEL = "com.sleeplikeababy/alarm_events"

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeAndShowOverLockscreen()
    }

    private fun wakeAndShowOverLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for Trip Control & Battery Optimization
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIP_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val lat = call.argument<Double>("destLat") ?: 0.0
                    val lng = call.argument<Double>("destLng") ?: 0.0
                    val name = call.argument<String>("destName") ?: "Destination"
                    val radius = call.argument<Double>("alertRadius") ?: 1000.0

                    val serviceIntent = Intent(this, TripForegroundService::class.java).apply {
                        action = TripForegroundService.ACTION_START
                        putExtra(TripForegroundService.EXTRA_DEST_LAT, lat)
                        putExtra(TripForegroundService.EXTRA_DEST_LNG, lng)
                        putExtra(TripForegroundService.EXTRA_DEST_NAME, name)
                        putExtra(TripForegroundService.EXTRA_ALERT_RADIUS, radius)
                    }
                    ContextCompat.startForegroundService(this, serviceIntent)
                    result.success(true)
                }
                "stopTracking" -> {
                    val serviceIntent = Intent(this, TripForegroundService::class.java).apply {
                        action = TripForegroundService.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                "isBatteryOptimizationIgnored" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnored)
                }
                "requestIgnoreBattery" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "checkPermissions" -> {
                    val hasFineLocation = ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED

                    val hasBackgroundLocation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }

                    val hasNotifications = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }

                    result.success(
                        mapOf(
                            "hasLocation" to hasFineLocation,
                            "hasBackgroundLocation" to hasBackgroundLocation,
                            "hasNotifications" to hasNotifications
                        )
                    )
                }
                "requestPermissions" -> {
                    val permissionsNeeded = mutableListOf<String>()
                    if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                        permissionsNeeded.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
                        permissionsNeeded.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        permissionsNeeded.add(android.Manifest.permission.POST_NOTIFICATIONS)
                    }
                    if (permissionsNeeded.isNotEmpty()) {
                        androidx.core.app.ActivityCompat.requestPermissions(
                            this,
                            permissionsNeeded.toTypedArray(),
                            1001
                        )
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel streaming native location updates to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    TripForegroundService.locationUpdateListener = { json ->
                        mainHandler.post {
                            events?.success(json.toString())
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    TripForegroundService.locationUpdateListener = null
                }
            }
        )

        // EventChannel streaming native alarm actions (dismiss/snooze) to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    TripForegroundService.alarmEventListener = { event ->
                        mainHandler.post {
                            events?.success(event)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    TripForegroundService.alarmEventListener = null
                }
            }
        )
    }
}
