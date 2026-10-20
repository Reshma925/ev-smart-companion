(() => {
  const notificationListeners = new Map();
  const disconnectListeners = new Map();

  globalThis.VehicleBleBridge = {
    isSupported() {
      return Boolean(
        navigator.bluetooth &&
          typeof navigator.bluetooth.requestDevice === "function",
      );
    },

    isSecureContext() {
      return globalThis.isSecureContext === true;
    },

    bluetoothPolicyStatus() {
      const policy =
        document.permissionsPolicy || document.featurePolicy || null;
      if (!policy || typeof policy.allowsFeature !== "function") {
        return "unknown";
      }
      return policy.allowsFeature("bluetooth") ? "allowed" : "blocked";
    },

    getAvailabilityStatus() {
      if (
        !navigator.bluetooth ||
        typeof navigator.bluetooth.getAvailability !== "function"
      ) {
        return Promise.resolve("unknown");
      }
      return navigator.bluetooth
        .getAvailability()
        .then((available) => (available ? "available" : "unavailable"));
    },

    requestDevice(serviceUuid) {
      try {
        return navigator.bluetooth
          .requestDevice({
            filters: [{ services: [serviceUuid] }],
          })
          .catch((error) => {
            throw new Error(
              `DEVICE_REQUEST: ${error?.name || "Error"}: ${
                error?.message || String(error)
              }`,
            );
          });
      } catch (error) {
        throw new Error(
          `DEVICE_REQUEST: ${error?.name || "Error"}: ${
            error?.message || String(error)
          }`,
        );
      }
    },

    getDeviceName(device) {
      return device.name || null;
    },

    connect(device) {
      return device.gatt.connect().catch((error) => {
        throw new Error(
          `GATT_CONNECT: ${error?.name || "Error"}: ${
            error?.message || String(error)
          }`,
        );
      });
    },

    getService(server, serviceUuid) {
      return server
        .getPrimaryService(serviceUuid)
        .catch((error) => {
          throw new Error(
            `GATT_SERVICE_DISCOVERY: ${error?.name || "Error"}: ${
              error?.message || String(error)
            }`,
          );
        });
    },

    getCharacteristic(service, characteristicUuid) {
      return service.getCharacteristic(characteristicUuid).catch((error) => {
        throw new Error(
          `GATT_CHARACTERISTIC_DISCOVERY: ${error?.name || "Error"}: ${
            error?.message || String(error)
          }`,
        );
      });
    },

    startNotifications(characteristic) {
      return characteristic.startNotifications().catch((error) => {
        throw new Error(
          `NOTIFICATION_SUBSCRIPTION: ${error?.name || "Error"}: ${
            error?.message || String(error)
          }`,
        );
      });
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
      return characteristic
        .writeValueWithResponse(new Uint8Array(bytes))
        .catch((error) => {
          throw new Error(
            `GATT_WRITE: ${error?.name || "Error"}: ${
              error?.message || String(error)
            }`,
          );
        });
    },

    disconnect(device) {
      if (device.gatt.connected) device.gatt.disconnect();
    },
  };
})();
