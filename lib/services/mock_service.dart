import '../models/vehicle.dart';

class MockService {
  static String? accountName;
  static String? accountEmail;
  static String? accountMobile;
  static String? accountPassword;

  static const otp = '123456';

  static const vehicles = <Vehicle>[
    Vehicle(
      model: 'Kia EV6',
      registrationNumber: 'TN01AB1234',
      ownerName: 'Rahul Kumar',
      vin: 'KNDC3DLC5N5123456',
    ),
    Vehicle(
      model: 'Tata Nexon EV',
      registrationNumber: 'MH12CD5678',
      ownerName: 'Ananya Sharma',
      vin: 'MAT627123NEXON0001',
    ),
    Vehicle(
      model: 'Tata Curvv EV',
      registrationNumber: 'DL04EF9012',
      ownerName: 'Vikram Singh',
      vin: 'MAT627123CURVV0002',
    ),
    Vehicle(
      model: 'MG ZS EV',
      registrationNumber: 'KA05GH3456',
      ownerName: 'Priya Menon',
      vin: 'LSJW74U65PZ123456',
    ),
    Vehicle(
      model: 'Hyundai Ioniq 5',
      registrationNumber: 'TN09IJ7890',
      ownerName: 'Arjun Rao',
      vin: 'KMHKN81B5NU123456',
    ),
  ];

  static Vehicle? findVehicle({
    required String model,
    required String registrationNumber,
    required String ownerName,
    required String vin,
  }) {
    for (final vehicle in vehicles) {
      if (vehicle.model == model &&
          vehicle.registrationNumber.toLowerCase() ==
              registrationNumber.toLowerCase() &&
          vehicle.ownerName.toLowerCase() == ownerName.toLowerCase() &&
          vehicle.vin.toLowerCase() == vin.toLowerCase()) {
        return vehicle;
      }
    }
    return null;
  }
}
