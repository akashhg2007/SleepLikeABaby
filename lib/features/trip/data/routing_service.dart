import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/utils/distance_calculator.dart';
import '../domain/location_point.dart';

/// Result encapsulating road-network geometry, road distance, and expected transit duration.
class RouteResult {
  final List<LocationPoint> points;
  final double distanceMeters;
  final double durationSeconds;
  final bool isFromRoadNetwork;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isFromRoadNetwork = true,
  });

  /// Approximate travel time formatted (e.g., '35 min' or '1 h 10 min')
  String get formattedDuration {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return remMins > 0 ? '${hours}h ${remMins}m' : '${hours}h';
  }
}

/// Routing service implementing near-zero-cost OpenStreetMap directions
/// using OSRM with OpenRouteService fallback and straight-line fallback.
class RoutingService {
  final http.Client _client;
  final String? openRouteServiceApiKey;

  RoutingService({
    http.Client? client,
    this.openRouteServiceApiKey,
  }) : _client = client ?? http.Client();

  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const String _orsBaseUrl = 'https://api.openrouteservice.org/v2/directions/driving-car';
  static const String _userAgent =
      'SleepLikeABaby-Routing/1.0.0 (contact: mobile-lead@sleeplikeababy.app)';

  /// Calculates a route between [originLat], [originLng] and [destLat], [destLng].
  /// Calls OSRM or OpenRouteService once at trip start/planning.
  /// Falls back gracefully to straight-line navigation if offline or throttled.
  Future<RouteResult> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // 1. Try OSRM public demo server (Free, no API key required)
    try {
      final url = Uri.parse(
        '$_osrmBaseUrl/$originLng,$originLat;$destLng,$destLat?overview=full&geometries=geojson',
      );

      final response = await _client
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final primary = routes[0] as Map<String, dynamic>;
          final distance = (primary['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (primary['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = primary['geometry'] as Map<String, dynamic>?;
          final rawCoords = geometry?['coordinates'] as List<dynamic>?;

          if (rawCoords != null && rawCoords.isNotEmpty) {
            final now = DateTime.now();
            final points = rawCoords.map((c) {
              final coordPair = c as List<dynamic>;
              return LocationPoint(
                latitude: (coordPair[1] as num).toDouble(),
                longitude: (coordPair[0] as num).toDouble(),
                accuracy: 5.0,
                timestamp: now,
              );
            }).toList();

            return RouteResult(
              points: points,
              distanceMeters: distance,
              durationSeconds: duration,
              isFromRoadNetwork: true,
            );
          }
        }
      }
    } catch (_) {
      // Fallback to ORS or straight line
    }

    // 2. Try OpenRouteService if API key is configured
    final apiKey = openRouteServiceApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final orsUri = Uri.parse(_orsBaseUrl).replace(
          queryParameters: {
            'start': '$originLng,$originLat',
            'end': '$destLng,$destLat',
          },
        );

        final response = await _client.get(
          orsUri,
          headers: {
            'Authorization': apiKey,
            'User-Agent': _userAgent,
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final feature = features[0] as Map<String, dynamic>;
            final properties = feature['properties'] as Map<String, dynamic>? ?? {};
            final summary = properties['summary'] as Map<String, dynamic>? ?? {};
            final distance = (summary['distance'] as num?)?.toDouble() ?? 0.0;
            final duration = (summary['duration'] as num?)?.toDouble() ?? 0.0;

            final geometry = feature['geometry'] as Map<String, dynamic>?;
            final rawCoords = geometry?['coordinates'] as List<dynamic>?;

            if (rawCoords != null && rawCoords.isNotEmpty) {
              final now = DateTime.now();
              final points = rawCoords.map((c) {
                final coordPair = c as List<dynamic>;
                return LocationPoint(
                  latitude: (coordPair[1] as num).toDouble(),
                  longitude: (coordPair[0] as num).toDouble(),
                  accuracy: 5.0,
                  timestamp: now,
                );
              }).toList();

              return RouteResult(
                points: points,
                distanceMeters: distance,
                durationSeconds: duration,
                isFromRoadNetwork: true,
              );
            }
          }
        }
      } catch (_) {
        // Fallback to straight line
      }
    }

    // 3. Resilient Fallback: Direct Haversine straight line
    final straightDistance = DistanceCalculator.haversineDistanceMeters(
      originLat,
      originLng,
      destLat,
      destLng,
    );
    // Rough estimate assuming 40 km/h average speed in transit
    final estimatedSeconds = (straightDistance / (40.0 * 1000 / 3600)).roundToDouble();
    final now = DateTime.now();

    return RouteResult(
      points: [
        LocationPoint(latitude: originLat, longitude: originLng, accuracy: 10.0, timestamp: now),
        LocationPoint(latitude: destLat, longitude: destLng, accuracy: 10.0, timestamp: now),
      ],
      distanceMeters: straightDistance,
      durationSeconds: estimatedSeconds,
      isFromRoadNetwork: false,
    );
  }
}
