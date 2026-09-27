import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Station {
  final String name;
  final String provider;
  final String type; // 'AC' or 'DC'
  final double lat;
  final double lng;
  final double costPerKwh; // rupees
  final bool isFast;
  final bool available;

  Station({
    required this.name,
    required this.provider,
    required this.type,
    required this.lat,
    required this.lng,
    required this.costPerKwh,
    required this.isFast,
    required this.available,
  });

  factory Station.fromMap(Map<String, dynamic> m) => Station(
        name: m['name'],
        provider: m['provider'],
        type: m['type'],
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        costPerKwh: (m['costPerKwh'] as num).toDouble(),
        isFast: m['isFast'],
        available: m['available'],
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'provider': provider,
        'type': type,
        'lat': lat,
        'lng': lng,
        'costPerKwh': costPerKwh,
        'isFast': isFast,
        'available': available,
      };
}

class StationService {
  final _col = FirebaseFirestore.instance.collection('stations');

  // All stations from Firebase, updating live
  Stream<List<Station>> stations() => _col
      .snapshots()
      .map((s) => s.docs.map((d) => Station.fromMap(d.data())).toList());

  // Puts sample stations in Firebase the first time, so the map isn't empty
  Future<void> addSampleStationsIfEmpty() async {
    final existing = await _col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    for (final s in sampleStations) {
      await _col.add(s.toMap());
    }
  }
}

// Straight-line distance between two points in km (haversine formula)
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// Sample data from three made-up providers
final sampleStations = [
  Station(name: 'Anna Nagar Fast Charge Hub', provider: 'VoltGo', type: 'DC',
      lat: 13.0850, lng: 80.2101, costPerKwh: 22, isFast: true, available: true),
  Station(name: 'T. Nagar Mall Parking', provider: 'ChargeHub', type: 'AC',
      lat: 13.0418, lng: 80.2341, costPerKwh: 15, isFast: false, available: true),
  Station(name: 'Adyar EV Point', provider: 'GreenPlug', type: 'DC',
      lat: 13.0012, lng: 80.2565, costPerKwh: 24, isFast: true, available: false),
  Station(name: 'Velachery Metro Charger', provider: 'VoltGo', type: 'AC',
      lat: 12.9815, lng: 80.2180, costPerKwh: 14, isFast: false, available: true),
  Station(name: 'Guindy Highway Supercharge', provider: 'ChargeHub', type: 'DC',
      lat: 13.0067, lng: 80.2206, costPerKwh: 25, isFast: true, available: true),
  Station(name: 'Nungambakkam Office Park', provider: 'GreenPlug', type: 'AC',
      lat: 13.0569, lng: 80.2425, costPerKwh: 16, isFast: false, available: false),
  Station(name: 'Porur Junction Charger', provider: 'VoltGo', type: 'DC',
      lat: 13.0382, lng: 80.1565, costPerKwh: 21, isFast: true, available: true),
  Station(name: 'OMR Tech Park Station', provider: 'ChargeHub', type: 'AC',
      lat: 12.9416, lng: 80.2362, costPerKwh: 15, isFast: false, available: true),
];