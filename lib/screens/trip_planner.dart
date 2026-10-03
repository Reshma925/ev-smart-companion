import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/charging_station.dart';
import '../models/road_route.dart';
import '../models/trip_plan.dart';
import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';
import '../services/charging_station_service.dart';
import '../services/distance_unit_service.dart';
import '../services/ev_range_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/road_directions_service.dart';
import '../services/trip_feasibility_service.dart';
import '../services/trip_planning_service.dart';
import '../widgets/destination_autocomplete_field.dart';

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
  final FirestoreService _firestore = FirestoreService();
  final LocationService _locationService = LocationService();
  final TripFeasibilityService _feasibility = const TripFeasibilityService();
  final RoadDirectionsService _directions = RoadDirectionsService();
  final ChargingStationService _stations = ChargingStationService();
  late final TripPlanningService _planner = TripPlanningService(
    directions: _directions,
    stations: _stations,
    feasibility: _feasibility,
  );

  LatLng? _start;
  TripPlanningResult? _result;
  GeocodedDestination? _selectedDestination;
  String _destinationQuery = '';
  String? _errorMessage;
  String? _locationMessage;
  String? _locationError;
  String? _observedVehicleId;
  double? _observedBattery;
  bool _locating = false;
  bool _planning = false;
  int _requestGeneration = 0;
  double _safetyReserveFraction = 0.2;

  @override
  void dispose() {
    _directions.close();
    _stations.close();
    super.dispose();
  }

  void _invalidatePlan({String? message}) {
    _requestGeneration++;
    setState(() {
      _result = null;
      _errorMessage = null;
      _planning = false;
      if (message != null) _locationMessage = message;
    });
  }

  Future<void> _locateStart() async {
    final generation = ++_requestGeneration;
    setState(() {
      _locating = true;
      _locationMessage = 'Finding your current location…';
      _locationError = null;
      _result = null;
      _errorMessage = null;
    });
    final resolution = await _locationService.resolveCurrentLocation();
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _locating = false;
      _locationMessage = resolution.message;
      _locationError = resolution.locationAvailable ? null : resolution.message;
      _start = resolution.position;
    });
  }

  Future<void> _planTrip({
    required Vehicle vehicle,
    required VehicleData? telemetry,
  }) async {
    final selectedDestination = _selectedDestination;
    final destinationQuery =
        selectedDestination?.displayLabel ?? _destinationQuery.trim();
    final start = _start;
    final maximumRangeKm = vehicle.maximumRangeKm;
    final battery = telemetry?.battery;
    if (start == null) {
      setState(() => _errorMessage = 'Detect your current location first.');
      return;
    }
    if (destinationQuery.isEmpty) {
      setState(() => _errorMessage = 'Enter a destination to plan your trip.');
      return;
    }
    if (maximumRangeKm == null ||
        !maximumRangeKm.isFinite ||
        maximumRangeKm <= 0 ||
        battery == null ||
        !battery.isFinite ||
        battery < 0 ||
        battery > 100) {
      setState(() {
        _errorMessage =
            'A valid vehicle maximum range and live battery reading are required.';
      });
      return;
    }

    final generation = ++_requestGeneration;
    setState(() {
      _planning = true;
      _result = null;
      _errorMessage = null;
    });
    try {
      final vehicleState = _feasibility.createVehicleState(
        vehicleId: vehicle.id,
        vehicleModel: vehicle.model,
        maximumRangeKm: maximumRangeKm,
        batteryPercentage: battery,
        safetyReserveFraction: _safetyReserveFraction,
      );
      final request = TripPlanningRequest(
        start: start,
        destinationQuery: destinationQuery,
        vehicle: vehicleState,
        selectedDestination: selectedDestination,
        safetyReserveFraction: _safetyReserveFraction,
      );
      final result = await _planner.plan(request);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _result = result;
        _planning = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Trip planning failed: $error\n$stackTrace');
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _planning = false;
        _errorMessage =
            'Could not plan this trip. Check the destination and your network connection, then retry. ($error)';
      });
    }
  }

  Future<void> _changeVehicle(String uid, String vehicleId) async {
    _invalidatePlan(message: 'Vehicle changed. Plan the trip again.');
    try {
      await _firestore.setConnectedVehicle(uid: uid, vehicleId: vehicleId);
    } catch (error, stackTrace) {
      debugPrint(
        'Could not change the selected trip vehicle: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Could not select that vehicle. Please try again. ($error)',
      );
    }
  }

  Future<void> _openJourney(TripPlanningResult result) async {
    final coordinates = <LatLng>[
      result.start,
      ...result.selectedStops.map((station) => station.location),
      result.destination.location,
    ].map((point) => '${point.latitude},${point.longitude}').join(';');
    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': coordinates,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(
        () => _errorMessage = 'Could not open the route in OpenStreetMap.',
      );
    }
  }

  void _destinationChanged(String value) {
    final shouldRebuild =
        _result != null || _planning || _selectedDestination != null;
    _destinationQuery = value;
    _selectedDestination = null;
    _requestGeneration++;
    if (shouldRebuild) {
      setState(() {
        _result = null;
        _errorMessage = null;
        _planning = false;
      });
    }
  }

  void _destinationSelected(GeocodedDestination? place) {
    if (place == null) return;
    setState(() {
      _selectedDestination = place;
      _destinationQuery = place.displayLabel;
      _result = null;
      _errorMessage = null;
      _planning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Planner')),
        body: const Center(child: Text('Please sign in to plan a trip.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: StreamBuilder<List<Vehicle>>(
        stream: _firestore.watchLinkedVehicles(uid),
        builder: (context, vehiclesSnapshot) {
          if (vehiclesSnapshot.hasError) {
            return const Center(
              child: Text('Could not load your linked vehicles.'),
            );
          }
          final vehicles = vehiclesSnapshot.data;
          if (vehicles == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<Vehicle?>(
            stream: _firestore.watchConnectedVehicle(uid),
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.hasError) {
                return const Center(
                  child: Text('Could not load the selected vehicle.'),
                );
              }
              final vehicle = vehicleSnapshot.data;
              if (vehicle == null) {
                if (vehicleSnapshot.connectionState != ConnectionState.active) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const Center(
                  child: Text(
                    'Select an active vehicle before planning a trip.',
                  ),
                );
              }
              _observeVehicle(vehicle);
              return StreamBuilder<VehicleData?>(
                key: ValueKey(vehicle.id),
                stream: _firestore.watchVehicleTelemetry(vehicle.id),
                builder: (context, telemetrySnapshot) {
                  if (telemetrySnapshot.hasError) {
                    return const Center(
                      child: Text('Could not load live battery telemetry.'),
                    );
                  }
                  return _buildPlanner(
                    uid: uid,
                    vehicles: vehicles,
                    vehicle: vehicle,
                    telemetry: telemetrySnapshot.data,
                    telemetryLoading:
                        telemetrySnapshot.connectionState !=
                            ConnectionState.active &&
                        !telemetrySnapshot.hasData,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _observeVehicle(Vehicle vehicle) {
    final previousId = _observedVehicleId;
    if (previousId == vehicle.id) return;
    _observedVehicleId = vehicle.id;
    if (previousId != null) {
      _requestGeneration++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _result = null;
          _errorMessage = null;
          _planning = false;
          _locationMessage = 'Vehicle changed. Plan the trip again.';
        });
      });
    }
  }

  void _observeBattery(String vehicleId, double? battery) {
    if (_observedVehicleId != vehicleId) {
      _observedBattery = battery;
      return;
    }
    final previousBattery = _observedBattery;
    _observedBattery = battery;
    if (previousBattery == battery ||
        previousBattery == null ||
        battery == null) {
      return;
    }
    _requestGeneration++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorMessage = null;
        _planning = false;
        _locationMessage = 'Battery telemetry changed. Plan the trip again.';
      });
    });
  }

  Widget _buildPlanner({
    required String uid,
    required List<Vehicle> vehicles,
    required Vehicle vehicle,
    required VehicleData? telemetry,
    required bool telemetryLoading,
  }) {
    _observeBattery(vehicle.id, telemetry?.battery);
    final maximumRangeKm = vehicle.maximumRangeKm;
    final battery = telemetry?.battery;
    final availableRange =
        maximumRangeKm == null ||
            battery == null ||
            !maximumRangeKm.isFinite ||
            maximumRangeKm <= 0 ||
            !battery.isFinite ||
            battery < 0 ||
            battery > 100
        ? null
        : EvRangeService.calculateCurrentRangeKm(
            maximumRangeKm: maximumRangeKm,
            batteryPercentage: battery,
          );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _vehicleSelector(uid, vehicles, vehicle),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Current battery',
                battery == null
                    ? 'Unavailable'
                    : '${battery.toStringAsFixed(0)}%',
                Icons.battery_charging_full,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Available range',
                availableRange == null
                    ? 'Unavailable'
                    : DistanceUnitService.format(
                        availableRange,
                        widget.distanceUnit,
                        decimals: 0,
                      ),
                Icons.route,
              ),
            ),
          ],
        ),
        if (telemetryLoading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          )
        else if (battery == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Live battery telemetry is unavailable.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        _locationPicker(),
        const SizedBox(height: 12),
        DestinationAutocompleteField(
          searchPlaces: (query) => _directions.searchPlaces(
            query,
            proximity: _start,
          ),
          onQueryChanged: _destinationChanged,
          onPlaceSelected: _destinationSelected,
        ),
        const SizedBox(height: 15),
        Text(
          'Minimum safety reserve: ${(_safetyReserveFraction * 100).round()}%',
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        Slider(
          value: _safetyReserveFraction,
          min: 0.1,
          max: 0.4,
          divisions: 6,
          label: '${(_safetyReserveFraction * 100).round()}%',
          onChanged: (value) {
            _requestGeneration++;
            setState(() {
              _safetyReserveFraction = value;
              _result = null;
              _errorMessage = null;
              _planning = false;
            });
          },
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _planning || telemetryLoading
              ? null
              : () => _planTrip(vehicle: vehicle, telemetry: telemetry),
          icon: _planning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.alt_route),
          label: Text(_planning ? 'Planning route…' : 'Plan Trip'),
        ),
        if (_locationMessage != null || _locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _locationError ?? _locationMessage!,
              style: TextStyle(
                color: _locationError == null
                    ? AppTheme.mutedBlue
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (_errorMessage != null) _messageCard(_errorMessage!, isError: true),
        if (_result case final result?) ...[
          const SizedBox(height: 16),
          _resultView(result),
        ],
      ],
    );
  }

  Widget _vehicleSelector(String uid, List<Vehicle> vehicles, Vehicle current) {
    return DropdownButtonFormField<String>(
      key: ValueKey(current.id),
      initialValue: current.id,
      decoration: const InputDecoration(
        labelText: 'Planning vehicle',
        prefixIcon: Icon(Icons.electric_car),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final vehicle in vehicles)
          DropdownMenuItem(
            value: vehicle.id,
            child: Text('${vehicle.model} · ${vehicle.registrationNumber}'),
          ),
      ],
      onChanged: (value) {
        if (value != null && value != current.id) {
          _changeVehicle(uid, value);
        }
      },
    );
  }

  Widget _locationPicker() {
    return Card(
      child: ListTile(
        leading: Icon(
          _start == null ? Icons.location_searching : Icons.my_location,
          color: AppTheme.blue,
        ),
        title: Text(_start == null ? 'Starting location' : 'Current location'),
        subtitle: Text(
          _start == null
              ? 'Your location is used as the route origin.'
              : '${_start!.latitude.toStringAsFixed(5)}, '
                    '${_start!.longitude.toStringAsFixed(5)}',
        ),
        trailing: IconButton(
          tooltip: 'Detect current location',
          onPressed: _locating ? null : _locateStart,
          icon: _locating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        onTap: _locating ? null : _locateStart,
      ),
    );
  }

  Widget _resultView(TripPlanningResult result) {
    final route = result.route;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _messageCard(
          result.isFeasible
              ? 'A deterministic route and charging-stop sequence is within range.'
              : result.warnings.first,
          isError: !result.isFeasible,
        ),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(route.points),
                  padding: const EdgeInsets.all(28),
                ),
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.flutter_application_2',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.points,
                      strokeWidth: 4,
                      color: AppTheme.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: result.start,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    Marker(
                      point: result.destination.location,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    for (final station in result.liveStations)
                      Marker(
                        point: station.location,
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.ev_station,
                          color:
                              result.selectedStops.any(
                                (selected) => selected.id == station.id,
                              )
                              ? Colors.green.shade700
                              : AppTheme.mutedBlue,
                          size: 23,
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Road distance',
                DistanceUnitService.format(
                  route.distanceKm,
                  widget.distanceUnit,
                  decimals: 0,
                ),
                Icons.straighten,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Driving time',
                _durationLabel(route.duration),
                Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Live stations found along route: ${result.liveStations.length}',
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Available range ${DistanceUnitService.format(result.request.vehicle.availableRangeKm, widget.distanceUnit, decimals: 0)} · '
          'usable before first stop ${DistanceUnitService.format(result.request.vehicle.usableRangeKm, widget.distanceUnit, decimals: 0)} · '
          'reserve ${(_safetyReserveFraction * 100).round()}%',
          style: const TextStyle(color: AppTheme.mutedBlue),
        ),
        if (result.liveStations.isEmpty)
          _messageCard(
            'No live OpenStreetMap charging stations were found along this route.',
            isError: true,
          ),
        if (result.legs.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Range feasibility by leg',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final leg in result.legs)
            Card(
              child: ListTile(
                leading: Icon(
                  leg.isReachable ? Icons.check_circle : Icons.error,
                  color: leg.isReachable ? Colors.green : Colors.red,
                ),
                title: Text('${leg.from} → ${leg.to}'),
                subtitle: Text(
                  '${DistanceUnitService.format(leg.distanceKm, widget.distanceUnit, decimals: 0)} · '
                  '${leg.isReachable ? "reserve maintained" : "exceeds safe range"}',
                ),
                trailing: IconButton(
                  tooltip: 'Station diversion',
                  onPressed: null,
                  icon: const Icon(Icons.info_outline),
                ),
              ),
            ),
        ],
        if (result.selectedStops.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Suggested live charging stops',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (var index = 0; index < result.selectedStops.length; index++)
            _stationCard(
              index + 1,
              result.selectedStops[index],
              result.stationAssessments,
            ),
        ],
        for (final warning in result.warnings.skip(result.isFeasible ? 0 : 1))
          _messageCard(warning, isError: false),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openJourney(result),
          icon: const Icon(Icons.navigation),
          label: const Text('Open route in OpenStreetMap'),
        ),
      ],
    );
  }

  Widget _stationCard(
    int number,
    ChargingStation station,
    List<TripStationAssessment> assessments,
  ) {
    final assessment = assessments
        .where((item) => item.station.id == station.id)
        .firstOrNull;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text(station.name ?? 'Charging station'),
        subtitle: Text(
          '${station.operator ?? 'Operator unavailable'} · '
          '${DistanceUnitService.format(assessment?.routeProgressKm ?? 0, widget.distanceUnit, decimals: 0)} from start · '
          'diversion ${DistanceUnitService.format(station.distanceFromRouteKm ?? 0, widget.distanceUnit, decimals: 1)}',
        ),
        trailing: assessment == null
            ? null
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E0E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blue),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(color: AppTheme.mutedBlue)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(String text, {required bool isError}) {
    final color = isError ? Colors.red.shade700 : AppTheme.mutedBlue;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : const Color(0xFFF2F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }

  static String _durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return '$hours h $minutes min';
  }
}
