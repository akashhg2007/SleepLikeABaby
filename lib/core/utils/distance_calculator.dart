import 'dart:math' as math;

/// High-precision geodetic math utilities including Haversine distance,
/// spherical bearing, and destination overshoot / missed stop detection.
class DistanceCalculator {
  DistanceCalculator._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates geodesic surface distance in meters between two coordinates using the Haversine formula.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  /// Calculates the initial forward bearing (azimuth) from point 1 to point 2 in degrees (0 to 360).
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);
    final dLon = _degreesToRadians(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  /// Evaluates whether the commuter has overshot / passed their destination.
  ///
  /// Criteria for overshoot:
  /// 1. The commuter was previously close (minDistanceReached <= alertRadius * 1.5).
  /// 2. Current distance is significantly larger than the minimum achieved distance (e.g., > minDistance + 200m).
  /// 3. The current travel bearing compared to bearing to destination shows divergence (> 110 degrees away).
  static bool isOvershootDetected({
    required double currentDistance,
    required double minDistanceReached,
    required double alertRadius,
    required double userBearing,
    required double bearingToDestination,
    double distanceSlackMeters = 200.0,
  }) {
    // Has not been reasonably close yet
    if (minDistanceReached > alertRadius * 2.0) {
      return false;
    }

    // Has distance meaningfully increased from the minimum reached?
    final hasIncreased =
        currentDistance >= (minDistanceReached + distanceSlackMeters);
    if (!hasIncreased) {
      return false;
    }

    // Is the user moving away from the destination?
    // Angular difference between movement heading and destination bearing
    final diff = (userBearing - bearingToDestination).abs() % 360.0;
    final angularDifference = diff > 180.0 ? 360.0 - diff : diff;

    // If angular difference is greater than 110 degrees, the user is heading away from destination
    return angularDifference > 110.0;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
}
