import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/road_route.dart';

class RoadDirectionsService {
  RoadDirectionsService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, GeocodedDestination> _destinationCache = {};
  final Map<String, RoadRoute> _routeCache = {};

  Future<GeocodedDestination> geocode(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Destination cannot be empty.');
    }
    final cached = _destinationCache[normalizedQuery.toLowerCase()];
    if (cached != null) return cached;

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': normalizedQuery,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '1',
    });
    final response = await _request(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw const FormatException('No matching destination was found.');
    }

    final result = Map<String, dynamic>.from(decoded.first as Map);
    final latitude = double.tryParse(result['lat']?.toString() ?? '');
    final longitude = double.tryParse(result['lon']?.toString() ?? '');
    final displayName = result['display_name']?.toString().trim();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        displayName == null ||
        displayName.isEmpty) {
      throw const FormatException('Destination result had invalid coordinates.');
    }
    final destination = GeocodedDestination(
      name: result['name']?.toString().trim().isNotEmpty == true
          ? result['name'].toString().trim()
          : normalizedQuery,
      address: displayName,
      location: LatLng(latitude, longitude),
    );
    _destinationCache[normalizedQuery.toLowerCase()] = destination;
    return destination;
  }

  Future<RoadRoute> route({
    required LatLng origin,
    required GeocodedDestination destination,
  }) async {
    final cacheKey = [
      origin.latitude.toStringAsFixed(4),
      origin.longitude.toStringAsFixed(4),
      destination.location.latitude.toStringAsFixed(5),
      destination.location.longitude.toStringAsFixed(5),
    ].join(',');
    final cached = _routeCache[cacheKey];
    if (cached != null) return cached;

    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.location.longitude},${destination.location.latitude}';
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final response = await _request(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['code'] != 'Ok' ||
        decoded['routes'] is! List ||
        (decoded['routes'] as List).isEmpty) {
      throw const FormatException('A driving route could not be found.');
    }
    final route = Map<String, dynamic>.from(
      (decoded['routes'] as List).first as Map,
    );
    final geometry = route['geometry'];
    final rawCoordinates = geometry is Map ? geometry['coordinates'] : null;
    if (rawCoordinates is! List || rawCoordinates.length < 2) {
      throw const FormatException('Routing service returned no route geometry.');
    }
    final points = <LatLng>[];
    for (final coordinate in rawCoordinates) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final longitude = _asDouble(coordinate[0]);
      final latitude = _asDouble(coordinate[1]);
      if (latitude == null || longitude == null) continue;
      points.add(LatLng(latitude, longitude));
    }
    final distanceMeters = _asDouble(route['distance']);
    final durationSeconds = _asDouble(route['duration']);
    if (points.length < 2 ||
        distanceMeters == null ||
        durationSeconds == null ||
        distanceMeters < 0 ||
        durationSeconds < 0) {
      throw const FormatException('Routing service returned invalid route data.');
    }

    final result = RoadRoute(
      points: List.unmodifiable(points),
      distanceKm: distanceMeters / 1000,
      duration: Duration(seconds: durationSeconds.round()),
      destination: destination,
    );
    _routeCache[cacheKey] = result;
    return result;
  }

  Future<http.Response> _request(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'EVSmartCompanion/1.0 (charging route search)',
              ...headers,
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (error, stackTrace) {
      debugPrint('OpenStreetMap route request failed: $error\n$stackTrace');
      throw const RoadDirectionsException(
        'Destination or route service is temporarily unavailable. Check your connection and retry.',
      );
    }
    if (response.statusCode != 200) {
      debugPrint(
        'OpenStreetMap route endpoint returned HTTP ${response.statusCode}.',
      );
      throw const RoadDirectionsException(
        'Destination or route service is temporarily unavailable. Retry shortly.',
      );
    }
    return response;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class RoadDirectionsException implements Exception {
  const RoadDirectionsException(this.message);

  final String message;

  @override
  String toString() => message;
}
