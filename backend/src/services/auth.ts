import { createHash, randomBytes, randomUUID, timingSafeEqual } from 'node:crypto';

import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';

import { ACCESS_TOKEN_TTL_SECONDS, signAccessToken } from '../middleware/auth.js';
import { HttpError } from '../middleware/errors.js';
import { RefreshToken } from '../models/refreshToken.js';
import { User } from '../models/user.js';
import { Vehicle } from '../models/vehicle.js';
import { badRequest, conflict, isDuplicateKeyError } from './errors.js';
import { userJson, type UserRecord, type VehicleRecord } from './serialize.js';
import { findVerifiedVehicle, vehicleMatches, type VehicleDetails } from './vehicles.js';

const BCRYPT_ROUNDS = process.env.NODE_ENV === 'test' ? 4 : 12;
export const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

// Compared against when the email is unknown, so response time does not reveal
// which emails have accounts.
const DUMMY_HASH = bcrypt.hashSync('not-a-real-password-for-timing', BCRYPT_ROUNDS);

const invalidCredentials = () =>
  new HttpError(401, 'invalid_credentials', 'Email or password is incorrect.');
const invalidRefreshToken = () =>
  new HttpError(401, 'unauthenticated', 'Your sign-in has expired. Please sign in again.');

export type TokenPair = {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
};

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

async function issueRefreshToken(userId: string, familyId: string): Promise<string> {
  const id = randomUUID();
  const secret = randomBytes(32).toString('base64url');
  await RefreshToken.create({
    _id: id,
    userId,
    familyId,
    secretHash: sha256(secret),
    expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
  });
  return `${id}.${secret}`;
}

async function issueTokens(
  jwtSecret: string,
  user: { uid: string; email: string },
  familyId: string = randomUUID(),
): Promise<TokenPair> {
  return {
    accessToken: await signAccessToken(jwtSecret, user),
    accessTokenExpiresIn: ACCESS_TOKEN_TTL_SECONDS,
    refreshToken: await issueRefreshToken(user.uid, familyId),
  };
}

/** Finds a stored refresh token whose secret matches, or null. */
async function findRefreshToken(token: string) {
  const [id, secret] = token.split('.');
  if (!id || !secret) return null;
  const stored = await RefreshToken.findById(id);
  if (!stored) return null;
  const expected = Buffer.from(stored.secretHash, 'hex');
  const actual = Buffer.from(sha256(secret), 'hex');
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;
  return stored;
}

export type SignUpInput = VehicleDetails & {
  name: string;
  email: string;
  password: string;
  phone?: string;
  city?: string;
};

/**
 * Sign-up: verifies the vehicle, claims it and creates the account with a
 * hashed password in one transaction. On any error nothing is saved.
 */
export async function signUp(input: SignUpInput): Promise<VehicleRecord> {
  const email = input.email.trim().toLowerCase();
  const verified = await findVerifiedVehicle(input);
  if (await User.exists({ email })) {
    throw conflict('An account already exists for this email. Please log in.', 'email_taken');
  }
  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
  const uid = randomUUID();
  try {
    await mongoose.connection.transaction(async (session) => {
      const claimed = await Vehicle.findOneAndUpdate(
        { _id: verified._id, ownerUid: null, isActive: true },
        { ownerUid: uid },
        { session, new: true },
      ).lean<VehicleRecord>();
      if (!claimed) {
        throw conflict(
          'This vehicle is already linked to another account.',
          'vehicle_already_claimed',
        );
      }
      if (!vehicleMatches(input, claimed)) {
        throw badRequest('Vehicle details could not be verified.', 'vehicle_not_verified');
      }
      await User.create(
        [
          {
            _id: uid,
            name: input.name,
            email,
            passwordHash,
            phone: input.phone ?? '',
            city: input.city ?? '',
            vehicleId: claimed._id,
            vehicleRegistrationNumber: claimed.registrationNumber,
          },
        ],
        { session },
      );
    });
  } catch (error) {
    if (isDuplicateKeyError(error)) {
      throw conflict('An account already exists for this email. Please log in.', 'email_taken');
    }
    throw error;
  }
  return { ...verified, ownerUid: uid };
}

export async function login(
  jwtSecret: string,
  emailInput: string,
  password: string,
): Promise<TokenPair & { user: ReturnType<typeof userJson> }> {
  const email = emailInput.trim().toLowerCase();
  const user = await User.findOne({ email })
    .select('+passwordHash')
    .lean<UserRecord & { passwordHash: string }>();
  const matches = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
  if (!user || !matches) throw invalidCredentials();
  const { passwordHash: _hash, ...profile } = user;
  const tokens = await issueTokens(jwtSecret, { uid: user._id, email: user.email });
  return { ...tokens, user: userJson(profile) };
}

/** Rotates a refresh token. Reusing an already-rotated token revokes all of the user's tokens. */
export async function refresh(jwtSecret: string, token: string): Promise<TokenPair> {
  const stored = await findRefreshToken(token);
  if (!stored) throw invalidRefreshToken();
  if (stored.revokedAt) {
    if (stored.replacedBy) {
      // A stolen, already-used token: end every session of this user.
      await RefreshToken.updateMany(
        { userId: stored.userId, revokedAt: null },
        { revokedAt: new Date() },
      );
    }
    throw invalidRefreshToken();
  }
  if (stored.expiresAt.getTime() <= Date.now()) throw invalidRefreshToken();
  const user = await User.findById(stored.userId).lean<UserRecord>();
  if (!user) throw invalidRefreshToken();

  const tokens = await issueTokens(
    jwtSecret,
    { uid: user._id, email: user.email },
    stored.familyId,
  );
  const [newId] = tokens.refreshToken.split('.');
  // Only one concurrent refresh can win; the loser is treated as reuse.
  const rotated = await RefreshToken.updateOne(
    { _id: stored._id, revokedAt: null },
    { revokedAt: new Date(), replacedBy: newId },
  );
  if (rotated.modifiedCount !== 1) {
    await RefreshToken.deleteOne({ _id: newId });
    throw invalidRefreshToken();
  }
  return tokens;
}

/** Ends a session. Unknown or already-revoked tokens are ignored. */
export async function logout(token: string): Promise<void> {
  const stored = await findRefreshToken(token);
  if (!stored) return;
  await RefreshToken.updateMany(
    { familyId: stored.familyId, revokedAt: null },
    { revokedAt: new Date() },
  );
}

/** Changes the password, ends every other session and returns fresh tokens. */
export async function changePassword(
  jwtSecret: string,
  uid: string,
  currentPassword: string,
  newPassword: string,
): Promise<TokenPair> {
  const user = await User.findById(uid)
    .select('+passwordHash')
    .lean<UserRecord & { passwordHash: string }>();
  if (!user || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
    throw new HttpError(400, 'invalid_credentials', 'The current password is incorrect.');
  }
  const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  await User.updateOne({ _id: uid }, { passwordHash });
  await RefreshToken.updateMany({ userId: uid, revokedAt: null }, { revokedAt: new Date() });
  return issueTokens(jwtSecret, { uid, email: user.email });
}
