import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sleep_like_a_baby/features/trip/data/routing_service.dart';

void main() {
  group('RoutingService Tests', () {
    test('Parses valid OSRM response correctly into route points and distance', () async {
      final mockOsrmResponse = {
        'code': 'Ok',
        'routes': [
          {
            'distance': 15420.5,
            'duration': 1850.0,
            'geometry': {
              'coordinates': [
                [-73.9772, 40.7527],
                [-73.9800, 40.7550],
                [-73.9900, 40.7600],
              ],
              'type': 'LineString',
            },
          }
        ],
      };

      final client = MockClient((request) async {
        return http.Response(json.encode(mockOsrmResponse), 200);
      });

      final service = RoutingService(client: client);
      final result = await service.fetchRoute(
        originLat: 40.7527,
        originLng: -73.9772,
        destLat: 40.7600,
        destLng: -73.9900,
      );

      expect(result.isFromRoadNetwork, isTrue);
      expect(result.points.length, equals(3));
      expect(result.distanceMeters, closeTo(15420.5, 0.1));
      expect(result.durationSeconds, closeTo(1850.0, 0.1));
      expect(result.formattedDuration, equals('31 min'));
      expect(result.points.first.latitude, closeTo(40.7527, 0.0001));
      expect(result.points.first.longitude, closeTo(-73.9772, 0.0001));
    });

    test('Falls back gracefully to straight-line when OSRM encounters error', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = RoutingService(client: client);
      final result = await service.fetchRoute(
        originLat: 40.7527,
        originLng: -73.9772,
        destLat: 40.7505,
        destLng: -73.9934,
      );

      expect(result.isFromRoadNetwork, isFalse);
      expect(result.points.length, equals(2));
      expect(result.distanceMeters, greaterThan(1000.0));
      expect(result.durationSeconds, greaterThan(0));
    });
  });
}
