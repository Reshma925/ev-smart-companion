import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/location_service.dart';
import 'package:flutter_application_2/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

class _StubLocationService extends LocationService {
  _StubLocationService(this.resolution);

  final LocationResolution resolution;

  @override
  Future<LocationResolution> resolveCurrentLocation({
    void Function(LocationStage stage)? onStage,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    onStage?.call(LocationStage.checkingPermission);
    onStage?.call(LocationStage.gettingLocation);
    return resolution;
  }
}

void main() {
  test('passes live Geolocator coordinates into weather state', () async {
    const position = LatLng(13.0827, 80.2707);
    final locationService = _StubLocationService(
      const LocationResolution(
        position: position,
        message: 'Current location detected.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: true,
        locationAvailable: true,
      ),
    );
    final client = MockClient((request) async {
      expect(request.url.queryParameters['latitude'], '13.0827');
      expect(request.url.queryParameters['longitude'], '80.2707');
      return http.Response(
        jsonEncode({
          'current': {
            'temperature_2m': 24,
            'relative_humidity_2m': 70,
            'apparent_temperature': 26,
            'is_day': 1,
            'precipitation': 0,
            'rain': 0,
            'weather_code': 2,
            'wind_speed_10m': 10,
            'visibility': 10000,
            'time': '2026-10-03T10:00',
          },
        }),
        200,
      );
    });
    final service = WeatherService(
      client: client,
      locationService: locationService,
    );
    addTearDown(client.close);

    LatLng? reportedLocation;
    final weather = await service.fetchCurrentConditions(
      onLocation: (value) => reportedLocation = value,
    );

    expect(reportedLocation, position);
    expect(weather.locationLabel, '13.08°, 80.27°');
  });

  test(
    'reports unavailable current location without contacting weather API',
    () {
      final locationService = _StubLocationService(
        const LocationResolution(
          message: 'Location services are disabled. Enable them and retry.',
          permissionGranted: false,
          permanentlyDenied: false,
          serviceEnabled: false,
          locationAvailable: false,
        ),
      );
      final client = MockClient((_) async {
        fail('Weather API must not be called without a location.');
      });
      final service = WeatherService(
        client: client,
        locationService: locationService,
      );
      addTearDown(client.close);

      expect(
        service.fetchCurrentConditions(),
        throwsA(isA<WeatherLocationException>()),
      );
    },
  );
}
