import '../constants/app_constants.dart';

/// Calculates speed-aware estimated time of arrival (ETA) and dynamic alert triggers.
class EtaCalculator {
  EtaCalculator._();

  /// Calculates ETA duration given remaining distance (meters) and current speed (km/h).
  /// Returns null if speed is too low to compute meaningful arrival time.
  static Duration? calculateEta({
    required double distanceRemainingMeters,
    required double speedKmh,
  }) {
    // Under 5 km/h, transit user is walking or stationary; ETA estimation is unreliable
    if (speedKmh < 5.0) {
      return null;
    }

    final speedMps = speedKmh * (1000.0 / 3600.0);
    final seconds = distanceRemainingMeters / speedMps;

    if (seconds <= 0 || seconds.isInfinite || seconds.isNaN) {
      return null;
    }

    return Duration(seconds: seconds.round());
  }

  /// Determines if speed-aware advance alerting should fire.
  ///
  /// For example, if a train is travelling at 120 km/h (~33 m/s), a 1000m radius
  /// will be traversed in only 30 seconds, leaving insufficient time for a sleeping
  /// passenger to wake up and gather luggage. If early alert buffer is enabled,
  /// this triggers when ETA is <= minEarlyAlertSeconds (e.g. 120 seconds).
  static bool shouldTriggerSpeedAwareAlert({
    required double distanceRemainingMeters,
    required double speedKmh,
    int alertBufferSeconds = AppConstants.minEarlyAlertSeconds,
  }) {
    // Only applies at high speeds (e.g. >= 40 km/h)
    if (speedKmh < AppConstants.highSpeedThresholdKmh) {
      return false;
    }

    final eta = calculateEta(
      distanceRemainingMeters: distanceRemainingMeters,
      speedKmh: speedKmh,
    );

    if (eta == null) return false;
    return eta.inSeconds <= alertBufferSeconds;
  }
}
