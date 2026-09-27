import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleData {
  final double battery; // %
  final double range; // km
  final double batteryHealth; // %
  final int healthScore; // 0-100
  final bool isCharging;

  VehicleData(this.battery, this.range, this.batteryHealth, this.healthScore,
      this.isCharging);

  // Turns the data saved in Firebase back into VehicleData
  factory VehicleData.fromMap(Map<String, dynamic> m) => VehicleData(
        (m['battery'] as num).toDouble(),
        (m['range'] as num).toDouble(),
        (m['batteryHealth'] as num).toDouble(),
        (m['healthScore'] as num).toInt(),
        m['isCharging'] as bool,
      );
}

class VehicleSimulator {
  // The place in Firebase where the car's data is saved
  final _doc = FirebaseFirestore.instance.collection('vehicles').doc('demo');
  Timer? _timer;

  double battery = 80;
  double batteryHealth = 95;
  bool isCharging = false;
  final double maxRange = 300;

  // The dashboard listens to Firebase, not to the simulator directly
  Stream<VehicleData> get stream => _doc
      .snapshots()
      .where((snap) => snap.exists)
      .map((snap) => VehicleData.fromMap(snap.data()!));

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isCharging) {
        battery += 1;
        if (battery >= 100) {
          battery = 100;
          isCharging = false;
        }
      } else {
        battery -= 0.5;
        if (battery <= 20) isCharging = true;
      }

      batteryHealth -= 0.001;
      final range = maxRange * (battery / 100) * (batteryHealth / 100);
      final healthScore = (batteryHealth * 0.7 + battery * 0.3).round();

      // Save the new readings to Firebase
      _doc.set({
        'battery': double.parse(battery.toStringAsFixed(1)),
       'range': double.parse(range.toStringAsFixed(1)),
       'batteryHealth': double.parse(batteryHealth.toStringAsFixed(2)),
        'healthScore': healthScore,
        'isCharging': isCharging,
         'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void stop() => _timer?.cancel();
}