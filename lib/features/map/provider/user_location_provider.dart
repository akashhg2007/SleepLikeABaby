import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../trip/domain/location_point.dart';
import '../data/user_location_service.dart';

/// Singleton provider for UserLocationService
final userLocationServiceProvider = Provider<UserLocationService>((ref) {
  final service = UserLocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod StateNotifier tracking real-time user location, permissions, and accuracy
class RealtimeLocationNotifier extends Notifier<LocationPoint?> {
  late final UserLocationService _service;

  @override
  LocationPoint? build() {
    _service = ref.watch(userLocationServiceProvider);

    // Automatically check permission & retrieve location on build
    _init();

    ref.onDispose(() {
      _service.stopRealtimeTracking();
    });

    return _service.lastLocation;
  }

  Future<void> _init() async {
    final fix = await _service.getCurrentLocation(requestIfNeeded: true);
    if (fix != null) {
      state = fix;
    }

    _service.startRealtimeTracking(
      onUpdate: (point) {
        state = point;
      },
    );
  }

  /// Forces an immediate GPS refresh and centers location
  Future<LocationPoint?> refreshLocation() async {
    final fix = await _service.getCurrentLocation(requestIfNeeded: true);
    if (fix != null) {
      state = fix;
    }
    return fix;
  }
}

/// Provider exposing real-time user location point
final userLocationNotifierProvider =
    NotifierProvider<RealtimeLocationNotifier, LocationPoint?>(
      RealtimeLocationNotifier.new,
    );

/// Helper provider returning current LatLng or null
final userLatLngProvider = Provider<LatLng?>((ref) {
  final loc = ref.watch(userLocationNotifierProvider);
  if (loc == null) return null;
  return LatLng(loc.latitude, loc.longitude);
});
