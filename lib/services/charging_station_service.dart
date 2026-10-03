import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/charging_station.dart';

class ChargingStationService {
  ChargingStationService({http.Client? client})
    : _client = client ?? http.Client();

  static final Uri _endpoint = Uri.https(
    'overpass-api.de',
    '/api/interpreter',
  );
  static const double defaultRouteCorridorWidthKm = 5;

  final http.Client _client;
  final Map<String, (DateTime, List<ChargingStation>)> _cache = {};

  Future<List<ChargingStation>> findNearbyStations({
    required LatLng center,
    required double radiusKm,
  }) async {
    if (!radiusKm.isFinite || radiusKm <= 0) {
      throw ArgumentError.value(radiusKm, 'radiusKm', 'Must be positive.');
    }

    final radiusMeters = (radiusKm * 1000).round();
    final query = '''
[out:json][timeout:40];
(
  node["amenity"="charging_station"](around:$radiusMeters,${center.latitude},${center.longitude});
  way["amenity"="charging_station"](around:$radiusMeters,${center.latitude},${center.longitude});
  relation["amenity"="charging_station"](around:$radiusMeters,${center.latitude},${center.longitude});
);
out center tags;
''';

    final cacheKey =
        'near:${center.latitude.toStringAsFixed(5)},'
        '${center.longitude.toStringAsFixed(5)}:${radiusKm.toStringAsFixed(3)}';
    final cached = _cached(cacheKey);
    if (cached != null) {
      final refreshedDistances = cached
          .map(
            (station) => station.withDistanceFromOrigin(
              ChargingStation.distanceBetweenKm(center, station.location),
            ),
          )
          .where((station) => station.distanceKm <= radiusKm)
          .toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return List.unmodifiable(refreshedDistances);
    }
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 50));

    if (response.statusCode != 200) {
      throw StateError(
        'OpenStreetMap station search failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
      throw const FormatException('OpenStreetMap returned invalid station data.');
    }

    final stations = _parseStations(
      decoded['elements'] as List,
      origin: center,
    ).where((station) => station.distanceKm <= radiusKm).toList();
    stations.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final result = _deduplicate(stations);
    _cache[cacheKey] = (DateTime.now(), result);
    return result;
  }

  Future<List<ChargingStation>> findAlongRoute({
    required LatLng origin,
    required List<LatLng> routePoints,
    required double searchRadiusKm,
    double corridorWidthKm = defaultRouteCorridorWidthKm,
  }) async {
    if (routePoints.length < 2) {
      throw ArgumentError.value(
        routePoints,
        'routePoints',
        'At least two route points are required.',
      );
    }
    if (!corridorWidthKm.isFinite || corridorWidthKm <= 0) {
      throw ArgumentError.value(
        corridorWidthKm,
        'corridorWidthKm',
        'Must be a positive finite value.',
      );
    }
    if (!searchRadiusKm.isFinite || searchRadiusKm <= 0) {
      throw ArgumentError.value(
        searchRadiusKm,
        'searchRadiusKm',
        'Must be a positive finite radius.',
      );
    }

    final cacheKey = 'route:${corridorWidthKm.toStringAsFixed(1)}:'
        '${searchRadiusKm.toStringAsFixed(3)}:'
        '${origin.latitude.toStringAsFixed(5)},'
        '${origin.longitude.toStringAsFixed(5)}:'
        '${Object.hashAll(routePoints.map((point) => Object.hash(
          point.latitude.toStringAsFixed(5),
          point.longitude.toStringAsFixed(5),
        )))}';
    final cached = _cached(cacheKey);
    if (cached != null) {
      return cached
          .map(
            (station) => station.withDistanceFromOrigin(
              ChargingStation.distanceBetweenKm(origin, station.location),
            ),
          )
          .where((station) => station.distanceKm <= searchRadiusKm)
          .toList(growable: false);
    }

    final radiusMeters = (searchRadiusKm * 1000).round();
    final query = '''
[out:json][timeout:40];
(
  node["amenity"="charging_station"](around:$radiusMeters,${origin.latitude},${origin.longitude});
  way["amenity"="charging_station"](around:$radiusMeters,${origin.latitude},${origin.longitude});
  relation["amenity"="charging_station"](around:$radiusMeters,${origin.latitude},${origin.longitude});
);
out center tags;
''';
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 50));
    if (response.statusCode != 200) {
      throw StateError(
        'OpenStreetMap route-corridor search failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
      throw const FormatException(
        'OpenStreetMap returned invalid route-corridor data.',
      );
    }
    final candidates = _parseStations(
      decoded['elements'] as List,
      origin: origin,
    );
    final stations = candidates
        .map((station) {
          final routeDistance = _distanceToRouteKm(
            station.location,
            routePoints,
          );
          return routeDistance <= corridorWidthKm &&
                  station.distanceKm <= searchRadiusKm
              ? station.withDistanceFromRoute(routeDistance)
              : null;
        })
        .whereType<ChargingStation>()
        .toList();
    stations.sort(
      (a, b) =>
          (a.distanceFromRouteKm ?? 0).compareTo(b.distanceFromRouteKm ?? 0),
    );
    final result = _deduplicate(stations);
    _cache[cacheKey] = (DateTime.now(), result);
    return result;
  }

  Future<List<ChargingStation>> findAlongEntireRoute({
    required LatLng origin,
    required List<LatLng> routePoints,
    double corridorWidthKm = defaultRouteCorridorWidthKm,
  }) async {
    if (routePoints.length < 2) {
      throw ArgumentError.value(
        routePoints,
        'routePoints',
        'At least two route points are required.',
      );
    }
    if (!corridorWidthKm.isFinite || corridorWidthKm <= 0) {
      throw ArgumentError.value(
        corridorWidthKm,
        'corridorWidthKm',
        'Must be a positive finite value.',
      );
    }

    final geometryHash = Object.hashAll(
      routePoints.map(
        (point) => Object.hash(
          point.latitude.toStringAsFixed(5),
          point.longitude.toStringAsFixed(5),
        ),
      ),
    );
    final cacheKey =
        'entire-route:${corridorWidthKm.toStringAsFixed(2)}:'
        '${origin.latitude.toStringAsFixed(5)},'
        '${origin.longitude.toStringAsFixed(5)}:$geometryHash';
    final cached = _cached(cacheKey);
    if (cached != null) return List.unmodifiable(cached);

    final sampleSpacingKm = math.min(10.0, corridorWidthKm);
    final centers = _sampleRoute(routePoints, sampleSpacingKm);
    final radiusMeters =
        ((corridorWidthKm + sampleSpacingKm / 2) * 1000).ceil();
    final selectors = StringBuffer();
    for (final center in centers) {
      selectors
        ..writeln(
          'node["amenity"="charging_station"]'
          '(around:$radiusMeters,${center.latitude},${center.longitude});',
        )
        ..writeln(
          'way["amenity"="charging_station"]'
          '(around:$radiusMeters,${center.latitude},${center.longitude});',
        )
        ..writeln(
          'relation["amenity"="charging_station"]'
          '(around:$radiusMeters,${center.latitude},${center.longitude});',
        );
    }
    final query = '''
[out:json][timeout:90];
(
$selectors);
out center tags;
''';
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 100));
    if (response.statusCode != 200) {
      throw StateError(
        'OpenStreetMap full-route station search failed '
        '(${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
      throw const FormatException(
        'OpenStreetMap returned invalid full-route station data.',
      );
    }
    final stations = _parseStations(
      decoded['elements'] as List,
      origin: origin,
    )
        .map((station) {
          final diversionKm = distanceToRouteKm(
            station.location,
            routePoints,
          );
          return diversionKm <= corridorWidthKm
              ? station.withDistanceFromRoute(diversionKm)
              : null;
        })
        .whereType<ChargingStation>()
        .toList();
    stations.sort(
      (a, b) => (a.distanceFromRouteKm ?? 0).compareTo(
        b.distanceFromRouteKm ?? 0,
      ),
    );
    final result = _deduplicate(stations);
    _cache[cacheKey] = (DateTime.now(), result);
    return result;
  }

  List<ChargingStation> _parseStations(
    List elements, {
    required LatLng origin,
  }) {
    final stations = <ChargingStation>[];
    final seenIds = <String>{};
    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;
      try {
        final station = ChargingStation.fromOverpassElement(
          element,
          origin: origin,
        );
        if (seenIds.add(station.id)) stations.add(station);
      } on FormatException catch (error) {
        debugPrint('Skipping malformed OpenStreetMap charging station: $error');
      }
    }
    return stations;
  }

  List<ChargingStation> _deduplicate(List<ChargingStation> stations) {
    final unique = <ChargingStation>[];
    for (final station in stations) {
      final duplicate = unique.any((existing) {
        final stationName = _normalizedIdentity(station.name);
        final existingName = _normalizedIdentity(existing.name);
        final stationOperator = _normalizedIdentity(station.operator);
        final existingOperator = _normalizedIdentity(existing.operator);
        if (stationName.isEmpty ||
            existingName.isEmpty ||
            stationOperator.isEmpty ||
            existingOperator.isEmpty ||
            stationName != existingName ||
            stationOperator != existingOperator) {
          return false;
        }
        final distance = ChargingStation.distanceBetweenKm(
          station.location,
          existing.location,
        );
        return distance <= 0.01;
      });
      if (!duplicate) unique.add(station);
    }
    return List.unmodifiable(unique);
  }

  static String _normalizedIdentity(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  List<ChargingStation>? _cached(String key) {
    final value = _cache[key];
    if (value == null) return null;
    if (DateTime.now().difference(value.$1) > const Duration(minutes: 3)) {
      _cache.remove(key);
      return null;
    }
    return value.$2;
  }

  static double _distanceToRouteKm(LatLng point, List<LatLng> route) {
    if (route.length == 1) {
      return ChargingStation.distanceBetweenKm(point, route.single);
    }
    var minimum = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final meanLatitude = point.latitude * math.pi / 180;
      final scaleX = 111.320 * math.cos(meanLatitude);
      final scaleY = 110.574;
      final dx = (end.longitude - start.longitude) * scaleX;
      final dy = (end.latitude - start.latitude) * scaleY;
      final px = (point.longitude - start.longitude) * scaleX;
      final py = (point.latitude - start.latitude) * scaleY;
      final lengthSquared = dx * dx + dy * dy;
      final fraction = lengthSquared == 0
          ? 0.0
          : ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
      final closestX = dx * fraction;
      final closestY = dy * fraction;
      minimum = math.min(
        minimum,
        math.sqrt(math.pow(px - closestX, 2) + math.pow(py - closestY, 2)),
      );
    }
    return minimum;
  }

  static double distanceToRouteKm(LatLng point, List<LatLng> route) =>
      _distanceToRouteKm(point, route);

  static List<LatLng> _sampleRoute(List<LatLng> route, double spacingKm) {
    final samples = <LatLng>[route.first];
    var distanceSinceSample = 0.0;
    for (var index = 1; index < route.length; index++) {
      final start = route[index - 1];
      final end = route[index];
      final segmentLength = ChargingStation.distanceBetweenKm(start, end);
      var consumed = 0.0;
      while (segmentLength > 0 &&
          distanceSinceSample + segmentLength - consumed >= spacingKm) {
        final needed = spacingKm - distanceSinceSample;
        consumed += needed;
        final fraction = consumed / segmentLength;
        samples.add(
          LatLng(
            start.latitude + (end.latitude - start.latitude) * fraction,
            start.longitude + (end.longitude - start.longitude) * fraction,
          ),
        );
        distanceSinceSample = 0;
      }
      distanceSinceSample += segmentLength - consumed;
    }
    if (samples.last != route.last) samples.add(route.last);
    return samples;
  }

  void close() {
    _client.close();
  }
}
