const { createHash } = require("node:crypto");

const CARD_ID = "current";
const MIGRATION_TRANSACTION_LIMIT = 400;
const PAYPAL_API_BASE_URL = "https://api-m.sandbox.paypal.com";
const MAX_PAYPAL_RECHARGE_AMOUNT = 10000;
// Demo-only conversion for PayPal Sandbox; this is not a live exchange rate.
const DEMO_EXCHANGE_RATE_INR_TO_USD = 0.012;
const PAYPAL_SANDBOX_CURRENCY = "USD";

class PayPalApiError extends Error {
  constructor(operation, status, errorName, paypalMessage, details, debugId) {
    super(`PayPal ${operation} failed with HTTP ${status}.`);
    this.name = "PayPalApiError";
    this.status = status;
    this.paypalErrorName = errorName;
    this.paypalMessage = paypalMessage;
    this.details = details;
    this.debugId = debugId;
  }
}

function paypalOrderDocumentId(orderId) {
  return createHash("sha256").update(orderId).digest("hex");
}

function convertInrToPaypalAmount(inrAmount) {
  return Number(
    (inrAmount * DEMO_EXCHANGE_RATE_INR_TO_USD + Number.EPSILON).toFixed(2),
  );
}

async function throwPayPalApiError(operation, response) {
  let body = {};
  try {
    body = await response.json();
  } catch {
    // PayPal error metadata may be absent; never expose the raw response body.
  }
  const safeText = (value) =>
    typeof value === "string"
      ? value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, 500)
      : undefined;
  const details = Array.isArray(body.details)
    ? body.details
        .filter((detail) => detail && typeof detail === "object")
        .map((detail) => ({
          ...(safeText(detail.issue) ? { issue: safeText(detail.issue) } : {}),
          ...(safeText(detail.field) ? { field: safeText(detail.field) } : {}),
          ...(safeText(detail.description)
            ? { description: safeText(detail.description) }
            : {}),
        }))
    : [];
  const errorName = safeText(body.name) ?? safeText(body.error);
  const message = safeText(body.message);
  const debugId = safeText(body.debug_id);
  console.error(`[PayPal Recharge] ${operation} response diagnostics:`, {
    httpStatus: response.status,
    ...(errorName ? { name: errorName } : {}),
    ...(message ? { message } : {}),
    ...(details.length ? { details } : {}),
    ...(debugId ? { debug_id: debugId } : {}),
  });
  throw new PayPalApiError(
    operation,
    response.status,
    errorName,
    message,
    details,
    debugId,
  );
}

async function paypalRequest({
  operation,
  path,
  method = "GET",
  paypalClientId,
  paypalClientSecret,
  body,
  requestId,
  accessToken,
}) {
  let token = accessToken;
  if (!token) {
    const oauthEndpoint = `${PAYPAL_API_BASE_URL}/v1/oauth2/token`;
    console.info(`[PayPal Recharge] PayPal OAuth endpoint: ${oauthEndpoint}`);
    const tokenResponse = await fetch(oauthEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${Buffer.from(
          `${paypalClientId}:${paypalClientSecret}`,
        ).toString("base64")}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials",
    });
    console.info(
      `[PayPal Recharge] PayPal OAuth HTTP status: ${tokenResponse.status}`,
    );
    if (!tokenResponse.ok) {
      console.error("[PayPal Recharge] OAuth success: false");
      await throwPayPalApiError("OAuth token request", tokenResponse);
    }
    const tokenBody = await tokenResponse.json();
    token = tokenBody.access_token;
    if (typeof token !== "string" || !token) {
      throw new Error("PayPal Sandbox did not return an access token.");
    }
    console.info("[PayPal Recharge] OAuth success: true");
    console.info("[PayPal Recharge] OAuth token obtained.");
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
  if (requestId) headers["PayPal-Request-Id"] = requestId;
  const serializedBody = body === undefined ? undefined : JSON.stringify(body);
  if (operation === "order creation") {
    const paypalAmount = body?.purchase_units?.[0]?.amount;
    if (
      paypalAmount?.currency_code !== PAYPAL_SANDBOX_CURRENCY ||
      typeof paypalAmount.value !== "string" ||
      !/^\d+\.\d{2}$/.test(paypalAmount.value)
    ) {
      throw new Error(
        "PayPal order must use a formatted USD amount before submission.",
      );
    }
    console.info(
      `[PayPal Recharge] PayPal Create Order endpoint: ${PAYPAL_API_BASE_URL}${path}`,
    );
    console.info("[PayPal Recharge] PayPal Create Order method: POST");
    console.info(
      "[PayPal Recharge] PayPal Create Order exact serialized request body:",
      serializedBody,
    );
  }
  const response = await fetch(`${PAYPAL_API_BASE_URL}${path}`, {
    method,
    headers,
    ...(serializedBody === undefined ? {} : { body: serializedBody }),
  });
  if (operation === "order creation") {
    console.info(
      `[PayPal Recharge] PayPal Create Order HTTP status: ${response.status}`,
    );
  }
  if (!response.ok) await throwPayPalApiError(operation, response);
  return response.json();
}

function normalizeText(value) {
  return String(value ?? "").trim().replace(/\s+/g, " ").toLowerCase();
}

function normalizeRegistration(value) {
  return String(value ?? "").replace(/\s+/g, "").toUpperCase();
}

function normalizeVin(value) {
  return String(value ?? "").replace(/\s+/g, "").toUpperCase();
}

function requireText(data, key, maxLength = 256) {
  const value = typeof data?.[key] === "string" ? data[key].trim() : "";
  if (value.length === 0 || value.length > maxLength) {
    throw new Error(`Invalid ${key}.`);
  }
  return value;
}

