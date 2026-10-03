import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/charging_station.dart';
import 'package:flutter_application_2/services/charging_station_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('ChargingStation', () {
    test('parses OSM tags and calculates geographic distance', () {
      final station = ChargingStation.fromOverpassElement({
        'type': 'node',
        'id': 42,
        'lat': 13.0827,
        'lon': 80.2707,
        'tags': {
          'amenity': 'charging_station',
          'name': 'City charging point',
          'operator': 'Local operator',
          'addr:street': 'Main Road',
          'addr:city': 'Chennai',
          'socket:type2': '2',
          'socket:type2:output': '22 kW',
          'capacity': '2',
          'opening_hours': '24/7',
        },
      }, origin: const LatLng(13.0827, 80.2707));

      expect(station.id, 'node/42');
      expect(station.name, 'City charging point');
      expect(station.operator, 'Local operator');
      expect(station.address, 'Main Road, Chennai');
      expect(station.connectors, ['type2']);
      expect(station.power, '22 kW');
      expect(station.chargingPoints, 2);
      expect(station.openingHours, '24/7');
      expect(station.distanceKm, 0);
      expect(station.phone, isNull);
    });

    test(
      'parses way center coordinates and leaves absent tags unavailable',
      () {
        final station = ChargingStation.fromOverpassElement({
          'type': 'way',
          'id': 17,
          'center': {'lat': 10.0, 'lon': 20.0},
          'tags': {'amenity': 'charging_station'},
        }, origin: const LatLng(10, 20));

        expect(station.location, const LatLng(10, 20));
        expect(station.name, isNull);
        expect(station.operator, isNull);
        expect(station.chargingPoints, isNull);
      },
    );

    test(
      'fast-charge classification requires source power of at least 50 kW',
      () {
        ChargingStation stationWithPower(String power) => ChargingStation(
          id: power,
          location: const LatLng(0, 0),
          distanceKm: 0,
          power: power,
        );

        expect(stationWithPower('22 kW').isFastCharging, isFalse);
        expect(stationWithPower('50 kW').isFastCharging, isTrue);
        expect(stationWithPower('150kW / 22 kW').isFastCharging, isTrue);
        expect(
          const ChargingStation(
            id: 'unknown-power',
            location: LatLng(0, 0),
            distanceKm: 0,
          ).isFastCharging,
          isFalse,
        );
      },
    );
  });

  test(
    'queries Overpass using the range radius and sorts by distance',
    () async {
      late String query;
      final client = MockClient((request) async {
        query = request.bodyFields['data']!;
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 2,
                'lat': 13.1,
                'lon': 80.27,
                'tags': {'amenity': 'charging_station', 'operator': 'B'},
              },
              {
                'type': 'node',
                'id': 1,
                'lat': 13.09,
                'lon': 80.27,
                'tags': {'amenity': 'charging_station', 'operator': 'A'},
              },
            ],
          }),
          200,
        );
      });
      final service = ChargingStationService(client: client);
      addTearDown(service.close);

      final stations = await service.findNearbyStations(
        center: const LatLng(13.0827, 80.2707),
        radiusKm: 30,
      );

      expect(query, contains('around:30000,13.0827,80.2707'));
      expect(stations.map((station) => station.operator), ['A', 'B']);
      expect(stations.first.distanceKm, lessThan(stations.last.distanceKm));
    },
  );

  test('filters corridor candidates and records distance from route', () async {
    late String query;
    final client = MockClient((request) async {
      query = request.bodyFields['data']!;
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 0.01,
              'lon': 0.5,
              'tags': {
                'amenity': 'charging_station',
                'name': 'On route',
                'operator': 'Network A',
              },
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 0.1,
              'lon': 0.5,
              'tags': {
                'amenity': 'charging_station',
                'name': 'Too far from route',
                'operator': 'Network B',
              },
            },
            {
              'type': 'node',
              'id': 3,
              'lat': 0,
              'lon': 1.5,
              'tags': {
                'amenity': 'charging_station',
                'name': 'Outside search radius',
                'operator': 'Network C',
              },
            },
          ],
        }),
        200,
      );
    });
    final service = ChargingStationService(client: client);
    addTearDown(service.close);

    final stations = await service.findAlongRoute(
      origin: const LatLng(0, 0),
      routePoints: const [LatLng(0, 0), LatLng(0, 2)],
      searchRadiusKm: 100,
      corridorWidthKm: 5,
    );

    expect(query, contains('around:100000,0.0,0.0'));
    expect(stations.map((station) => station.name), ['On route']);
    expect(stations.single.distanceFromRouteKm, closeTo(1.1, 0.2));
    expect(stations.single.distanceKm, greaterThan(40));
  });
}
