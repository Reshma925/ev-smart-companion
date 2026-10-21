import type { Request, RequestHandler } from 'express';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

import type { AuthUser } from '../types.js';
import { HttpError } from './errors.js';

/** Verifies a Firebase ID token. Injected so tests never call Google. */
export type TokenVerifier = (idToken: string) => Promise<AuthUser>;

const firebaseAppName = 'ev-backend';

/** Only the project ID is needed: ID tokens are checked against Google's public keys. */
export function createFirebaseTokenVerifier(projectId: string): TokenVerifier {
  const app =
    getApps().find((existing) => existing.name === firebaseAppName) ??
    initializeApp({ projectId }, firebaseAppName);
  const auth = getAuth(app);
  return async (idToken) => {
    const decoded = await auth.verifyIdToken(idToken);
    return {
      uid: decoded.uid,
      email: decoded.email ?? null,
      emailVerified: decoded.email_verified === true,
    };
  };
}

export function requireAuth(verify: TokenVerifier): RequestHandler {
  return async (req, _res, next) => {
    const header = req.headers.authorization ?? '';
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    if (!match?.[1]) {
      throw new HttpError(401, 'unauthenticated', 'Sign in to continue.');
    }
    try {
      req.user = await verify(match[1]);
    } catch {
      throw new HttpError(
        401,
        'unauthenticated',
        'Your sign-in has expired. Please sign in again.',
      );
    }
    next();
  };
}

/** For handlers behind requireAuth. */
export function currentUser(req: Request): AuthUser {
  if (!req.user) throw new HttpError(401, 'unauthenticated', 'Sign in to continue.');
  return req.user;
}
