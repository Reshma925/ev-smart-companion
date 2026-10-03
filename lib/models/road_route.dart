import 'package:latlong2/latlong.dart';

class GeocodedDestination {
  const GeocodedDestination({
    required this.name,
    required this.address,
    required this.location,
  });

  final String name;
  final String address;
  final LatLng location;
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