function vehicleMatches(data, vehicle) {
  return (
    vehicle?.isActive === true &&
    normalizeRegistration(vehicle.registrationNumber) ===
      normalizeRegistration(data.registrationNumber) &&
    normalizeText(vehicle.model) === normalizeText(data.model) &&
    normalizeText(vehicle.ownerName) === normalizeText(data.ownerName) &&
    normalizeVin(vehicle.vin) === normalizeVin(data.vin)
  );
}

function vehiclePublicData(vehicleId, data) {
  return {
    id: vehicleId,
    model: data.model ?? "",
    registrationNumber: data.registrationNumber ?? "",
    ownerName: data.ownerName ?? "",
    vin: data.vin ?? "",
    bluetoothDeviceId: data.bluetoothDeviceId ?? "",
    bluetoothDeviceName: data.bluetoothDeviceName ?? "",
    isActive: data.isActive === true,
    ...(typeof data.batteryCapacityKwh === "number"
      ? { batteryCapacityKwh: data.batteryCapacityKwh }
      : {}),
    ...(typeof data.batteryPercentage === "number"
      ? { batteryPercentage: data.batteryPercentage }
      : {}),
    ...(typeof data.maximumRangeKm === "number"
      ? { maximumRangeKm: data.maximumRangeKm }
      : {}),
    ...(typeof data.health === "number" ? { health: data.health } : {}),
    connectorType: data.connectorType ?? "",
    ...(data.createdAt ? { createdAt: data.createdAt.toDate?.().toISOString() ?? null } : {}),
  };
}

async function findVerifiedVehicle(db, data) {
  const registrationNumber = normalizeRegistration(
    requireText(data, "registrationNumber", 32),
  );
  const submittedVehicle = {
    registrationNumber,
    model: requireText(data, "model"),
    ownerName: requireText(data, "ownerName"),
    vin: normalizeVin(requireText(data, "vin", 64)),
  };
  const query = await db
    .collection("vehicles")
    .where("registrationNumber", "==", registrationNumber)
    .where("isActive", "==", true)
    .limit(2)
    .get();

  const matches = query.docs.filter((document) => {
    const vehicle = document.data();
    return vehicleMatches(submittedVehicle, vehicle);
  });
  if (matches.length !== 1 || query.docs.length !== 1) {
    throw new Error("Vehicle details could not be verified.");
  }
  return matches[0];
}

function membershipRef(db, uid, vehicleId) {
  return db.collection("users").doc(uid).collection("vehicles").doc(vehicleId);
}

function vehicleClaimRef(db, vehicleId) {
  return db.collection("vehicleClaims").doc(vehicleId);
}

function cardRef(db, uid, vehicleId) {
  return db.collection("users").doc(uid)
    .collection("vehicles").doc(vehicleId)
    .collection("chargingCard")
    .doc(CARD_ID);
}

function legacyCardRefs(db, uid, vehicleId) {
  const user = db.collection("users").doc(uid);
  return [
    user.collection("chargingCard").doc(CARD_ID),
    db.collection("vehicles").doc(vehicleId)
      .collection("chargingCard").doc(CARD_ID),
  ];
}

function lastFourFromCard(data) {
  const candidate =
    data.cardNumber ?? data.cardLastFour ?? data.maskedCardNumber ?? "";
  const compact = String(candidate).replace(/[^A-Za-z0-9]/g, "");
  return compact.length >= 4 ? compact.slice(-4) : null;
}

function asTimestamp(value, Timestamp) {
  if (value && typeof value.toDate === "function") return value;
  if (value instanceof Date) return Timestamp.fromDate(value);
  if (typeof value === "string") {
    const date = new Date(value);
    if (Number.isFinite(date.getTime())) return Timestamp.fromDate(date);
  }
  return null;
}

async function verifyAndCreateUserProfile({ db, Timestamp, uid, authEmail, data }) {
  const name = requireText(data, "name", 128);
  const phone = typeof data.phone === "string" ? data.phone.trim() : "";
  if (phone.length > 32) throw new Error("Invalid phone.");
  if (!authEmail || typeof authEmail !== "string") {
    throw new Error("The authenticated account must include an email address.");
  }
  if (
    typeof data.email === "string" &&
    data.email.trim().toLowerCase() !== authEmail.trim().toLowerCase()
  ) {
    throw new Error("The profile email must match the authenticated account.");
  }

  const vehicleDoc = await findVerifiedVehicle(db, data);
  const vehicleData = vehicleDoc.data();
  const userDoc = db.collection("users").doc(uid);
  const memberDoc = membershipRef(db, uid, vehicleDoc.id);
  const claimDoc = vehicleClaimRef(db, vehicleDoc.id);

  await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userDoc);
    const memberSnapshot = await transaction.get(memberDoc);
    const claimSnapshot = await transaction.get(claimDoc);
    const currentVehicleSnapshot = await transaction.get(vehicleDoc.ref);
    const existingOwners = await transaction.get(
      db.collection("users").where("vehicleId", "==", vehicleDoc.id).limit(2),
    );
    const existingMemberships = await transaction.get(
      db.collectionGroup("vehicles")
        .where("vehicleId", "==", vehicleDoc.id)
        .limit(2),
    );
    if (!vehicleMatches(data, currentVehicleSnapshot.data())) {
      throw new Error("Vehicle details could not be verified.");
    }
    if (userSnapshot.exists) {
      throw new Error("A Firebase profile already exists for this account.");
    }
    if (
      memberSnapshot.exists ||
      claimSnapshot.exists ||
      !existingOwners.empty ||
      existingMemberships.docs.some(
        (document) => document.ref.path.split("/").length === 4,
      )
    ) {
      throw new Error("This vehicle is already linked to a Firebase account.");
    }

    const now = Timestamp.now();
    transaction.create(claimDoc, { uid, vehicleId: vehicleDoc.id, linkedAt: now });
    transaction.create(userDoc, {
      uid,
      name,
      email: authEmail.trim(),
      phone,
      vehicleId: vehicleDoc.id,
      vehicleRegistrationNumber: vehicleData.registrationNumber,
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(memberDoc, {
      uid,
      vehicleId: vehicleDoc.id,
      model: vehicleData.model,
      registrationNumber: vehicleData.registrationNumber,
      linkedAt: now,
    });
  });

  return vehiclePublicData(vehicleDoc.id, vehicleData);
}

