import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/services/distance_unit_service.dart';

void main() {
  group('DistanceUnitService', () {
    test('converts kilometres to miles for display', () {
      expect(DistanceUnitService.format(100, 'mi'), '62.1 mi');
    });

    test('keeps kilometre display when kilometres are selected', () {
      expect(DistanceUnitService.format(100, 'km'), '100.0 km');
    });

    test('normalizes stored mile preference values', () {
      expect(DistanceUnitService.normalize('Miles'), DistanceUnitService.mi);
      expect(DistanceUnitService.normalize('mi'), DistanceUnitService.mi);
    });

    test('converts speed consistently with the selected distance unit', () {
      expect(DistanceUnitService.formatSpeed(100, 'mi'), '62 mph');
      expect(DistanceUnitService.formatSpeed(100, 'km'), '100 km/h');
    });
  });
}
