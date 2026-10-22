# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native foreground service and boot receiver
-keep class com.sleeplikeababy.sleep_like_a_baby.TripForegroundService { *; }
-keep class com.sleeplikeababy.sleep_like_a_baby.BootReceiver { *; }
-keep class com.sleeplikeababy.sleep_like_a_baby.MainActivity { *; }

# Notification and audio plugins
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
