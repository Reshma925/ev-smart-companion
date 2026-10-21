// Inserts or repairs the demo vehicles. Safe to run repeatedly: it never
// changes ownerUid (a claimed vehicle stays claimed) and never overwrites a
// range or connector a user configured in the app. No telemetry is seeded:
// live vehicle data comes only from the BLE simulator.
import { loadDatabaseEnv } from '../config/env.js';
import { connectDatabase, disconnectDatabase } from '../db/connect.js';
import * as models from '../models/index.js';
import { Vehicle } from '../models/vehicle.js';

type SeedVehicle = {
  _id: string;
  identity: {
    registrationNumber: string;
    model: string;
    ownerName: string;
    vin: string;
    bluetoothDeviceId: string;
    bluetoothDeviceName: string;
    isActive: boolean;
  };
  // Only filled in when empty. 350 km matches the simulator (range = battery % × 3.5).
  configuration: { maximumRangeKm: number; connectorType: string };
};

const seedVehicles: SeedVehicle[] = [
  {
    _id: 'EV001',
    identity: {
      registrationNumber: 'TN01AB1234',
      model: 'EV Smart X1',
      ownerName: 'Registered Vehicle Owner 1',
      vin: 'EVVIN001',
      bluetoothDeviceId: 'EV-SIM-001',
      bluetoothDeviceName: 'EV-Simulator-01',
      isActive: true,
    },
    configuration: { maximumRangeKm: 350, connectorType: 'CCS2' },
  },
  {
    _id: 'EV002',
    identity: {
      registrationNumber: 'TN02CD5678',
      model: 'EV Smart X2',
      ownerName: 'Registered Vehicle Owner 2',
      vin: 'EVVIN002',
      bluetoothDeviceId: 'EV-SIM-002',
      bluetoothDeviceName: 'EV-Simulator-02',
      isActive: true,
    },
    configuration: { maximumRangeKm: 350, connectorType: 'CCS2' },
  },
];

const env = loadDatabaseEnv();
await connectDatabase({ uri: env.mongodbUri, dbName: env.mongodbDbName, autoIndex: false });

let exitCode = 0;
try {
  for (const model of Object.values(models)) {
    if (typeof model === 'function' && 'createIndexes' in model) await model.createIndexes();
  }

  for (const seed of seedVehicles) {
    const existing = await Vehicle.findById(seed._id).lean();
    if (!existing) {
      await Vehicle.create({ _id: seed._id, ...seed.identity, ...seed.configuration });
      console.log(`${seed._id}: created`);
      continue;
    }
    const updates: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(seed.identity)) {
      if ((existing as Record<string, unknown>)[key] !== value) updates[key] = value;
    }
    for (const [key, value] of Object.entries(seed.configuration)) {
      const current = (existing as Record<string, unknown>)[key];
      if (current === null || current === undefined || current === '') updates[key] = value;
    }
    if (Object.keys(updates).length === 0) {
      console.log(
        `${seed._id}: skipped (already up to date${existing.ownerUid ? ', claimed' : ''})`,
      );
      continue;
    }
    await Vehicle.updateOne({ _id: seed._id }, updates, { runValidators: true });
    console.log(`${seed._id}: updated ${Object.keys(updates).join(', ')} (ownerUid unchanged)`);
  }
} catch (error) {
  console.error('Seeding failed:', error instanceof Error ? error.message : error);
  exitCode = 1;
} finally {
  await disconnectDatabase();
}
process.exit(exitCode);
