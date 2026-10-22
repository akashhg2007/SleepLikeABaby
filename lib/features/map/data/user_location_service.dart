import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../trip/domain/location_point.dart';

/// Comprehensive real-time location service managing device GPS permissions,
/// fast initial fix, and high-frequency stream updates for Google Maps navigation.
class UserLocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LocationPoint> _locationStreamController =
      StreamController<LocationPoint>.broadcast();

  LocationPoint? _lastLocation;
  bool _isLocating = false;

  Stream<LocationPoint> get locationStream => _locationStreamController.stream;
  LocationPoint? get lastLocation => _lastLocation;
  bool get isLocating => _isLocating;

  /// Checks if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Verifies current permission status.
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Proactively requests location permission if not already granted.
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Fetches the user's immediate location, first checking last known for 0-latency,
  /// then acquiring a high-accuracy GPS fix.
  Future<LocationPoint?> getCurrentLocation({bool requestIfNeeded = true}) async {
    try {
      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return _lastLocation;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied && requestIfNeeded) {
        permission = await requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _lastLocation;
      }

      _isLocating = true;

      // 1. Instant cache retrieval (0ms latency for initial map render)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final fix = _positionToLocationPoint(lastKnown);
        _lastLocation = fix;
        _locationStreamController.add(fix);
      }

      // 2. High-accuracy active GPS query
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final point = _positionToLocationPoint(current);
      _lastLocation = point;
      _locationStreamController.add(point);
      _isLocating = false;
      return point;
    } catch (_) {
      _isLocating = false;
      return _lastLocation;
    }
  }

  /// Starts continuous real-time position updates matching Google Maps navigation mode.
  void startRealtimeTracking({
    void Function(LocationPoint point)? onUpdate,
  }) {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // 2-meter sensitivity for smooth real-time car/train/walk puck
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        final point = _positionToLocationPoint(position);
        _lastLocation = point;
        _locationStreamController.add(point);
        if (onUpdate != null) {
          onUpdate(point);
        }
      },
      onError: (err) {
        // Fallback silently or recover gracefully on degraded GPS
      },
    );
  }

  /// Stops continuous real-time tracking stream.
  void stopRealtimeTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  LocationPoint _positionToLocationPoint(Position pos) {
    return LocationPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      bearing: pos.heading,
      altitude: pos.altitude,
      timestamp: pos.timestamp,
    );
  }

  LatLng? get lastLatLng => _lastLocation != null
      ? LatLng(_lastLocation!.latitude, _lastLocation!.longitude)
      : null;

  void dispose() {
    stopRealtimeTracking();
    _locationStreamController.close();
  }
}
