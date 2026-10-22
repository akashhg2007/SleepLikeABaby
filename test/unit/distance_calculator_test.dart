import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_like_a_baby/core/utils/distance_calculator.dart';

void main() {
  group('DistanceCalculator - Haversine Distance', () {
    test('Identical points return 0 distance', () {
      final distance = DistanceCalculator.haversineDistanceMeters(
        40.7527,
        -73.9772,
        40.7527,
        -73.9772,
      );
      expect(distance, closeTo(0.0, 0.001));
    });

    test(
      'Calculates accurate distance between Grand Central and Penn Station NYC (~1390m)',
      () {
        // Grand Central: 40.7527, -73.9772
        // Penn Station: 40.7505, -73.9934
        final distance = DistanceCalculator.haversineDistanceMeters(
          40.7527,
          -73.9772,
          40.7505,
          -73.9934,
        );
        expect(distance, closeTo(1390.0, 30.0));
      },
    );

    test(
      'Calculates antipodal / continental distance (London to Paris ~344km)',
      () {
        // London: 51.5074, -0.1278
        // Paris: 48.8566, 2.3522
        final distance = DistanceCalculator.haversineDistanceMeters(
          51.5074,
          -0.1278,
          48.8566,
          2.3522,
        );
        expect(distance / 1000.0, closeTo(344.0, 5.0));
      },
    );
  });

  group('DistanceCalculator - Bearing Calculation', () {
    test('Calculates due North bearing (0 degrees)', () {
      final bearing = DistanceCalculator.calculateBearing(0.0, 0.0, 10.0, 0.0);
      expect(bearing, closeTo(0.0, 0.1));
    });

    test('Calculates due East bearing (90 degrees)', () {
      final bearing = DistanceCalculator.calculateBearing(0.0, 0.0, 0.0, 10.0);
      expect(bearing, closeTo(90.0, 0.1));
    });

    test('Calculates due South bearing (180 degrees)', () {
      final bearing = DistanceCalculator.calculateBearing(10.0, 0.0, 0.0, 0.0);
      expect(bearing, closeTo(180.0, 0.1));
    });
  });

  group('DistanceCalculator - Overshoot Detection', () {
    test('Does not detect overshoot if never close to destination', () {
      final isOvershoot = DistanceCalculator.isOvershootDetected(
        currentDistance: 5000.0,
        minDistanceReached: 4800.0,
        alertRadius: 1000.0,
        userBearing: 180.0,
        bearingToDestination: 0.0,
      );
      expect(isOvershoot, isFalse);
    });

    test('Does not detect overshoot if moving closer towards destination', () {
      final isOvershoot = DistanceCalculator.isOvershootDetected(
        currentDistance: 600.0,
        minDistanceReached: 600.0,
        alertRadius: 1000.0,
        userBearing: 90.0,
        bearingToDestination: 90.0, // moving directly toward
      );
      expect(isOvershoot, isFalse);
    });

    test(
      'Detects overshoot when distance increases and heading away from stop',
      () {
        // Reached 100m, now 450m away and moving opposite heading (bearing difference 180 deg)
        final isOvershoot = DistanceCalculator.isOvershootDetected(
          currentDistance: 450.0,
          minDistanceReached: 100.0,
          alertRadius: 500.0,
          userBearing: 270.0,
          bearingToDestination: 90.0,
        );
        expect(isOvershoot, isTrue);
      },
    );
  });
}
