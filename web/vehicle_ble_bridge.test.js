const assert = require("node:assert/strict");
const { readFile } = require("node:fs/promises");
const { join } = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

async function loadBridge(bluetooth) {
  const script = await readFile(join(__dirname, "vehicle_ble_bridge.js"), "utf8");
  const context = { navigator: { bluetooth }, Uint8Array, Promise, Map, Array };
  context.globalThis = context;
  vm.runInNewContext(script, context);
  return context.VehicleBleBridge;
}

test("uses the shared protocol service filter and bridges GATT state and commands", async () => {
  const [protocol, simulator] = await Promise.all([
    readFile(
    join(
      __dirname,
      "../packages/vehicle_ble_protocol/lib/vehicle_ble_protocol.dart",
    ),
    "utf8",
    ),
    readFile(
      join(__dirname, "../vehicle_simulator/lib/vehicle_simulator_peripheral.dart"),
      "utf8",
    ),
  ]);
  const serviceUuid = protocol.match(
    /const vehicleControlServiceUuid = '([^']+)';/,
  )?.[1];
  const advertisedName = protocol.match(
    /const vehicleSimulatorAdvertisedName = '([^']+)';/,
  )?.[1];
  assert.equal(serviceUuid, "8a7e1000-6d8a-4a31-b8d1-1f40cc5a0001");
  assert.equal(advertisedName, "EV-Simulator-01");
  assert.match(
    simulator,
    /await _manager\.addService\([\s\S]*?uuid:\s*UUID\.fromString\(vehicleControlServiceUuid\)/,
  );
  assert.match(
    simulator,
    /await _manager\.startAdvertising\([\s\S]*?serviceUUIDs:\s*\[UUID\.fromString\(vehicleControlServiceUuid\)\]/,
  );
  assert.match(simulator, /name:\s*vehicleSimulatorAdvertisedName/);
  assert.ok(
    simulator.indexOf("await _manager.addService(") <
      simulator.indexOf("await _manager.startAdvertising("),
    "GATT service registration must complete before advertising starts",
  );
  const stateUuid = "8a7e1001-6d8a-4a31-b8d1-1f40cc5a0001";
  const commandUuid = "8a7e1002-6d8a-4a31-b8d1-1f40cc5a0001";
  const listeners = new Map();
  let requestOptions;
  let writtenBytes;
  let disconnected;
  const stateCharacteristic = {
    addEventListener(name, callback) {
      listeners.set(name, callback);
    },
    removeEventListener(name) {
      listeners.delete(name);
    },
    startNotifications() {
      return Promise.resolve(this);
    },
  };
  const commandCharacteristic = {
    writeValueWithResponse(value) {
      writtenBytes = Array.from(value);
      return Promise.resolve();
    },
  };
  const service = {
    getCharacteristic(uuid) {
      return Promise.resolve(
        uuid === stateUuid ? stateCharacteristic : commandCharacteristic,
      );
    },
  };
  const deviceListeners = new Map();
  const device = {
    addEventListener(name, callback) {
      deviceListeners.set(name, callback);
    },
    removeEventListener(name) {
      deviceListeners.delete(name);
    },
    gatt: {
      connected: true,
      connect() {
        return Promise.resolve({
          getPrimaryService(uuid) {
            assert.equal(uuid, serviceUuid);
            return Promise.resolve(service);
          },
        });
      },
      disconnect() {
        this.connected = false;
      },
    },
  };
  const bridge = await loadBridge({
    requestDevice(options) {
      requestOptions = options;
      return Promise.resolve(device);
    },
  });

  assert.equal(bridge.isSupported(), true);
  const selected = await bridge.requestDevice(serviceUuid);
  assert.equal(selected, device);
  assert.equal(requestOptions.filters.length, 1);
  assert.equal(requestOptions.filters[0].services[0], serviceUuid);
  const server = await bridge.connect(selected);
  const state = await bridge.getCharacteristic(server, serviceUuid, stateUuid);
  const command = await bridge.getCharacteristic(server, serviceUuid, commandUuid);

  bridge.addNotificationListener(state, 1, (bytes) => {
    assert.deepEqual(bytes, [0xe7, 4, 1, 0, 65]);
  });
  await bridge.startNotifications(state);
  listeners.get("characteristicvaluechanged")({
    target: { value: new DataView(new Uint8Array([0xe7, 4, 1, 0, 65]).buffer) },
  });

  bridge.addDisconnectListener(selected, 2, () => {
    disconnected = true;
  });
  deviceListeners.get("gattserverdisconnected")();
  await bridge.write(command, [0xe7, 5, 1, 0, 65]);
  assert.deepEqual(writtenBytes, [0xe7, 5, 1, 0, 65]);
  assert.equal(disconnected, true);

  bridge.removeNotificationListener(state, 1);
  bridge.removeDisconnectListener(selected, 2);
  assert.equal(listeners.size, 0);
  assert.equal(deviceListeners.size, 0);
});

test("reports Web Bluetooth unavailable when the browser lacks the API", async () => {
  const bridge = await loadBridge(undefined);
  assert.equal(bridge.isSupported(), false);
});