async function linkVerifiedVehicle({ db, Timestamp, uid, data }) {
  const vehicleDoc = await findVerifiedVehicle(db, data);
  const vehicleData = vehicleDoc.data();
  const userDoc = db.collection("users").doc(uid);
  const memberDoc = membershipRef(db, uid, vehicleDoc.id);
  const claimDoc = vehicleClaimRef(db, vehicleDoc.id);
  await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userDoc);
    const memberSnapshot = await transaction.get(memberDoc);
    const claimSnapshot = await transaction.get(claimDoc);
    const currentVehicleSnapshot = await transaction.get(vehicleDoc.ref);
    const existingOwners = await transaction.get(
      db.collection("users").where("vehicleId", "==", vehicleDoc.id).limit(2),
    );
    const existingMemberships = await transaction.get(
      db.collectionGroup("vehicles")
        .where("vehicleId", "==", vehicleDoc.id)
        .limit(2),
    );
    if (!vehicleMatches(data, currentVehicleSnapshot.data())) {
      throw new Error("Vehicle details could not be verified.");
    }
    if (!userSnapshot.exists) throw new Error("Create a user profile first.");
    if (
      (claimSnapshot.exists && claimSnapshot.data().uid !== uid) ||
      existingOwners.docs.some((document) => document.id !== uid) ||
      existingMemberships.docs.some(
        (document) =>
          document.ref.path.split("/").length === 4 &&
          document.ref.parent.parent?.id !== uid,
      )
    ) {
      throw new Error("This vehicle is already linked to another account.");
    }
    const now = Timestamp.now();
    if (!claimSnapshot.exists) {
      transaction.create(claimDoc, {
        uid,
        vehicleId: vehicleDoc.id,
        linkedAt: now,
      });
    }
    if (!memberSnapshot.exists) {
      transaction.create(memberDoc, {
        uid,
        vehicleId: vehicleDoc.id,
        model: vehicleData.model,
        registrationNumber: vehicleData.registrationNumber,
        linkedAt: now,
      });
    }
  });
  return vehiclePublicData(vehicleDoc.id, vehicleData);
}

async function setConnectedVehicle({ db, Timestamp, uid, vehicleId }) {
  if (typeof vehicleId !== "string" || vehicleId.trim().length === 0) {
    throw new Error("A vehicle ID is required.");
  }
  const normalizedVehicleId = vehicleId.trim();
  const userDoc = db.collection("users").doc(uid);
  const memberDoc = membershipRef(db, uid, normalizedVehicleId);
  const vehicleDoc = db.collection("vehicles").doc(normalizedVehicleId);
  await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userDoc);
    const memberSnapshot = await transaction.get(memberDoc);
    const vehicleSnapshot = await transaction.get(vehicleDoc);
    const vehicleData = vehicleSnapshot.data();
    if (!userSnapshot.exists || !memberSnapshot.exists) {
      throw new Error("This vehicle is not linked to your account.");
    }
    if (!vehicleSnapshot.exists || vehicleData?.isActive !== true) {
      throw new Error("The selected vehicle is unavailable or inactive.");
    }
    transaction.update(userDoc, {
      vehicleId: normalizedVehicleId,
      vehicleRegistrationNumber: vehicleData.registrationNumber,
      updatedAt: Timestamp.now(),
    });
  });
  return { vehicleId: normalizedVehicleId };
}

async function getLegacyChargingCardSummary({ db, uid, vehicleId }) {
  if (typeof vehicleId !== "string" || vehicleId.trim().length === 0) {
    throw new Error("A connected vehicle ID is required.");
  }
  const normalizedVehicleId = vehicleId.trim();
  const userDoc = db.collection("users").doc(uid);
  const vehicleDoc = db.collection("vehicles").doc(normalizedVehicleId);
  const legacyCards = legacyCardRefs(db, uid, normalizedVehicleId);
  const [userSnapshot, vehicleSnapshot, ...legacySnapshots] = await Promise.all([
    userDoc.get(),
    vehicleDoc.get(),
    ...legacyCards.map((reference) => reference.get()),
  ]);
  if (
    !userSnapshot.exists ||
    userSnapshot.data().vehicleId !== normalizedVehicleId
  ) {
    throw new Error("Only the currently connected vehicle can view this legacy card.");
  }
  if (!vehicleSnapshot.exists || vehicleSnapshot.data().isActive !== true) {
    throw new Error("The connected vehicle is unavailable or inactive.");
  }
  const existingLegacyCards = legacySnapshots.filter((snapshot) => snapshot.exists);
  if (existingLegacyCards.length > 1) {
    throw new Error(
      "Multiple legacy charging cards exist. They need manual review before migration.",
    );
  }
  if (existingLegacyCards.length === 0) return null;

  const legacyCard = existingLegacyCards[0].data();
  const lastFour = lastFourFromCard(legacyCard);
  const rawExpiryDate = legacyCard.expiryDate;
  const expiryDate =
    typeof rawExpiryDate?.toDate === "function"
      ? rawExpiryDate.toDate()
      : rawExpiryDate instanceof Date
        ? rawExpiryDate
        : typeof rawExpiryDate === "string"
          ? new Date(rawExpiryDate)
          : null;
  return {
    cardType:
      typeof legacyCard.cardType === "string" ? legacyCard.cardType : null,
    maskedCardNumber: lastFour ? `XXXX XXXX XXXX ${lastFour}` : null,
    cardHolderName:
      typeof legacyCard.cardHolderName === "string"
        ? legacyCard.cardHolderName
        : null,
    balance:
      typeof legacyCard.balance === "number" &&
      Number.isFinite(legacyCard.balance)
        ? legacyCard.balance
        : null,
    currency:
      typeof legacyCard.currency === "string" ? legacyCard.currency : null,
    status: typeof legacyCard.status === "string" ? legacyCard.status : null,
    expiryDate:
      expiryDate && Number.isFinite(expiryDate.getTime())
        ? expiryDate.toISOString()
        : null,
  };
}

