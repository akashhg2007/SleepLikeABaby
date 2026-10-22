package com.sleeplikeababy.sleep_like_a_baby

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.*
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class TripForegroundService : Service(), LocationListener {

    companion object {
        const val CHANNEL_TRACKING_ID = "trip_tracking_channel"
        const val CHANNEL_ALARM_ID = "alarm_high_importance"
        const val NOTIFICATION_TRACKING_ID = 1002
        const val NOTIFICATION_ALARM_ID = 1001

        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_DISMISS = "ACTION_DISMISS"
        const val ACTION_SNOOZE = "ACTION_SNOOZE"

        const val EXTRA_DEST_LAT = "EXTRA_DEST_LAT"
        const val EXTRA_DEST_LNG = "EXTRA_DEST_LNG"
        const val EXTRA_DEST_NAME = "EXTRA_DEST_NAME"
        const val EXTRA_ALERT_RADIUS = "EXTRA_ALERT_RADIUS"

        var locationUpdateListener: ((JSONObject) -> Unit)? = null
        var alarmEventListener: ((String) -> Unit)? = null
    }

    private var locationManager: LocationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    private var destLat: Double = 0.0
    private var destLng: Double = 0.0
    private var destName: String = "Destination"
    private var alertRadius: Double = 1000.0

    private var isAlarmTriggered: Boolean = false
    private var isSnoozed: Boolean = false
    private var snoozeEndTime: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        createNotificationChannels()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_STICKY

        when (intent.action) {
            ACTION_START -> {
                destLat = intent.getDoubleExtra(EXTRA_DEST_LAT, 0.0)
                destLng = intent.getDoubleExtra(EXTRA_DEST_LNG, 0.0)
                destName = intent.getStringExtra(EXTRA_DEST_NAME) ?: "Destination"
                alertRadius = intent.getDoubleExtra(EXTRA_ALERT_RADIUS, 1000.0)

                startTrackingForeground()
                startLocationUpdates()
            }
            ACTION_STOP -> {
                stopTracking()
            }
            ACTION_DISMISS -> {
                stopAlarmSound()
                alarmEventListener?.invoke("dismiss")
                stopTracking()
            }
            ACTION_SNOOZE -> {
                stopAlarmSound()
                isSnoozed = true
                snoozeEndTime = System.currentTimeMillis() + (3 * 60 * 1000) // 3 minutes
                alarmEventListener?.invoke("snooze")
                updateOngoingNotification("Alarm Snoozed for 3 minutes • Tracking active")
            }
        }

        return START_STICKY
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SleepLikeABaby:TripWakeLock"
            ).apply {
                acquire(12 * 60 * 60 * 1000L) // 12 hours max safety timeout
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Tracking Channel (Silent/Ongoing)
            val trackingChannel = NotificationChannel(
                CHANNEL_TRACKING_ID,
                "Journey Tracking Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live destination distance while app is locked or backgrounded"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(trackingChannel)

            // Urgent Alarm Channel
            val alarmChannel = NotificationChannel(
                CHANNEL_ALARM_ID,
                "Destination Wake Up Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent full-screen alarm when approaching destination"
                enableVibration(true)
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(alarmChannel)
        }
    }

    private fun startTrackingForeground() {
        val notification = buildOngoingNotification("Monitoring distance to $destName...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_TRACKING_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_TRACKING_ID, notification)
        }
    }

    private fun buildOngoingNotification(contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, TripForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_TRACKING_ID)
            .setContentTitle("Sleep Journey to $destName")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateOngoingNotification(contentText: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_TRACKING_ID, buildOngoingNotification(contentText))
    }

    private fun startLocationUpdates() {
        try {
            val minTimeMs = 2000L // 2 seconds for high-frequency navigation responsiveness
            val minDistanceMeters = 2.0f // 2 meters

            // 1. Immediately emit best cached location for 0-latency distance calculation
            val lastGps = try { locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER) } catch (_: Exception) { null }
            val lastNet = try { locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { null }
            val lastPassive = try { locationManager?.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER) } catch (_: Exception) { null }

            val candidates = listOfNotNull(lastGps, lastNet, lastPassive)
            val bestLast = candidates.maxByOrNull { it.time }
            if (bestLast != null) {
                onLocationChanged(bestLast)
            }

            // 2. Register GPS provider
            if (locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    minTimeMs,
                    minDistanceMeters,
                    this
                )
            }

            // 3. Register Network provider for indoor/cell tower assisted fixes
            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                locationManager?.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    minTimeMs,
                    minDistanceMeters,
                    this
                )
            }

            // 4. Register Passive provider to capture fixes triggered by Google Play Services / Google Maps
            try {
                locationManager?.requestLocationUpdates(
                    LocationManager.PASSIVE_PROVIDER,
                    minTimeMs,
                    minDistanceMeters,
                    this
                )
            } catch (_: Exception) {}
        } catch (_: SecurityException) {}
    }

    override fun onLocationChanged(location: Location) {
        // Compute distance to destination
        val results = FloatArray(1)
        Location.distanceBetween(
            location.latitude,
            location.longitude,
            destLat,
            destLng,
            results
        )
        val distanceMeters = results[0].toDouble()

        // Relay to Flutter EventChannel listener
        val json = JSONObject().apply {
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("accuracy", location.accuracy.toDouble())
            put("speed", location.speed.toDouble())
            put("bearing", location.bearing.toDouble())
            put("altitude", location.altitude)
            put("timestamp", location.time)
            put("distanceMeters", distanceMeters)
        }
        locationUpdateListener?.invoke(json)

        // Update ongoing notification
        val distText = if (distanceMeters >= 1000) {
            String.format("%.1f km", distanceMeters / 1000.0)
        } else {
            String.format("%d m", distanceMeters.toInt())
        }
        updateOngoingNotification("Distance: $distText • Wake up radius: ${alertRadius.toInt()} m")

        // Check if snooze expired
        if (isSnoozed && System.currentTimeMillis() >= snoozeEndTime) {
            isSnoozed = false
        }

        // Native Alarm Evaluation Fallback
        if (!isAlarmTriggered && !isSnoozed && distanceMeters <= alertRadius) {
            triggerNativeAlarm(distanceMeters)
        }
    }

    private fun triggerNativeAlarm(distanceMeters: Double) {
        isAlarmTriggered = true
        alarmEventListener?.invoke("alarm_triggered")

        // 1. Play native loud audio on STREAM_ALARM
        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {}

        // 2. Pulse vibrator
        try {
            val pattern = longArrayOf(0, 600, 250, 600, 250, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (_: Exception) {}

        // 3. Post Full-Screen Intent Notification to wake locked device
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            2,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, TripForegroundService::class.java).apply { action = ACTION_DISMISS }
        val dismissPendingIntent = PendingIntent.getService(this, 3, dismissIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val snoozeIntent = Intent(this, TripForegroundService::class.java).apply { action = ACTION_SNOOZE }
        val snoozePendingIntent = PendingIntent.getService(this, 4, snoozeIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val alarmNotification = NotificationCompat.Builder(this, CHANNEL_ALARM_ID)
            .setContentTitle("WAKE UP! Approaching $destName")
            .setContentText("You are within ${alertRadius.toInt()}m of your stop!")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_media_play, "I am Awake", dismissPendingIntent)
            .addAction(android.R.drawable.ic_popup_sync, "Snooze 3m", snoozePendingIntent)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ALARM_ID, alarmNotification)
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}

        try {
            vibrator?.cancel()
        } catch (_: Exception) {}

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ALARM_ID)
    }

    private fun stopTracking() {
        stopAlarmSound()
        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {}

        releaseWakeLock()
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }
}
