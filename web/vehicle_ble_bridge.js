(() => {
  const notificationListeners = new Map();
  const disconnectListeners = new Map();

  globalThis.VehicleBleBridge = {
    isSupported() {
      return Boolean(navigator.bluetooth);
    },

    requestDevice(serviceUuid) {
      return navigator.bluetooth.requestDevice({
        filters: [{ services: [serviceUuid] }],
      });
    },

    getDeviceName(device) {
      return device.name || null;
    },

    connect(device) {
      return device.gatt.connect();
    },

    getCharacteristic(server, serviceUuid, characteristicUuid) {
      return server
        .getPrimaryService(serviceUuid)
        .then((service) => service.getCharacteristic(characteristicUuid));
    },

    startNotifications(characteristic) {
      return characteristic.startNotifications();
    },

    addNotificationListener(characteristic, listenerId, callback) {
      const listener = (event) => {
        const value = event.target.value;
        const bytes = Array.from(
          new Uint8Array(value.buffer, value.byteOffset, value.byteLength),
        );
        callback(bytes);
      };
      notificationListeners.set(listenerId, { characteristic, listener });
      characteristic.addEventListener('characteristicvaluechanged', listener);
    },

    removeNotificationListener(characteristic, listenerId) {
      const entry = notificationListeners.get(listenerId);
      if (entry) {
        characteristic.removeEventListener(
          'characteristicvaluechanged',
          entry.listener,
        );
        notificationListeners.delete(listenerId);
      }
    },

    addDisconnectListener(device, listenerId, callback) {
      const listener = () => callback();
      disconnectListeners.set(listenerId, { device, listener });
      device.addEventListener('gattserverdisconnected', listener);
    },

    removeDisconnectListener(device, listenerId) {
      const entry = disconnectListeners.get(listenerId);
      if (entry) {
        device.removeEventListener('gattserverdisconnected', entry.listener);
        disconnectListeners.delete(listenerId);
      }
    },

    write(characteristic, bytes) {
      return characteristic.writeValueWithResponse(new Uint8Array(bytes));
    },

    disconnect(device) {
      if (device.gatt.connected) device.gatt.disconnect();
    },
  };
})();
