import 'package:flutter/material.dart';
import 'package:vehicle_ble_protocol/vehicle_ble_protocol.dart';

import '../services/vehicle_ble_client.dart';

class VehicleBleStateView extends StatelessWidget {
  const VehicleBleStateView({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    VehicleBleClient client,
    VehicleStateSnapshot? snapshot,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final client = VehicleBleClient.shared;
    return AnimatedBuilder(
      animation: client,
      builder: (context, _) => ValueListenableBuilder<VehicleStateSnapshot?>(
        valueListenable: client.snapshot,
        builder: (context, snapshot, _) => builder(context, client, snapshot),
      ),
    );
  }
}
