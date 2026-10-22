import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_like_a_baby/features/alarm/service/alarm_service.dart';
import 'package:sleep_like_a_baby/features/destination/domain/destination.dart';
import 'package:sleep_like_a_baby/features/trip/data/trip_repository.dart';
import 'package:sleep_like_a_baby/features/trip/domain/location_point.dart';
import 'package:sleep_like_a_baby/features/trip/domain/trip_state.dart';
import 'package:sleep_like_a_baby/core/native_bridge/native_location_bridge.dart';
import 'package:sleep_like_a_baby/features/trip/provider/trip_notifier.dart';
import 'package:sleep_like_a_baby/features/trip/provider/trip_providers.dart';

class FakeAlarmService implements AlarmService {
  @override
  bool isRinging = false;
  int triggerCount = 0;
  int stopCount = 0;
  bool lastWasOvershoot = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> triggerAlarm({
    required String title,
    required String message,
    bool isOvershoot = false,
  }) async {
    triggerCount++;
    lastWasOvershoot = isOvershoot;
    isRinging = true;
  }

  @override
  Future<void> stopAlarm() async {
    stopCount++;
    isRinging = false;
  }

  @override
  void dispose() {}
}

class FakeNativeLocationBridge implements NativeLocationBridge {
  @override
  Stream<LocationPoint> get locationStream => const Stream.empty();

  @override
  Stream<String> get alarmEventStream => const Stream.empty();

  @override
  Future<bool> startTracking({
    required Destination destination,
    required double alertRadius,
  }) async => true;

  @override
  Future<bool> stopTracking() async => true;

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => true;

  @override
  Future<Map<String, bool>> checkPermissions() async => {
    'hasLocation': true,
    'hasBackgroundLocation': true,
    'hasNotifications': true,
  };

  @override
  Future<bool> requestPermissions() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripNotifier State Machine Tests', () {
    late TripRepository repository;
    late FakeAlarmService fakeAlarm;
    late ProviderContainer container;

