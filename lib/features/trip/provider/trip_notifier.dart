import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/native_bridge/native_location_bridge.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/utils/eta_calculator.dart';
import '../../../core/utils/gps_filter.dart';
import '../../alarm/service/alarm_service.dart';
import '../../destination/domain/destination.dart';
import '../../map/provider/user_location_provider.dart';
import '../data/routing_service.dart';
import '../data/trip_repository.dart';
import '../domain/location_point.dart';
import '../domain/trip_state.dart';
import 'trip_providers.dart';

/// Riverpod 3 Notifier encapsulating the entire trip lifecycle, geofence math,
/// speed-aware alerting, overshoot detection, and persistent state.
class TripNotifier extends Notifier<TripModel> {
  late TripRepository _repository;
  late AlarmService _alarmService;
  late NativeLocationBridge _nativeBridge;
  late RoutingService _routingService;
  late GpsFilter _gpsFilter;

  Timer? _watchdogTimer;
  StreamSubscription<LocationPoint>? _locationSub;
  StreamSubscription<LocationPoint>? _foregroundLocationSub;
  StreamSubscription<String>? _alarmEventSub;

  int _consecutiveInZoneFixes = 0;
  bool speedAwareAlertsEnabled = true;
  bool overshootAlertsEnabled = true;

  @override
  TripModel build() {
    _repository = ref.watch(tripRepositoryProvider);
    _alarmService = ref.watch(alarmServiceProvider);
    _nativeBridge = ref.watch(nativeLocationBridgeProvider);
    _routingService = ref.watch(routingServiceProvider);
    _gpsFilter = GpsFilter();

    ref.onDispose(() {
      _watchdogTimer?.cancel();
      _locationSub?.cancel();
      _foregroundLocationSub?.cancel();
      _alarmEventSub?.cancel();
    });

    _startGpsWatchdog();

    final active = _repository.getActiveTrip();
    if (active != null) {
      return active;
    }

    return TripModel(
      id: const Uuid().v4(),
      destination: const Destination(
        id: 'initial',
        name: 'No Destination',
        displayName: 'Choose a destination to begin',
        latitude: 0.0,
        longitude: 0.0,
      ),
      alertRadiusMeters: AppConstants.defaultAlertRadius,
      status: TripStatus.idle,
      startTime: DateTime.now(),
    );
  }

  /// Starts a new journey towards the chosen destination.
  void startTrip({
    required Destination destination,
    required double alertRadius,
    LocationPoint? initialLocation,
  }) {
    _gpsFilter.reset();
    _consecutiveInZoneFixes = 0;

    final effectiveLocation =
        initialLocation ?? ref.read(userLocationNotifierProvider);

    double initialDistance = 0.0;
    if (effectiveLocation != null) {
      initialDistance = DistanceCalculator.haversineDistanceMeters(
        effectiveLocation.latitude,
        effectiveLocation.longitude,
        destination.latitude,
        destination.longitude,
      );
    }

    state = TripModel(
      id: const Uuid().v4(),
      destination: destination,
      alertRadiusMeters: alertRadius,
      status: TripStatus.active,
      startTime: DateTime.now(),
      lastFix: effectiveLocation,
      initialDistanceMeters: initialDistance,
      distanceToDestinationMeters: initialDistance,
      minDistanceReachedMeters: initialDistance > 0
          ? initialDistance
          : double.infinity,
      currentSpeedKmh: effectiveLocation?.speedKmh ?? 0.0,
    );

    _repository.saveActiveTrip(state);

    // Fetch OpenStreetMap route geometry asynchronously
    _fetchAndApplyRoute(destination, effectiveLocation);

    // Launch native background service
    _nativeBridge.startTracking(
      destination: destination,
      alertRadius: alertRadius,
    );

    // Listen to native location fixes
    _locationSub?.cancel();
    _locationSub = _nativeBridge.locationStream.listen(processLocationUpdate);

    // Also listen to foreground high-frequency location fixes
    _foregroundLocationSub?.cancel();
    _foregroundLocationSub = ref
        .read(userLocationServiceProvider)
        .locationStream
        .listen(processLocationUpdate);

    // Listen to native lockscreen notification actions
    _alarmEventSub?.cancel();
    _alarmEventSub = _nativeBridge.alarmEventStream.listen((event) {
      if (event == 'dismiss') {
        dismissAlarm();
      } else if (event == 'snooze') {
        snoozeAlarm();
      }
    });
  }

