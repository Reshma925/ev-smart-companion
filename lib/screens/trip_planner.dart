import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/distance_unit_service.dart';
import '../services/ev_range_service.dart';
import '../services/firestore_service.dart';
import '../services/station_service.dart'; // for distanceKm

// Cities the user can pick, with their map coordinates
const cities = <String, LatLng>{
  'Chennai': LatLng(13.0827, 80.2707),
  'Coimbatore': LatLng(11.0168, 76.9558),
  'Madurai': LatLng(9.9252, 78.1198),
  'Tiruchirappalli': LatLng(10.7905, 78.7047),
  'Salem': LatLng(11.6643, 78.1460),
  'Tirunelveli': LatLng(8.7139, 77.7567),
  'Vellore': LatLng(12.9165, 79.1325),
  'Erode': LatLng(11.3410, 77.7172),
  'Tiruppur': LatLng(11.1085, 77.3411),
  'Thanjavur': LatLng(10.7870, 79.1378),
  'Puducherry': LatLng(11.9416, 79.8083),
  'Kanyakumari': LatLng(8.0883, 77.5385),
  'Krishnagiri': LatLng(12.5186, 78.2137),
  'Hosur': LatLng(12.7409, 77.8253),
  'Bengaluru': LatLng(12.9716, 77.5946),
  'Mysuru': LatLng(12.2958, 76.6394),
  'Palakkad': LatLng(10.7867, 76.6548),
  'Thrissur': LatLng(10.5276, 76.2144),
  'Kochi': LatLng(9.9312, 76.2673),
  'Kozhikode': LatLng(11.2588, 75.7804),
  'Thiruvananthapuram': LatLng(8.5241, 76.9366),
  'Hyderabad': LatLng(17.3850, 78.4867),
};

class TripPlan {
  final double distanceKm;
  final List<String> stops;
  final Duration duration;
  final double arrivalBattery;
  TripPlan(this.distanceKm, this.stops, this.duration, this.arrivalBattery);
}

class TripPlannerPage extends StatefulWidget {
  const TripPlannerPage({
    super.key,
    required this.vehicleId,
    required this.onConfigureVehicle,
    this.distanceUnit = DistanceUnitService.km,
  });
  final String vehicleId;
  final VoidCallback onConfigureVehicle;
  final String distanceUnit;

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<Vehicle?> _vehicleStream = _firestoreService
      .watchVehicleById(widget.vehicleId);
  late final Stream<VehicleData?> _telemetryStream = _firestoreService
      .watchVehicleTelemetry(widget.vehicleId);

  String? from;
  String? to;
  TripPlan? plan;

  double? _currentRangeKm(double battery, double? maximumRangeKm) {
    if (!battery.isFinite ||
        battery < 0 ||
        battery > 100 ||
        maximumRangeKm == null ||
        !maximumRangeKm.isFinite ||
        maximumRangeKm <= 0) {
      return null;
    }
    return EvRangeService.calculateCurrentRangeKm(
      maximumRangeKm: maximumRangeKm,
      batteryPercentage: battery,
    );
  }

  // Finds the city closest to a point on the route
  String nearestCity(LatLng p, String exclude) {
    String best = cities.keys.first;
    double bestDist = double.infinity;
    cities.forEach((name, c) {
      if (name == exclude) return;
      final d = distanceKm(p.latitude, p.longitude, c.latitude, c.longitude);
      if (d < bestDist) {
        bestDist = d;
        best = name;
      }
    });
    return best;
  }

