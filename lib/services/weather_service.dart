import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/weather_data.dart';

class WeatherService {
  WeatherService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  bool get isWeb => kIsWeb;

  Future<WeatherData> fetchCurrentConditions({
    void Function(WeatherLoadStage stage)? onStage,
  }) async {
    onStage?.call(WeatherLoadStage.checkingPermission);
    final position = await _requestCurrentPosition(onStage: onStage);
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
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'Weather service returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Weather service returned invalid data.');
    }
    return WeatherData.fromOpenMeteo(decoded, locationLabel: locationLabel);
  }

  Future<Position> _requestCurrentPosition({
    void Function(WeatherLoadStage stage)? onStage,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (kIsWeb && permission == LocationPermission.deniedForever) {
      throw WeatherPermissionException(permanentlyDenied: true, isWeb: kIsWeb);
    }
    if (!kIsWeb && permission == LocationPermission.deniedForever) {
      throw WeatherPermissionException(permanentlyDenied: true, isWeb: false);
    }
    if (!kIsWeb &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.unableToDetermine)) {
      onStage?.call(WeatherLoadStage.requestingPermission);
      permission = await Geolocator.requestPermission();
    }
    if (!kIsWeb && permission == LocationPermission.deniedForever) {
      throw WeatherPermissionException(permanentlyDenied: true, isWeb: kIsWeb);
    }
    if (!kIsWeb &&
        permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw WeatherPermissionException(permanentlyDenied: false, isWeb: kIsWeb);
    }

    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherLocationException(
        'Location services are turned off. Turn them on to see local driving conditions.',
      );
    }

    try {
      // Web geolocation prompts through getCurrentPosition itself. Calling
      // requestPermission first loses browser error details and can mistake
      // an unrequested browser prompt for a denial.
      onStage?.call(
        kIsWeb &&
                (permission == LocationPermission.denied ||
                    permission == LocationPermission.unableToDetermine)
            ? WeatherLoadStage.requestingPermission
            : WeatherLoadStage.gettingLocation,
      );
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(const Duration(seconds: 15));
    } on PermissionDeniedException {
      if (kIsWeb &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine)) {
        throw WeatherPermissionException(permanentlyDenied: false, isWeb: true);
      }
      throw WeatherPermissionException(
        permanentlyDenied: kIsWeb,
        isWeb: kIsWeb,
      );
    } on LocationServiceDisabledException {
      throw const WeatherLocationException(
        'Location services are turned off. Turn them on to see local driving conditions.',
      );
    } on PositionUpdateException {
      throw const WeatherLocationException(
        'Your location is currently unavailable. Check that location services are enabled for this device and retry.',
      );
    } on TimeoutException {
      throw const WeatherLocationException(
        'Your location could not be determined in time. Check location settings and retry.',
      );
    } catch (error) {
      if (error is WeatherPermissionException ||
          error is WeatherLocationException) {
        rethrow;
      }
      throw WeatherLocationException(
        'Unable to determine your location: $error',
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
  }) : super(
         'Location permission is required to show local driving conditions.',
       );

  final bool permanentlyDenied;
  final bool isWeb;
}

class WeatherLocationException extends WeatherServiceException {
  const WeatherLocationException(super.message);
}
