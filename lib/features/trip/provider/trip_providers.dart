import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/native_bridge/native_location_bridge.dart';
import '../../alarm/service/alarm_service.dart';
import '../data/routing_service.dart';
import '../data/trip_repository.dart';
import '../domain/trip_state.dart';
import 'trip_notifier.dart';

/// Provider for RoutingService (OSRM / OpenRouteService).
final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService();
});

/// Provider for persistent TripRepository.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  throw UnimplementedError('Initialize tripRepositoryProvider in main.dart');
});

/// Provider for AlarmService.
final alarmServiceProvider = Provider<AlarmService>((ref) {
  final service = AlarmService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for NativeLocationBridge.
final nativeLocationBridgeProvider = Provider<NativeLocationBridge>((ref) {
  return NativeLocationBridge();
});

/// Riverpod 3 NotifierProvider managing active trip state machine.
final tripNotifierProvider = NotifierProvider<TripNotifier, TripModel>(
  TripNotifier.new,
);
