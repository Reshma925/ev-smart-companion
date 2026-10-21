import mongoose from 'mongoose';

import { logger } from '../logger.js';

mongoose.set('strictQuery', true);
// Treats any object containing $-operators in a filter as a literal value,
// so a body like {"email": {"$gt": ""}} cannot widen a query.
mongoose.set('sanitizeFilter', true);

export async function connectDatabase(options: {
  uri: string;
  dbName: string;
  autoIndex: boolean;
}): Promise<typeof mongoose> {
  try {
    const connection = await mongoose.connect(options.uri, {
      dbName: options.dbName,
      autoIndex: options.autoIndex,
      serverSelectionTimeoutMS: 15_000,
    });
    logger.info({ dbName: options.dbName }, 'Connected to MongoDB');
    return connection;
  } catch (error) {
    const name = error instanceof Error ? error.name : 'Error';
    logger.error(
      { errorName: name },
      'Could not connect to MongoDB. Check MONGODB_URI, the database user password and Atlas Network Access.',
    );
    throw error;
  }
}

export async function disconnectDatabase(): Promise<void> {
  await mongoose.disconnect();
}
