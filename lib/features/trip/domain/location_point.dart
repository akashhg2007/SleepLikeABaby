/// Immutable model representing a raw or filtered location fix.
class LocationPoint {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; // in meters/second
  final double bearing; // in degrees 0-360
  final double altitude;
  final DateTime timestamp;
  final bool isMock;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed = 0.0,
    this.bearing = 0.0,
    this.altitude = 0.0,
    required this.timestamp,
    this.isMock = false,
  });

  /// Speed in kilometers per hour.
  double get speedKmh => speed * 3.6;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'bearing': bearing,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
      'isMock': isMock,
    };
  }

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMock: json['isMock'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'LocationPoint(lat: $latitude, lng: $longitude, acc: ${accuracy}m, speed: ${speedKmh.toStringAsFixed(1)}km/h)';
}