    const destination = Destination(
      id: 'dest_grand_central',
      name: 'Grand Central Terminal',
      displayName: '89 E 42nd St, New York',
      latitude: 40.7527,
      longitude: -73.9772,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = TripRepository(prefs);
      fakeAlarm = FakeAlarmService();
      container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          alarmServiceProvider.overrideWithValue(fakeAlarm),
          nativeLocationBridgeProvider.overrideWithValue(
            FakeNativeLocationBridge(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    TripNotifier getNotifier() => container.read(tripNotifierProvider.notifier);
    TripModel getState() => container.read(tripNotifierProvider);

    test(
      'Starting trip sets status to active with initial destination and radius',
      () {
        getNotifier().startTrip(destination: destination, alertRadius: 1000.0);

        final state = getState();
        expect(state.status, equals(TripStatus.active));
        expect(state.destination.name, equals('Grand Central Terminal'));
        expect(state.alertRadiusMeters, equals(1000.0));
        expect(fakeAlarm.triggerCount, equals(0));
      },
    );

    test('Distance update outside alert radius keeps trip active', () {
      getNotifier().startTrip(destination: destination, alertRadius: 500.0);

      // Point ~10 km away (Brooklyn)
      final farFix = LocationPoint(
        latitude: 40.6782,
        longitude: -73.9442,
        accuracy: 10.0,
        speed: 10.0,
        bearing: 0.0,
        timestamp: DateTime.now(),
      );

      getNotifier().processLocationUpdate(farFix);

      final state = getState();
      expect(state.status, equals(TripStatus.active));
      expect(state.distanceToDestinationMeters, greaterThan(5000.0));
      expect(fakeAlarm.triggerCount, equals(0));
    });

    test('Distance update crossing inside alert radius triggers alarm', () {
      getNotifier().startTrip(destination: destination, alertRadius: 1000.0);

      // Point ~300 meters away from Grand Central
      final closeFix = LocationPoint(
        latitude: 40.7510,
        longitude: -73.9780,
        accuracy: 10.0,
        speed: 5.0,
        bearing: 45.0,
        timestamp: DateTime.now(),
      );

      getNotifier().processLocationUpdate(closeFix);

      final state = getState();
      expect(state.status, equals(TripStatus.alarmRinging));
      expect(fakeAlarm.triggerCount, equals(1));
      expect(fakeAlarm.lastWasOvershoot, isFalse);
    });

    test(
      'Speed-aware dynamic alert triggers early when traveling at express speed',
      () {
        getNotifier().startTrip(
          destination: destination,
          alertRadius: 500.0, // Static radius 500m
        );

        // User is 1.5 km away (outside 500m radius), but traveling at 90 km/h (25 m/s)
        // ETA is 1500m / 25m/s = 60 seconds (<= 120s early warning threshold!)
        final highSpeedFix = LocationPoint(
          latitude: 40.7400, // ~1.5km south
          longitude: -73.9772,
          accuracy: 10.0,
          speed: 25.0, // 90 km/h
          bearing: 0.0, // Heading due North toward destination
          timestamp: DateTime.now(),
        );

        getNotifier().processLocationUpdate(highSpeedFix);

        final state = getState();
        expect(state.status, equals(TripStatus.alarmRinging));
        expect(state.isSpeedAlertTriggered, isTrue);
        expect(fakeAlarm.triggerCount, equals(1));
      },
    );

    test('Overshoot detection triggers urgent missed-stop alarm', () {
      getNotifier().startTrip(destination: destination, alertRadius: 500.0);

      final t0 = DateTime.now();

      // Step 1: Commuter arrives very close (100m away)
      final arrivedClose = LocationPoint(
        latitude: 40.7525,
        longitude: -73.9770,
        accuracy: 10.0,
        speed: 10.0,
        bearing: 0.0,
        timestamp: t0,
      );
      getNotifier().processLocationUpdate(arrivedClose);
      expect(getState().status, equals(TripStatus.alarmRinging));

      // User taps snooze
      getNotifier().snoozeAlarm();
      expect(getState().status, equals(TripStatus.snoozed));

      // Step 2: Train continues past station! Now 500m away heading North (bearing away)
      final passedStop = LocationPoint(
        latitude: 40.7580,
        longitude: -73.9770,
        accuracy: 10.0,
        speed: 15.0,
        bearing: 0.0, // Still heading North away from Grand Central
        timestamp: t0.add(const Duration(seconds: 40)),
      );

      getNotifier().processLocationUpdate(passedStop);

      final state = getState();
      expect(state.status, equals(TripStatus.missedOvershoot));
      expect(state.isOvershootDetected, isTrue);
      expect(fakeAlarm.lastWasOvershoot, isTrue);
    });

    test('Snooze and Dismiss lifecycle', () {
      getNotifier().startTrip(destination: destination, alertRadius: 1000.0);

      getNotifier().snoozeAlarm(duration: const Duration(minutes: 3));
      expect(getState().status, equals(TripStatus.snoozed));
      expect(fakeAlarm.stopCount, equals(1));

      getNotifier().dismissAlarm();
      expect(getState().status, equals(TripStatus.arrived));
      expect(fakeAlarm.stopCount, equals(2));
    });

    test('Perimeter fix requires consecutive location confirmation before ringing alarm', () {
      getNotifier().startTrip(destination: destination, alertRadius: 1000.0);

      // Point near perimeter (~810m away from Grand Central) with accuracy 35m (> 25m)
      final perimeterFix1 = LocationPoint(
        latitude: 40.7600,
        longitude: -73.9772,
        accuracy: 35.0,
        speed: 2.0,
        bearing: 180.0,
        timestamp: DateTime.now(),
      );

      // First fix inside perimeter zone does not trigger immediately (protecting against single multipath jump)
      getNotifier().processLocationUpdate(perimeterFix1);
      expect(getState().status, equals(TripStatus.active));
      expect(fakeAlarm.triggerCount, equals(0));

      // Second consecutive fix confirms genuine arrival and triggers alarm!
      final perimeterFix2 = LocationPoint(
        latitude: 40.7595,
        longitude: -73.9772,
        accuracy: 30.0,
        speed: 2.0,
        bearing: 180.0,
        timestamp: DateTime.now().add(const Duration(seconds: 3)),
      );

      getNotifier().processLocationUpdate(perimeterFix2);
      expect(getState().status, equals(TripStatus.alarmRinging));
      expect(fakeAlarm.triggerCount, equals(1));
    });
  });
}
