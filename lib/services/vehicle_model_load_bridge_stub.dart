class VehicleModelLoadEvent {
  const VehicleModelLoadEvent({required this.loaded, this.error});

  final bool loaded;
  final String? error;
}

Stream<VehicleModelLoadEvent> get vehicleModelLoadEvents =>
    const Stream<VehicleModelLoadEvent>.empty();

void initializeVehicleModelLoadBridge() {}
