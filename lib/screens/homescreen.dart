import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/distance_unit_service.dart';
import '../services/firestore_service.dart';
import '../services/weather_service.dart';
import '../widgets/weather_card.dart';
import 'charging_station_page.dart';
import 'maintenance.dart';
import 'learn_screen.dart';
import 'profile_page.dart';
import '../services/learning_assistant_service.dart';
import 'trip_planner.dart';
import 'vehicle_health_page.dart';
import 'vehicle_details_page.dart';
import 'vehicle_controls_page.dart';

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
    required this.telemetry,
  });

  final String name;
  final Vehicle vehicle;
  final Stream<VehicleData?> telemetry;
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final WeatherService weatherService = WeatherService();
  late Future<_DashboardIdentity> dashboardIdentity;
  StreamSubscription<Vehicle?>? _vehicleSubscription;
  Vehicle? _latestVehicle;
  String? _vehicleStreamError;
  String _distanceUnit = 'km';
  int navIndex = 0;

  @override
  void initState() {
    super.initState();
    dashboardIdentity = _loadDashboardIdentity();
    _loadDistanceUnitPreference();
  }

  Future<void> _loadDistanceUnitPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await firestoreService.getUserProfile(uid);
      if (!mounted) return;
      setState(() {
        _distanceUnit = DistanceUnitService.normalize(profile?.distanceUnit);
      });
    } catch (_) {
      // Keep the kilometre default if the preference cannot be loaded.
    }
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    weatherService.dispose();
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

    // Re-read authoritative identity from Firestore each time the dashboard opens.
    final vehicle = await firestoreService.getVehicleById(vehicleId);
    if (vehicle == null) {
      throw StateError(
        'Your registered vehicle is missing or inactive in Firestore.',
      );
    }
    await _vehicleSubscription?.cancel();
    _latestVehicle = vehicle;
    _vehicleStreamError = null;
    _vehicleSubscription = firestoreService
        .watchVehicleById(vehicleId)
        .listen(
          (updatedVehicle) {
            if (!mounted) return;
            if (updatedVehicle == null) {
              setState(
                () => _vehicleStreamError =
                    'The registered vehicle is no longer available in Firestore.',
              );
              return;
            }
            setState(() {
              _latestVehicle = updatedVehicle;
              _vehicleStreamError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(
              () => _vehicleStreamError =
                  'Could not refresh vehicle data from Firestore: $error',
            );
          },
        );

    return _DashboardIdentity(
      name: profile.name,
      vehicle: vehicle,
      telemetry: firestoreService.watchVehicleTelemetry(vehicle.id),
    );
  }

  void retryLoadingIdentity() {
    setState(() => dashboardIdentity = _loadDashboardIdentity());
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void openChargingMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChargingStationPage()),
    );
  }

  Future<void> openProfile() async {
    setState(() => navIndex = 3);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    if (mounted) {
      setState(() => navIndex = 0);
      _loadDistanceUnitPreference();
    }
  }

  Future<void> openLearn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => navIndex = 2);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearnScreen(
          vehicleStream: firestoreService.watchConnectedVehicle(uid),
          telemetryStreamFor: firestoreService.watchVehicleTelemetry,
          assistant: FirebaseLearningAssistantService(),
          distanceUnit: _distanceUnit,
        ),
      ),
    );
    if (mounted) setState(() => navIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: FutureBuilder<_DashboardIdentity>(
          future: dashboardIdentity,
          builder: (context, identitySnapshot) {
            if (identitySnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (identitySnapshot.hasError || !identitySnapshot.hasData) {
              return _LoadError(
                message:
                    identitySnapshot.error?.toString() ??
                    'Could not load your Firestore vehicle profile.',
                onRetry: retryLoadingIdentity,
              );
            }

            final identity = identitySnapshot.data!;
            if (_vehicleStreamError != null) {
              return _LoadError(
                message: _vehicleStreamError!,
                onRetry: retryLoadingIdentity,
              );
            }
            final vehicle = _latestVehicle ?? identity.vehicle;
            return StreamBuilder<VehicleData?>(
              stream: identity.telemetry,
              builder: (context, telemetrySnapshot) {
                if (telemetrySnapshot.hasError) {
                  return _LoadError(
                    message:
                        'Could not load vehicle telemetry: ${telemetrySnapshot.error}',
                    onRetry: retryLoadingIdentity,
                  );
                }
                if (!telemetrySnapshot.hasData) {
                  if (telemetrySnapshot.connectionState ==
                      ConnectionState.active) {
                    return _LoadError(
                      message:
                          'No live vehicle telemetry is currently available in Firestore.',
                      onRetry: retryLoadingIdentity,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final data = telemetrySnapshot.data!;
                    final contentWidth = wide ? 1160.0 : 760.0;
                    final batterySection = _BatteryPanel(
                      data: data,
                      distanceUnit: _distanceUnit,
                    );
                    final weatherSection = WeatherCard(
                      service: weatherService,
                      distanceUnit: _distanceUnit,
                    );
                    final summary = _VehicleHealthSummary(data: data);
                    final actions = _QuickActions(
                      onControls: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VehicleControlsPage(vehicle: vehicle),
                        ),
                      ),
                      onTripPlanner: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripPlannerPage(
                            vehicleId: vehicle.id,
                            onConfigureVehicle: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VehicleDetailsPage(vehicle: vehicle),
                              ),
                            ),
                            distanceUnit: _distanceUnit,
                          ),
                        ),
                      ),
                      onHealth: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VehicleHealthPage(vehicle: vehicle),
                        ),
                      ),
                      onMaintenance: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaintenancePage(vehicle: vehicle),
                        ),
                      ),
                    );

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                wide ? 32 : 20,
                                16,
                                wide ? 32 : 20,
                                28,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _DashboardHeader(
                                    greeting: greeting(),
                                    name: identity.name,
                                    onProfile: openProfile,
                                  ),
                                  const SizedBox(height: 22),
                                  _VehicleHero(vehicle: vehicle, data: data),
                                  const SizedBox(height: 18),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: batterySection),
                                        const SizedBox(width: 16),
                                        Expanded(child: weatherSection),
                                      ],
                                    )
                                  else ...[
                                    batterySection,
                                    const SizedBox(height: 14),
                                    weatherSection,
                                  ],
                                  const SizedBox(height: 16),
                                  summary,
                                  const SizedBox(height: 24),
                                  _SectionHeading(
                                    eyebrow: 'AT A GLANCE',
                                    title: 'Your next move',
                                  ),
                                  const SizedBox(height: 12),
                                  actions,
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (index) {
          if (index == 3) {
            openProfile();
          } else {
            setState(() => navIndex = index);
            if (index == 1) openChargingMap();
            if (index == 2) openLearn();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.blue,
        unselectedItemColor: AppTheme.mutedBlue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station_rounded),
            label: 'Charging',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.name,
    required this.onProfile,
  });

  final String greeting;
  final String name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.bolt_rounded, color: Color(0xFF71D6C0)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EV SMART COMPANION',
              style: TextStyle(
                color: AppTheme.mutedBlue,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$greeting, ${name.split(' ').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Open profile',
        onPressed: onProfile,
        icon: const CircleAvatar(
          radius: 21,
          backgroundColor: Colors.white,
          child: Icon(Icons.person_outline_rounded, color: AppTheme.navy),
        ),
      ),
    ],
  );
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle, required this.data});

  final Vehicle vehicle;
  final VehicleData data;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 21),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF101F34), Color(0xFF183A51), Color(0xFF12665F)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24101F34),
          blurRadius: 22,
          offset: Offset(0, 11),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -22,
          top: -54,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
                width: 24,
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD7A7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 7,
                          color: Color(0xFF55E0AF),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          data.battery <= 20
                              ? 'LOW BATTERY'
                              : data.isCharging
                              ? 'CHARGING'
                              : 'VEHICLE LINKED',
                          style: const TextStyle(
                            color: Color(0xFFB3F2D9),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    vehicle.model,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    vehicle.registrationNumber,
                    style: const TextStyle(
                      color: Color(0xFFBDD0DD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (vehicle.bluetoothDeviceName.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_rounded,
                          size: 16,
                          color: Color(0xFF73D9D0),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            vehicle.bluetoothDeviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD0E2E8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Preview',
                          style: TextStyle(
                            color: Color(0xFFB5C4CC),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.electric_car_rounded,
              size: 86,
              color: Color(0xFF7BDCC8),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BatteryPanel extends StatelessWidget {
  const _BatteryPanel({required this.data, required this.distanceUnit});

  final VehicleData data;
  final String distanceUnit;

  @override
  Widget build(BuildContext context) {
    final battery = (data.battery / 100).clamp(0.0, 1.0);
    final displayRange = DistanceUnitService.format(
      data.range,
      distanceUnit,
      decimals: 0,
    );
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C172A3B),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(eyebrow: 'ENERGY', title: 'Driving range'),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: battery),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE9EEF2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            data.battery <= 20
                                ? const Color(0xFFE7A647)
                                : const Color(0xFF28A985),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.battery.round()}%',
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'BATTERY',
                          style: TextStyle(
                            color: AppTheme.mutedBlue,
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayRange.split(' ').first,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 39,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DistanceUnitService.normalize(distanceUnit) == DistanceUnitService.mi ? 'mi' : 'km'} estimated range',
                      style: const TextStyle(
                        color: AppTheme.mutedBlue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ChargeBadge(isCharging: data.isCharging),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: battery,
              minHeight: 6,
              backgroundColor: const Color(0xFFE9EEF2),
              valueColor: AlwaysStoppedAnimation<Color>(
                data.battery <= 20
                    ? const Color(0xFFE7A647)
                    : const Color(0xFF28A985),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeBadge extends StatelessWidget {
  const _ChargeBadge({required this.isCharging});

  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    final color = isCharging
        ? const Color(0xFF197B69)
        : const Color(0xFF526477);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isCharging ? const Color(0xFFE6F6EF) : const Color(0xFFF0F3F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCharging ? Icons.bolt_rounded : Icons.power_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isCharging ? 'Charging now' : 'Not charging',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleHealthSummary extends StatelessWidget {
  const _VehicleHealthSummary({required this.data});

  final VehicleData data;

  @override
  Widget build(BuildContext context) {
    final scoreColor = data.healthScore >= 80
        ? const Color(0xFF21896D)
        : data.healthScore >= 60
        ? const Color(0xFFD38A2F)
        : const Color(0xFFC95454);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final content = [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (data.healthScore / 100).clamp(0.0, 1.0),
                          strokeWidth: 4,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                        Text(
                          '${data.healthScore}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Vehicle health',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _SummaryMetric(
              label: 'BATTERY HEALTH',
              value: '${data.batteryHealth.toStringAsFixed(1)}%',
              icon: Icons.favorite_outline,
            ),
            _SummaryMetric(
              label: 'STATUS',
              value: data.isCharging ? 'Charging' : 'Ready',
              icon: data.isCharging
                  ? Icons.bolt_rounded
                  : Icons.check_circle_outline,
            ),
          ];
          if (compact) {
            return Column(
              children: [
                Row(children: [content[0]]),
                const Divider(height: 24),
                Row(
                  children: [content[1], const SizedBox(width: 12), content[2]],
                ),
              ],
            );
          }
          return Row(
            children: [
              content[0],
              const _SummaryDivider(),
              content[1],
              const _SummaryDivider(),
              content[2],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF318B72)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.mutedBlue,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: const Color(0xFFD1E5DC),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onControls,
    required this.onTripPlanner,
    required this.onHealth,
    required this.onMaintenance,
  });

  final VoidCallback onControls;
  final VoidCallback onTripPlanner;
  final VoidCallback onHealth;
  final VoidCallback onMaintenance;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 4 : 2;
      final actions = [
        _ActionItem(
          'Controls',
          'Manage your EV',
          Icons.tune_rounded,
          const Color(0xFFE4F3ED),
          const Color(0xFF168266),
          onControls,
        ),
        _ActionItem(
          'Trip planner',
          'Plan your route',
          Icons.alt_route_rounded,
          const Color(0xFFE9EFFB),
          const Color(0xFF416FC0),
          onTripPlanner,
        ),
        _ActionItem(
          'Vehicle health',
          'Check diagnostics',
          Icons.monitor_heart_outlined,
          const Color(0xFFF2ECFB),
          const Color(0xFF8055B5),
          onHealth,
        ),
        _ActionItem(
          'Maintenance',
          'Service schedule',
          Icons.build_circle_outlined,
          const Color(0xFFFFF1E2),
          const Color(0xFFCC8128),
          onMaintenance,
        ),
      ];
      final spacing = 10.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final action in actions)
            SizedBox(
              width: width,
              child: _ActionTile(action: action),
            ),
        ],
      );
    },
  );
}

class _ActionItem {
  const _ActionItem(
    this.title,
    this.subtitle,
    this.icon,
    this.tint,
    this.color,
    this.onTap,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color color;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _ActionItem action;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(action.icon, color: action.color, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.mutedBlue,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppTheme.mutedBlue,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppTheme.mutedBlue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: AppTheme.mutedBlue,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
