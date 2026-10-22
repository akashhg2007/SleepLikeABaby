import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_like_a_baby/features/destination/domain/destination.dart';
import 'package:sleep_like_a_baby/features/trip/data/trip_repository.dart';
import 'package:sleep_like_a_baby/features/trip/domain/location_point.dart';
import 'package:sleep_like_a_baby/features/trip/domain/trip_state.dart';

void main() {
  group('Lifecycle Recovery & Persistence Tests', () {
    late SharedPreferences prefs;
    late TripRepository repository;

    const destination = Destination(
      id: 'dest_tokyo_shinjuku',
      name: 'Shinjuku Station',
      displayName: 'Shinjuku, Tokyo, Japan',
      latitude: 35.6896,
      longitude: 139.7006,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = TripRepository(prefs);
    });

    test(
      'Active trip persists to storage and restores accurately across app kills',
      () async {
        final trip = TripModel(
          id: 'trip-12345',
          destination: destination,
          alertRadiusMeters: 1500.0,
          status: TripStatus.active,
          startTime: DateTime.now().subtract(const Duration(minutes: 25)),
          distanceToDestinationMeters: 3400.0,
          minDistanceReachedMeters: 3400.0,
          currentSpeedKmh: 72.0,
          lastFix: LocationPoint(
            latitude: 35.6800,
            longitude: 139.7000,
            accuracy: 8.0,
            speed: 20.0,
            timestamp: DateTime.now(),
          ),
        );

        await repository.saveActiveTrip(trip);

        // Simulate app kill and fresh repository creation
        final freshRepository = TripRepository(prefs);
        final restored = freshRepository.getActiveTrip();

        expect(restored, isNotNull);
        expect(restored!.id, equals('trip-12345'));
        expect(restored.destination.name, equals('Shinjuku Station'));
        expect(restored.alertRadiusMeters, equals(1500.0));
        expect(restored.status, equals(TripStatus.active));
        expect(restored.distanceToDestinationMeters, equals(3400.0));
        expect(restored.currentSpeedKmh, equals(72.0));
      },
    );

    test('Arrived or cancelled trip is not restored as active', () async {
      final arrivedTrip = TripModel(
        id: 'trip-arrived',
        destination: destination,
        alertRadiusMeters: 1000.0,
        status: TripStatus.arrived,
        startTime: DateTime.now(),
      );

      await repository.saveActiveTrip(arrivedTrip);
      expect(repository.getActiveTrip(), isNull);

      final cancelledTrip = TripModel(
        id: 'trip-cancelled',
        destination: destination,
        alertRadiusMeters: 1000.0,
        status: TripStatus.cancelled,
        startTime: DateTime.now(),
      );

      await repository.saveActiveTrip(cancelledTrip);
      expect(repository.getActiveTrip(), isNull);
    });

    test(
      'Corrupted or invalid JSON data in storage recovers gracefully without crash',
      () async {
        await prefs.setString('active_trip_state_v1', '{invalid_json');
        expect(repository.getActiveTrip(), isNull);
      },
    );

    test('clearActiveTrip completely deletes stored state', () async {
      final trip = TripModel(
        id: 'trip-to-delete',
        destination: destination,
        alertRadiusMeters: 1000.0,
        status: TripStatus.active,
        startTime: DateTime.now(),
      );

      await repository.saveActiveTrip(trip);
      expect(repository.getActiveTrip(), isNotNull);

      await repository.clearActiveTrip();
      expect(repository.getActiveTrip(), isNull);
    });
  });
}
