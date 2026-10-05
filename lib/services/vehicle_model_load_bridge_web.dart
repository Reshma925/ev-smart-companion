import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class VehicleModelLoadEvent {
  const VehicleModelLoadEvent({required this.loaded, this.error});

  final bool loaded;
  final String? error;
}

final StreamController<VehicleModelLoadEvent> _events =
    StreamController<VehicleModelLoadEvent>.broadcast();
bool _initialized = false;
JSFunction? _messageListener;

Stream<VehicleModelLoadEvent> get vehicleModelLoadEvents => _events.stream;

void initializeVehicleModelLoadBridge() {
  if (_initialized) return;
  _initialized = true;
  _messageListener = ((web.Event event) {
    final data = (event as web.MessageEvent).data?.dartify();
    if (data is! Map || data['source'] != 'ev-smart-companion-model') return;
    final loaded = data['status'] == 'loaded';
    _events.add(
      VehicleModelLoadEvent(
        loaded: loaded,
        error: loaded ? null : data['error']?.toString(),
      ),
    );
  }).toJS;
  web.window.addEventListener('message', _messageListener);
}
