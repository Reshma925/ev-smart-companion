const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");
const admin = require("firebase-admin");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const {
  Timestamp: ClientTimestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const backend = require("../card_backend");

const projectId = "demo-ev-smart-companion";
let testEnvironment;
let adminApp;
let adminDb;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
  adminApp = admin.initializeApp({ projectId }, `charging-card-test-${Date.now()}`);
  adminDb = getFirestore(adminApp);
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
  if (adminApp) await adminApp.delete();
});

async function seedLinkedVehicles() {
  const timestamp = Timestamp.now();
  await adminDb.doc("users/alice").set({
    uid: "alice",
    name: "Alice",
    email: "alice@example.com",
    phone: "123",
    vehicleId: "EV001",
    vehicleRegistrationNumber: "REG-001",
    updatedAt: timestamp,
  });
  for (const [vehicleId, registrationNumber] of [
    ["EV001", "REG-001"],
    ["EV002", "REG-002"],
  ]) {
    await adminDb.doc(`vehicles/${vehicleId}`).set({
      model: `Model ${vehicleId}`,
      registrationNumber,
      ownerName: "Alice",
      vin: `VIN-${vehicleId}`,
      isActive: true,
    });
    await adminDb.doc(`users/alice/vehicles/${vehicleId}`).set({
      uid: "alice",
      vehicleId,
      model: `Model ${vehicleId}`,
      registrationNumber,
      linkedAt: timestamp,
    });
  }
  for (const vehicleId of ["EV001", "EV002"]) {
    await adminDb.doc(cardPath("alice", vehicleId)).set({
      cardId: "current",
      cardType: "EV Card",
      maskedCardNumber: `XXXX XXXX XXXX ${vehicleId.slice(-1).repeat(4)}`,
      cardHolderName: "Alice",
      vehicleId,
      vehicleModel: `Model ${vehicleId}`,
      vehicleRegistrationNumber: `REG-00${vehicleId.slice(-1)}`,
      vehicleVin: `VIN-${vehicleId}`,
      expiryDate: timestamp,
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: timestamp,
      updatedAt: timestamp,
    });
  }
}

function cardPath(uid, vehicleId) {
  return `users/${uid}/vehicles/${vehicleId}/chargingCard/current`;
}

function controlsPreferencesPath(uid, vehicleId) {
  return `users/${uid}/vehicles/${vehicleId}/controls/preferences`;
}

function defaultControlsPreferences() {
  return {
    notificationsEnabled: true,
    safetyAlertsEnabled: true,
    batteryAlertsEnabled: true,
    chargingAlertsEnabled: true,
    passengerProfiles: [],
    selectedProfileId: null,
    alertHistory: [],
    activeAlertKeys: [],
  };
}

async function seedConfirmedSession({
  sessionId = "session-001",
  uid = "alice",
  vehicleId = "EV001",
  amount = 25,
} = {}) {
  await adminDb.doc(`chargingSessions/${sessionId}`).set({
    uid,
    vehicleId,
    amount,
    currency: "INR",
    status: "confirmed",
    debitStatus: "pending",
    stationId: "station-001",
    stationName: "Trusted Station",
    operator: "Trusted Operator",
    confirmedAt: Timestamp.fromDate(new Date("2026-10-03T10:00:00Z")),
  });
}

