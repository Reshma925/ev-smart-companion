import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/road_directions_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('geocodes a destination and returns an OSRM road route', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'nominatim.openstreetmap.org') {
        expect(request.url.queryParameters['q'], 'Chennai Airport');
        return http.Response(
          jsonEncode([
            {
              'name': 'Chennai International Airport',
              'display_name': 'Chennai Airport, Chennai, India',
              'lat': '12.9941',
              'lon': '80.1709',
            },
          ]),
          200,
        );
      }
      expect(request.url.host, 'router.project-osrm.org');
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 12500,
              'duration': 1800,
              'geometry': {
                'coordinates': [
                  [80.27, 13.08],
                  [80.22, 13.03],
                  [80.1709, 12.9941],
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final service = RoadDirectionsService(client: client);
    addTearDown(client.close);

    final destination = await service.geocode('Chennai Airport');
    final route = await service.route(
      origin: const LatLng(13.08, 80.27),
      destination: destination,
    );

    expect(destination.location, const LatLng(12.9941, 80.1709));
    expect(route.points, hasLength(3));
    expect(route.distanceKm, 12.5);
    expect(route.duration, const Duration(minutes: 30));
    expect(route.destination.name, 'Chennai International Airport');
  });

  test('rejects empty destination query', () {
    final service = RoadDirectionsService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(service.close);

    expect(service.geocode('  '), throwsArgumentError);
  });
}
