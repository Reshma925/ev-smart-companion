const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");
const admin = require("firebase-admin");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const {
  Timestamp: ClientTimestamp,
  doc,
  getDoc,
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
    await adminDb.doc(
      `users/alice/vehicles/${vehicleId}/chargingCard/current`,
    ).set({
      cardId: "current",
      cardType: "EV Card",
      maskedCardNumber: `XXXX XXXX XXXX ${vehicleId.slice(-1).repeat(4)}`,
      cardHolderName: "Alice",
      vehicleId,
      expiryDate: timestamp,
      balance: 0,
      currency: "INR",
      status: "ACTIVE",
      registeredAt: timestamp,
      updatedAt: timestamp,
    });
  }
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
  await adminDb.doc("users/bob/vehicles/EV003/chargingCard/current").set({
    cardId: "current",
    balance: 500,
  });

  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  await assertSucceeds(
    getDoc(doc(aliceDb, "users/alice/vehicles/EV001/chargingCard/current")),
  );
  await assertFails(
    getDoc(doc(aliceDb, "users/bob/vehicles/EV003/chargingCard/current")),
  );
  await assertFails(getDoc(doc(aliceDb, "vehicles/EV003")));
  await assertFails(getDoc(doc(aliceDb, "vehicleClaims/EV001")));
});

test("clients cannot change card balance or write transaction records", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const cardRef = doc(aliceDb, "users/alice/vehicles/EV001/chargingCard/current");
  await assertFails(updateDoc(cardRef, { balance: 100 }));
  await assertFails(
    setDoc(
      doc(
        aliceDb,
        "users/alice/vehicles/EV001/chargingCard/current/transactions/fake",
      ),
      { amount: 1, status: "successful" },
    ),
  );
});

test("clients cannot register a second card while a legacy card exists", async () => {
  await seedLinkedVehicles();
  await adminDb
    .doc("users/alice/vehicles/EV001/chargingCard/current")
    .delete();
  await adminDb.doc("users/alice/chargingCard/current").set({
    cardType: "Old card",
    cardNumber: "12345678",
  });

  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  await assertFails(
    setDoc(
      doc(aliceDb, "users/alice/vehicles/EV001/chargingCard/current"),
      {
        cardId: "current",
        cardType: "EV Card",
        maskedCardNumber: "XXXX XXXX XXXX 1234",
        cardHolderName: "Alice",
        vehicleId: "EV001",
        expiryDate: ClientTimestamp.now(),
        balance: 0,
        currency: "INR",
        status: "ACTIVE",
        registeredAt: ClientTimestamp.now(),
        updatedAt: ClientTimestamp.now(),
      },
    ),
  );
});

test("profile settings remain editable but the connected vehicle stays protected", async () => {
  await seedLinkedVehicles();
  const aliceDb = testEnvironment.authenticatedContext("alice").firestore();
  const profile = doc(aliceDb, "users/alice");
  await assertSucceeds(
    updateDoc(profile, {
      city: "Springfield",
      updatedAt: ClientTimestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(profile, {
      vehicleId: "EV002",
      vehicleRegistrationNumber: "REG-002",
      updatedAt: ClientTimestamp.now(),
    }),
  );
});

test("legacy migration copies card and transactions without deleting legacy data", async () => {
  await seedLinkedVehicles();
  const timestamp = Timestamp.fromDate(new Date("2026-03-01T10:00:00Z"));
  await adminDb
    .doc("users/alice/vehicles/EV001/chargingCard/current")
    .delete();
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
    .doc("users/alice/vehicles/EV001/chargingCard/current")
    .get();
  const migratedTransaction = await adminDb
    .doc(
      "users/alice/vehicles/EV001/chargingCard/current/transactions/legacy-transaction",
    )
    .get();

  assert.equal(result.migrated, true);
  assert.equal(migrated.data().balance, 275.5);
  assert.equal(migrated.data().maskedCardNumber, "XXXX XXXX XXXX 3456");
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
    .doc(`users/alice/vehicles/${profile.data().vehicleId}/chargingCard/current`)
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
