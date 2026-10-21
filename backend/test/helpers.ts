import type { Router } from 'express';

import { createApp } from '../src/app.js';
import type { TokenVerifier } from '../src/middleware/auth.js';

/** Test tokens look like "test:<uid>"; anything else is rejected like a bad token. */
export const fakeVerifier: TokenVerifier = async (token) => {
  const uid = /^test:([\w-]+)$/.exec(token)?.[1];
  if (!uid) throw new Error('invalid token');
  return { uid, email: `${uid}@example.com`, emailVerified: true };
};

export function bearer(uid: string) {
  return { Authorization: `Bearer test:${uid}` };
}

export function testApp(routers: Router[] = []) {
  return createApp({
    nodeEnv: 'test',
    corsOrigins: ['http://localhost:5100'],
    verifyIdToken: fakeVerifier,
    routers,
  });
}