async function migrateLegacyChargingCard({ db, Timestamp, uid, vehicleId }) {
  if (typeof vehicleId !== "string" || vehicleId.trim().length === 0) {
    throw new Error("A connected vehicle ID is required.");
  }
  const normalizedVehicleId = vehicleId.trim();
  const userDoc = db.collection("users").doc(uid);
  const vehicleDoc = db.collection("vehicles").doc(normalizedVehicleId);
  const memberDoc = membershipRef(db, uid, normalizedVehicleId);
  const claimDoc = vehicleClaimRef(db, normalizedVehicleId);
  const legacyCards = legacyCardRefs(db, uid, normalizedVehicleId);
  const destinationCard = cardRef(db, uid, normalizedVehicleId);

  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userDoc);
    const vehicleSnapshot = await transaction.get(vehicleDoc);
    const memberSnapshot = await transaction.get(memberDoc);
    const claimSnapshot = await transaction.get(claimDoc);
    const destinationSnapshot = await transaction.get(destinationCard);
    const legacySnapshots = await Promise.all(
      legacyCards.map((reference) => transaction.get(reference)),
    );

    if (!userSnapshot.exists || userSnapshot.data().vehicleId !== normalizedVehicleId) {
      throw new Error("Only the currently connected vehicle can receive this legacy card.");
    }
    if (!vehicleSnapshot.exists || vehicleSnapshot.data().isActive !== true) {
      throw new Error("The connected vehicle is unavailable or inactive.");
    }
    const legacyIndexes = legacySnapshots
      .map((snapshot, index) => (snapshot.exists ? index : -1))
      .filter((index) => index >= 0);
    if (legacyIndexes.length === 0) {
      throw new Error("No legacy charging card exists.");
    }
    if (legacyIndexes.length > 1) {
      throw new Error(
        "Multiple legacy charging cards exist. They need manual review before migration.",
      );
    }
    const legacyIndex = legacyIndexes[0];
    const legacyCardDoc = legacyCards[legacyIndex];
    const legacySnapshot = legacySnapshots[legacyIndex];
    const oldTransactions = await transaction.get(
      legacyCardDoc.collection("transactions")
        .limit(MIGRATION_TRANSACTION_LIMIT + 1),
    );
    if (claimSnapshot.exists && claimSnapshot.data().uid !== uid) {
      throw new Error("This vehicle is already linked to another account.");
    }
    if (destinationSnapshot.exists) {
      return { migrated: false, alreadyExists: true };
    }
    if (oldTransactions.size > MIGRATION_TRANSACTION_LIMIT) {
      throw new Error(
        `This card has more than ${MIGRATION_TRANSACTION_LIMIT} legacy transactions and requires a paged support migration.`,
      );
    }

    const oldCard = legacySnapshot.data();
    const legacyVehicleId = oldCard.vehicleId ?? oldCard.linkedVehicleId;
    if (
      typeof legacyVehicleId === "string" &&
      legacyVehicleId.trim().length > 0 &&
      legacyVehicleId.trim() !== normalizedVehicleId
    ) {
      throw new Error("The legacy charging card belongs to a different vehicle.");
    }
    const balance = oldCard.balance;
    if (typeof balance !== "number" || !Number.isFinite(balance) || balance < 0) {
      throw new Error("The legacy card has no valid Firebase balance to migrate.");
    }
    const lastFour = lastFourFromCard(oldCard);
    if (!lastFour) {
      throw new Error("The legacy card has no usable card number suffix.");
    }
    const cardType =
      typeof oldCard.cardType === "string" ? oldCard.cardType.trim() : "";
    const cardHolderName =
      typeof oldCard.cardHolderName === "string"
        ? oldCard.cardHolderName.trim()
        : "";
    if (!cardType || !cardHolderName) {
      throw new Error("The legacy card is missing card type or holder name.");
    }
    const registeredAt =
      asTimestamp(oldCard.registeredAt ?? oldCard.createdAt, Timestamp) ??
      Timestamp.now();
    const status =
      typeof oldCard.status === "string" && oldCard.status.trim()
        ? oldCard.status.trim().toUpperCase()
        : "ACTIVE";
    const currency =
      typeof oldCard.currency === "string" && oldCard.currency.trim().length === 3
        ? oldCard.currency.trim().toUpperCase()
        : "INR";

    if (!memberSnapshot.exists) {
      transaction.create(memberDoc, {
        uid,
        vehicleId: normalizedVehicleId,
        model: vehicleSnapshot.data().model ?? "",
        registrationNumber: vehicleSnapshot.data().registrationNumber ?? "",
        linkedAt: Timestamp.now(),
      });
    }
    if (!claimSnapshot.exists) {
      transaction.create(claimDoc, {
        uid,
        vehicleId: normalizedVehicleId,
        linkedAt: Timestamp.now(),
      });
    }
    transaction.create(destinationCard, {
      cardId: CARD_ID,
      cardType,
      maskedCardNumber: `XXXX XXXX XXXX ${lastFour}`,
      cardHolderName,
      vehicleId: normalizedVehicleId,
      vehicleModel: vehicleSnapshot.data().model ?? "",
      vehicleRegistrationNumber:
        vehicleSnapshot.data().registrationNumber ?? "",
      vehicleVin: vehicleSnapshot.data().vin ?? "",
      ...(asTimestamp(oldCard.expiryDate, Timestamp)
        ? { expiryDate: asTimestamp(oldCard.expiryDate, Timestamp) }
        : {}),
      balance,
      currency,
      status,
      registeredAt,
      updatedAt: Timestamp.now(),
    });

    for (const oldTransaction of oldTransactions.docs) {
      const data = oldTransaction.data();
      const timestamp =
        asTimestamp(data.timestamp ?? data.date, Timestamp) ?? Timestamp.now();
      const migratedTransaction = {
        transactionId: oldTransaction.id,
        cardId: CARD_ID,
        vehicleId: normalizedVehicleId,
        timestamp,
        status: typeof data.status === "string" ? data.status : "unknown",
      };
      for (const key of [
        "type",
        "amount",
        "balanceBefore",
        "balanceAfter",
        "stationId",
        "stationName",
        "operator",
        "description",
        "currency",
        "sessionReferenceId",
      ]) {
        const value = data[key];
        if (
          typeof value === "string" && value.trim() ||
          typeof value === "number" && Number.isFinite(value)
        ) {
          migratedTransaction[key] = value;
        }
      }
      transaction.create(
        destinationCard.collection("transactions").doc(oldTransaction.id),
        migratedTransaction,
      );
    }
    return {
      migrated: true,
      transactionCount: oldTransactions.size,
      vehicleId: normalizedVehicleId,
    };
  });

  return result;
}