test("users can read their own vehicle card but not another user's card", async () => {
  await seedLinkedVehicles();
  await adminDb.doc("users/bob").set({ uid: "bob", vehicleId: "EV003" });
  await adminDb.doc("vehicles/EV003").set({
    model: "Model EV003",
    registrationNumber: "REG-003",
    isActive: true,
  });
  await adminDb.doc("users/bob/vehicles/EV003").set({
    uid: "bob",
    vehicleId: "EV003",
  });
  await adminDb.doc(cardPath("bob", "EV003")).set({
    cardId: "current",
    balance: 500,
  });

  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  await assertSucceeds(
    getDoc(doc(aliceDb, cardPath("alice", "EV001"))),
  );
  await assertFails(
    getDoc(doc(aliceDb, cardPath("bob", "EV003"))),
  );
  await assertFails(
    getDoc(doc(aliceDb, "users/alice/vehicles/EV003/chargingCard/current")),
  );
  await assertFails(
    setDoc(doc(aliceDb, cardPath("alice", "EV003")), {
      cardId: "current",
      cardType: "EV Card",
      maskedCardNumber: "XXXX XXXX XXXX 3333",
      cardHolderName: "Alice",
      vehicleId: "EV003",
      vehicleModel: "Model EV003",
      vehicleRegistrationNumber: "REG-003",
      vehicleVin: "VIN-EV003",
      expiryDate: ClientTimestamp.now(),
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: ClientTimestamp.now(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertFails(getDoc(doc(aliceDb, "vehicles/EV003")));
  await assertFails(getDoc(doc(aliceDb, "vehicleClaims/EV001")));
});

test("vehicle owners can create and read maintenance records only for their vehicles", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const record = {
    vehicleId: "EV001",
    serviceType: "Brake inspection",
    category: "Brakes",
    serviceDate: ClientTimestamp.fromDate(new Date("2026-09-12T00:00:00Z")),
    nextServiceDate: ClientTimestamp.fromDate(new Date("2027-09-12T00:00:00Z")),
    odometerKm: 24860,
    cost: 3200,
    serviceCenter: "EV Service Centre",
    notes: "Inspection completed",
    status: "Completed",
    source: "user_entered",
    createdAt: ClientTimestamp.now(),
    updatedAt: ClientTimestamp.now(),
  };

  await assertSucceeds(
    setDoc(doc(aliceDb, "vehicles/EV001/maintenance/brake-check"), record),
  );
  const snapshot = await assertSucceeds(
    getDoc(doc(aliceDb, "vehicles/EV001/maintenance/brake-check")),
  );
  assert.equal(snapshot.data().cost, 3200);
  await assertFails(
    getDoc(doc(aliceDb, "vehicles/EV003/maintenance/brake-check")),
  );
  await assertFails(
    setDoc(doc(aliceDb, "vehicles/EV003/maintenance/not-owned"), {
      ...record,
      vehicleId: "EV003",
    }),
  );
  await assertFails(
    setDoc(doc(aliceDb, "vehicles/EV001/maintenance/invalid"), {
      ...record,
      cost: "3200",
    }),
  );
});

test("an owner can read a missing card document to display the empty state", async () => {
  await seedLinkedVehicles();
  await adminDb.doc(cardPath("alice", "EV001")).delete();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();

  const snapshot = await assertSucceeds(
    getDoc(doc(aliceDb, cardPath("alice", "EV001"))),
  );
  assert.equal(snapshot.exists(), false);
});

test("vehicle owners can initialize and read scoped controls preferences", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const missingPreferences = doc(
    aliceDb,
    controlsPreferencesPath("alice", "EV001"),
  );

  const missingSnapshot = await assertSucceeds(getDoc(missingPreferences));
  assert.equal(missingSnapshot.exists(), false);

  await assertSucceeds(
    setDoc(missingPreferences, {
      vehicleId: "EV001",
      preferences: defaultControlsPreferences(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
  const initializedSnapshot = await assertSucceeds(getDoc(missingPreferences));
  assert.equal(initializedSnapshot.data().preferences.passengerProfiles.length, 0);

  const membershipOwnedPreferences = doc(
    aliceDb,
    controlsPreferencesPath("alice", "EV002"),
  );
  await assertSucceeds(getDoc(membershipOwnedPreferences));

  await assertFails(
    getDoc(doc(aliceDb, controlsPreferencesPath("alice", "EV003"))),
  );
  await assertFails(
    getDoc(doc(aliceDb, controlsPreferencesPath("bob", "EV003"))),
  );
  await assertFails(
    setDoc(missingPreferences, {
      vehicleId: "EV002",
      preferences: defaultControlsPreferences(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
});

test("an owner can register a card using Firestore vehicle details", async () => {
  await seedLinkedVehicles();
  await adminDb.doc(cardPath("alice", "EV001")).delete();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const card = doc(aliceDb, cardPath("alice", "EV001"));
  await assertSucceeds(
    setDoc(card, {
      cardId: "current",
      cardType: "EV Smart Card",
      maskedCardNumber: "XXXX XXXX XXXX 4821",
      cardHolderName: "Maheswara",
      vehicleId: "EV001",
      vehicleModel: "Model EV001",
      vehicleRegistrationNumber: "REG-001",
      vehicleVin: "VIN-EV001",
      expiryDate: ClientTimestamp.now(),
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: ClientTimestamp.now(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
  const snapshot = await assertSucceeds(getDoc(card));
  assert.equal(snapshot.exists(), true);
  assert.equal(snapshot.data().maskedCardNumber, "XXXX XXXX XXXX 4821");
});

test("primary vehicle card access does not require a membership subdocument", async () => {
  await seedLinkedVehicles();
  await adminDb.doc("users/alice/vehicles/EV001").delete();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();

  await assertSucceeds(
    getDoc(doc(aliceDb, cardPath("alice", "EV001"))),
  );
});

test("a user can list only their own linked-vehicle membership documents", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const bobDb = testEnvironment.authenticatedContext("bob").firestore();

  const aliceVehicles = await assertSucceeds(
    getDocs(collection(aliceDb, "users/alice/vehicles")),
  );
  assert.deepEqual(
    aliceVehicles.docs.map((document) => document.id).sort(),
    ["EV001", "EV002"],
  );
  await assertFails(getDocs(collection(bobDb, "users/alice/vehicles")));
});

test("clients cannot read or create trusted charging-session confirmations", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const session = doc(aliceDb, "chargingSessions/session-client");
  await assertFails(getDoc(session));
  await assertFails(
    setDoc(session, {
      uid: "alice",
      vehicleId: "EV001",
      amount: 1,
      status: "confirmed",
      debitStatus: "pending",
    }),
  );
});

test("a trusted confirmed session atomically debits and records once", async () => {
  await seedLinkedVehicles();
  await adminDb
    .doc(cardPath("alice", "EV001"))
    .update({ balance: 100 });
  await seedConfirmedSession();

  const result = await backend.debitConfirmedChargingSession({
    db: adminDb,
    Timestamp,
    uid: "alice",
    sessionId: "session-001",
  });
  const card = await adminDb
    .doc(cardPath("alice", "EV001"))
    .get();
  const transaction = await adminDb
    .doc(
      `${cardPath("alice", "EV001")}/transactions/session-001`,
    )
    .get();
  const session = await adminDb.doc("chargingSessions/session-001").get();

  assert.equal(result.balanceBefore, 100);
  assert.equal(result.balanceAfter, 75);
  assert.equal(card.data().balance, 75);
  assert.equal(transaction.data().amount, 25);
  assert.equal(transaction.data().balanceBefore, 100);
  assert.equal(transaction.data().balanceAfter, 75);
  assert.equal(transaction.data().stationName, "Trusted Station");
  assert.equal(session.data().debitStatus, "completed");

  const retry = await backend.debitConfirmedChargingSession({
    db: adminDb,
    Timestamp,
    uid: "alice",
    sessionId: "session-001",
  });
  assert.equal(retry.alreadyDebited, true);
  assert.equal(
    (
      await adminDb
        .collection(
          `${cardPath("alice", "EV001")}/transactions`,
        )
        .get()
    ).size,
    1,
  );
});

test("insufficient card balance leaves the session and balance unchanged", async () => {
  await seedLinkedVehicles();
  await seedConfirmedSession({ amount: 1 });

  await assert.rejects(
    backend.debitConfirmedChargingSession({
      db: adminDb,
      Timestamp,
      uid: "alice",
      sessionId: "session-001",
    }),
    /Insufficient charging card balance/,
  );
  const card = await adminDb
    .doc(cardPath("alice", "EV001"))
    .get();
  const session = await adminDb.doc("chargingSessions/session-001").get();
  const transactions = await adminDb
    .collection(
      `${cardPath("alice", "EV001")}/transactions`,
    )
    .get();
  assert.equal(card.data().balance, 0);
  assert.equal(session.data().debitStatus, "pending");
  assert.equal(transactions.size, 0);
});

test("a user cannot debit another user's trusted charging session", async () => {
  await seedLinkedVehicles();
  await seedConfirmedSession({ uid: "bob" });
  await assert.rejects(
    backend.debitConfirmedChargingSession({
      db: adminDb,
      Timestamp,
      uid: "alice",
      sessionId: "session-001",
    }),
    /does not belong to your account/,
  );
});

test("vehicle changes synchronize stored card vehicle details", async () => {
  await seedLinkedVehicles();
  const count = await backend.syncVehicleCardSnapshots({
    db: adminDb,
    vehicleId: "EV001",
    vehicleData: {
      model: "Updated EV",
      registrationNumber: "REG-UPDATED",
      vin: "VIN-UPDATED",
    },
  });
  const card = await adminDb
    .doc(cardPath("alice", "EV001"))
    .get();
  assert.equal(count, 1);
  assert.equal(card.data().vehicleModel, "Updated EV");
  assert.equal(card.data().vehicleRegistrationNumber, "REG-UPDATED");
  assert.equal(card.data().vehicleVin, "VIN-UPDATED");
  assert.equal(card.data().balance, 0);
});

test("users can register cards on any vehicle linked to their account", async () => {
  await seedLinkedVehicles();
  await adminDb.doc(cardPath("alice", "EV002")).delete();

  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const cardRef = doc(
    aliceDb,
    cardPath("alice", "EV002"),
  );
  await assertSucceeds(
    setDoc(cardRef, {
      cardId: "current",
      cardType: "EV Card",
      maskedCardNumber: "XXXX XXXX XXXX 2222",
      cardHolderName: "Alice",
      vehicleId: "EV002",
      vehicleModel: "Model EV002",
      vehicleRegistrationNumber: "REG-002",
      vehicleVin: "VIN-EV002",
      expiryDate: ClientTimestamp.now(),
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: ClientTimestamp.now(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
  const savedCard = await getDoc(cardRef);
  assert.equal(savedCard.exists(), true);
  assert.equal(savedCard.data().maskedCardNumber, "XXXX XXXX XXXX 2222");
  assert.equal(savedCard.data().balance, 0);
  assert.equal(savedCard.data().vehicleId, "EV002");
  assert.equal(savedCard.data().vehicleRegistrationNumber, "REG-002");
  assert.equal(savedCard.data().vehicleVin, "VIN-EV002");
  assert.equal("cardNumber" in savedCard.data(), false);
  assert.equal("cvv" in savedCard.data(), false);
  const unauthenticatedDb = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(unauthenticatedDb, cardPath("alice", "EV001")), {
      cardId: "current",
    }),
  );
  await assertSucceeds(
    updateDoc(cardRef, {
      cardHolderName: "Alice Example",
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertFails(updateDoc(cardRef, { balance: 500 }));
});

test("clients cannot change card balance or write transaction records", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const cardRef = doc(aliceDb, cardPath("alice", "EV001"));
  await assertFails(updateDoc(cardRef, { balance: 100 }));
  await assertFails(
    setDoc(
      doc(
        aliceDb,
        `${cardPath("alice", "EV001")}/transactions/fake`,
      ),
      { amount: 1, status: "successful" },
    ),
  );

  await adminDb.doc(cardPath("alice", "EV002")).delete();
  await assertFails(
    setDoc(doc(aliceDb, cardPath("alice", "EV002")), {
      cardId: "current",
      cardType: "EV Card",
      maskedCardNumber: "XXXX XXXX XXXX 2222",
      cardNumber: "4111111111112222",
      cvv: "123",
      cardHolderName: "Alice",
      vehicleId: "EV002",
      vehicleModel: "Model EV002",
      vehicleRegistrationNumber: "REG-002",
      vehicleVin: "VIN-EV002",
      expiryDate: ClientTimestamp.now(),
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: ClientTimestamp.now(),
      updatedAt: ClientTimestamp.now(),
    }),
  );
});

test("legacy cards do not block registration at the canonical vehicle path", async () => {
  await seedLinkedVehicles();
  await adminDb.doc(cardPath("alice", "EV001")).delete();
  const legacyCard = adminDb.doc("users/alice/chargingCard/current");
  await legacyCard.set({
    cardType: "Old card",
    cardNumber: "12345678",
  });
  await adminDb
    .doc("users/alice/chargingCard/current/transactions/legacy")
    .set({ amount: 2 });

  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  await assertFails(
    getDoc(doc(aliceDb, "users/alice/chargingCard/current")),
  );
  await assertFails(
    getDoc(
      doc(aliceDb, "users/alice/chargingCard/current/transactions/legacy"),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(aliceDb, cardPath("alice", "EV001")),
      {
        cardId: "current",
        cardType: "EV Card",
        maskedCardNumber: "XXXX XXXX XXXX 1234",
        cardHolderName: "Alice",
        vehicleId: "EV001",
        vehicleModel: "Model EV001",
        vehicleRegistrationNumber: "REG-001",
        vehicleVin: "VIN-EV001",
        expiryDate: ClientTimestamp.now(),
        balance: 0,
        currency: "INR",
        status: "ACTIVE",
        registeredAt: ClientTimestamp.now(),
        updatedAt: ClientTimestamp.now(),
      },
    ),
  );
  assert.equal((await legacyCard.get()).exists, true);
});

test("previous vehicle-root card migration copies without deleting its source", async () => {
  await seedLinkedVehicles();
  const timestamp = Timestamp.fromDate(new Date("2026-05-01T10:00:00Z"));
  await adminDb.doc(cardPath("alice", "EV001")).delete();
  const previousCard = adminDb.doc(
    "vehicles/EV001/chargingCard/current",
  );
  await previousCard.set({
    cardType: "Previous EV Card",
    cardNumber: "9999 8888 7777 1234",
    cardHolderName: "Alice",
    vehicleId: "EV001",
    balance: 44.5,
    currency: "INR",
    status: "ACTIVE",
    registeredAt: timestamp,
  });
  await previousCard.collection("transactions").doc("old-transaction").set({
    amount: 5.5,
    type: "debit",
    balanceBefore: 50,
    balanceAfter: 44.5,
    timestamp,
    status: "completed",
  });

  const result = await backend.migrateLegacyChargingCard({
    db: adminDb,
    Timestamp,
    uid: "alice",
    vehicleId: "EV001",
  });
  const canonicalCard = await adminDb
    .doc(cardPath("alice", "EV001"))
    .get();
  const canonicalTransaction = await adminDb
    .doc(`${cardPath("alice", "EV001")}/transactions/old-transaction`)
    .get();

  assert.equal(result.migrated, true);
  assert.equal(canonicalCard.data().balance, 44.5);
  assert.equal(canonicalCard.data().maskedCardNumber, "XXXX XXXX XXXX 1234");
  assert.equal(canonicalTransaction.data().balanceAfter, 44.5);
  assert.equal((await previousCard.get()).exists, true);
  assert.equal((await previousCard.collection("transactions").get()).size, 1);
});

test("profile settings are editable and vehicle switching stays owner-validated", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const profile = doc(aliceDb, "users/alice");
  await assertSucceeds(
    updateDoc(profile, {
      city: "Springfield",
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertSucceeds(
    updateDoc(profile, {
      vehicleId: "EV002",
      vehicleRegistrationNumber: "REG-002",
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(profile, {
      vehicleId: "EV003",
      vehicleRegistrationNumber: "REG-003",
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(profile, {
      vehicleId: "EV002",
      vehicleRegistrationNumber: "REG-001",
      updatedAt: ClientTimestamp.now(),
    }),
  );
});

test("legacy migration copies card and transactions without deleting legacy data", async () => {
  await seedLinkedVehicles();
  const timestamp = Timestamp.fromDate(new Date("2026-03-01T10:00:00Z"));
  await adminDb.doc(cardPath("alice", "EV001")).delete();
  const legacyCard = adminDb.doc("users/alice/chargingCard/current");
  await legacyCard.set({
    cardId: "current",
    cardType: "Legacy EV Card",
    cardNumber: "1234 5678 9012 3456",
    cardHolderName: "Alice",
    vehicleId: "EV001",
    balance: 275.5,
    currency: "INR",
    status: "ACTIVE",
    expiryDate: timestamp,
    registeredAt: timestamp,
  });
  await legacyCard.collection("transactions").doc("legacy-transaction").set({
    amount: 25,
    type: "debit",
    balanceBefore: 300.5,
    balanceAfter: 275.5,
    stationName: "Old station",
    operator: "Operator",
    paymentPassword: "must-not-copy",
    timestamp,
    status: "completed",
  });

  const summary = await backend.getLegacyChargingCardSummary({
    db: adminDb,
    uid: "alice",
    vehicleId: "EV001",
  });
  assert.equal(summary.maskedCardNumber, "XXXX XXXX XXXX 3456");
  assert.equal("cardNumber" in summary, false);

  const result = await backend.migrateLegacyChargingCard({
    db: adminDb,
    Timestamp,
    uid: "alice",
    vehicleId: "EV001",
  });
  const migrated = await adminDb
    .doc(cardPath("alice", "EV001"))
    .get();
  const migratedTransaction = await adminDb
    .doc(
      `${cardPath("alice", "EV001")}/transactions/legacy-transaction`,
    )
    .get();

  assert.equal(result.migrated, true);
  assert.equal(migrated.data().balance, 275.5);
  assert.equal(migrated.data().maskedCardNumber, "XXXX XXXX XXXX 3456");
  assert.equal(migrated.data().vehicleModel, "Model EV001");
  assert.equal(migrated.data().vehicleRegistrationNumber, "REG-001");
  assert.equal(migrated.data().vehicleVin, "VIN-EV001");
  assert.equal("cardNumber" in migrated.data(), false);
  assert.equal(migratedTransaction.data().vehicleId, "EV001");
  assert.equal(migratedTransaction.data().paymentPassword, undefined);
  assert.equal((await legacyCard.get()).exists, true);
  assert.equal((await legacyCard.collection("transactions").get()).size, 1);
  const repeat = await backend.migrateLegacyChargingCard({
    db: adminDb,
    Timestamp,
    uid: "alice",
    vehicleId: "EV001",
  });
  assert.equal(repeat.alreadyExists, true);
});

test("trusted signup verifies the vehicle and prevents a second account claim", async () => {
  await adminDb.doc("vehicles/EV001").set({
    model: "Model EV001",
    registrationNumber: "REG-001",
    ownerName: "Alice",
    vin: "VIN-EV001",
    isActive: true,
  });
  const signup = {
    name: "Alice",
    phone: "+10000000000",
    registrationNumber: " reg-001 ",
    model: "model ev001",
    ownerName: "alice",
    vin: "vin-ev001",
  };
  await assert.rejects(
    backend.verifyAndCreateUserProfile({
      db: adminDb,
      Timestamp,
      uid: "bad-vin-user",
      authEmail: "bad@example.com",
      data: { ...signup, vin: "wrong-vin" },
    }),
    /could not be verified/,
  );

  const vehicle = await backend.verifyAndCreateUserProfile({
    db: adminDb,
    Timestamp,
    uid: "alice",
    authEmail: "alice@example.com",
    data: signup,
  });
  assert.equal(vehicle.id, "EV001");
  assert.equal((await adminDb.doc("users/alice").get()).data().vehicleId, "EV001");
  assert.equal((await adminDb.doc("vehicleClaims/EV001").get()).data().uid, "alice");

  await assert.rejects(
    backend.verifyAndCreateUserProfile({
      db: adminDb,
      Timestamp,
      uid: "bob",
      authEmail: "bob@example.com",
      data: signup,
    }),
    /already linked/,
  );
  assert.equal((await adminDb.doc("users/bob").get()).exists, false);
});

test("switching the connected vehicle selects that vehicle's card", async () => {
  await seedLinkedVehicles();
  const result = await backend.setConnectedVehicle({
    db: adminDb,
    Timestamp,
    uid: "alice",
    vehicleId: "EV002",
  });
  const profile = await adminDb.doc("users/alice").get();
  const selectedCard = await adminDb
    .doc(cardPath("alice", profile.data().vehicleId))
    .get();

  assert.equal(result.vehicleId, "EV002");
  assert.equal(profile.data().vehicleId, "EV002");
  assert.equal(selectedCard.data().vehicleId, "EV002");
  await assert.rejects(
    backend.setConnectedVehicle({
      db: adminDb,
      Timestamp,
      uid: "alice",
      vehicleId: "EV003",
    }),
    /not linked/,
  );
});
