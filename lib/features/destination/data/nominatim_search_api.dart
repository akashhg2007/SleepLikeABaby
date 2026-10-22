import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/destination.dart';

/// Geocoding search service using Photon (Komoot OSM) with Nominatim fallback
/// and offline transit hub fallbacks.
class NominatimSearchApi {
  final http.Client _client;

  NominatimSearchApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _photonBaseUrl = 'https://photon.komoot.io/api';
  static const String _photonReverseUrl = 'https://photon.komoot.io/reverse';
  static const String _nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _userAgent =
      'SleepLikeABaby-DestinationAlarm/1.0.0 (contact: mobile-lead@sleeplikeababy.app)';

  /// Search places by keyword with offline fallback.
  Future<List<Destination>> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Try Photon (fast, no heavy rate limiting)
      final uri = Uri.parse(_photonBaseUrl).replace(
        queryParameters: {
          'q': cleanQuery,
          'limit': '10',
          if (proximityLat != null && proximityLng != null) ...{
            'lat': proximityLat.toStringAsFixed(6),
            'lon': proximityLng.toStringAsFixed(6),
          },
        },
      );

      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data =
            json.decode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          return features.map((f) {
            final properties = f['properties'] as Map<String, dynamic>? ?? {};
            final geometry = f['geometry'] as Map<String, dynamic>? ?? {};
            final coordinates =
                geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

            final name = properties['name'] as String? ?? cleanQuery;
            final street = properties['street'] as String?;
            final city = properties['city'] as String?;
            final country = properties['country'] as String?;
            final category = properties['osm_value'] as String?;

            final addressParts = [
              if (street != null && street.isNotEmpty) street,
              if (city != null && city.isNotEmpty) city,
              if (country != null && country.isNotEmpty) country,
            ];
            final displayName = addressParts.isNotEmpty
                ? addressParts.join(', ')
                : name;

            return Destination(
              id: 'photon_${f['properties']?['osm_id'] ?? coordinates.join('_')}',
              name: name,
              displayName:
                  '$name${displayName != name ? ', $displayName' : ''}',
              latitude: (coordinates[1] as num).toDouble(),
              longitude: (coordinates[0] as num).toDouble(),
              category: category,
            );
          }).toList();
        }
      }
    } catch (_) {
      // Fallback to Nominatim if Photon encounters error
    }

    try {
      // 2. Nominatim fallback
      final nomUri = Uri.parse(_nominatimSearchUrl).replace(
        queryParameters: {
          'q': cleanQuery,
          'format': 'json',
          'addressdetails': '1',
          'limit': '10',
        },
      );

      final response = await _client
          .get(nomUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) {
          final map = item as Map<String, dynamic>;
          final name =
              map['name'] as String? ??
              map['display_name']?.toString().split(',').first ??
              cleanQuery;
          return Destination(
            id: 'nom_${map['place_id'] ?? map['osm_id']}',
            name: name,
            displayName: map['display_name'] as String? ?? name,
            latitude: double.parse(map['lat'].toString()),
            longitude: double.parse(map['lon'].toString()),
            category: map['type'] as String?,
          );
        }).toList();
      }
    } catch (_) {
      // Return empty list on network or parse failure
    }

    return const [];
  }

  /// Reverse geocode coordinates to friendly place name.
  Future<Destination> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(_photonReverseUrl).replace(
        queryParameters: {
          'lat': lat.toStringAsFixed(6),
          'lon': lng.toStringAsFixed(6),
        },
      );

      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data =
            json.decode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final prop =
              features.first['properties'] as Map<String, dynamic>? ?? {};
          final name =
              prop['name'] as String? ??
              prop['street'] as String? ??
              'Selected Point';
          final city = prop['city'] as String?;
          final country = prop['country'] as String?;
          final full = [name, ?city, ?country].join(', ');
          return Destination(
            id: 'point_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
            name: name,
            displayName: full,
            latitude: lat,
            longitude: lng,
            category: prop['osm_value'] as String?,
          );
        }
      }
    } catch (_) {}

    return Destination(
      id: 'point_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
      name: 'Custom Location',
      displayName: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      latitude: lat,
      longitude: lng,
    );
  }
}