function normalizeRechargeCurrency(value) {
  const normalized = typeof value === "string" ? value.trim().toUpperCase() : "";
  return /^[A-Z]{3}$/.test(normalized) ? normalized : "INR";
}

function validateRechargeAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("Recharge amount must be greater than zero.");
  }
  if (amount > MAX_PAYPAL_RECHARGE_AMOUNT) {
    throw new Error(
      `Recharge amount cannot exceed ${MAX_PAYPAL_RECHARGE_AMOUNT.toFixed(2)}.`,
    );
  }
  if (Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-7) {
    throw new Error("Recharge amounts must use no more than two decimals.");
  }
  return Number((Math.round(amount * 100) / 100).toFixed(2));
}

async function ensureVehicleCard({ db, uid, vehicleId }) {
  const normalizedVehicleId = typeof vehicleId === "string" ? vehicleId.trim() : "";
  if (!normalizedVehicleId) {
    throw new Error("A connected vehicle ID is required.");
  }
  const userRef = db.collection("users").doc(uid);
  const membershipRef = db.collection("users").doc(uid).collection("vehicles").doc(normalizedVehicleId);
  const vehicleRef = db.collection("vehicles").doc(normalizedVehicleId);
  const cardRefInstance = cardRef(db, uid, normalizedVehicleId);
  const [
    userSnapshot,
    membershipSnapshot,
    vehicleSnapshot,
    cardSnapshot,
  ] = await Promise.all([
    userRef.get(),
    membershipRef.get(),
    vehicleRef.get(),
    cardRefInstance.get(),
  ]);

  if (!userSnapshot.exists) {
    throw new Error("This vehicle is not linked to your account.");
  }
  const userData = userSnapshot.data();
  const membershipData = membershipSnapshot.data();
  const primaryVehicleMatches = userData?.vehicleId === normalizedVehicleId;
  const membershipMatches =
    membershipSnapshot.exists &&
    membershipData?.uid === uid &&
    membershipData?.vehicleId === normalizedVehicleId;
  if (!primaryVehicleMatches && !membershipMatches) {
    throw new Error("This vehicle is not linked to your account.");
  }
  if (!vehicleSnapshot.exists || vehicleSnapshot.data()?.isActive !== true) {
    throw new Error("The linked vehicle is unavailable or inactive.");
  }
  if (!cardSnapshot.exists) {
    throw new Error("No charging card is registered for this vehicle.");
  }

  return {
    cardRef: cardRefInstance,
    cardSnapshot,
  };
}