  /// Fetches route polyline and road distance once at trip start without polling.
  Future<void> _fetchAndApplyRoute(
    Destination destination,
    LocationPoint? origin,
  ) async {
    if (origin == null) return;
    try {
      final route = await _routingService.fetchRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
      );
      if (state.status == TripStatus.active &&
          state.destination.id == destination.id) {
        state = state.copyWith(
          routeCoordinates: route.points,
          routeDistanceMeters: route.distanceMeters,
          estimatedSecondsRemaining: route.durationSeconds.toInt(),
        );
        _repository.saveActiveTrip(state);
      }
    } catch (_) {}
  }

  /// Ingests a new GPS fix and evaluates distance, ETA, and alarm conditions.
  void processLocationUpdate(LocationPoint rawFix) {
    if (state.status != TripStatus.active &&
        state.status != TripStatus.snoozed) {
      return;
    }

    // 1. Accuracy and Spike Filter
    if (!_gpsFilter.isValidFix(rawFix)) {
      return;
    }

    final dest = state.destination;
    final distance = DistanceCalculator.haversineDistanceMeters(
      rawFix.latitude,
      rawFix.longitude,
      dest.latitude,
      dest.longitude,
    );

    final minReached = math.min(state.minDistanceReachedMeters, distance);
    final bearingToDest = DistanceCalculator.calculateBearing(
      rawFix.latitude,
      rawFix.longitude,
      dest.latitude,
      dest.longitude,
    );

    final speedKmh = rawFix.speedKmh;
    final eta = EtaCalculator.calculateEta(
      distanceRemainingMeters: distance,
      speedKmh: speedKmh,
    );

    // Check Snooze expiry
    var currentStatus = state.status;
    if (currentStatus == TripStatus.snoozed && state.snoozeEndTime != null) {
      if (DateTime.now().isAfter(state.snoozeEndTime!)) {
        currentStatus = TripStatus.active;
      }
    }

    bool triggerAlarm = false;
    bool isOvershoot = false;
    bool isSpeedTriggered = false;

    // 2. Overshoot / Passed Stop Detection
    if (overshootAlertsEnabled &&
        (currentStatus == TripStatus.active ||
            currentStatus == TripStatus.snoozed)) {
      if (DistanceCalculator.isOvershootDetected(
        currentDistance: distance,
        minDistanceReached: minReached,
        alertRadius: state.alertRadiusMeters,
        userBearing: rawFix.bearing,
        bearingToDestination: bearingToDest,
      )) {
        isOvershoot = true;
        currentStatus = TripStatus.missedOvershoot;
        triggerAlarm = true;
      }
    }

    // 3. Normal Geofence Radius Trigger with Consecutive-Location Confirmation
    if (!isOvershoot && currentStatus == TripStatus.active) {
      if (distance <= state.alertRadiusMeters) {
        _consecutiveInZoneFixes++;
        // Confirms arrival: 2 consecutive fixes within zone, OR deep arrival (<= 60% radius) with high accuracy
        final bool isConfirmedArrival =
            _consecutiveInZoneFixes >= 2 ||
            (rawFix.accuracy <= 25.0 && distance <= state.alertRadiusMeters * 0.6);

        if (isConfirmedArrival) {
          currentStatus = TripStatus.alarmRinging;
          triggerAlarm = true;
        }
      } else {
        _consecutiveInZoneFixes = 0; // Reset confirmation if fix drifts outside
        if (speedAwareAlertsEnabled) {
          // 4. Speed-Aware Early Trigger
          if (EtaCalculator.shouldTriggerSpeedAwareAlert(
            distanceRemainingMeters: distance,
            speedKmh: speedKmh,
          )) {
            currentStatus = TripStatus.alarmRinging;
            isSpeedTriggered = true;
            triggerAlarm = true;
          }
        }
      }
    }

    // Update state
    state = state.copyWith(
      lastFix: rawFix,
      distanceToDestinationMeters: distance,
      minDistanceReachedMeters: minReached,
      currentSpeedKmh: speedKmh,
      estimatedSecondsRemaining: eta?.inSeconds,
      status: currentStatus,
      isOvershootDetected: isOvershoot,
      isSpeedAlertTriggered: isSpeedTriggered,
      isGpsDegraded: false, // fresh valid fix
    );

    _repository.saveActiveTrip(state);

    // Fire audio and notifications if triggered
    if (triggerAlarm) {
      if (isOvershoot) {
        _alarmService.triggerAlarm(
          title: 'Missed Destination Alert!',
          message: 'You have passed ${dest.name}! Wake up immediately.',
          isOvershoot: true,
        );
      } else {
        _alarmService.triggerAlarm(
          title: 'Approaching ${dest.name}!',
          message:
              'Wake up! You are within ${_formatDistance(state.alertRadiusMeters)} of your stop.',
        );
      }
    }
  }

  /// Snoozes alarm for specified duration (default 3 mins).
  void snoozeAlarm({Duration duration = AppConstants.defaultSnoozeDuration}) {
    _alarmService.stopAlarm();
    final snoozeEnd = DateTime.now().add(duration);
    state = state.copyWith(
      status: TripStatus.snoozed,
      snoozeEndTime: snoozeEnd,
    );
    _repository.saveActiveTrip(state);
  }

  /// Dismisses alarm when commuter wakes up.
  void dismissAlarm() {
    _alarmService.stopAlarm();
    _nativeBridge.stopTracking();
    _locationSub?.cancel();
    _foregroundLocationSub?.cancel();
    _alarmEventSub?.cancel();

    state = state.copyWith(status: TripStatus.arrived);
    _repository.clearActiveTrip();
  }

  /// Pauses tracking.
  void pauseTrip() {
    if (state.status == TripStatus.active) {
      state = state.copyWith(status: TripStatus.paused);
      _repository.saveActiveTrip(state);
    }
  }

  /// Resumes tracking.
  void resumeTrip() {
    if (state.status == TripStatus.paused) {
      state = state.copyWith(status: TripStatus.active);
      _repository.saveActiveTrip(state);
    }
  }

  /// Cancels active journey.
  void cancelTrip() {
    _alarmService.stopAlarm();
    _nativeBridge.stopTracking();
    _locationSub?.cancel();
    _foregroundLocationSub?.cancel();
    _alarmEventSub?.cancel();

    state = state.copyWith(status: TripStatus.cancelled);
    _repository.clearActiveTrip();
  }

  /// Watchdog checking if GPS signals have stalled for > 90 seconds.
  void _startGpsWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.status == TripStatus.active && state.lastFix != null) {
        final elapsed = DateTime.now().difference(state.lastFix!.timestamp);
        if (elapsed > AppConstants.gpsStalenessThreshold &&
            !state.isGpsDegraded) {
          state = state.copyWith(isGpsDegraded: true);
        }
      }
    });
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }
}
