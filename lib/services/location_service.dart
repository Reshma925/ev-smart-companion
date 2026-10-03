import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStage { checkingPermission, requestingPermission, gettingLocation }

class LocationResolution {
  const LocationResolution({
    this.position,
    required this.message,
    required this.permissionGranted,
    required this.permanentlyDenied,
    required this.serviceEnabled,
    required this.locationAvailable,
  });

  final LatLng? position;
  final String message;
  final bool permissionGranted;
  final bool permanentlyDenied;
  final bool serviceEnabled;
  final bool locationAvailable;
}

class LocationService {
  Future<LocationResolution> resolveCurrentLocation({
    void Function(LocationStage stage)? onStage,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    try {
      onStage?.call(LocationStage.checkingPermission);
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        return const LocationResolution(
          message:
              'Location services are disabled. Enable location services and retry.',
          permissionGranted: false,
          permanentlyDenied: false,
          serviceEnabled: false,
          locationAvailable: false,
        );
      }

      var permission = await Geolocator.checkPermission();
      final browserMustPrompt =
          kIsWeb &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine);
      if (!kIsWeb &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine)) {
        onStage?.call(LocationStage.requestingPermission);
        permission = await Geolocator.requestPermission();
      }

      if (!kIsWeb &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine)) {
        return const LocationResolution(
          message:
              'Location permission is required to find nearby charging stations and local driving conditions.',
          permissionGranted: false,
          permanentlyDenied: false,
          serviceEnabled: true,
          locationAvailable: false,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResolution(
          message:
              'Location access is blocked. Enable it in your browser or device settings, then retry.',
          permissionGranted: false,
          permanentlyDenied: true,
          serviceEnabled: true,
          locationAvailable: false,
        );
      }

      onStage?.call(
        browserMustPrompt
            ? LocationStage.requestingPermission
            : LocationStage.gettingLocation,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      ).timeout(timeLimit + const Duration(seconds: 2));

      return LocationResolution(
        position: LatLng(position.latitude, position.longitude),
        message: 'Current location detected.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: true,
        locationAvailable: true,
      );
    } on PermissionDeniedException catch (error, stackTrace) {
      debugPrint('Geolocator denied location access: $error\n$stackTrace');
      return LocationResolution(
        message: kIsWeb
            ? 'Allow location access for this site in your browser, then retry. Browser location requires HTTPS or localhost.'
            : 'Location permission is required to detect your current position.',
        permissionGranted: false,
        permanentlyDenied: kIsWeb,
        serviceEnabled: true,
        locationAvailable: false,
      );
    } on LocationServiceDisabledException catch (error, stackTrace) {
      debugPrint('Device location services are disabled: $error\n$stackTrace');
      return const LocationResolution(
        message:
            'Location services are disabled. Enable location services and retry.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: false,
        locationAvailable: false,
      );
    } on PositionUpdateException catch (error, stackTrace) {
      debugPrint('Geolocator could not obtain a position: $error\n$stackTrace');
      return const LocationResolution(
        message:
            'Your location is temporarily unavailable. Check GPS, network and location settings, then retry.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: true,
        locationAvailable: false,
      );
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('Geolocator location request timed out: $error\n$stackTrace');
      return const LocationResolution(
        message:
            'Your location could not be determined in time. Check location access and retry.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: true,
        locationAvailable: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Location lookup failed: $error\n$stackTrace');
      return LocationResolution(
        message: kIsWeb
            ? 'Unable to detect location. Allow this site to use location and use HTTPS or localhost, then retry.'
            : 'Unable to detect your location. Check location settings and retry.',
        permissionGranted: true,
        permanentlyDenied: false,
        serviceEnabled: true,
        locationAvailable: false,
      );
    }
  }

  Future<bool> openLocationSettings() => Geolocator.openAppSettings();
}