async function createPayPalRechargeOrder({
  db,
  Timestamp,
  uid,
  vehicleId,
  amount,
  currency,
  paypalClientId,
  paypalClientSecret,
}) {
  const normalizedVehicleId = typeof vehicleId === "string" ? vehicleId.trim() : "";
  const rechargeAmount = validateRechargeAmount(amount);
  const { cardSnapshot } = await ensureVehicleCard({
    db,
    uid,
    vehicleId: normalizedVehicleId,
  });
  const cardCurrency = normalizeRechargeCurrency(
    cardSnapshot.data().currency,
  );
  if (
    currency !== undefined &&
    normalizeRechargeCurrency(currency) !== cardCurrency
  ) {
    throw new Error("Recharge currency must match the charging card currency.");
  }
  const normalizedCurrency = cardCurrency;
  if (normalizedCurrency !== "INR") {
    throw new Error("PayPal Sandbox demo conversion requires an INR charging card.");
  }
  const paypalAmount = convertInrToPaypalAmount(rechargeAmount);
  const currentBalance =
    typeof cardSnapshot.data().balance === "number" &&
    Number.isFinite(cardSnapshot.data().balance)
      ? cardSnapshot.data().balance
      : 0;
  if (!paypalClientId || !paypalClientSecret) {
    throw new Error(
      "PayPal Sandbox credentials are not configured for the local emulator.",
    );
  }

  const order = await paypalRequest({
    operation: "order creation",
    path: "/v2/checkout/orders",
    method: "POST",
    paypalClientId,
    paypalClientSecret,
    requestId: createHash("sha256")
      .update(`${uid}:${normalizedVehicleId}:${Date.now()}:${Math.random()}`)
      .digest("hex")
      .slice(0, 36),
    body: {
      intent: "CAPTURE",
      purchase_units: [
        {
          reference_id: normalizedVehicleId,
          description: "EV Smart Companion charging-card recharge",
          amount: {
            currency_code: PAYPAL_SANDBOX_CURRENCY,
            value: paypalAmount.toFixed(2),
          },
        },
      ],
      application_context: {
        brand_name: "EV Smart Companion",
        landing_page: "LOGIN",
        user_action: "PAY_NOW",
        return_url: "https://example.com/paypal-return",
        cancel_url: "https://example.com/paypal-cancel",
      },
    },
  });

  if (typeof order.id !== "string" || !order.id) {
    throw new Error("PayPal Sandbox did not return an order ID.");
  }
  console.info("[PayPal Recharge] PayPal Sandbox order created.");
  const approval = Array.isArray(order.links)
    ? order.links.find((link) => link.rel === "approve")
    : null;
  if (!approval || typeof approval.href !== "string") {
    throw new Error("PayPal Sandbox did not return an approval link.");
  }

  await db
    .collection("paypalRechargeOrders")
    .doc(paypalOrderDocumentId(order.id))
    .create({
      orderId: order.id,
      uid,
      vehicleId: normalizedVehicleId,
      amount: rechargeAmount,
      currency: normalizedCurrency,
      paypalAmount,
      paypalCurrency: PAYPAL_SANDBOX_CURRENCY,
      conversionType: "demo_fixed_rate",
      demoExchangeRate: DEMO_EXCHANGE_RATE_INR_TO_USD,
      status: "PENDING",
      createdAt: Timestamp.now(),
    });

  return {
    success: true,
    orderId: order.id,
    approvalUrl: approval.href,
    status: order.status,
    amount: rechargeAmount,
    currency: normalizedCurrency,
    paypalAmount,
    paypalCurrency: PAYPAL_SANDBOX_CURRENCY,
    conversionType: "demo_fixed_rate",
    demoExchangeRate: DEMO_EXCHANGE_RATE_INR_TO_USD,
    currentBalance,
    paypalClientId,
    paymentProvider: "PayPal Sandbox",
  };
}