  void planTrip(double battery, double? maximumRangeKm) {
    final currentRange = _currentRangeKm(battery, maximumRangeKm);
    if (currentRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valid live battery telemetry and a configured maximum vehicle range are required.',
          ),
        ),
      );
      return;
    }
    if (maximumRangeKm == null) return;
    if (from == null || to == null || from == to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick two different cities from the suggestions.'),
        ),
      );
      return;
    }
    final a = cities[from]!;
    final b = cities[to]!;

    // Roads are longer than a straight line, so add 25%
    final road =
        distanceKm(a.latitude, a.longitude, b.latitude, b.longitude) * 1.25;

    // Range on a full battery, worked out from the current battery and range
    final fullRange = maximumRangeKm;
    final reserve = fullRange * 0.2; // always keep 20% battery
    final leg = fullRange * 0.6; // distance after charging from 20% to 80%

    // Add a charging stop every time the battery would reach 20%
    final stops = <String>[];
    var reach = (currentRange - reserve).clamp(0, double.infinity).toDouble();
    while (reach < road && stops.length < 10) {
      final f = reach / road;
      final point = LatLng(
        a.latitude + (b.latitude - a.latitude) * f,
        a.longitude + (b.longitude - a.longitude) * f,
      );
      stops.add(nearestCity(point, to!));
      reach += leg;
    }

    final lastCharge = stops.isEmpty ? 0.0 : reach - leg;
    final startBattery = stops.isEmpty ? battery : 80.0;
    final arrivalBattery = startBattery - (road - lastCharge) / fullRange * 100;

    // Average 60 km/h, plus 40 minutes per charging stop
    final minutes = (road / 60 * 60).round() + stops.length * 40;

    setState(
      () => plan = TripPlan(
        road,
        stops,
        Duration(minutes: minutes),
        arrivalBattery,
      ),
    );
  }

  // Opens OpenStreetMap directions with the planned charging stops.
  Future<void> startJourney() async {
    final a = cities[from]!;
    final b = cities[to]!;
    final points = [
      a,
      ...plan!.stops.map((stop) => cities[stop]!),
      b,
    ].map((point) => '${point.latitude},${point.longitude}').join(';');
    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': points,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget cityField(String label, IconData icon, void Function(String) onPick) {
    return Autocomplete<String>(
      optionsBuilder: (value) => cities.keys.where(
        (c) => c.toLowerCase().contains(value.text.toLowerCase()),
      ),
      onSelected: (city) {
        onPick(city);
        setState(() => plan = null);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E0E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blue),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.mutedBlue)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: StreamBuilder<Vehicle?>(
        stream: _vehicleStream,
        builder: (context, vehicleSnapshot) {
          if (vehicleSnapshot.hasError) {
            return const Center(
              child: Text('Could not load vehicle configuration from Firebase.'),
            );
          }
          if (!vehicleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vehicle = vehicleSnapshot.data;
          if (vehicle == null) {
            return const Center(
              child: Text('The registered vehicle is unavailable in Firebase.'),
            );
          }
          return StreamBuilder<VehicleData?>(
            stream: _telemetryStream,
            builder: (context, telemetrySnapshot) {
              if (telemetrySnapshot.hasError) {
                return const Center(
                  child: Text('Could not load live battery telemetry from Firebase.'),
                );
              }
              if (!telemetrySnapshot.hasData) {
                if (telemetrySnapshot.connectionState == ConnectionState.active) {
                  return const Center(
                    child: Text('Live battery telemetry is unavailable.'),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }
              return _buildPlanner(
                context,
                telemetrySnapshot.data!.battery,
                vehicle.maximumRangeKm,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanner(
    BuildContext context,
    double battery,
    double? maximumRangeKm,
  ) {
    final p = plan;
    final currentRange = _currentRangeKm(battery, maximumRangeKm);
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current Battery % and Estimated Range
          Row(
            children: [
              Expanded(
                child: infoCard(
                  'Current Battery',
                  '${battery.toStringAsFixed(0)}%',
                  Icons.battery_std,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: infoCard(
                  'Estimated Range',
                  currentRange == null
                      ? 'Not available'
                      : DistanceUnitService.format(
                          currentRange,
                          widget.distanceUnit,
                          decimals: 0,
                        ),
                  Icons.route,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (currentRange == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valid live battery telemetry and a configured maximum vehicle range are required.',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  TextButton.icon(
                    onPressed: widget.onConfigureVehicle,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configure known vehicle data'),
                  ),
                ],
              ),
            ),

          // From and Destination fields
          cityField('From', Icons.my_location, (c) => from = c),
          const SizedBox(height: 12),
          cityField('Destination', Icons.flag_outlined, (c) => to = c),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => planTrip(battery, maximumRangeKm),
            child: const Text('Plan Trip'),
          ),

          if (p != null) ...[
            const SizedBox(height: 24),

            // Trip summary and Estimated Arrival Time
            Row(
              children: [
                Expanded(
                  child: infoCard(
                    'Distance',
                    DistanceUnitService.format(
                      p.distanceKm,
                      widget.distanceUnit,
                      decimals: 0,
                    ),
                    Icons.straighten,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: infoCard(
                    'Arrival',
                    TimeOfDay.fromDateTime(
                      DateTime.now().add(p.duration),
                    ).format(context),
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Travel time about ${p.duration.inHours} h ${p.duration.inMinutes % 60} min · '
              'Battery on arrival about ${p.arrivalBattery.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.mutedBlue),
            ),
            const SizedBox(height: 20),

            // Suggested Charging Stops
            const Text(
              'Suggested Charging Stops',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 8),
            if (p.stops.isEmpty)
              const Text(
                'No charging needed. You can reach your destination '
                'on your current battery.',
              )
            else
              for (var i = 0; i < p.stops.length; i++)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.stops[i]),
                    subtitle: const Text(
                      'Charge 20% → 80% · about 40 min (DC fast)',
                    ),
                  ),
                ),
            const SizedBox(height: 20),

            // Start Journey button
            FilledButton.icon(
              onPressed: startJourney,
              icon: const Icon(Icons.navigation),
              label: const Text('Start Journey'),
            ),
          ],
        ],
    );
  }
}
