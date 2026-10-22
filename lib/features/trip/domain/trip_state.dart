import '../../destination/domain/destination.dart';
import 'location_point.dart';

/// Finite state enum representing trip progression.
enum TripStatus {
  idle,
  active,
  paused,
  alarmRinging,
  snoozed,
  arrived,
  missedOvershoot,
  cancelled,
}

/// Immutable Trip state model holding live telemetry, distance tracking, and alert status.
class TripModel {
  final String id;
  final Destination destination;
  final double alertRadiusMeters;
  final TripStatus status;
  final DateTime startTime;
  final LocationPoint? lastFix;
  final double initialDistanceMeters;
  final double distanceToDestinationMeters;
  final double minDistanceReachedMeters;
  final double currentSpeedKmh;
  final int? estimatedSecondsRemaining;
  final bool isSpeedAlertTriggered;
  final bool isOvershootDetected;
  final bool isGpsDegraded;
  final DateTime? snoozeEndTime;
  final List<LocationPoint>? routeCoordinates;
  final double? routeDistanceMeters;

  const TripModel({
    required this.id,
    required this.destination,
    required this.alertRadiusMeters,
    required this.status,
    required this.startTime,
    this.lastFix,
    this.initialDistanceMeters = 0.0,
    this.distanceToDestinationMeters = 0.0,
    this.minDistanceReachedMeters = double.infinity,
    this.currentSpeedKmh = 0.0,
    this.estimatedSecondsRemaining,
    this.isSpeedAlertTriggered = false,
    this.isOvershootDetected = false,
    this.isGpsDegraded = false,
    this.snoozeEndTime,
    this.routeCoordinates,
    this.routeDistanceMeters,
  });

  /// Fraction of trip completed (0.0 to 1.0).
  double get progressFraction {
    if (initialDistanceMeters <= 0) return 0.0;
    final covered = initialDistanceMeters - distanceToDestinationMeters;
    return (covered / initialDistanceMeters).clamp(0.0, 1.0);
  }

  TripModel copyWith({
    String? id,
    Destination? destination,
    double? alertRadiusMeters,
    TripStatus? status,
    DateTime? startTime,
    LocationPoint? lastFix,
    double? initialDistanceMeters,
    double? distanceToDestinationMeters,
    double? minDistanceReachedMeters,
    double? currentSpeedKmh,
    int? estimatedSecondsRemaining,
    bool? isSpeedAlertTriggered,
    bool? isOvershootDetected,
    bool? isGpsDegraded,
    DateTime? snoozeEndTime,
    List<LocationPoint>? routeCoordinates,
    double? routeDistanceMeters,
  }) {
    return TripModel(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      alertRadiusMeters: alertRadiusMeters ?? this.alertRadiusMeters,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      lastFix: lastFix ?? this.lastFix,
      initialDistanceMeters:
          initialDistanceMeters ?? this.initialDistanceMeters,
      distanceToDestinationMeters:
          distanceToDestinationMeters ?? this.distanceToDestinationMeters,
      minDistanceReachedMeters:
          minDistanceReachedMeters ?? this.minDistanceReachedMeters,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      estimatedSecondsRemaining:
          estimatedSecondsRemaining ?? this.estimatedSecondsRemaining,
      isSpeedAlertTriggered:
          isSpeedAlertTriggered ?? this.isSpeedAlertTriggered,
      isOvershootDetected: isOvershootDetected ?? this.isOvershootDetected,
      isGpsDegraded: isGpsDegraded ?? this.isGpsDegraded,
      snoozeEndTime: snoozeEndTime ?? this.snoozeEndTime,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination.toJson(),
      'alertRadiusMeters': alertRadiusMeters,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'lastFix': lastFix?.toJson(),
      'initialDistanceMeters': initialDistanceMeters,
      'distanceToDestinationMeters': distanceToDestinationMeters,
      'minDistanceReachedMeters': minDistanceReachedMeters.isFinite
          ? minDistanceReachedMeters
          : null,
      'currentSpeedKmh': currentSpeedKmh,
      'estimatedSecondsRemaining': estimatedSecondsRemaining,
      'isSpeedAlertTriggered': isSpeedAlertTriggered,
      'isOvershootDetected': isOvershootDetected,
      'isGpsDegraded': isGpsDegraded,
      'snoozeEndTime': snoozeEndTime?.toIso8601String(),
      'routeCoordinates': routeCoordinates?.map((p) => p.toJson()).toList(),
      'routeDistanceMeters': routeDistanceMeters,
    };
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      destination: Destination.fromJson(
        json['destination'] as Map<String, dynamic>,
      ),
      alertRadiusMeters: (json['alertRadiusMeters'] as num).toDouble(),
      status: TripStatus.values.byName(json['status'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      lastFix: json['lastFix'] != null
          ? LocationPoint.fromJson(json['lastFix'] as Map<String, dynamic>)
          : null,
      initialDistanceMeters:
          (json['initialDistanceMeters'] as num?)?.toDouble() ?? 0.0,
      distanceToDestinationMeters:
          (json['distanceToDestinationMeters'] as num?)?.toDouble() ?? 0.0,
      minDistanceReachedMeters:
          (json['minDistanceReachedMeters'] as num?)?.toDouble() ??
          double.infinity,
      currentSpeedKmh: (json['currentSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      estimatedSecondsRemaining: json['estimatedSecondsRemaining'] as int?,
      isSpeedAlertTriggered: json['isSpeedAlertTriggered'] as bool? ?? false,
      isOvershootDetected: json['isOvershootDetected'] as bool? ?? false,
      isGpsDegraded: json['isGpsDegraded'] as bool? ?? false,
      snoozeEndTime: json['snoozeEndTime'] != null
          ? DateTime.parse(json['snoozeEndTime'] as String)
          : null,
      routeCoordinates: (json['routeCoordinates'] as List<dynamic>?)
          ?.map((p) => LocationPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      routeDistanceMeters: (json['routeDistanceMeters'] as num?)?.toDouble(),
    );
  }
}