async function capturePayPalRechargeOrder({
  db,
  Timestamp,
  uid,
  vehicleId,
  orderId,
  paypalClientId,
  paypalClientSecret,
}) {
  const normalizedVehicleId = typeof vehicleId === "string" ? vehicleId.trim() : "";
  const normalizedOrderId = typeof orderId === "string" ? orderId.trim() : "";
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(normalizedOrderId)) {
    throw new Error("A valid PayPal order ID is required.");
  }

  if (!paypalClientId || !paypalClientSecret) {
    throw new Error(
      "PayPal Sandbox credentials are not configured for the local emulator.",
    );
  }

  const orderRecordRef = db
    .collection("paypalRechargeOrders")
    .doc(paypalOrderDocumentId(normalizedOrderId));
  const orderRecordSnapshot = await orderRecordRef.get();
  if (!orderRecordSnapshot.exists) {
    throw new Error("This PayPal order is not registered for capture.");
  }
  const orderRecord = orderRecordSnapshot.data();
  if (orderRecord.uid !== uid || orderRecord.vehicleId !== normalizedVehicleId) {
    throw new Error("This PayPal order does not belong to this account and vehicle.");
  }
  if (orderRecord.status === "COMPLETED") {
    return {
      success: true,
      alreadyCaptured: true,
      transactionId: orderRecord.transactionId,
      vehicleId: normalizedVehicleId,
      balanceAfter: orderRecord.balanceAfter,
      amount: orderRecord.amount,
      currency: orderRecord.currency,
      paypalAmount: orderRecord.paypalAmount,
      paypalCurrency: orderRecord.paypalCurrency,
      conversionType: orderRecord.conversionType,
      demoExchangeRate: orderRecord.demoExchangeRate,
      paymentProvider: "PayPal Sandbox",
    };
  }

  const { cardRef, cardSnapshot } = await ensureVehicleCard({
    db,
    uid,
    vehicleId: normalizedVehicleId,
  });

  console.info(`[PayPal Recharge] Capturing PayPal order: ${normalizedOrderId}`);
  const capture = await paypalRequest({
    operation: "capture",
    path: `/v2/checkout/orders/${encodeURIComponent(normalizedOrderId)}/capture`,
    method: "POST",
    paypalClientId,
    paypalClientSecret,
    requestId: paypalOrderDocumentId(`${normalizedOrderId}:capture`).slice(0, 36),
    body: {},
  });
  const verifiedCapture = capture?.purchase_units?.[0]?.payments?.captures?.[0];
  if (capture?.status !== "COMPLETED" || verifiedCapture?.status !== "COMPLETED") {
    throw new Error("PayPal did not confirm a completed capture.");
  }

  const paymentAmount = Number.parseFloat(
    verifiedCapture?.amount?.value ?? "0",
  );
  const paymentCurrency = verifiedCapture?.amount?.currency_code ?? "";

  const validatedPaypalAmount = validateRechargeAmount(paymentAmount);
  const normalizedPaypalCurrency = normalizeRechargeCurrency(paymentCurrency);
  const validatedAmount = validateRechargeAmount(orderRecord.amount);
  const normalizedCurrency = normalizeRechargeCurrency(orderRecord.currency);
  const expectedPaypalAmount = convertInrToPaypalAmount(validatedAmount);
  if (
    orderRecord.conversionType !== "demo_fixed_rate" ||
    orderRecord.demoExchangeRate !== DEMO_EXCHANGE_RATE_INR_TO_USD ||
    orderRecord.paypalCurrency !== PAYPAL_SANDBOX_CURRENCY ||
    orderRecord.paypalAmount !== expectedPaypalAmount ||
    validatedPaypalAmount !== expectedPaypalAmount ||
    normalizedPaypalCurrency !== PAYPAL_SANDBOX_CURRENCY ||
    normalizedCurrency !== normalizeRechargeCurrency(cardSnapshot.data().currency)
  ) {
    throw new Error("The PayPal capture amount does not match the recharge order.");
  }
  console.info("[PayPal Recharge] PayPal capture completed.");
  const captureId = verifiedCapture.id;
  if (typeof captureId !== "string" || !captureId) {
    throw new Error("PayPal did not return a capture ID.");
  }
  const transactionId = `paypal-${paypalOrderDocumentId(normalizedOrderId)}`;
  const transactionRef = cardRef.collection("transactions").doc(transactionId);

  return db.runTransaction(async (transaction) => {
    const [freshCard, freshOrder, existingTransaction] = await Promise.all([
      transaction.get(cardRef),
      transaction.get(orderRecordRef),
      transaction.get(transactionRef),
    ]);
    if (!freshCard.exists) {
      throw new Error("No charging card is registered for this vehicle.");
    }
    if (!freshOrder.exists) {
      throw new Error("This PayPal order is not registered for capture.");
    }
    const freshOrderData = freshOrder.data();
    if (freshOrderData.uid !== uid || freshOrderData.vehicleId !== normalizedVehicleId) {
      throw new Error("This PayPal order does not belong to this account and vehicle.");
    }
    if (freshOrderData.status === "COMPLETED" || existingTransaction.exists) {
      const completed = existingTransaction.exists
        ? existingTransaction.data()
        : freshOrderData;
      return {
        success: true,
        alreadyCaptured: true,
        transactionId,
        vehicleId: normalizedVehicleId,
        balanceAfter: completed.balanceAfter,
        amount: completed.amount,
        currency: completed.currency,
        paypalAmount: completed.paypalAmount,
        paypalCurrency: completed.paypalCurrency,
        conversionType: completed.conversionType,
        demoExchangeRate: completed.demoExchangeRate,
        paymentProvider: "PayPal Sandbox",
      };
    }
    const freshCardData = freshCard.data();
    const currentCardBalance =
      typeof freshCardData.balance === "number" &&
      Number.isFinite(freshCardData.balance)
        ? freshCardData.balance
        : 0;
    const balanceAfter = Number((currentCardBalance + validatedAmount).toFixed(2));

    transaction.update(cardRef, {
      balance: balanceAfter,
      lastRechargeAmount: validatedAmount,
      lastRechargeDate: Timestamp.now(),
      updatedAt: Timestamp.now(),
      currency: normalizedCurrency,
    });

    transaction.create(transactionRef, {
      transactionId,
      cardId: CARD_ID,
      vehicleId: normalizedVehicleId,
      type: "credit",
      amount: validatedAmount,
      currency: normalizedCurrency,
      paypalAmount: validatedPaypalAmount,
      paypalCurrency: normalizedPaypalCurrency,
      conversionType: orderRecord.conversionType,
      demoExchangeRate: orderRecord.demoExchangeRate,
      balanceBefore: Number(currentCardBalance.toFixed(2)),
      balanceAfter,
      provider: "paypal",
      paymentProvider: "PayPal Sandbox",
      paypalOrderId: normalizedOrderId,
      paypalCaptureId: captureId,
      status: "completed",
      description: "PayPal recharge",
      timestamp: Timestamp.now(),
    });

    transaction.update(orderRecordRef, {
      status: "COMPLETED",
      captureId,
      amount: validatedAmount,
      currency: normalizedCurrency,
      paypalAmount: validatedPaypalAmount,
      paypalCurrency: normalizedPaypalCurrency,
      conversionType: orderRecord.conversionType,
      demoExchangeRate: orderRecord.demoExchangeRate,
      transactionId,
      balanceAfter,
      completedAt: Timestamp.now(),
    });

    return {
      success: true,
      transactionId,
      vehicleId: normalizedVehicleId,
      balanceBefore: currentCardBalance,
      balanceAfter,
      amount: validatedAmount,
      currency: normalizedCurrency,
      paypalAmount: validatedPaypalAmount,
      paypalCurrency: normalizedPaypalCurrency,
      conversionType: orderRecord.conversionType,
      demoExchangeRate: orderRecord.demoExchangeRate,
      paymentProvider: "PayPal Sandbox",
    };
  });
}

