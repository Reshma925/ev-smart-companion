const CARD_ID = "current";
const MIGRATION_TRANSACTION_LIMIT = 400;

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
  return membershipRef(db, uid, vehicleId)
    .collection("chargingCard")
    .doc(CARD_ID);
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
  const legacyCardDoc = userDoc.collection("chargingCard").doc(CARD_ID);
  const [userSnapshot, vehicleSnapshot, legacySnapshot] = await Promise.all([
    userDoc.get(),
    vehicleDoc.get(),
    legacyCardDoc.get(),
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
  if (!legacySnapshot.exists) return null;

  const legacyCard = legacySnapshot.data();
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
  const legacyCardDoc = userDoc.collection("chargingCard").doc(CARD_ID);
  const legacyTransactions = legacyCardDoc.collection("transactions");
  const destinationCard = cardRef(db, uid, normalizedVehicleId);

  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userDoc);
    const vehicleSnapshot = await transaction.get(vehicleDoc);
    const memberSnapshot = await transaction.get(memberDoc);
    const claimSnapshot = await transaction.get(claimDoc);
    const legacySnapshot = await transaction.get(legacyCardDoc);
    const destinationSnapshot = await transaction.get(destinationCard);
    const oldTransactions = await transaction.get(
      legacyTransactions.limit(MIGRATION_TRANSACTION_LIMIT + 1),
    );

    if (!userSnapshot.exists || userSnapshot.data().vehicleId !== normalizedVehicleId) {
      throw new Error("Only the currently connected vehicle can receive this legacy card.");
    }
    if (!vehicleSnapshot.exists || vehicleSnapshot.data().isActive !== true) {
      throw new Error("The connected vehicle is unavailable or inactive.");
    }
    if (!legacySnapshot.exists) throw new Error("No legacy charging card exists.");
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

module.exports = {
  CARD_ID,
  MIGRATION_TRANSACTION_LIMIT,
  findVerifiedVehicle,
  getLegacyChargingCardSummary,
  linkVerifiedVehicle,
  migrateLegacyChargingCard,
  setConnectedVehicle,
  verifyAndCreateUserProfile,
};
