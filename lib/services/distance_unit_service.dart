class DistanceUnitService {
  static const String km = 'km';
  static const String mi = 'mi';

  static String normalize(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw == 'mi' || raw == 'mile' || raw == 'miles') return mi;
    return km;
  }

  static double toDisplay(double kilometres, String? selectedUnit) {
    final unit = normalize(selectedUnit);
    if (unit == mi) {
      return kilometres * 0.621371;
    }
    return kilometres;
  }

  static double speedToDisplay(
    double kilometresPerHour,
    String? selectedUnit,
  ) => toDisplay(kilometresPerHour, selectedUnit);

  static String format(
    double kilometres,
    String? selectedUnit, {
    int decimals = 1,
  }) {
    final value = toDisplay(kilometres, selectedUnit);
    final unit = normalize(selectedUnit) == mi ? 'mi' : 'km';
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  static String formatSpeed(double kilometresPerHour, String? selectedUnit) {
    final value = speedToDisplay(kilometresPerHour, selectedUnit);
    final unit = normalize(selectedUnit) == mi ? 'mph' : 'km/h';
    return '${value.round()} $unit';
  }
}
