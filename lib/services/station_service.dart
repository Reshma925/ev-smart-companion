// Legacy sample-data station service kept intentionally empty to prevent
// mock charging-station data being used in the application.
class Station {
  const Station();
}

class StationService {
  Future<void> addSampleStationsIfEmpty() async {}
}

double distanceKm(double lat1, double lng1, double lat2, double lng2) => 0.0;
