import 'package:latlong2/latlong.dart';

import 'charging_station.dart';
import 'road_route.dart';

class TripVehicleState {
  const TripVehicleState({
    required this.vehicleId,
    required this.vehicleModel,
    required this.maximumRangeKm,
    required this.batteryPercentage,
    required this.availableRangeKm,
    required this.usableRangeKm,
    required this.minimumReserveKm,
  });

  final String vehicleId;
  final String vehicleModel;
  final double maximumRangeKm;
  final double batteryPercentage;
  final double availableRangeKm;
  final double usableRangeKm;
  final double minimumReserveKm;
}

class TripPlanningRequest {
  const TripPlanningRequest({
    required this.start,
    required this.destinationQuery,
    required this.vehicle,
    this.selectedDestination,
    this.routeCorridorWidthKm = 5,
    this.safetyReserveFraction = 0.2,
  });

  final LatLng start;
  final String destinationQuery;
  final GeocodedDestination? selectedDestination;
  final TripVehicleState vehicle;
  final double routeCorridorWidthKm;
  final double safetyReserveFraction;
}

class TripLegAssessment {
  const TripLegAssessment({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.availableRangeKm,
    required this.minimumReserveKm,
    required this.remainingRangeKm,
    required this.isReachable,
  });

  final String from;
  final String to;
  final double distanceKm;
  final double availableRangeKm;
  final double minimumReserveKm;
  final double remainingRangeKm;
  final bool isReachable;
}

class TripStationAssessment {
  const TripStationAssessment({
    required this.station,
    required this.routeProgressKm,
    required this.incomingLeg,
    required this.selectedForPlan,
  });

  final ChargingStation station;
  final double routeProgressKm;
  final TripLegAssessment? incomingLeg;
  final bool selectedForPlan;
}

class TripPlanningResult {
  const TripPlanningResult({
    required this.request,
    required this.start,
    required this.destination,
    required this.route,
    required this.liveStations,
    required this.stationAssessments,
    required this.selectedStops,
    required this.legs,
    required this.isFeasible,
    required this.warnings,
  });

  final TripPlanningRequest request;
  final LatLng start;
  final GeocodedDestination destination;
  final RoadRoute route;
  final List<ChargingStation> liveStations;
  final List<TripStationAssessment> stationAssessments;
  final List<ChargingStation> selectedStops;
  final List<TripLegAssessment> legs;
  final bool isFeasible;
  final List<String> warnings;
}
