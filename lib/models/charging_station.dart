import 'package:latlong2/latlong.dart';

class ChargingStation {
  const ChargingStation({
    required this.id,
    required this.location,
    required this.distanceKm,
    this.name,
    this.operator,
    this.address,
    this.distanceFromRouteKm,
    this.connectors = const [],
    this.chargingPoints,
    this.power,
    this.openingHours,
    this.availability,
    this.phone,
    this.website,
    this.access,
    this.fee,
  });

  final String id;
  final LatLng location;
  final double distanceKm;
  final String? name;
  final String? operator;
  final String? address;
  final double? distanceFromRouteKm;
  final List<String> connectors;
  final int? chargingPoints;
  final String? power;
  final String? openingHours;
  final String? availability;
  final String? phone;
  final String? website;
  final String? access;
  final String? fee;

  bool get isFastCharging {
    final value = power;
    if (value == null) return false;
    final powerValues = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*kw',
      caseSensitive: false,
    ).allMatches(value);
    return powerValues.any((match) {
      final kilowatts = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      return kilowatts != null && kilowatts >= 50;
    });
  }

  ChargingStation withDistanceFromRoute(double distanceFromRouteKm) =>
      ChargingStation(
    id: id,
    location: location,
    distanceKm: distanceKm,
    name: name,
    operator: operator,
    address: address,
    distanceFromRouteKm: distanceFromRouteKm,
    connectors: connectors,
    chargingPoints: chargingPoints,
    power: power,
    openingHours: openingHours,
    availability: availability,
    phone: phone,
    website: website,
    access: access,
    fee: fee,
  );

  ChargingStation withDistanceFromOrigin(double distanceFromOriginKm) =>
      ChargingStation(
        id: id,
        location: location,
        distanceKm: distanceFromOriginKm,
        name: name,
        operator: operator,
        address: address,
        distanceFromRouteKm: distanceFromRouteKm,
        connectors: connectors,
        chargingPoints: chargingPoints,
        power: power,
        openingHours: openingHours,
        availability: availability,
        phone: phone,
        website: website,
        access: access,
        fee: fee,
      );

  factory ChargingStation.fromOverpassElement(
    Map<String, dynamic> element, {
    required LatLng origin,
  }) {
    final tags = element['tags'] is Map
        ? Map<String, dynamic>.from(element['tags'] as Map)
        : <String, dynamic>{};
    final center = element['center'] is Map
        ? element['center'] as Map
        : const <String, dynamic>{};
    final latitude = _number(element['lat'] ?? center['lat']);
    final longitude = _number(element['lon'] ?? center['lon']);
    if (latitude == null || longitude == null) {
      throw const FormatException('Station is missing valid coordinates.');
    }

    final location = LatLng(latitude, longitude);
    final distanceKm = const Distance().as(
      LengthUnit.Kilometer,
      origin,
      location,
    );
    final connectors = <String>{};
    for (final key in tags.keys) {
      if (!key.startsWith('socket:') ||
          key.endsWith(':output') ||
          key.endsWith(':voltage') ||
          key.endsWith(':current') ||
          key.endsWith(':quantity')) {
        continue;
      }
      final value = tags[key]?.toString().trim().toLowerCase();
      if (value == null ||
          value.isEmpty ||
          value == 'no' ||
          value == 'false' ||
          value == '0') {
        continue;
      }
      final connector = key.split(':').elementAtOrNull(1);
      if (connector != null && connector.isNotEmpty) {
        connectors.add(connector.replaceAll('_', ' '));
      }
    }

    final power = _firstTag(tags, const [
      'charging_station:output',
      'maxpower',
      'output',
    ]);
    final socketPower = tags.entries
        .where(
          (entry) =>
              entry.key.startsWith('socket:') &&
              entry.key.endsWith(':output') &&
              entry.value.toString().trim().isNotEmpty,
        )
        .map((entry) => entry.value.toString().trim())
        .toSet();
    final address = _address(tags);

    return ChargingStation(
      id: '${element['type'] ?? 'element'}/${element['id'] ?? ''}',
      location: location,
      distanceKm: distanceKm,
      name: _firstTag(tags, const ['name', 'name:en']),
      operator: _firstTag(tags, const ['operator']),
      address: address,
      connectors: connectors.toList()..sort(),
      chargingPoints: _integer(
        tags['capacity'] ?? tags['charging_station:capacity'],
      ),
      power: power ?? (socketPower.isEmpty ? null : socketPower.join(', ')),
      openingHours: _firstTag(tags, const ['opening_hours']),
      availability: _firstTag(tags, const ['availability', 'status']),
      phone: _firstTag(tags, const ['contact:phone', 'phone']),
      website: _firstTag(tags, const ['contact:website', 'website']),
      access: _firstTag(tags, const ['access']),
      fee: _firstTag(tags, const ['fee']),
    );
  }

  static String? _address(Map<String, dynamic> tags) {
    final fullAddress = _firstTag(tags, const ['addr:full']);
    if (fullAddress != null) return fullAddress;

    final parts = [
      _firstTag(tags, const ['addr:housenumber']),
      _firstTag(tags, const ['addr:street']),
      _firstTag(tags, const ['addr:suburb', 'addr:neighbourhood']),
      _firstTag(tags, const ['addr:city', 'addr:town', 'addr:village']),
      _firstTag(tags, const ['addr:postcode']),
      _firstTag(tags, const ['addr:state']),
      _firstTag(tags, const ['addr:country']),
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? _firstTag(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _integer(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
