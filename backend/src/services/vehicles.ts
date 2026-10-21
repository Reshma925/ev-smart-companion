// Vehicle verification, linking and switching, ported from the original
// backend. A vehicle is claimed atomically through vehicles.ownerUid.
import { ChargingCard } from '../models/chargingCard.js';
import { normalizeRegistration, normalizeVin } from '../models/common.js';
import { User } from '../models/user.js';
import { Vehicle } from '../models/vehicle.js';
import { badRequest, conflict, notFound, vehicleNotFound } from './errors.js';
import type { VehicleRecord } from './serialize.js';

export type VehicleDetails = {
  registrationNumber: string;
  model: string;
  ownerName: string;
  vin: string;
};

const normalizeText = (value: string) => value.trim().replace(/\s+/g, ' ').toLowerCase();

export function vehicleMatches(details: VehicleDetails, vehicle: VehicleRecord | null): boolean {
  return (
    vehicle?.isActive === true &&
    normalizeRegistration(vehicle.registrationNumber) ===
      normalizeRegistration(details.registrationNumber) &&
    normalizeText(vehicle.model) === normalizeText(details.model) &&
    normalizeText(vehicle.ownerName) === normalizeText(details.ownerName) &&
    normalizeVin(vehicle.vin) === normalizeVin(details.vin)
  );
}

const notVerified = () =>
  badRequest('Vehicle details could not be verified.', 'vehicle_not_verified');

export async function findVerifiedVehicle(details: VehicleDetails): Promise<VehicleRecord> {
  const candidates = await Vehicle.find({
    registrationNumber: normalizeRegistration(details.registrationNumber),
    isActive: true,
  })
    .limit(2)
    .lean<VehicleRecord[]>();
  const [only] = candidates;
  if (candidates.length !== 1 || !only || !vehicleMatches(details, only)) throw notVerified();
  return only;
}

/**
 * The single ownership check for every route with a vehicleId. Someone else's
 * vehicle (or a missing one) is reported as 404 so IDs cannot be probed.
 */
export async function requireOwnedVehicle(
  uid: string,
  vehicleId: string,
  options: { requireActive?: boolean } = {},
): Promise<VehicleRecord> {
  const vehicle = await Vehicle.findById(vehicleId).lean<VehicleRecord>();
  if (!vehicle || vehicle.ownerUid !== uid) throw vehicleNotFound();
  if ((options.requireActive ?? true) && vehicle.isActive !== true) {
    throw conflict('The linked vehicle is unavailable or inactive.', 'vehicle_inactive');
  }
  return vehicle;
}

export async function linkVehicle(uid: string, details: VehicleDetails): Promise<VehicleRecord> {
  const verified = await findVerifiedVehicle(details);
  if (!(await User.exists({ _id: uid }))) {
    throw conflict('Create a user profile first.', 'profile_missing');
  }
  if (verified.ownerUid === uid) return verified;
  const claimed = await Vehicle.findOneAndUpdate(
    { _id: verified._id, ownerUid: null, isActive: true },
    { ownerUid: uid },
    { new: true },
  ).lean<VehicleRecord>();
  if (!claimed) {
    throw conflict('This vehicle is already linked to another account.', 'vehicle_already_claimed');
  }
  return claimed;
}

export async function listOwnedVehicles(uid: string): Promise<VehicleRecord[]> {
  return Vehicle.find({ ownerUid: uid, isActive: true })
    .sort({ model: 1, _id: 1 })
    .lean<VehicleRecord[]>();
}

export async function setConnectedVehicle(uid: string, vehicleId: string): Promise<string> {
  const vehicle = await requireOwnedVehicle(uid, vehicleId);
  const updated = await User.updateOne(
    { _id: uid },
    { vehicleId: vehicle._id, vehicleRegistrationNumber: vehicle.registrationNumber },
  );
  if (updated.matchedCount === 0) throw notFound('Create a user profile first.', 'profile_missing');
  return vehicle._id;
}

/** The connected vehicle, if it is still owned and active; otherwise null. */
export async function getConnectedVehicle(uid: string): Promise<VehicleRecord | null> {
  const user = await User.findById(uid).lean();
  if (!user?.vehicleId) return null;
  const vehicle = await Vehicle.findById(user.vehicleId).lean<VehicleRecord>();
  return vehicle && vehicle.ownerUid === uid && vehicle.isActive === true ? vehicle : null;
}

/** Matches the typed details against the user's connected vehicle. */
export async function verifyConnectedVehicleDetails(
  uid: string,
  details: VehicleDetails,
): Promise<VehicleRecord | null> {
  const vehicle = await getConnectedVehicle(uid);
  return vehicle && vehicleMatches(details, vehicle) ? vehicle : null;
}

export async function updateVehicleConfiguration(
  uid: string,
  vehicleId: string,
  input: { maximumRangeKm: number; batteryCapacityKwh?: number | null; connectorType: string },
): Promise<VehicleRecord> {
  await requireOwnedVehicle(uid, vehicleId, { requireActive: false });
  const updates: Record<string, unknown> = {
    maximumRangeKm: input.maximumRangeKm,
    connectorType: input.connectorType,
  };
  // As before, a missing capacity keeps the stored value.
  if (input.batteryCapacityKwh !== undefined && input.batteryCapacityKwh !== null) {
    updates.batteryCapacityKwh = input.batteryCapacityKwh;
  }
  const vehicle = await Vehicle.findByIdAndUpdate(vehicleId, updates, {
    new: true,
    runValidators: true,
  }).lean<VehicleRecord>();
  if (!vehicle) throw vehicleNotFound();
  // Replaces the syncVehicleChargingCardDetails trigger.
  await ChargingCard.updateMany(
    { vehicleId, uid },
    {
      vehicleModel: vehicle.model,
      vehicleRegistrationNumber: vehicle.registrationNumber,
      vehicleVin: vehicle.vin,
    },
  );
  return vehicle;
}
