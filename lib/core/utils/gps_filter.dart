import '../constants/app_constants.dart';
import '../../features/trip/domain/location_point.dart';
import 'distance_calculator.dart';

/// GPS Filter to discard inaccurate fixes, cell tower jumps, and unrealistic GPS teleports.
class GpsFilter {
  final double maxAcceptableAccuracy;
  final double maxRealisticSpeedMetersPerSec;

  LocationPoint? _lastValidFix;

  GpsFilter({
    this.maxAcceptableAccuracy = AppConstants.maxAcceptableAccuracyMeters,
    this.maxRealisticSpeedMetersPerSec =
        100.0, // ~360 km/h (Express bullet train max)
  });

  /// Evaluates whether a raw GPS fix is valid and acceptable for trip evaluation.
  bool isValidFix(LocationPoint fix) {
    // 1. Accuracy threshold check
    if (fix.accuracy <= 0 || fix.accuracy > maxAcceptableAccuracy) {
      return false;
    }

    // 2. Coordinate range check
    if (fix.latitude < -90.0 || fix.latitude > 90.0) return false;
    if (fix.longitude < -180.0 || fix.longitude > 180.0) return false;

    // 3. Jump / Teleport check if we have a previous fix
    if (_lastValidFix != null) {
      final timeDeltaSeconds =
          fix.timestamp.difference(_lastValidFix!.timestamp).inMilliseconds /
          1000.0;

      // Duplicate timestamp or out-of-order reading
      if (timeDeltaSeconds <= 0.1) {
        return false;
      }

      final distanceMeters = DistanceCalculator.haversineDistanceMeters(
        _lastValidFix!.latitude,
        _lastValidFix!.longitude,
        fix.latitude,
        fix.longitude,
      );

      final impliedSpeed = distanceMeters / timeDeltaSeconds;
      if (impliedSpeed > maxRealisticSpeedMetersPerSec) {
        // Unrealistic jump (e.g. cell tower switch or GPS glitch)
        return false;
      }
    }

    _lastValidFix = fix;
    return true;
  }

  void reset() {
    _lastValidFix = null;
  }
}
