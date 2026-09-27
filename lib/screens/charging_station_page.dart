import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../services/station_service.dart';

class ChargingStationPage extends StatefulWidget {
  const ChargingStationPage({super.key});

  @override
  State<ChargingStationPage> createState() => _ChargingStationPageState();
}

class _ChargingStationPageState extends State<ChargingStationPage> {
  final service = StationService();
  late final stationStream = service.stations();

  // Fixed "current location" for now. Replace with real GPS later.
  final myLocation = const LatLng(13.0827, 80.2707);

  String search = '';
  bool fastOnly = false;
  bool availableOnly = false;
  String type = 'All'; // All, AC or DC

  @override
  void initState() {
    super.initState();
    service.addSampleStationsIfEmpty();
  }

  double dist(Station s) =>
      distanceKm(myLocation.latitude, myLocation.longitude, s.lat, s.lng);

  List<Station> applyFilters(List<Station> all) {
    final q = search.toLowerCase();
    final list = all.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.provider.toLowerCase().contains(q)) return false;
      if (fastOnly && !s.isFast) return false;
      if (availableOnly && !s.available) return false;
      if (type != 'All' && s.type != type) return false;
      return true;
    }).toList();
    list.sort((a, b) => dist(a).compareTo(dist(b))); // nearest first
    return list;
  }

  // Opens Google Maps directions to the station
  Future<void> navigate(Station s) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void openFilters() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  FilterChip(
                    label: const Text('Fast Charger'),
                    selected: fastOnly,
                    onSelected: (v) => update(() => fastOnly = v),
                  ),
                  FilterChip(
                    label: const Text('Available'),
                    selected: availableOnly,
                    onSelected: (v) => update(() => availableOnly = v),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('Charger type'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final t in ['All', 'AC', 'DC'])
                    ChoiceChip(
                      label: Text(t),
                      selected: type == t,
                      onSelected: (_) => update(() => type = t),
                    ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charging Stations')),
      body: StreamBuilder<List<Station>>(
        stream: stationStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load stations: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stations = applyFilters(snap.data!);

          return Column(
            children: [
              // Search bar and filter button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search stations or providers',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => search = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: openFilters,
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),

              // Map with station markers
              SizedBox(
                height: 250,
                child: FlutterMap(
                  options: MapOptions(initialCenter: myLocation, initialZoom: 11.5),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ev_smart_companion',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: myLocation,
                        child: const Icon(Icons.my_location, color: Colors.red),
                      ),
                      for (final s in stations)
                        Marker(
                          point: LatLng(s.lat, s.lng),
                          width: 36,
                          height: 36,
                          child: Icon(Icons.ev_station,
                              size: 32,
                              color: s.available ? Colors.green : Colors.grey),
                        ),
                    ]),
                    const RichAttributionWidget(attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ]),
                  ],
                ),
              ),

              // List of nearby stations
              Expanded(
                child: stations.isEmpty
                    ? const Center(child: Text('No stations match your filters'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: stations.length,
                        itemBuilder: (context, i) {
                          final s = stations[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              title: Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.navy)),
                              subtitle: Text(
                                '${s.provider} · ${dist(s).toStringAsFixed(1)} km\n'
                                '${s.type}${s.isFast ? ' Fast' : ''} · '
                                '₹${s.costPerKwh.toStringAsFixed(0)}/kWh · '
                                '${s.available ? 'Available' : 'Busy'}',
                              ),
                              isThreeLine: true,
                              trailing: FilledButton(
                                onPressed: () => navigate(s),
                                child: const Text('Navigate'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}