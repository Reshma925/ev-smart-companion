import 'package:flutter/foundation.dart';

import '../models/trip_plan.dart';
import 'charging_station_service.dart';
import 'road_directions_service.dart';
import 'trip_feasibility_service.dart';

class TripPlanningService {
  TripPlanningService({
    required this.directions,
    required this.stations,
    this.feasibility = const TripFeasibilityService(),
  });

  final RoadDirectionsService directions;
  final ChargingStationService stations;
  final TripFeasibilityService feasibility;

  Future<TripPlanningResult> plan(TripPlanningRequest request) async {
    final destination =
        request.selectedDestination ??
        await directions.geocode(request.destinationQuery);
    final route = await directions.route(
      origin: request.start,
      destination: destination,
    );
    final liveStations = await stations.findAlongEntireRoute(
      origin: request.start,
      routePoints: route.points,
      corridorWidthKm: request.routeCorridorWidthKm,
    );
    debugPrint(
      'Trip planner: received ${liveStations.length} live stations along '
      '${route.distanceKm.toStringAsFixed(1)} km route.',
    );
    return feasibility.assess(
      request: request,
      destination: destination,
      route: route,
      stations: liveStations,
    );
  }
}
