import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleData {
  const VehicleData({
    required this.battery,
    required this.range,
    required this.batteryHealth,
    required this.healthScore,
    required this.isCharging,
    this.updatedAt,
    this.batteryTemperatureC,
    this.batteryCapacityKwh,
    this.batteryAgeMonths,
    this.chargingCycles,
    this.motorHealth,
    this.motorTemperatureC,
    this.brakeHealth,
    this.hardBrakingEvents,
    this.tripsAnalyzed,
    this.tirePressureTrendPsiPerWeek,
    this.tirePressureFlPsi,
    this.tirePressureFrPsi,
    this.tirePressureRlPsi,
    this.tirePressureRrPsi,
    this.tireTemperatureFlC,
    this.tireTemperatureFrC,
    this.tireTemperatureRlC,
    this.tireTemperatureRrC,
    this.softwareHealth,
    this.dcFastChargePercentage,
    this.ecoScore,
    this.ecoStreakDays,
    this.efficiencyKmPerKwh,
    this.regenerativeEnergyKwh,
    this.lastTripDistanceKm,
    this.lastTripEnergyKwh,
    this.odometerKm,
  });

  final double battery;
  final double range;
  final double batteryHealth;
  final int healthScore;
  final bool isCharging;
  final DateTime? updatedAt;
  final double? batteryTemperatureC;
  final double? batteryCapacityKwh;
  final int? batteryAgeMonths;
  final int? chargingCycles;
  final double? motorHealth;
  final double? motorTemperatureC;
  final double? brakeHealth;
  final int? hardBrakingEvents;
  final int? tripsAnalyzed;
  final double? tirePressureTrendPsiPerWeek;
  final double? tirePressureFlPsi;
  final double? tirePressureFrPsi;
  final double? tirePressureRlPsi;
  final double? tirePressureRrPsi;
  final double? tireTemperatureFlC;
  final double? tireTemperatureFrC;
  final double? tireTemperatureRlC;
  final double? tireTemperatureRrC;
  final double? softwareHealth;
  final double? dcFastChargePercentage;
  final int? ecoScore;
  final int? ecoStreakDays;
  final double? efficiencyKmPerKwh;
  final double? regenerativeEnergyKwh;
  final double? lastTripDistanceKm;
  final double? lastTripEnergyKwh;
  final double? odometerKm;

  factory VehicleData.fromMap(Map<String, dynamic> map) {
    return VehicleData(
      battery: _number(map['battery'] ?? map['batteryPercentage']),
      range: _number(map['range']),
      batteryHealth: _number(map['batteryHealth']),
      healthScore: _integer(map['healthScore']),
      isCharging: map['isCharging'] is bool && map['isCharging'] as bool,
      updatedAt: _readDate(map['updatedAt']),
      batteryTemperatureC: _optionalNumber(map['batteryTemperatureC']),
      batteryCapacityKwh: _optionalNumber(map['batteryCapacityKwh']),
      batteryAgeMonths: _optionalInteger(map['batteryAgeMonths']),
      chargingCycles: _optionalInteger(map['chargingCycles']),
      motorHealth: _optionalNumber(map['motorHealth']),
      motorTemperatureC: _optionalNumber(map['motorTemperatureC']),
      brakeHealth: _optionalNumber(map['brakeHealth']),
      hardBrakingEvents: _optionalInteger(map['hardBrakingEvents']),
      tripsAnalyzed: _optionalInteger(map['tripsAnalyzed']),
      tirePressureTrendPsiPerWeek: _optionalNumber(
        map['tirePressureTrendPsiPerWeek'],
      ),
      tirePressureFlPsi: _optionalNumber(map['tirePressureFlPsi']),
      tirePressureFrPsi: _optionalNumber(map['tirePressureFrPsi']),
      tirePressureRlPsi: _optionalNumber(map['tirePressureRlPsi']),
      tirePressureRrPsi: _optionalNumber(map['tirePressureRrPsi']),
      tireTemperatureFlC: _optionalNumber(map['tireTemperatureFlC']),
      tireTemperatureFrC: _optionalNumber(map['tireTemperatureFrC']),
      tireTemperatureRlC: _optionalNumber(map['tireTemperatureRlC']),
      tireTemperatureRrC: _optionalNumber(map['tireTemperatureRrC']),
      softwareHealth: _optionalNumber(map['softwareHealth']),
      dcFastChargePercentage: _optionalNumber(map['dcFastChargePercentage']),
      ecoScore: _optionalInteger(map['ecoScore']),
      ecoStreakDays: _optionalInteger(map['ecoStreakDays']),
      efficiencyKmPerKwh: _optionalNumber(map['efficiencyKmPerKwh']),
      regenerativeEnergyKwh: _optionalNumber(map['regenerativeEnergyKwh']),
      lastTripDistanceKm: _optionalNumber(map['lastTripDistanceKm']),
      lastTripEnergyKwh: _optionalNumber(map['lastTripEnergyKwh']),
      odometerKm: _optionalNumber(map['odometerKm'] ?? map['odometer']),
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _optionalNumber(Object? value) {
    final number = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
    return number != null && number.isFinite ? number : null;
  }

  static int? _optionalInteger(Object? value) {
    final number = switch (value) {
      num() => value.toInt(),
      String() => int.tryParse(value),
      _ => null,
    };
    return number;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
