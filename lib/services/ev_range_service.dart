enum EvReachabilityStatus { safe, caution, unreachable }

class EvRangeAssessment {
  const EvRangeAssessment({
    required this.status,
    required this.usableRangeKm,
    required this.remainingRangeKm,
    required this.rangeAfterTripKm,
    required this.label,
  });

  final EvReachabilityStatus status;
  final double usableRangeKm;
  final double remainingRangeKm;
  final double rangeAfterTripKm;
  final String label;
}

class EvRangeService {
  static const double defaultSafetyFactor = 0.7;
  static const double chargingSearchSafetyFactor = 0.8;

  static double calculateCurrentRangeKm({
    required double maximumRangeKm,
    required double batteryPercentage,
  }) {
    if (!maximumRangeKm.isFinite || maximumRangeKm <= 0) {
      throw ArgumentError.value(
        maximumRangeKm,
        'maximumRangeKm',
        'Must be a positive finite range.',
      );
    }
    if (!batteryPercentage.isFinite ||
        batteryPercentage < 0 ||
        batteryPercentage > 100) {
      throw ArgumentError.value(
        batteryPercentage,
        'batteryPercentage',
        'Must be between 0 and 100.',
      );
    }
    return maximumRangeKm * batteryPercentage / 100;
  }

  static double calculateUsableRange({
    required double estimatedRangeKm,
    double safetyFactor = chargingSearchSafetyFactor,
  }) {
    if (!estimatedRangeKm.isFinite || estimatedRangeKm < 0) {
      throw ArgumentError.value(
        estimatedRangeKm,
        'estimatedRangeKm',
        'Must be finite and non-negative.',
      );
    }
    if (!safetyFactor.isFinite || safetyFactor < 0 || safetyFactor > 1) {
      throw ArgumentError.value(
        safetyFactor,
        'safetyFactor',
        'Must be between zero and one.',
      );
    }
    return estimatedRangeKm * safetyFactor;
  }

  static EvRangeAssessment assessRouteReachability({
    required num currentEstimatedRangeKm,
    required num routeDistanceKm,
    double safetyFactor = defaultSafetyFactor,
  }) {
    final currentRange = currentEstimatedRangeKm.toDouble();
    final routeDistance = routeDistanceKm.toDouble();
    final usableRangeKm = calculateUsableRange(
      estimatedRangeKm: currentRange,
      safetyFactor: safetyFactor,
    );
    final remainingRangeKm = currentRange - routeDistance;
    final rangeAfterTripKm = remainingRangeKm > 0 ? remainingRangeKm : 0.0;

    if (routeDistanceKm <= 0) {
      return EvRangeAssessment(
        status: EvReachabilityStatus.safe,
        usableRangeKm: usableRangeKm,
        remainingRangeKm: currentRange,
        rangeAfterTripKm: currentRange,
        label: 'Here',
      );
    }

    if (routeDistanceKm <= usableRangeKm) {
      final closeToLimit = (usableRangeKm - routeDistance) <= usableRangeKm * 0.15;
      final status = closeToLimit
          ? EvReachabilityStatus.caution
          : EvReachabilityStatus.safe;
      final label = closeToLimit
          ? 'Low range margin'
          : 'Within estimated range';
      return EvRangeAssessment(
        status: status,
        usableRangeKm: usableRangeKm,
        remainingRangeKm: remainingRangeKm,
        rangeAfterTripKm: rangeAfterTripKm,
        label: label,
      );
    }

    return EvRangeAssessment(
      status: EvReachabilityStatus.unreachable,
      usableRangeKm: usableRangeKm,
      remainingRangeKm: remainingRangeKm,
      rangeAfterTripKm: rangeAfterTripKm,
      label: 'Beyond current estimated range',
    );
  }
}
