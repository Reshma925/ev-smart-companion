import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
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
  const TripPlannerPage({super.key, required this.battery, required this.range});
  final double battery; // current battery % from the dashboard
  final double range; // current range in km from the dashboard

  @override
  State<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends State<TripPlannerPage> {
  String? from;
  String? to;
  TripPlan? plan;

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

  void planTrip() {
    if (from == null || to == null || from == to) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick two different cities from the suggestions.')));
      return;
    }
    final a = cities[from]!;
    final b = cities[to]!;

    // Roads are longer than a straight line, so add 25%
    final road = distanceKm(a.latitude, a.longitude, b.latitude, b.longitude) * 1.25;

    // Range on a full battery, worked out from the current battery and range
    final fullRange =
        widget.battery > 0 ? widget.range * 100 / widget.battery : 300.0;
    final reserve = fullRange * 0.2; // always keep 20% battery
    final leg = fullRange * 0.6; // distance after charging from 20% to 80%

    // Add a charging stop every time the battery would reach 20%
    final stops = <String>[];
    var reach = (widget.range - reserve).clamp(0, double.infinity).toDouble();
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
    final startBattery = stops.isEmpty ? widget.battery : 80.0;
    final arrivalBattery = startBattery - (road - lastCharge) / fullRange * 100;

    // Average 60 km/h, plus 40 minutes per charging stop
    final minutes = (road / 60 * 60).round() + stops.length * 40;

    setState(() => plan =
        TripPlan(road, stops, Duration(minutes: minutes), arrivalBattery));
  }

  // Opens Google Maps with the route and charging stops
  Future<void> startJourney() async {
    final a = cities[from]!;
    final b = cities[to]!;
    final waypoints = plan!.stops
        .map((s) => '${cities[s]!.latitude},${cities[s]!.longitude}')
        .join('|');
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${a.latitude},${a.longitude}'
        '&destination=${b.latitude},${b.longitude}'
        '${waypoints.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(waypoints)}'}'
        '&travelmode=driving';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget cityField(String label, IconData icon, void Function(String) onPick) {
    return Autocomplete<String>(
      optionsBuilder: (value) => cities.keys.where(
          (c) => c.toLowerCase().contains(value.text.toLowerCase())),
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
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current Battery % and Estimated Range
          Row(
            children: [
              Expanded(
                child: infoCard('Current Battery',
                    '${widget.battery.toStringAsFixed(0)}%', Icons.battery_std),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: infoCard('Estimated Range',
                    '${widget.range.toStringAsFixed(0)} km', Icons.route),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // From and Destination fields
          cityField('From', Icons.my_location, (c) => from = c),
          const SizedBox(height: 12),
          cityField('Destination', Icons.flag_outlined, (c) => to = c),
          const SizedBox(height: 20),
          FilledButton(onPressed: planTrip, child: const Text('Plan Trip')),

          if (p != null) ...[
            const SizedBox(height: 24),

            // Trip summary and Estimated Arrival Time
            Row(
              children: [
                Expanded(
                  child: infoCard('Distance',
                      '${p.distanceKm.toStringAsFixed(0)} km', Icons.straighten),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: infoCard(
                      'Arrival',
                      TimeOfDay.fromDateTime(DateTime.now().add(p.duration))
                          .format(context),
                      Icons.schedule),
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
            const Text('Suggested Charging Stops',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy)),
            const SizedBox(height: 8),
            if (p.stops.isEmpty)
              const Text('No charging needed. You can reach your destination '
                  'on your current battery.')
            else
              for (var i = 0; i < p.stops.length; i++)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.stops[i]),
                    subtitle: const Text('Charge 20% → 80% · about 40 min (DC fast)'),
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
      ),
    );
  }
}