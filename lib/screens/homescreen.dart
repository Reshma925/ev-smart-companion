import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/vehicle_simulator.dart';
import 'charging_station_page.dart';
import 'login_page.dart';
import 'maintenance.dart';
import 'trip_planner.dart';
import 'vehicle_health_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DashboardIdentity {
  const _DashboardIdentity({
    required this.name,
    required this.vehicle,
    required this.simulator,
  });

  final String name;
  final Vehicle vehicle;
  final VehicleSimulator simulator;
}

class _HomeScreenState extends State<HomeScreen> {
  final authService = AuthService();
  final firestoreService = FirestoreService();
  late Future<_DashboardIdentity> dashboardIdentity;
  VehicleSimulator? simulator;
  int navIndex = 0;
  bool loggingOut = false;

  @override
  void initState() {
    super.initState();
    dashboardIdentity = _loadDashboardIdentity();
  }

  @override
  void dispose() {
    simulator?.stop();
    super.dispose();
  }

  Future<_DashboardIdentity> _loadDashboardIdentity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please log in to load your dashboard.');

    final profile = await firestoreService.getUserProfile(uid);
    final vehicleId = profile?.vehicleId;
    if (profile == null || vehicleId == null || vehicleId.isEmpty) {
      throw StateError(
        'Your Firestore user profile has no registered vehicle.',
      );
    }
    if (vehicleId != widget.vehicle.id) {
      throw StateError(
        'The selected vehicle does not match your Firestore profile.',
      );
    }

    // Refresh identity from Firestore instead of treating the route argument as authoritative.
    final vehicle = await firestoreService.getVehicleById(vehicleId);
    if (vehicle == null) {
      throw StateError(
        'Your registered vehicle is missing or inactive in Firestore.',
      );
    }

    simulator?.stop();
    final liveSimulator = VehicleSimulator(vehicleId: vehicle.id)..start();
    simulator = liveSimulator;
    return _DashboardIdentity(
      name: profile.name,
      vehicle: vehicle,
      simulator: liveSimulator,
    );
  }

  void retryLoadingIdentity() {
    setState(() => dashboardIdentity = _loadDashboardIdentity());
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> logout() async {
    if (loggingOut) return;
    setState(() => loggingOut = true);
    try {
      await authService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_DashboardIdentity>(
          future: dashboardIdentity,
          builder: (context, identitySnapshot) {
            if (identitySnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (identitySnapshot.hasError || !identitySnapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        identitySnapshot.error?.toString() ??
                            'Could not load your Firestore vehicle profile.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: retryLoadingIdentity,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final identity = identitySnapshot.data!;
            return StreamBuilder<VehicleData>(
              stream: identity.simulator.stream,
              builder: (context, telemetrySnapshot) {
                if (telemetrySnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load vehicle telemetry: ${telemetrySnapshot.error}',
                    ),
                  );
                }
                if (!telemetrySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = telemetrySnapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${greeting()}, ${identity.name} · ${identity.vehicle.model}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !loggingOut,
                          onSelected: (value) {
                            if (value == 'logout') logout();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'logout',
                              child: Text('Log out'),
                            ),
                          ],
                          icon: loggingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.more_vert),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${identity.vehicle.registrationNumber} · ${identity.vehicle.bluetoothDeviceName}',
                      style: const TextStyle(color: AppTheme.mutedBlue),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.electric_car,
                      size: 110,
                      color: AppTheme.blue,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: infoCard(
                            'Battery',
                            '${data.battery.toStringAsFixed(0)}%',
                            Icons.battery_std,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: infoCard(
                            'Range',
                            '${data.range.toStringAsFixed(0)} km',
                            Icons.route,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: data.healthScore / 100,
                              strokeWidth: 12,
                              color: AppTheme.blue,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${data.healthScore}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  const Text(
                                    'Health Score',
                                    style: TextStyle(color: AppTheme.mutedBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: infoCard(
                            'Battery Health',
                            '${data.batteryHealth.toStringAsFixed(1)}%',
                            Icons.favorite_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: infoCard(
                            'Charging',
                            data.isCharging ? 'Charging' : 'Not charging',
                            data.isCharging
                                ? Icons.battery_charging_full
                                : Icons.power_off,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        actionButton(
                          'Charging\nMap',
                          Icons.ev_station,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChargingStationPage(),
                            ),
                          ),
                        ),
                        actionButton(
                          'Trip\nPlanner',
                          Icons.map_outlined,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripPlannerPage(
                                battery: data.battery,
                                range: data.range,
                              ),
                            ),
                          ),
                        ),
                        actionButton(
                          'Vehicle\nHealth',
                          Icons.monitor_heart_outlined,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VehicleHealthPage(vehicle: identity.vehicle),
                            ),
                          ),
                        ),
                        actionButton(
                          'Mainte-\nnance',
                          Icons.build_outlined,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MaintenancePage(vehicle: identity.vehicle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (index) => setState(() => navIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.blue,
        unselectedItemColor: AppTheme.mutedBlue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station),
            label: 'Charging',
          ),
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
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.navy),
        ),
      ],
    );
  }
}
