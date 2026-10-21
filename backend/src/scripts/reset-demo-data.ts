// Removes all accounts and everything tied to them (cards, transactions,
// PayPal orders, maintenance, preferences, photos, sessions, login sessions)
// and makes every vehicle claimable again. Vehicles themselves are kept.
// Used when the login system changed; safe to run on demo data only.
import mongoose from 'mongoose';

import { loadDatabaseEnv } from '../config/env.js';
import { connectDatabase, disconnectDatabase } from '../db/connect.js';
import * as models from '../models/index.js';
import { Vehicle } from '../models/vehicle.js';

const collectionsToClear = [
  'users',
  'refreshTokens',
  'chargingCards',
  'cardTransactions',
  'paypalOrders',
  'chargingSessions',
  'maintenanceRecords',
  'controlsPreferences',
  'profilePhotos',
];

const env = loadDatabaseEnv();
await connectDatabase({ uri: env.mongodbUri, dbName: env.mongodbDbName, autoIndex: false });

let exitCode = 0;
try {
  const db = mongoose.connection.db;
  if (!db) throw new Error('Not connected.');
  const existing = new Set((await db.listCollections().toArray()).map((c) => c.name));
  for (const name of collectionsToClear) {
    if (!existing.has(name)) {
      console.log(`${name}: not present`);
      continue;
    }
    const count = await db.collection(name).countDocuments();
    // Dropping also removes indexes from the previous login system.
    await db.collection(name).drop();
    console.log(`${name}: removed ${count} document(s)`);
  }
  // (sanitizeFilter blocks $-operators in filters, so update every vehicle.)
  const released = await Vehicle.updateMany({}, { ownerUid: null });
  console.log(
    `vehicles: kept ${await Vehicle.countDocuments()}, released ${released.modifiedCount}`,
  );
  for (const model of Object.values(models)) {
    if (typeof model === 'function' && 'createIndexes' in model) await model.createIndexes();
  }
  console.log('indexes: rebuilt');
} catch (error) {
  console.error('Reset failed:', error instanceof Error ? error.message : error);
  exitCode = 1;
} finally {
  await disconnectDatabase();
}
process.exit(exitCode);