async function debitConfirmedChargingSession({ db, Timestamp, uid, sessionId }) {
  if (
    typeof sessionId !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(sessionId)
  ) {
    throw new Error("A valid charging-session reference is required.");
  }

  const sessionRef = db.collection("chargingSessions").doc(sessionId);
  return db.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionRef);
    if (!sessionSnapshot.exists) {
      throw new Error("No trusted charging-session confirmation was found.");
    }
    const session = sessionSnapshot.data();
    if (session.uid !== uid) {
      throw new Error("This charging session does not belong to your account.");
    }

    const vehicleId =
      typeof session.vehicleId === "string" ? session.vehicleId.trim() : "";
    if (!vehicleId) {
      throw new Error("The confirmed charging session has no vehicle.");
    }
    const userRef = db.collection("users").doc(uid);
    const membership = membershipRef(db, uid, vehicleId);
    const claimRef = vehicleClaimRef(db, vehicleId);
    const vehicleRef = db.collection("vehicles").doc(vehicleId);
    const card = cardRef(db, uid, vehicleId);
    const transactionRef = card.collection("transactions").doc(sessionId);

    const [
      userSnapshot,
      membershipSnapshot,
      claimSnapshot,
      vehicleSnapshot,
      cardSnapshot,
      transactionSnapshot,
    ] = await Promise.all([
      transaction.get(userRef),
      transaction.get(membership),
      transaction.get(claimRef),
      transaction.get(vehicleRef),
      transaction.get(card),
      transaction.get(transactionRef),
    ]);

    if (
      !userSnapshot.exists ||
      userSnapshot.data().uid !== uid ||
      (userSnapshot.data().vehicleId !== vehicleId && !membershipSnapshot.exists)
    ) {
      throw new Error("This vehicle is not linked to your account.");
    }
    if (claimSnapshot.exists && claimSnapshot.data().uid !== uid) {
      throw new Error("This vehicle is linked to another account.");
    }
    if (!vehicleSnapshot.exists || vehicleSnapshot.data().isActive !== true) {
      throw new Error("The session vehicle is unavailable or inactive.");
    }
    if (session.debitStatus === "completed") {
      if (!transactionSnapshot.exists) {
        throw new Error("The completed session has no charging transaction.");
      }
      return {
        alreadyDebited: true,
        transactionId: transactionRef.id,
        vehicleId,
        balanceAfter: transactionSnapshot.data().balanceAfter,
      };
    }
    if (session.status !== "confirmed" || session.debitStatus !== "pending") {
      throw new Error("The charging session is not trusted and confirmed.");
    }
    if (transactionSnapshot.exists) {
      throw new Error("A transaction already exists for this charging session.");
    }
    if (!cardSnapshot.exists) {
      throw new Error("No charging card is registered for this vehicle.");
    }

    const amount = session.amount;
    const currentBalance = cardSnapshot.data().balance;
    if (
      typeof amount !== "number" ||
      !Number.isFinite(amount) ||
      amount <= 0 ||
      typeof currentBalance !== "number" ||
      !Number.isFinite(currentBalance) ||
      currentBalance < 0
    ) {
      throw new Error("The session amount or charging-card balance is invalid.");
    }
    const amountMinor = Math.round(amount * 100);
    const balanceBeforeMinor = Math.round(currentBalance * 100);
    if (Math.abs(amount * 100 - amountMinor) > 1e-7) {
      throw new Error("Charging amounts must use no more than two decimals.");
    }
    if (balanceBeforeMinor < amountMinor) {
      throw new Error("Insufficient charging card balance.");
    }
    const balanceAfterMinor = balanceBeforeMinor - amountMinor;
    const balanceBefore = balanceBeforeMinor / 100;
    const balanceAfter = balanceAfterMinor / 100;
    const currency =
      typeof session.currency === "string"
        ? session.currency.trim().toUpperCase()
        : cardSnapshot.data().currency;
    if (typeof currency !== "string" || !/^[A-Z]{3}$/.test(currency)) {
      throw new Error("The confirmed charging session has an invalid currency.");
    }
    const timestamp = session.confirmedAt ?? Timestamp.now();

    transaction.update(card, {
      balance: balanceAfter,
      updatedAt: Timestamp.now(),
    });
    transaction.create(transactionRef, {
      transactionId: transactionRef.id,
      cardId: CARD_ID,
      vehicleId,
      type: "debit",
      amount: amountMinor / 100,
      currency,
      balanceBefore,
      balanceAfter,
      stationId: typeof session.stationId === "string" ? session.stationId : "",
      stationName:
        typeof session.stationName === "string" ? session.stationName : "",
      operator: typeof session.operator === "string" ? session.operator : "",
      sessionReferenceId: sessionId,
      timestamp,
      status: "completed",
      description: "Confirmed charging session",
    });
    transaction.update(sessionRef, {
      debitStatus: "completed",
      debitTransactionId: transactionRef.id,
      balanceBefore,
      balanceAfter,
      debitedAt: Timestamp.now(),
    });

    return {
      alreadyDebited: false,
      transactionId: transactionRef.id,
      vehicleId,
      balanceBefore,
      balanceAfter,
    };
  });
}

async function syncVehicleCardSnapshots({ db, vehicleId, vehicleData }) {
  if (typeof vehicleId !== "string" || vehicleId.trim().length === 0) {
    throw new Error("A valid vehicle ID is required.");
  }
  const normalizedVehicleId = vehicleId.trim();
  const [primaryOwners, linkedMemberships] = await Promise.all([
    db.collection("users").where("vehicleId", "==", normalizedVehicleId).get(),
    db.collectionGroup("vehicles")
      .where("vehicleId", "==", normalizedVehicleId)
      .get(),
  ]);
  const ownerIds = new Set(primaryOwners.docs.map((document) => document.id));
  for (const membership of linkedMemberships.docs) {
    const userDocument = membership.ref.parent.parent;
    if (
      membership.ref.parent.id === "vehicles" &&
      userDocument?.parent.id === "users"
    ) {
      ownerIds.add(userDocument.id);
    }
  }
  let updatedCards = 0;
  await Promise.all([...ownerIds].map(async (uid) => {
    const card = cardRef(db, uid, normalizedVehicleId);
    const snapshot = await card.get();
    if (!snapshot.exists) return;
    await card.update({
      vehicleModel: vehicleData.model ?? "",
      vehicleRegistrationNumber: vehicleData.registrationNumber ?? "",
      vehicleVin: vehicleData.vin ?? "",
    });
    updatedCards += 1;
  }));
  return updatedCards;
}

module.exports = {
  CARD_ID,
  DEMO_EXCHANGE_RATE_INR_TO_USD,
  MIGRATION_TRANSACTION_LIMIT,
  PayPalApiError,
  capturePayPalRechargeOrder,
  convertInrToPaypalAmount,
  createPayPalRechargeOrder,
  debitConfirmedChargingSession,
  findVerifiedVehicle,
  getLegacyChargingCardSummary,
  linkVerifiedVehicle,
  migrateLegacyChargingCard,
  setConnectedVehicle,
  syncVehicleCardSnapshots,
  verifyAndCreateUserProfile,
};
