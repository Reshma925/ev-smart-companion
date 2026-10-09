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
const paypalClientId = defineSecret("PAYPAL_CLIENT_ID");
const paypalClientSecret = defineSecret("PAYPAL_CLIENT_SECRET");

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
    : message.includes("Recharge amount") ||
        message.includes("Recharge currency")
      ? "invalid-argument"
      : message.includes("already")
      ? "already-exists"
      : "failed-precondition";
  return new HttpsError(code, message);
}

function paypalCredentials() {
  let clientId = "";
  let clientSecret = "";
  try {
    clientId = paypalClientId.value();
  } catch (error) {
    console.error("[PayPal Recharge] Could not read local client ID secret.", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
  }
  try {
    clientSecret = paypalClientSecret.value();
  } catch (error) {
    console.error("[PayPal Recharge] Could not read local client secret.", {
      name: error instanceof Error ? error.name : "UnknownError",
    });
  }
  console.info(
    `[PayPal Recharge] PayPal client ID configured: ${Boolean(clientId)}`,
  );
  console.info(
    `[PayPal Recharge] PayPal client secret configured: ${Boolean(clientSecret)}`,
  );
  if (!clientId || !clientSecret) {
    throw new HttpsError(
      "failed-precondition",
      "PayPal Sandbox credentials are not configured for the local emulator.",
    );
  }
  return { paypalClientId: clientId, paypalClientSecret: clientSecret };
}

function mapPayPalError(error, operation) {
  if (error instanceof HttpsError) return error;
  if (error instanceof backend.PayPalApiError) {
    const metadata = {
      httpStatus: error.status,
      ...(error.paypalErrorName ? { paypalErrorName: error.paypalErrorName } : {}),
      ...(error.paypalMessage ? { paypalMessage: error.paypalMessage } : {}),
      ...(error.details?.length ? { details: error.details } : {}),
      ...(error.debugId ? { debugId: error.debugId } : {}),
    };
    console.error(`[PayPal Recharge] ${operation} failed.`, metadata);
    const details = [
      `HTTP ${error.status}`,
      ...(error.paypalErrorName ? [error.paypalErrorName] : []),
      ...(error.paypalMessage ? [error.paypalMessage] : []),
      ...(error.details ?? []).map((detail) =>
        [
          detail.issue,
          detail.field ? `field ${detail.field}` : undefined,
          detail.description,
        ]
          .filter(Boolean)
          .join(": "),
      ),
      ...(error.debugId ? [`debug_id ${error.debugId}`] : []),
    ].join(", ");
    return new HttpsError(
      error.status === 422 ? "invalid-argument" : "unavailable",
      `PayPal Sandbox ${operation} failed (${details}).`,
    );
  }
  console.error(`[PayPal Recharge] ${operation} failed.`, {
    name: error instanceof Error ? error.name : "UnknownError",
    message: error instanceof Error ? error.message : "Unknown error",
    stack: error instanceof Error ? error.stack : undefined,
  });
  return new HttpsError(
    "internal",
    `PayPal Sandbox ${operation} could not be completed. No balance was added.`,
  );
}

function mapRechargeCallError(error, operation) {
  if (error instanceof HttpsError) return error;
  const message = error instanceof Error ? error.message : "";
  if (message.includes("PayPal Sandbox credentials are not configured")) {
    return new HttpsError(
      "failed-precondition",
      "PayPal Sandbox credentials are not configured for the local emulator.",
    );
  }
  if (
    message.includes("vehicle") ||
    message.includes("charging card") ||
    message.includes("Recharge amount") ||
    message.includes("Recharge currency") ||
    message.includes("PayPal order")
  ) {
    return mapError(error);
  }
  return mapPayPalError(error, operation);
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

exports.createPayPalRechargeOrder = onCall({
  secrets: [paypalClientId, paypalClientSecret],
  timeoutSeconds: 30,
}, async (request) => {
  console.info("[PayPal Recharge] createPayPalRechargeOrder invoked");
  try {
    return await backend.createPayPalRechargeOrder({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      vehicleId: request.data?.vehicleId,
      amount: request.data?.amount,
      currency: request.data?.currency,
      ...paypalCredentials(),
    });
  } catch (error) {
    throw mapRechargeCallError(error, "order creation");
  }
});

exports.capturePayPalRechargeOrder = onCall({
  secrets: [paypalClientId, paypalClientSecret],
  timeoutSeconds: 30,
}, async (request) => {
  console.info("[PayPal Recharge] capturePayPalRechargeOrder invoked");
  console.info(
    `[PayPal Recharge] capture request authenticated: ${Boolean(request.auth?.uid)}`,
  );
  try {
    return await backend.capturePayPalRechargeOrder({
      db,
      Timestamp,
      uid: authenticatedUid(request),
      vehicleId: request.data?.vehicleId,
      orderId: request.data?.orderId,
      ...paypalCredentials(),
    });
  } catch (error) {
    throw mapRechargeCallError(error, "capture");
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
