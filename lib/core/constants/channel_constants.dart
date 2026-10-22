/// Native Platform Channel Names and Method IDs for Android & iOS background tracking.
class ChannelConstants {
  ChannelConstants._();

  static const String tripMethodChannel = 'com.sleeplikeababy/trip_service';
  static const String locationEventChannel =
      'com.sleeplikeababy/location_stream';
  static const String alarmEventChannel = 'com.sleeplikeababy/alarm_events';

  // Method Names
  static const String methodStartTracking = 'startTracking';
  static const String methodStopTracking = 'stopTracking';
  static const String methodUpdateDestination = 'updateDestination';
  static const String methodRequestIgnoreBattery = 'requestIgnoreBattery';
  static const String methodIsBatteryOptimizationIgnored =
      'isBatteryOptimizationIgnored';
  static const String methodCheckPermissions = 'checkPermissions';
  static const String methodRequestPermissions = 'requestPermissions';
  static const String methodPlayAlarm = 'playAlarm';
  static const String methodStopAlarm = 'stopAlarm';

  // Event Types
  static const String eventLocationUpdate = 'location_update';
  static const String eventGpsStatusChange = 'gps_status_change';
  static const String eventAlarmTriggered = 'alarm_triggered';
  static const String eventNotificationDismiss = 'notification_dismiss';
  static const String eventNotificationSnooze = 'notification_snooze';
}
