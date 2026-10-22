import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for traffic incidents and congestion delay alerts.
class TrafficIncident {
  final String description;
  final int delaySeconds;
  final double magnitudeOfDelay;

  const TrafficIncident({
    required this.description,
    required this.delaySeconds,
    this.magnitudeOfDelay = 0.0,
  });

  String get formattedDelay {
    if (delaySeconds <= 0) return 'No delay';
    final mins = (delaySeconds / 60).round();
    return '+$mins min delay';
  }
}

/// Optional TomTom Traffic Service for periodic / on-demand traffic incident refreshes.
/// Designed specifically to stay within free monthly allowances and NOT poll continuously.
class TomTomTrafficService {
  final http.Client _client;
  final String? apiKey;

  TomTomTrafficService({
    http.Client? client,
    this.apiKey,
  }) : _client = client ?? http.Client();

  bool get isConfigured {
    final key = apiKey;
    return key != null && key.isNotEmpty;
  }

  /// Fetches traffic incidents inside a bounding box.
  /// Should be called occasionally (e.g., at trip start or manual refresh),
  /// strictly avoiding high-frequency periodic polling to preserve quotas.
  Future<List<TrafficIncident>> fetchIncidents({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty) return const [];
    try {
      final bbox = '$minLng,$minLat,$maxLng,$maxLat';
      final url = Uri.parse(
        'https://api.tomtom.com/traffic/services/5/incidentDetails?bbox=$bbox&key=$key',
      );
      final response = await _client.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final incidents = data['incidents'] as List<dynamic>? ?? [];
        return incidents.map((inc) {
          final props = inc['properties'] as Map<String, dynamic>? ?? {};
          final events = props['events'] as List<dynamic>? ?? [];
          final desc = events.isNotEmpty
              ? (events[0]['description'] as String? ?? 'Traffic Incident')
              : 'Traffic Incident';
          final delay = (props['delay'] as num?)?.toInt() ?? 0;
          final mag = (props['magnitudeOfDelay'] as num?)?.toDouble() ?? 0.0;
          return TrafficIncident(
            description: desc,
            delaySeconds: delay,
            magnitudeOfDelay: mag,
          );
        }).toList();
      }
    } catch (_) {}
    return const [];
  }
}
