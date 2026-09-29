import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/vehicle.dart';
import '../services/vehicle_simulator.dart';
import 'charging_station_page.dart';
import 'trip_planner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final sim = VehicleSimulator(widget.vehicle);
  int navIndex = 0;

  @override
  void initState() {
    super.initState();
    sim.start();
  }

  @override
  void dispose() {
    sim.stop();
    super.dispose();
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<VehicleData>(
          stream: sim.stream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Greeting
                Text(
                  '${greeting()}, ${widget.vehicle.ownerName.split(' ').first}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                Text(
                  widget.vehicle.model,
                  style: const TextStyle(color: AppTheme.mutedBlue),
                ),
                const SizedBox(height: 20),

                // Vehicle image
                const Icon(Icons.electric_car, size: 110, color: AppTheme.blue),
                const SizedBox(height: 20),

                // Battery % and Range
                Row(
                  children: [
                    Expanded(
                      child: infoCard('Battery',
                          '${d.battery.toStringAsFixed(0)}%', Icons.battery_std),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: infoCard('Range',
                          '${d.range.toStringAsFixed(0)} km', Icons.route),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Vehicle Health Score (circular gauge)
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: d.healthScore / 100,
                          strokeWidth: 12,
                          color: AppTheme.blue,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${d.healthScore}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const Text('Health Score',
                                  style: TextStyle(color: AppTheme.mutedBlue)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Battery Health and Charging Status
                Row(
                  children: [
                    Expanded(
                      child: infoCard(
                          'Battery Health',
                          '${d.batteryHealth.toStringAsFixed(1)}%',
                          Icons.favorite_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: infoCard(
                          'Charging',
                          d.isCharging ? 'Charging' : 'Not charging',
                          d.isCharging
                              ? Icons.battery_charging_full
                              : Icons.power_off),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    actionButton('Charging\nMap', Icons.ev_station,
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ChargingStationPage()),
                            )),
                   
                   
                   actionButton('Trip\nPlanner', Icons.map_outlined,
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TripPlannerPage(
                                      battery: d.battery, range: d.range)),
                            )),
                    actionButton('Vehicle\nHealth', Icons.monitor_heart_outlined),
                    actionButton('Mainte-\nnance', Icons.build_outlined),
                  ],
                ),
              ],
            );
          },
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (i) => setState(() => navIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.blue,
        unselectedItemColor: AppTheme.mutedBlue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.ev_station), label: 'Charging'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
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

  Widget actionButton(String label, IconData icon, [VoidCallback? onTap]) {
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.blue),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.navy)),
      ],
    );
  }
}