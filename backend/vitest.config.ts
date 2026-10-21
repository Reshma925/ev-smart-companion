import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    setupFiles: ['./test/setup.ts'],
    // One in-memory MongoDB replica set per worker; transactions need a replica set.
    fileParallelism: false,
    hookTimeout: 120_000,
    testTimeout: 30_000,
  },
});
