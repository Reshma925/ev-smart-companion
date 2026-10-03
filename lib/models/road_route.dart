import 'package:latlong2/latlong.dart';

class GeocodedDestination {
  const GeocodedDestination({
    required this.name,
    required this.address,
    required this.location,
    this.displayName,
    this.placeId,
    this.addressComponents = const {},
  });

  final String name;
  final String address;
  final LatLng location;
  final String? displayName;
  final String? placeId;
  final Map<String, String> addressComponents;

  String get displayLabel => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : name;
}

class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.duration,
    required this.destination,
  });

  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;
  final GeocodedDestination destination;
}
