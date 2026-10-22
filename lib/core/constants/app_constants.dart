/// Application constants for SleepLikeABaby destination alarm.
class AppConstants {
  AppConstants._();

  static const String appName = 'SleepLikeABaby';

  // Alert distance presets in meters
  static const List<double> alertRadiusPresets = [
    200.0,
    500.0,
    1000.0,
    2000.0,
    5000.0,
  ];
  static const double defaultAlertRadius = 1000.0; // 1 km
  static const double minAlertRadius = 100.0; // 100 meters
  static const double maxAlertRadius = 20000.0; // 20 km

  // GPS Accuracy filters
  static const double maxAcceptableAccuracyMeters =
      75.0; // Discard readings worse than 75m
  static const double poorAccuracyThresholdMeters =
      40.0; // Warn if between 40m and 75m
  static const Duration gpsStalenessThreshold = Duration(seconds: 90);

  // Speed-aware alerting
  static const double highSpeedThresholdKmh = 40.0; // Transit / Train speed
  static const int minEarlyAlertSeconds =
      120; // 2 minutes early alert buffer at speed

  // Snooze
  static const Duration defaultSnoozeDuration = Duration(minutes: 3);

  // Storage Keys
  static const String keyActiveTrip = 'active_trip_state_v1';
  static const String keyRecentDestinations = 'recent_destinations_v1';
  static const String keyUserSettings = 'user_settings_v1';
}
