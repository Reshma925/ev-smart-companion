import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/ev_range_service.dart';

void main() {
  test('calculates current driving range from battery and rated range', () {
    expect(
      EvRangeService.calculateCurrentRangeKm(
        maximumRangeKm: 300,
        batteryPercentage: 72,
      ),
      216,
    );
  });

  test('rejects unavailable or invalid range inputs', () {
    expect(
      () => EvRangeService.calculateCurrentRangeKm(
        maximumRangeKm: 0,
        batteryPercentage: 72,
      ),
      throwsArgumentError,
    );
    expect(
      () => EvRangeService.calculateCurrentRangeKm(
        maximumRangeKm: 300,
        batteryPercentage: 101,
      ),
      throwsArgumentError,
    );
  });

  test('uses a documented safety margin for charging search radius', () {
    expect(EvRangeService.chargingSearchSafetyFactor, 0.8);
    expect(EvRangeService.calculateUsableRange(estimatedRangeKm: 216), 172.8);
  });
}
