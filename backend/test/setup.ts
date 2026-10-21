import { MongoMemoryReplSet } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { afterAll, afterEach, beforeAll } from 'vitest';

import '../src/db/connect.js';

let replSet: MongoMemoryReplSet | undefined;

beforeAll(async () => {
  replSet = await MongoMemoryReplSet.create({ replSet: { count: 1, storageEngine: 'wiredTiger' } });
  await mongoose.connect(replSet.getUri(), { dbName: 'ev_companion_test' });
});

afterEach(async () => {
  const collections = await mongoose.connection.db?.collections();
  for (const collection of collections ?? []) await collection.deleteMany({});
});

afterAll(async () => {
  await mongoose.disconnect();
  await replSet?.stop();
});
