package com.sleeplikeababy.sleep_like_a_baby

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val activeTripJson = prefs.getString("flutter.active_trip_state_v1", null)

            // If a trip was active when device rebooted, notify commuter immediately
            if (!activeTripJson.isNullOrEmpty() && !activeTripJson.contains("\"status\":\"arrived\"") && !activeTripJson.contains("\"status\":\"cancelled\"")) {
                postRecoveryNotification(context)
            }
        }
    }

    private fun postRecoveryNotification(context: Context) {
        val channelId = "trip_recovery_channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Trip Recovery Alert",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts you when phone reboots during an active destination journey"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle("Phone Rebooted During Journey!")
            .setContentText("Tap to reopen SleepLikeABaby and resume destination alarms.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(1003, notification)
    }
}
