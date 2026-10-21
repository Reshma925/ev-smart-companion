import { Router } from 'express';
import { z } from 'zod';

import { currentUser } from '../middleware/auth.js';
import { validate, validBody } from '../middleware/validate.js';
import { MAX_PROFILE_PHOTO_BYTES, ProfilePhoto } from '../models/profilePhoto.js';
import { User } from '../models/user.js';
import { badRequest, notFound } from '../services/errors.js';
import { userJson, vehicleJson, type UserRecord } from '../services/serialize.js';
import {
  getConnectedVehicle,
  linkVehicle,
  listOwnedVehicles,
  setConnectedVehicle,
} from '../services/vehicles.js';
import { isoDate, requiredText, text, vehicleDetails, vehicleIdParams } from './schemas.js';

// Only the fields a user may change. Email comes from the token,
// the connected vehicle from PUT /v1/me/connected-vehicle, the photo from PUT /v1/me/photo.
const updateProfileSchema = z.object({
  name: requiredText(128).optional(),
  phone: text(32)
    .refine(
      (value) => value === '' || /^[+()\d\s-]{7,32}$/.test(value),
      'must be a valid phone number',
    )
    .optional(),
  city: text(80).optional(),
  dateOfBirth: isoDate.nullable().optional(),
  preferredDrivingMode: text(40).optional(),
  preferredChargingMode: text(40).optional(),
  notificationPreference: text(40).optional(),
  distanceUnit: z.enum(['km', 'mi']).optional(),
  notificationsEnabled: z.boolean().optional(),
  locationEnabled: z.boolean().optional(),
});

const photoSchema = z.object({
  contentType: z.enum(['image/jpeg', 'image/png']),
  // 300 KB of bytes is at most 409,600 base64 characters.
  base64: z.string().max(Math.ceil(MAX_PROFILE_PHOTO_BYTES / 3) * 4 + 4),
});

const connectedVehicleSchema = vehicleIdParams;

function matchesMagicNumber(bytes: Buffer, contentType: 'image/jpeg' | 'image/png'): boolean {
  if (contentType === 'image/jpeg') {
    return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  return (
    bytes.length > 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  );
}

async function requireProfile(uid: string) {
  const user = await User.findById(uid).lean<UserRecord>();
  if (!user) throw notFound('No profile exists for this account yet.', 'profile_not_found');
  return user;
}

export function meRouter() {
  const router = Router();

  router.get('/me', async (req, res) => {
    res.json(userJson(await requireProfile(currentUser(req).uid)));
  });

  router.patch('/me', validate({ body: updateProfileSchema }), async (req, res) => {
    const { uid } = currentUser(req);
    const updates = validBody(req, updateProfileSchema);
    const user = await User.findByIdAndUpdate(uid, updates, {
      new: true,
      runValidators: true,
    }).lean<UserRecord>();
    if (!user) throw notFound('No profile exists for this account yet.', 'profile_not_found');
    res.json(userJson(user));
  });

  router.put('/me/photo', validate({ body: photoSchema }), async (req, res) => {
    const { uid } = currentUser(req);
    const { contentType, base64 } = validBody(req, photoSchema);
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(base64)) throw badRequest('The photo is not valid base64.');
    const bytes = Buffer.from(base64, 'base64');
    if (bytes.length === 0 || bytes.length > MAX_PROFILE_PHOTO_BYTES) {
      throw badRequest('The photo must be at most 300 KB.', 'photo_too_large');
    }
    if (!matchesMagicNumber(bytes, contentType)) {
      throw badRequest('The photo must be a real JPEG or PNG image.', 'photo_invalid_type');
    }
    await requireProfile(uid);
    // A document save (not an update) so the size validator sees the real Buffer.
    const photo = (await ProfilePhoto.findById(uid)) ?? new ProfilePhoto({ _id: uid });
    photo.contentType = contentType;
    photo.data = bytes;
    await photo.save();
    // The version query makes clients refetch after a change.
    const profileImageUrl = `/v1/me/photo?v=${Date.now()}`;
    await User.updateOne({ _id: uid }, { profileImageUrl });
    res.json({ profileImageUrl });
  });

  router.get('/me/photo', async (req, res) => {
    const photo = await ProfilePhoto.findById(currentUser(req).uid);
    if (!photo) throw notFound('No profile photo has been uploaded.', 'photo_not_found');
    res.set('Content-Type', photo.contentType);
    res.set('Cache-Control', 'private, max-age=0, must-revalidate');
    res.send(Buffer.from(photo.data));
  });

  router.post('/me/vehicles', validate({ body: z.object(vehicleDetails) }), async (req, res) => {
    const body = validBody(req, z.object(vehicleDetails));
    const vehicle = await linkVehicle(currentUser(req).uid, body);
    res.status(201).json({ vehicle: vehicleJson(vehicle) });
  });

  router.get('/me/vehicles', async (req, res) => {
    const vehicles = await listOwnedVehicles(currentUser(req).uid);
    res.json({ vehicles: vehicles.map(vehicleJson) });
  });

  router.put(
    '/me/connected-vehicle',
    validate({ body: connectedVehicleSchema }),
    async (req, res) => {
      const { vehicleId } = validBody(req, connectedVehicleSchema);
      res.json({ vehicleId: await setConnectedVehicle(currentUser(req).uid, vehicleId) });
    },
  );

  router.get('/me/connected-vehicle', async (req, res) => {
    const vehicle = await getConnectedVehicle(currentUser(req).uid);
    res.json({ vehicle: vehicle ? vehicleJson(vehicle) : null });
  });

  return router;
}
