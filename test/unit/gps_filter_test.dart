import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_like_a_baby/core/utils/gps_filter.dart';
import 'package:sleep_like_a_baby/features/trip/domain/location_point.dart';

void main() {
  group('GpsFilter Tests', () {
    late GpsFilter filter;

    setUp(() {
      filter = GpsFilter(
        maxAcceptableAccuracy: 75.0,
        maxRealisticSpeedMetersPerSec: 100.0,
      );
    });

    test('Accepts fix with high accuracy (<= 75m)', () {
      final fix = LocationPoint(
        latitude: 40.7527,
        longitude: -73.9772,
        accuracy: 12.0,
        speed: 15.0,
        bearing: 45.0,
        timestamp: DateTime.now(),
      );
      expect(filter.isValidFix(fix), isTrue);
    });

    test('Rejects fix with poor accuracy (> 75m)', () {
      final fix = LocationPoint(
        latitude: 40.7527,
        longitude: -73.9772,
        accuracy: 120.0, // Cell tower or indoor multipath
        speed: 0.0,
        timestamp: DateTime.now(),
      );
      expect(filter.isValidFix(fix), isFalse);
    });

    test('Rejects fix with invalid or negative accuracy', () {
      final fix = LocationPoint(
        latitude: 40.7527,
        longitude: -73.9772,
        accuracy: -1.0,
        timestamp: DateTime.now(),
      );
      expect(filter.isValidFix(fix), isFalse);
    });

    test('Rejects impossible teleport jump (> 100 m/s ~ 360 km/h)', () {
      final t0 = DateTime.now();
      final fix1 = LocationPoint(
        latitude: 40.7527,
        longitude: -73.9772,
        accuracy: 10.0,
        timestamp: t0,
      );
      expect(filter.isValidFix(fix1), isTrue);

      // 1 second later, jumped to London (51.5074, -0.1278) -> ~5500 km in 1 second!
      final fix2 = LocationPoint(
        latitude: 51.5074,
        longitude: -0.1278,
        accuracy: 10.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      );
      expect(filter.isValidFix(fix2), isFalse);
    });

    test('Accepts realistic transit motion (30 m/s ~ 108 km/h)', () {
      final t0 = DateTime.now();
      final fix1 = LocationPoint(
        latitude: 40.7500,
        longitude: -73.9900,
        accuracy: 10.0,
        timestamp: t0,
      );
      expect(filter.isValidFix(fix1), isTrue);

      // 10 seconds later, moved ~300 meters
      final fix2 = LocationPoint(
        latitude: 40.7527,
        longitude: -73.9900,
        accuracy: 10.0,
        timestamp: t0.add(const Duration(seconds: 10)),
      );
      expect(filter.isValidFix(fix2), isTrue);
    });
  });
}
