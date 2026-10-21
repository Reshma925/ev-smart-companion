import type { Request, RequestHandler } from 'express';
import { jwtVerify, SignJWT } from 'jose';

import type { AuthUser } from '../types.js';
import { HttpError } from './errors.js';

/** Verifies an access token. Injected so tests can use simple fake tokens. */
export type TokenVerifier = (accessToken: string) => Promise<AuthUser>;

export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
const ISSUER = 'ev-smart-companion-api';
const AUDIENCE = 'ev-smart-companion-app';

function secretKey(secret: string): Uint8Array {
  return new TextEncoder().encode(secret);
}

/** Signs a short-lived HS256 access token for the given user. */
export async function signAccessToken(
  secret: string,
  user: { uid: string; email: string },
): Promise<string> {
  return new SignJWT({ email: user.email, typ: 'access' })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(user.uid)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(secretKey(secret));
}

export function createJwtVerifier(secret: string): TokenVerifier {
  const key = secretKey(secret);
  return async (accessToken) => {
    const { payload } = await jwtVerify(accessToken, key, {
      algorithms: ['HS256'],
      issuer: ISSUER,
      audience: AUDIENCE,
    });
    if (payload.typ !== 'access' || typeof payload.sub !== 'string' || !payload.sub) {
      throw new Error('Not an access token.');
    }
    return {
      uid: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : null,
      emailVerified: false,
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
