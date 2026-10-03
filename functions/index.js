const admin = require("firebase-admin");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const backend = require("./card_backend");

admin.initializeApp();
const db = getFirestore();

function authenticatedUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  const message = error instanceof Error ? error.message : "Request failed.";
  const code = message.includes("already") ? "already-exists" : "failed-precondition";
  return new HttpsError(code, message);
}

exports.verifyAndCreateUserProfile = onCall(async (request) => {
  try {
    const uid = authenticatedUid(request);
    const vehicle = await backend.verifyAndCreateUserProfile({
      db,
      Timestamp,
      uid,
      authEmail: request.auth.token.email,
      data: request.data,
    });
    return { vehicle };
  } catch (error) {
    throw mapError(error);
  }
});

exports.linkVerifiedVehicle = onCall(async (request) => {
  try {
    const vehicle = await backend.linkVerifiedVehicle({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      data: request.data,
    });
    return { vehicle };
  } catch (error) {
    throw mapError(error);
  }
});

exports.setConnectedVehicle = onCall(async (request) => {
  try {
    return await backend.setConnectedVehicle({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      vehicleId: request.data?.vehicleId,
    });
  } catch (error) {
    throw mapError(error);
  }
});

exports.getLegacyChargingCardSummary = onCall(async (request) => {
  try {
    const card = await backend.getLegacyChargingCardSummary({
      db,
      uid: authenticatedUid(request),
      vehicleId: request.data?.vehicleId,
    });
    return { card };
  } catch (error) {
    throw mapError(error);
  }
});

exports.migrateLegacyChargingCard = onCall(async (request) => {
  try {
    return await backend.migrateLegacyChargingCard({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      vehicleId: request.data?.vehicleId,
    });
  } catch (error) {
    throw mapError(error);
  }
});
