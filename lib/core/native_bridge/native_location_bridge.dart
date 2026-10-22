import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../constants/channel_constants.dart';
import '../../features/destination/domain/destination.dart';
import '../../features/trip/domain/location_point.dart';

/// Native platform bridge connecting Flutter with Android Kotlin Foreground Service
/// and iOS CoreLocation background managers.
class NativeLocationBridge {
  static const MethodChannel _methodChannel = MethodChannel(
    ChannelConstants.tripMethodChannel,
  );
  static const EventChannel _locationChannel = EventChannel(
    ChannelConstants.locationEventChannel,
  );
  static const EventChannel _alarmChannel = EventChannel(
    ChannelConstants.alarmEventChannel,
  );

  Stream<LocationPoint>? _locationStream;
  Stream<String>? _alarmEventStream;

  /// Starts native background foreground tracking service on Android or background CoreLocation on iOS.
  Future<bool> startTracking({
    required Destination destination,
    required double alertRadius,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startTracking', {
        'destLat': destination.latitude,
        'destLng': destination.longitude,
        'destName': destination.name,
        'alertRadius': alertRadius,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops native background service.
  Future<bool> stopTracking() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if battery optimization is disabled for this app on Android (Doze exemption).
  Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isBatteryOptimizationIgnored',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests battery optimization exemption.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestIgnoreBattery',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks native platform permission status.
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'checkPermissions',
      );
      if (result != null) {
        return {
          'hasLocation': result['hasLocation'] as bool? ?? false,
          'hasBackgroundLocation':
              result['hasBackgroundLocation'] as bool? ?? false,
          'hasNotifications': result['hasNotifications'] as bool? ?? false,
        };
      }
    } catch (_) {}
    return {
      'hasLocation': false,
      'hasBackgroundLocation': false,
      'hasNotifications': false,
    };
  }

  /// Proactively triggers native runtime permission prompt.
  Future<bool> requestPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }


  /// Stream of location updates emitted from the native foreground service.
  Stream<LocationPoint> get locationStream {
    _locationStream ??= _locationChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      final map = json.decode(event.toString()) as Map<String, dynamic>;
      final timestampMs =
          map['timestamp'] as num? ?? DateTime.now().millisecondsSinceEpoch;
      return LocationPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
        bearing: (map['bearing'] as num?)?.toDouble() ?? 0.0,
        altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt()),
      );
    });
    return _locationStream!;
  }

  /// Stream of alarm actions received from notification buttons or native ringer.
  Stream<String> get alarmEventStream {
    _alarmEventStream ??= _alarmChannel.receiveBroadcastStream().map(
      (dynamic event) => event.toString(),
    );
    return _alarmEventStream!;
  }
}
