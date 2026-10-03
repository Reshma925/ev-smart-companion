import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/weather_data.dart';
import 'location_service.dart';

class WeatherService {
  WeatherService({http.Client? client, LocationService? locationService})
    : _client = client ?? http.Client(),
      _locationService = locationService ?? LocationService(),
      _ownsClient = client == null;

  final http.Client _client;
  final LocationService _locationService;
  final bool _ownsClient;
  bool get isWeb => kIsWeb;

  Future<WeatherData> fetchCurrentConditions({
    void Function(WeatherLoadStage stage)? onStage,
    void Function(LatLng position)? onLocation,
  }) async {
    onStage?.call(WeatherLoadStage.checkingPermission);
    final resolution = await _locationService.resolveCurrentLocation(
      accuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 12),
      onStage: (stage) {
        onStage?.call(
          switch (stage) {
            LocationStage.checkingPermission =>
              WeatherLoadStage.checkingPermission,
            LocationStage.requestingPermission =>
              WeatherLoadStage.requestingPermission,
            LocationStage.gettingLocation => WeatherLoadStage.gettingLocation,
          },
        );
      },
    );
    final position = resolution.position;
    if (position == null) {
      if (!resolution.serviceEnabled) {
        throw WeatherLocationException(resolution.message);
      }
      if (!resolution.permissionGranted || resolution.permanentlyDenied) {
        throw WeatherPermissionException(
          permanentlyDenied: resolution.permanentlyDenied,
          isWeb: isWeb,
          message: resolution.message,
        );
      }
      throw WeatherLocationException(resolution.message);
    }
    onLocation?.call(position);

    final locationLabel =
        '${position.latitude.toStringAsFixed(2)}°, ${position.longitude.toStringAsFixed(2)}°';
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'rain',
        'weather_code',
        'wind_speed_10m',
        'visibility',
      ].join(','),
      'timezone': 'auto',
    });

    onStage?.call(WeatherLoadStage.fetchingWeather);
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('Weather request timed out: $error\n$stackTrace');
      throw const WeatherServiceException(
        'Local driving conditions could not be loaded. Check your connection and retry.',
      );
    } catch (error, stackTrace) {
      debugPrint('Weather request failed: $error\n$stackTrace');
      throw const WeatherServiceException(
        'Local driving conditions are temporarily unavailable. Please retry.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint('Weather service returned HTTP ${response.statusCode}.');
      throw const WeatherServiceException(
        'Local driving conditions are temporarily unavailable. Please retry.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Weather service returned invalid data.');
      }
      return WeatherData.fromOpenMeteo(decoded, locationLabel: locationLabel);
    } catch (error, stackTrace) {
      debugPrint('Weather service returned invalid data: $error\n$stackTrace');
      throw const WeatherServiceException(
        'Local driving conditions could not be read. Please retry.',
      );
    }
  }

  Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    return Geolocator.openAppSettings();
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

enum WeatherLoadStage {
  checkingPermission,
  requestingPermission,
  gettingLocation,
  fetchingWeather,
}

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherPermissionException extends WeatherServiceException {
  const WeatherPermissionException({
    required this.permanentlyDenied,
    required this.isWeb,
    required String message,
  }) : super(message);

  final bool permanentlyDenied;
  final bool isWeb;
}

class WeatherLocationException extends WeatherServiceException {
  const WeatherLocationException(super.message);
}
