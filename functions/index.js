const admin = require("firebase-admin");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const backend = require("./card_backend");
const learningAssistant = require("./learning_assistant");

admin.initializeApp();
const db = getFirestore();
const geminiApiKey = defineSecret("GEMINI_API_KEY");

function authenticatedUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to continue.");
  return uid;
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  const message = error instanceof Error ? error.message : "Request failed.";
  const code = message.includes("Insufficient charging card balance")
    ? "resource-exhausted"
    : message.includes("already")
      ? "already-exists"
      : "failed-precondition";
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

exports.askEvLearningAssistant = onCall(
  { secrets: [geminiApiKey], timeoutSeconds: 35 },
  async (request) => {
    console.info("[AI DEBUG] Function called: askEvLearningAssistant");
    const apiKey = geminiApiKey.value();
    if (apiKey) {
      console.info("[GEMINI DEBUG] GEMINI_API_KEY is available to function.");
    } else {
      console.error("[GEMINI ERROR] Missing GEMINI_API_KEY in function environment.");
    }
    console.info("[AI DEBUG] Request started at Firebase callable");
    console.info("[AI DEBUG] Provider: Google Gemini");
    console.info("[AI DEBUG] Endpoint: askEvLearningAssistant Firebase callable");
    console.info("[AI DEBUG] Request model: gemini-flash-latest");
    if (!request.auth?.uid) {
      const error = new HttpsError(
        "unauthenticated",
        "Sign in to use the EV assistant.",
      );
      console.error("[AI ERROR] Type:", error.name);
      console.error("[AI ERROR] Message:", error.message);
      console.error("[AI ERROR] HTTP status: not available at callable layer");
      console.error("[AI ERROR] Response body: not available at callable layer");
      console.error("[AI ERROR] Stack trace:", error.stack);
      throw error;
    }
    try {
      const answer = await learningAssistant.askLearningAssistant({
        message: request.data?.message,
        topic: request.data?.topic,
        context: request.data?.context,
        apiKey,
      });
      return { success: true, answer };
    } catch (error) {
      console.error("[AI ERROR] Type:", error?.name || typeof error);
      console.error("[AI ERROR] Message:", error?.message || "Unknown error");
      console.error(
        "[AI ERROR] HTTP status: see provider diagnostics above, if available",
      );
      console.error(
        "[AI ERROR] Response body: see provider diagnostics above, if available",
      );
      console.error("[AI ERROR] Stack trace:", error?.stack || "unavailable");
      const allowedCodes = new Set([
        "invalid-argument",
        "failed-precondition",
        "unavailable",
        "internal",
      ]);
      const code = allowedCodes.has(error?.code) ? error.code : "internal";
      if (code === "invalid-argument") {
        throw new HttpsError(code, error.message);
      }
      if (code === "failed-precondition") {
        throw new HttpsError(
          code,
          "The EV learning assistant is not configured yet.",
        );
      }
      throw new HttpsError(
        code,
        "The EV learning assistant is temporarily unavailable.",
      );
    }
  },
);

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

exports.debitConfirmedChargingSession = onCall(async (request) => {
  try {
    return await backend.debitConfirmedChargingSession({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      sessionId: request.data?.sessionId,
    });
  } catch (error) {
    throw mapError(error);
  }
});

exports.syncVehicleChargingCardDetails = onDocumentUpdated(
  "vehicles/{vehicleId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (
      before.model === after.model &&
      before.registrationNumber === after.registrationNumber &&
      before.vin === after.vin
    ) {
      return;
    }
    await backend.syncVehicleCardSnapshots({
      db,
      vehicleId: event.params.vehicleId,
      vehicleData: after,
    });
  },
);
