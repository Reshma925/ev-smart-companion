import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/charging_station.dart';
import '../models/road_route.dart';
import '../models/user_model.dart';
import '../models/vehicle.dart';
import '../services/charging_station_service.dart';
import '../services/distance_unit_service.dart';
import '../services/ev_range_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/road_directions_service.dart';
import '../widgets/charging_card_section.dart';
import 'vehicle_details_page.dart';

class ChargingStationPage extends StatefulWidget {
  const ChargingStationPage({super.key});

  @override
  State<ChargingStationPage> createState() => _ChargingStationPageState();
}

class _ChargingStationPageState extends State<ChargingStationPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final ChargingStationService _chargingService = ChargingStationService();
  final RoadDirectionsService _directionsService = RoadDirectionsService();
  final MapController _mapController = MapController();
  final TextEditingController _stationSearchController =
      TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  StreamSubscription<double?>? _telemetrySubscription;
  StreamSubscription<Vehicle?>? _vehicleSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;
  Vehicle? _vehicle;
  RoadRoute? _activeRoute;
  LatLng? _userLocation;
  List<ChargingStation> _stations = const [];
  String _distanceUnit = DistanceUnitService.km;
  String? _locationMessage;
  String? _vehicleMessage;
  String? _batterySourceNotice;
  String? _stationMessage;
  String? _destinationMessage;
  String? _selectedStationId;
  double? _batteryPercentage;
  double? _maximumRangeKm;
  double _zoom = 14;
  bool _loadingLocation = true;
  bool _loadingVehicle = true;
  bool _loadingTelemetry = true;
  bool _loadingStations = false;
  bool _permanentlyDenied = false;
  bool _hasSearched = false;
  bool _mapReady = false;
  bool _fastChargingOnly = false;
  bool _loadingRoute = false;
  bool _hasLiveBatteryTelemetry = false;
  bool _routeSearchMode = false;
  int _searchGeneration = 0;

  double? get _estimatedRangeKm {
    final maximumRange = _maximumRangeKm;
    final battery = _batteryPercentage;
    if (maximumRange == null ||
        battery == null ||
        maximumRange <= 0 ||
        !maximumRange.isFinite ||
        !battery.isFinite ||
        battery < 0 ||
        battery > 100) {
      return null;
    }
    return EvRangeService.calculateCurrentRangeKm(
      maximumRangeKm: maximumRange,
      batteryPercentage: battery,
    );
  }

  double? get _usableRangeKm {
    final range = _estimatedRangeKm;
    return range == null
        ? null
        : EvRangeService.calculateUsableRange(estimatedRangeKm: range);
  }

  double? get _searchRadiusKm => _estimatedRangeKm;

  bool get _canSearch => !_loadingStations && !_loadingRoute;

  List<ChargingStation> get _inRangeStations {
    final rangeKm = _searchRadiusKm;
    if (rangeKm == null) return const [];
    return _stations
        .where((station) => station.distanceKm <= rangeKm)
        .toList(growable: false);
  }

  List<ChargingStation> get _visibleStations {
    final query = _stationSearchController.text.trim().toLowerCase();
    return _inRangeStations
        .where((station) {
          if (_fastChargingOnly && !station.isFastCharging) return false;
          if (query.isEmpty) return true;
          final searchable = [
            station.name,
            station.operator,
            station.address,
            ...station.connectors,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _locateUser();
    _loadVehicle();
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _vehicleSubscription?.cancel();
    _profileSubscription?.cancel();
    _chargingService.close();
    _directionsService.close();
    _stationSearchController.dispose();
    _destinationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    if (!mounted) return;
    final subscription = _telemetrySubscription;
    final vehicleSubscription = _vehicleSubscription;
    final profileSubscription = _profileSubscription;
    _telemetrySubscription = null;
    _vehicleSubscription = null;
    _profileSubscription = null;
    await subscription?.cancel();
    await vehicleSubscription?.cancel();
    await profileSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _loadingVehicle = true;
      _maximumRangeKm = null;
      _batteryPercentage = null;
      _hasLiveBatteryTelemetry = false;
      _batterySourceNotice = null;
      _vehicle = null;
      _vehicleMessage = null;
      _loadingTelemetry = true;
      _stations = const [];
      _selectedStationId = null;
      _hasSearched = false;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('Sign in to load your registered vehicle telemetry.');
      }

      final profile = await _firestoreService.getUserProfile(uid);
      final vehicleId = profile?.vehicleId;
      if (profile == null || vehicleId == null || vehicleId.isEmpty) {
        throw StateError('Your Firestore profile has no linked vehicle.');
      }

      final vehicle = await _firestoreService.getVehicleById(vehicleId);
      if (vehicle == null) {
        throw StateError('Your registered vehicle could not be loaded.');
      }
      if (!mounted) return;
      setState(() {
        _vehicle = vehicle;
        _maximumRangeKm = _validMaximumRange(vehicle.maximumRangeKm);
        _batteryPercentage = _validBattery(vehicle.batteryPercentage);
        _batterySourceNotice = _batteryPercentage == null
            ? null
            : 'Using batteryPercentage from vehicles/${vehicle.id}; live telemetry has not arrived yet.';
        _loadingTelemetry = _batteryPercentage == null;
        _distanceUnit = DistanceUnitService.normalize(profile.distanceUnit);
        _loadingVehicle = false;
        _updateRangeMessages();
      });

      _telemetrySubscription = _firestoreService
          .watchVehicleBatteryPercentage(vehicle.id)
          .listen(
            _onBatteryPercentage,
            onError: (Object error) {
              debugPrint('Vehicle telemetry stream failed: $error');
              if (!mounted) return;
              final previousRange = _searchRadiusKm;
              final fallback = _validBattery(_vehicle?.batteryPercentage);
              setState(() {
                _loadingTelemetry = false;
                _hasLiveBatteryTelemetry = false;
                _batteryPercentage = fallback;
                _batterySourceNotice = fallback == null
                    ? null
                    : 'Live battery telemetry could not be read; using the stored batteryPercentage in vehicles/${_vehicle!.id}.';
                _updateRangeMessages();
              });
              _invalidateSearchResultsIfRangeChanged(previousRange);
            },
          );
      _vehicleSubscription = _firestoreService
          .watchVehicleById(vehicle.id)
          .listen(
            _onVehicleUpdated,
            onError: (Object error) {
              debugPrint('Vehicle configuration stream failed: $error');
              if (!mounted) return;
              setState(() {
                _vehicleMessage =
                    'Could not refresh vehicles/${_vehicle?.id ?? 'linked vehicle'} from Firebase. Check your connection and retry.';
              });
            },
          );
      _profileSubscription = _firestoreService
          .watchUserProfile(uid)
          .listen(
            (updatedProfile) {
              if (!mounted || updatedProfile == null) return;
              setState(() {
                _distanceUnit = DistanceUnitService.normalize(
                  updatedProfile.distanceUnit,
                );
              });
            },
            onError: (Object error) {
              debugPrint('Distance preference stream failed: $error');
              if (!mounted) return;
              setState(() {
                _vehicleMessage =
                    'Could not refresh your distance preference from Firebase.';
              });
            },
          );
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load the registered Firebase vehicle: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _loadingVehicle = false;
        _loadingTelemetry = false;
        _vehicleMessage = error is StateError
            ? error.message.toString()
            : 'Could not load vehicle data from Firebase. Check your connection and retry.';
      });
    }
  }

  void _onVehicleUpdated(Vehicle? vehicle) {
    if (!mounted) return;
    if (vehicle == null) {
      _searchGeneration++;
      setState(() {
        _vehicle = null;
        _maximumRangeKm = null;
        _stations = const [];
        _selectedStationId = null;
        _hasSearched = false;
        _vehicleMessage = 'Your registered vehicle is no longer available.';
      });
      return;
    }

    final oldRange = _searchRadiusKm;
    setState(() {
      _vehicle = vehicle;
      _maximumRangeKm = _validMaximumRange(vehicle.maximumRangeKm);
      if (!_hasLiveBatteryTelemetry) {
        _batteryPercentage = _validBattery(vehicle.batteryPercentage);
        _batterySourceNotice = _batteryPercentage == null
            ? null
            : 'Using batteryPercentage from vehicles/${vehicle.id}; live telemetry is unavailable.';
      }
      _updateRangeMessages();
    });
    final updatedRange = _searchRadiusKm;
    if (updatedRange != null && updatedRange != oldRange && _mapReady) {
      _fitRange(updatedRange);
    }
    _invalidateSearchResultsIfRangeChanged(oldRange);
  }

  void _onBatteryPercentage(double? batteryPercentage) {
    if (!mounted) return;
    final oldRange = _searchRadiusKm;
    if (batteryPercentage == null) {
      final fallback = _validBattery(_vehicle?.batteryPercentage);
      setState(() {
        _loadingTelemetry = false;
        _hasLiveBatteryTelemetry = false;
        _batteryPercentage = fallback;
        _batterySourceNotice = fallback == null
            ? null
            : 'Live battery telemetry is missing; using the stored batteryPercentage in vehicles/${_vehicle!.id}.';
        _updateRangeMessages();
      });
      _invalidateSearchResultsIfRangeChanged(oldRange);
      return;
    }

    if (!batteryPercentage.isFinite ||
        batteryPercentage < 0 ||
        batteryPercentage > 100) {
      setState(() {
        _loadingTelemetry = false;
        _hasLiveBatteryTelemetry = false;
        _batteryPercentage = null;
        _batterySourceNotice = null;
        _vehicleMessage =
            'Invalid battery percentage in vehicles/${_vehicle?.id ?? 'unknown vehicle'}/telemetry/live.battery or batteryPercentage. Expected a number from 0 to 100.';
      });
      _invalidateSearchResultsIfRangeChanged(oldRange);
      return;
    }

    setState(() {
      _batteryPercentage = batteryPercentage;
      _loadingTelemetry = false;
      _hasLiveBatteryTelemetry = true;
      _batterySourceNotice = null;
      _updateRangeMessages();
    });
    final range = _searchRadiusKm;
    if (range != null && range != oldRange && _mapReady) {
      _fitRange(range);
    }
    _invalidateSearchResultsIfRangeChanged(oldRange);
  }

  static double? _validMaximumRange(double? rangeKm) =>
      rangeKm != null && rangeKm.isFinite && rangeKm > 0 ? rangeKm : null;

  static double? _validBattery(double? battery) =>
      battery != null && battery.isFinite && battery >= 0 && battery <= 100
      ? battery
      : null;

  void _updateRangeMessages() {
    final vehicleId = _vehicle?.id;
    if (vehicleId == null) {
      _vehicleMessage ??= 'No registered vehicle is linked to this account.';
      return;
    }

    final missing = <String>[];
    if (_maximumRangeKm == null) {
      missing.add(
        'Maximum range is missing at vehicles/$vehicleId.maximumRangeKm (also checked maxRangeKm, estimatedRangeKm, estimatedRange and range). Open Vehicle Details to configure a known rated range.',
      );
    }
    if (_batteryPercentage == null) {
      missing.add(
        'Battery is missing at vehicles/$vehicleId/telemetry/live.battery or batteryPercentage, and vehicles/$vehicleId.batteryPercentage or battery.',
      );
    }
    _vehicleMessage = missing.isEmpty ? null : missing.join(' ');
  }

  void _invalidateSearchResultsIfRangeChanged(double? previousRangeKm) {
    if (!_hasSearched) return;
    final currentRangeKm = _searchRadiusKm;
    final rangeChanged =
        previousRangeKm == null ||
        currentRangeKm == null ||
        (currentRangeKm - previousRangeKm).abs() >= 0.5;
    if (!rangeChanged) return;
    _invalidateSearchResults(
      'Vehicle range changed. Search again for updated stations.',
    );
  }

  void _invalidateSearchResults(String message, {bool clearRoute = false}) {
    if (!_hasSearched && !(clearRoute && _activeRoute != null)) return;
    _searchGeneration++;
    setState(() {
      _stations = const [];
      _selectedStationId = null;
      _hasSearched = false;
      _stationMessage = message;
      if (clearRoute) {
        _activeRoute = null;
        _routeSearchMode = false;
      }
    });
  }

  Future<void> _locateUser() async {
    if (!mounted) return;
    setState(() {
      _loadingLocation = true;
      _locationMessage = null;
    });

    try {
      final resolution = await _locationService.resolveCurrentLocation();
      if (!mounted) return;
      final position = resolution.position;
      if (position == null) {
        setState(() {
          _loadingLocation = false;
          _locationMessage = resolution.message;
          _permanentlyDenied = resolution.permanentlyDenied;
        });
        return;
      }

      final previousLocation = _userLocation;
      setState(() {
        _userLocation = position;
        _loadingLocation = false;
        _locationMessage = null;
        _permanentlyDenied = false;
      });
      if (previousLocation != null && _mapReady) {
        _mapController.move(position, _zoom);
        final movedKm = const Distance().as(
          LengthUnit.Kilometer,
          previousLocation,
          position,
        );
        if (movedKm >= 0.5) {
          _invalidateSearchResults(
            'Your location changed. Search again for nearby stations.',
            clearRoute: true,
          );
        }
      }
      final range = _searchRadiusKm;
      if (range != null && _mapReady && !_hasSearched) _fitRange(range);
    } catch (error, stackTrace) {
      debugPrint('Could not determine current location: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationMessage =
            'Unable to detect your location. Check location settings and retry.';
        _permanentlyDenied = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_routeSearchMode) {
      await _findStationsAlongDestinationRoute();
    } else {
      await _findChargingStations();
    }
  }

  Future<void> _openChargingCard() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage('Sign in to view your charging card.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: ChargingCardSection(
          uid: uid,
          firestoreService: _firestoreService,
        ),
      ),
    );
  }

  Future<void> _retryCurrentSearch() async {
    if (_routeSearchMode) {
      await _findStationsAlongDestinationRoute();
    } else {
      await _findChargingStations();
    }
  }

  Future<void> _reloadVehicleDataFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to load vehicle information.');
    }
    final profile = await _firestoreService.getUserProfile(uid);
    final vehicleId = profile?.vehicleId;
    if (profile == null || vehicleId == null || vehicleId.isEmpty) {
      throw StateError('No vehicle is linked to this Firebase profile.');
    }
    final vehicle = await _firestoreService.getVehicleById(vehicleId);
    if (vehicle == null) {
      throw StateError('The linked vehicle document is missing or inactive.');
    }
    final liveBattery = await _firestoreService.getVehicleBatteryPercentage(
      vehicle.id,
    );
    final validLiveBattery = _validBattery(liveBattery);
    final storedBattery = _validBattery(vehicle.batteryPercentage);
    final resolvedBattery = liveBattery == null
        ? storedBattery
        : validLiveBattery;
    if (!mounted) return;
    final previousRange = _searchRadiusKm;
    setState(() {
      _vehicle = vehicle;
      _maximumRangeKm = _validMaximumRange(vehicle.maximumRangeKm);
      _batteryPercentage = resolvedBattery;
      _hasLiveBatteryTelemetry = liveBattery != null;
      _batterySourceNotice = liveBattery == null && storedBattery != null
          ? 'Live telemetry is absent; using the saved battery value from vehicles/${vehicle.id}.batteryPercentage.'
          : null;
      _distanceUnit = DistanceUnitService.normalize(profile.distanceUnit);
      _loadingVehicle = false;
      _loadingTelemetry = false;
      _updateRangeMessages();
      if (liveBattery != null && validLiveBattery == null) {
        _vehicleMessage =
            'Invalid battery percentage in vehicles/${vehicle.id}/telemetry/live.battery or batteryPercentage. Expected a number from 0 to 100.';
      }
    });
    _invalidateSearchResultsIfRangeChanged(previousRange);
  }

  Future<void> _findChargingStations() async {
    if (_loadingStations || _loadingRoute) return;
    setState(() {
      _loadingStations = true;
      _stationMessage = null;
    });
    try {
      await _locateUser();
      if (!mounted) return;
      if (_userLocation == null || _locationMessage != null) {
        setState(() {
          _loadingStations = false;
          _stationMessage =
              'Your current GPS location is unavailable. Retry location access, then search again.';
        });
        return;
      }
      await _reloadVehicleDataFromFirestore();
      if (!mounted) return;
      final location = _userLocation!;
      final rangeKm = _searchRadiusKm;
      if (rangeKm == null) {
        setState(() {
          _loadingStations = false;
          _stationMessage =
              _vehicleMessage ?? 'Firebase vehicle range data is unavailable.';
        });
        return;
      }
      if (rangeKm <= 0) {
        setState(() {
          _loadingStations = false;
          _stationMessage =
              'The current battery level provides no usable search radius. Charge the vehicle before searching.';
        });
        return;
      }

      final generation = ++_searchGeneration;
      final stations = await _chargingService.findNearbyStations(
        center: location,
        radiusKm: rangeKm,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _stations = stations;
        _loadingStations = false;
        _hasSearched = true;
        _selectedStationId = null;
        _activeRoute = null;
        _routeSearchMode = false;
        _destinationMessage = null;
      });
      _fitRange(rangeKm);
    } catch (error, stackTrace) {
      debugPrint('Nearby charging-station search failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadingStations = false;
        _hasSearched = true;
        _stationMessage = error is StateError
            ? error.message.toString()
            : error is FirebaseException
            ? 'Could not refresh your vehicle or telemetry from Firebase. Check your connection and retry.'
            : 'Charging-station data is temporarily unavailable. Check your connection and try again.';
      });
    }
  }

  Future<void> _findStationsAlongDestinationRoute() async {
    if (_loadingRoute || _loadingStations) return;
    final query = _destinationController.text.trim();
    if (query.isEmpty) {
      setState(
        () => _destinationMessage = 'Please select a valid destination.',
      );
      return;
    }

    setState(() {
      _loadingRoute = true;
      _destinationMessage = null;
    });
    await _locateUser();
    if (!mounted) return;
    final origin = _userLocation;
    if (origin == null || _locationMessage != null) {
      setState(() {
        _loadingRoute = false;
        _destinationMessage =
            'Your current location is unavailable. Retry location access.';
      });
      return;
    }
    try {
      await _reloadVehicleDataFromFirestore();
    } catch (error, stackTrace) {
      debugPrint(
        'Could not refresh vehicle data for route search: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _loadingRoute = false;
        _destinationMessage = error is StateError
            ? error.message.toString()
            : 'Could not refresh vehicle data from Firebase. Retry the route search.';
      });
      return;
    }
    if (!mounted) return;
    final usableRangeKm = _usableRangeKm;
    if (usableRangeKm == null || usableRangeKm <= 0) {
      setState(() {
        _loadingRoute = false;
        _destinationMessage =
            _vehicleMessage ??
            'The current battery level provides no usable route-search radius.';
      });
      return;
    }

    final generation = ++_searchGeneration;
    setState(() {
      _loadingStations = true;
      _destinationMessage = null;
      _stationMessage = null;
      _activeRoute = null;
      _routeSearchMode = false;
    });
    try {
      final destination = await _directionsService.geocode(query);
      final route = await _directionsService.route(
        origin: origin,
        destination: destination,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _activeRoute = route;
        _routeSearchMode = true;
        _loadingRoute = false;
        _destinationMessage = route.distanceKm > usableRangeKm
            ? 'The destination is beyond the current usable range. Plan charging stops before relying on this route.'
            : null;
      });
      final stations = await _chargingService.findAlongRoute(
        origin: origin,
        routePoints: route.points,
        searchRadiusKm: usableRangeKm,
      );
      if (!mounted || generation != _searchGeneration) return;
      final inRangeStations =
          stations
              .where((station) => station.distanceKm <= usableRangeKm)
              .toList()
            ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      setState(() {
        _stations = List.unmodifiable(inRangeStations);
        _loadingStations = false;
        _hasSearched = true;
        _selectedStationId = null;
      });
      if (_mapReady) {
        _zoom = 7.5;
        _mapController.move(
          LatLng(
            (origin.latitude + destination.location.latitude) / 2,
            (origin.longitude + destination.location.longitude) / 2,
          ),
          _zoom,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Route charging-station search failed: $error\n$stackTrace');
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _loadingRoute = false;
        _loadingStations = false;
        _hasSearched = true;
        _routeSearchMode = true;
        _destinationMessage = error is FormatException
            ? 'Please select a valid destination.'
            : error is RoadDirectionsException
            ? error.message
            : 'Unable to calculate the route or load stations. Check your connection and retry.';
      });
    }
  }

  Future<RoadRoute?> _showRouteToStation(ChargingStation station) async {
    final origin = _userLocation;
    if (origin == null) {
      _showMessage(
        'Your current location is unavailable. Retry location access.',
      );
      return null;
    }
    final destination = GeocodedDestination(
      name: station.name ?? 'Charging station',
      address: station.address ?? station.name ?? 'Charging station',
      location: station.location,
    );
    setState(() {
      _loadingRoute = true;
      _destinationMessage = null;
    });
    try {
      final route = await _directionsService.route(
        origin: origin,
        destination: destination,
      );
      if (!mounted) return null;
      setState(() {
        _activeRoute = route;
        _routeSearchMode = false;
        _loadingRoute = false;
      });
      if (_mapReady) {
        _zoom = 9;
        _mapController.move(
          LatLng(
            (origin.latitude + station.location.latitude) / 2,
            (origin.longitude + station.location.longitude) / 2,
          ),
          _zoom,
        );
      }
      return route;
    } catch (error, stackTrace) {
      debugPrint(
        'Could not route to charging station ${station.id}: $error\n$stackTrace',
      );
      if (!mounted) return null;
      setState(() => _loadingRoute = false);
      _showMessage(
        error is RoadDirectionsException
            ? error.message
            : 'Could not calculate directions. Please try again.',
      );
      return null;
    }
  }

  void _fitRange(double rangeKm) {
    if (!_mapReady || _userLocation == null || rangeKm <= 0) return;
    final nextZoom = (math.log(40075 / (2 * rangeKm)) / math.ln2)
        .clamp(4.5, 15.0)
        .toDouble();
    _zoom = nextZoom;
    _mapController.move(_userLocation!, nextZoom);
  }

  void _selectStation(ChargingStation station) {
    setState(() => _selectedStationId = station.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _StationDetailsSheet(
        station: station,
        distanceUnit: _distanceUnit,
        loadingRoute: _loadingRoute,
        onNavigate: () => _showRouteToStation(station),
        onCall: station.phone == null
            ? null
            : () => _launchPhone(station.phone!),
        onWebsite: station.website == null
            ? null
            : () => _launchWebsite(station.website!),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    await _launchExternal(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _launchWebsite(String website) async {
    final uri = Uri.tryParse(website);
    if (uri == null || !uri.hasScheme) {
      _showMessage('This station has an invalid website link.');
      return;
    }
    await _launchExternal(uri);
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showMessage('Could not open $uri');
      }
    } catch (error, stackTrace) {
      debugPrint('Could not open external link $uri: $error\n$stackTrace');
      _showMessage('Could not open the selected link.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rangeKm = _estimatedRangeKm;
    final searchRadiusKm = _searchRadiusKm;
    final location = _userLocation;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Charging Map',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'My Charging Card',
            onPressed: _openChargingCard,
            icon: const Icon(Icons.credit_card_rounded),
          ),
          IconButton(
            tooltip: 'Refresh location, vehicle data and stations',
            onPressed: _loadingStations || _loadingRoute ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _RangeSummary(
            battery: _batteryPercentage,
            rangeKm: rangeKm,
            searchRadiusKm: searchRadiusKm,
            unit: _distanceUnit,
            loading: _loadingVehicle || _loadingTelemetry,
            message: _vehicleMessage ?? _batterySourceNotice,
            messageIsNotice:
                _vehicleMessage == null && _batterySourceNotice != null,
            onConfigure: _vehicle == null || _maximumRangeKm != null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VehicleDetailsPage(vehicle: _vehicle),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSearch ? _findChargingStations : null,
                icon: _loadingStations
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ev_station_rounded),
                label: Text(
                  _loadingStations
                      ? 'Updating location and vehicle…'
                      : 'Find Nearby Stations',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _destinationController,
                  enabled: !_loadingRoute,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _findStationsAlongDestinationRoute(),
                  decoration: InputDecoration(
                    labelText: 'Where are you going?',
                    hintText: 'Enter a city or address',
                    prefixIcon: const Icon(Icons.location_searching_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Find stations along route',
                      onPressed: _loadingRoute
                          ? null
                          : _findStationsAlongDestinationRoute,
                      icon: _loadingRoute
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.alt_route_rounded),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE7EDF3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE7EDF3)),
                    ),
                  ),
                ),
                if (_destinationMessage != null) ...[
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _destinationMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB44343),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (_activeRoute != null) ...[
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_activeRoute!.destination.name} · '
                      '${DistanceUnitService.format(_activeRoute!.distanceKm, _distanceUnit)} · '
                      '${_formatDuration(_activeRoute!.duration)}'
                      '${_routeSearchMode ? ' · stations within ${ChargingStationService.defaultRouteCorridorWidthKm.toStringAsFixed(0)} km of route' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedBlue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (_routeSearchMode && _activeRoute != null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Range filter is geographic; road distance can be longer. Check directions before relying on reachability.',
                      maxLines: 2,
                      style: TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (location == null)
            Expanded(
              child: _LocationState(
                loading: _loadingLocation,
                message: _locationMessage,
                permanentlyDenied: _permanentlyDenied,
                onRetry: _locateUser,
                onOpenSettings: _openAppSettings,
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: _buildMap(location, searchRadiusKm),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _StationList(
                      stations: _visibleStations,
                      totalStationCount: _inRangeStations.length,
                      searchController: _stationSearchController,
                      distanceUnit: _distanceUnit,
                      loading: _loadingStations,
                      hasSearched: _hasSearched,
                      fastChargingOnly: _fastChargingOnly,
                      message: _stationMessage,
                      onRetry: _retryCurrentSearch,
                      onSearchChanged: (_) => setState(() {}),
                      onFastChargingChanged: (value) =>
                          setState(() => _fastChargingOnly = value),
                      onClearFilters: () {
                        _stationSearchController.clear();
                        setState(() => _fastChargingOnly = false);
                      },
                      onSelect: _selectStation,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng location, double? rangeKm) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: location,
            initialZoom: rangeKm == null ? 14 : _initialZoom(rangeKm),
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;
              if (rangeKm != null) _fitRange(rangeKm);
            },
            onPositionChanged: (camera, hasGesture) {
              _zoom = camera.zoom;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.flutter_application_2',
            ),
            if (rangeKm != null && rangeKm > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: location,
                    radius: rangeKm * 1000,
                    useRadiusInMeter: true,
                    color: AppTheme.blue.withValues(alpha: 0.08),
                    borderColor: AppTheme.blue.withValues(alpha: 0.45),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (_activeRoute != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _activeRoute!.points,
                    color: AppTheme.blue,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 48,
                  height: 48,
                  child: const _CurrentLocationMarker(),
                ),
                if (_activeRoute != null)
                  Marker(
                    point: _activeRoute!.destination.location,
                    width: 48,
                    height: 56,
                    child: const _DestinationMarker(),
                  ),
                ..._visibleStations.map(
                  (station) => Marker(
                    point: station.location,
                    width: station.id == _selectedStationId ? 48 : 40,
                    height: station.id == _selectedStationId ? 48 : 40,
                    child: _StationMarker(
                      selected: station.id == _selectedStationId,
                      onTap: () => _selectStation(station),
                    ),
                    alignment: Alignment.center,
                    key: ValueKey(station.id),
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => _launchExternal(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _MapStatusCard(loading: _loadingLocation),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapControl(
                tooltip: 'Zoom in',
                icon: Icons.add_rounded,
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 8),
              _MapControl(
                tooltip: 'Zoom out',
                icon: Icons.remove_rounded,
                onPressed: () => _zoomBy(-1),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'my_location',
            tooltip: 'My Location',
            onPressed: _loadingLocation ? null : _locateUser,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.blue,
            child: _loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        if (_locationMessage != null)
          Positioned(
            left: 12,
            right: 62,
            bottom: 12,
            child: _MapMessage(message: _locationMessage!),
          ),
      ],
    );
  }

  double _initialZoom(double radiusKm) =>
      (math.log(40075 / (2 * radiusKm)) / math.ln2).clamp(4.5, 15.0).toDouble();

  void _zoomBy(double amount) {
    _zoom = (_zoom + amount).clamp(3, 19).toDouble();
    _mapController.move(_mapController.camera.center, _zoom);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min drive';
    if (minutes == 0) return '$hours hr drive';
    return '$hours hr $minutes min drive';
  }

  Future<void> _openAppSettings() async {
    try {
      final opened = await _locationService.openLocationSettings();
      if (!opened) _showMessage('Could not open location settings.');
    } catch (error, stackTrace) {
      debugPrint('Could not open location settings: $error\n$stackTrace');
      _showMessage('Could not open location settings.');
    }
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({
    required this.battery,
    required this.rangeKm,
    required this.searchRadiusKm,
    required this.unit,
    required this.loading,
    required this.message,
    required this.messageIsNotice,
    required this.onConfigure,
  });

  final double? battery;
  final double? rangeKm;
  final double? searchRadiusKm;
  final String unit;
  final bool loading;
  final String? message;
  final bool messageIsNotice;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Battery',
                  value: battery == null ? null : '${battery!.round()}%',
                  loading: loading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.route_rounded,
                  label: 'Estimated range',
                  value: rangeKm == null
                      ? null
                      : DistanceUnitService.format(rangeKm!, unit, decimals: 0),
                  loading: loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: AppTheme.blue, size: 19),
              const SizedBox(width: 8),
              const Text(
                'Search radius',
                style: TextStyle(
                  color: AppTheme.mutedBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                searchRadiusKm == null
                    ? 'Not available'
                    : DistanceUnitService.format(
                        searchRadiusKm!,
                        unit,
                        decimals: 0,
                      ),
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (searchRadiusKm != null) ...[
            const SizedBox(height: 7),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Search radius uses 80% of estimated range as a safety reserve.',
                style: TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
              ),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message!,
                style: TextStyle(
                  color: messageIsNotice
                      ? AppTheme.mutedBlue
                      : const Color(0xFFB44343),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (message != null && onConfigure != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onConfigure,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Configure vehicle range'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.blue, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.mutedBlue, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                loading ? 'Loading…' : value ?? 'Not available',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StationList extends StatelessWidget {
  const _StationList({
    required this.stations,
    required this.totalStationCount,
    required this.searchController,
    required this.distanceUnit,
    required this.loading,
    required this.hasSearched,
    required this.fastChargingOnly,
    required this.message,
    required this.onRetry,
    required this.onSearchChanged,
    required this.onFastChargingChanged,
    required this.onClearFilters,
    required this.onSelect,
  });

  final List<ChargingStation> stations;
  final int totalStationCount;
  final TextEditingController searchController;
  final String distanceUnit;
  final bool loading;
  final bool hasSearched;
  final bool fastChargingOnly;
  final String? message;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onFastChargingChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<ChargingStation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Charging stations',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (stations.isNotEmpty)
                Text(
                  totalStationCount == stations.length
                      ? '${stations.length} found'
                      : '${stations.length} of $totalStationCount',
                  style: const TextStyle(
                    color: AppTheme.mutedBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search stations or operators',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE7EDF3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE7EDF3)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !fastChargingOnly,
                onSelected: (_) => onFastChargingChanged(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Fast Charging'),
                selected: fastChargingOnly,
                onSelected: (_) => onFastChargingChanged(true),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: Text('Searching charging stations…'))
              : message != null
              ? _ListMessage(
                  message: message!,
                  actionLabel: 'Try again',
                  onPressed: onRetry,
                )
              : stations.isNotEmpty
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  itemCount: stations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _StationCard(
                    station: stations[index],
                    distanceUnit: distanceUnit,
                    onTap: () => onSelect(stations[index]),
                  ),
                )
              : _ListMessage(
                  message: totalStationCount > 0
                      ? 'No stations match your search or selected filter.'
                      : hasSearched
                      ? 'No charging stations were found within your current estimated range.'
                      : 'Search for real OpenStreetMap charging stations within your estimated range.',
                  actionLabel: totalStationCount > 0
                      ? 'Clear filters'
                      : hasSearched
                      ? 'Search again'
                      : null,
                  onPressed: totalStationCount > 0
                      ? onClearFilters
                      : hasSearched
                      ? onRetry
                      : null,
                ),
        ),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.distanceUnit,
    required this.onTap,
  });

  final ChargingStation station;
  final String distanceUnit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = <String>[
      if (station.operator != null) station.operator!,
      DistanceUnitService.format(station.distanceKm, distanceUnit),
      if (station.connectors.isNotEmpty) station.connectors.join(', '),
      if (station.power != null) station.power!,
      if (station.distanceFromRouteKm != null)
        '${DistanceUnitService.format(station.distanceFromRouteKm!, distanceUnit)} from route',
      if (station.address != null) station.address!,
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: AppTheme.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name ?? 'Not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mutedBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationDetailsSheet extends StatefulWidget {
  const _StationDetailsSheet({
    required this.station,
    required this.distanceUnit,
    required this.loadingRoute,
    required this.onNavigate,
    required this.onCall,
    required this.onWebsite,
  });

  final ChargingStation station;
  final String distanceUnit;
  final bool loadingRoute;
  final Future<RoadRoute?> Function() onNavigate;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;

  @override
  State<_StationDetailsSheet> createState() => _StationDetailsSheetState();
}

class _StationDetailsSheetState extends State<_StationDetailsSheet> {
  RoadRoute? _route;
  bool _loading = false;

  Future<void> _showDirections() async {
    setState(() => _loading = true);
    final route = await widget.onNavigate();
    if (!mounted) return;
    setState(() {
      _route = route;
      _loading = false;
    });
  }

  String _available(String? value) =>
      value == null || value.trim().isEmpty ? 'Not available' : value;

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name ?? 'Not available',
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _available(station.operator),
            style: const TextStyle(color: AppTheme.mutedBlue),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading || widget.loadingRoute
                      ? null
                      : _showDirections,
                  icon: _loading || widget.loadingRoute
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.directions_rounded),
                  label: const Text('Directions'),
                ),
              ),
              if (widget.onCall != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.onCall,
                  child: const Icon(Icons.call_rounded),
                ),
              ],
              if (widget.onWebsite != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.onWebsite,
                  child: const Icon(Icons.language_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (_route != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Driving route: ${DistanceUnitService.format(_route!.distanceKm, widget.distanceUnit)} · '
                '${_route!.duration.inHours > 0 ? '${_route!.duration.inHours} hr ' : ''}'
                '${_route!.duration.inMinutes.remainder(60)} min',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _DetailRow(label: 'Address', value: _available(station.address)),
          _DetailRow(
            label: 'Distance',
            value: DistanceUnitService.format(
              station.distanceKm,
              widget.distanceUnit,
            ),
          ),
          if (station.distanceFromRouteKm != null)
            _DetailRow(
              label: 'Distance from route',
              value: DistanceUnitService.format(
                station.distanceFromRouteKm!,
                widget.distanceUnit,
              ),
            ),
          _DetailRow(
            label: 'Latitude / longitude',
            value:
                '${station.location.latitude.toStringAsFixed(5)}, '
                '${station.location.longitude.toStringAsFixed(5)}',
          ),
          _DetailRow(
            label: 'Connectors',
            value: station.connectors.isEmpty
                ? 'Not available'
                : station.connectors.join(', '),
          ),
          _DetailRow(
            label: 'Charging points',
            value: station.chargingPoints?.toString() ?? 'Not available',
          ),
          _DetailRow(label: 'Charging power', value: _available(station.power)),
          _DetailRow(
            label: 'Opening hours',
            value: _available(station.openingHours),
          ),
          _DetailRow(label: 'Phone', value: _available(station.phone)),
          _DetailRow(label: 'Website', value: _available(station.website)),
          _DetailRow(
            label: 'Reported availability/status',
            value: _available(station.availability),
          ),
          _DetailRow(label: 'Access', value: _available(station.access)),
          _DetailRow(label: 'Fee', value: _available(station.fee)),
          const SizedBox(height: 10),
          const Text(
            'Station details are sourced from OpenStreetMap and may be incomplete.',
            style: TextStyle(color: AppTheme.mutedBlue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 144,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.mutedBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.navy, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationState extends StatelessWidget {
  const _LocationState({
    required this.loading,
    required this.message,
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool loading;
  final String? message;
  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final denied =
        permanentlyDenied ||
        (message?.toLowerCase().contains('permission') ?? false);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(
                  denied
                      ? Icons.location_off_rounded
                      : Icons.my_location_rounded,
                  color: AppTheme.blue,
                  size: 36,
                ),
              const SizedBox(height: 16),
              Text(
                loading
                    ? 'Finding your location'
                    : denied
                    ? 'Location access needed'
                    : 'Location unavailable',
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loading
                    ? 'Allow location access to center the map on your current position.'
                    : message ??
                          'Your current location could not be determined.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.mutedBlue, height: 1.5),
              ),
              if (!loading) ...[
                const SizedBox(height: 16),
                if (permanentlyDenied && !kIsWeb)
                  Column(
                    children: [
                      FilledButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Open Settings'),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Try Again'),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.location_on_rounded,
    color: Color(0xFFD74D4D),
    size: 46,
    shadows: [Shadow(color: Colors.white, blurRadius: 3)],
  );
}

class _StationMarker extends StatelessWidget {
  const _StationMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: selected ? 40 : 32,
          height: selected ? 40 : 32,
          decoration: BoxDecoration(
            color: selected ? AppTheme.navy : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.blue, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.ev_station_rounded,
            color: selected ? Colors.white : AppTheme.blue,
            size: selected ? 20 : 17,
          ),
        ),
      ),
    );
  }
}

class _MapStatusCard extends StatelessWidget {
  const _MapStatusCard({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17324D).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, color: AppTheme.blue, size: 17),
          const SizedBox(width: 7),
          Text(
            loading ? 'Updating location' : 'Your location',
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFFB44343), fontSize: 12),
    ),
  );
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    borderRadius: BorderRadius.circular(13),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppTheme.navy,
      icon: Icon(icon),
    ),
  );
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedBlue, height: 1.4),
          ),
          if (onPressed != null && actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
