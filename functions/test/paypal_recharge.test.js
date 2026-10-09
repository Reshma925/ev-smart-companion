const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { test } = require("node:test");
const backend = require("../card_backend");

function createFakeFirestore(initialDocuments) {
  const documents = new Map(
    Object.entries(initialDocuments).map(([path, data]) => [path, structuredClone(data)]),
  );

  function document(path) {
    const id = path.split("/").at(-1);
    return {
      id,
      path,
      collection(name) {
        return collection(`${path}/${name}`);
      },
      async get() {
        const data = documents.get(path);
        return {
          exists: data !== undefined,
          data: () => data && structuredClone(data),
        };
      },
      async create(data) {
        if (documents.has(path)) throw new Error("Document already exists.");
        documents.set(path, structuredClone(data));
      },
      async update(data) {
        const existing = documents.get(path);
        if (!existing) throw new Error("Document does not exist.");
        documents.set(path, { ...existing, ...structuredClone(data) });
      },
    };
  }

  function collection(path) {
    return { doc: (id) => document(`${path}/${id}`) };
  }

  return {
    collection,
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        get: (ref) => ref.get(),
        update: (ref, data) => writes.push({ kind: "update", ref, data }),
        create: (ref, data) => writes.push({ kind: "create", ref, data }),
      };
      const result = await callback(transaction);
      for (const write of writes) {
        if (write.kind === "create") await write.ref.create(write.data);
        else await write.ref.update(write.data);
      }
      return result;
    },
    documents,
  };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

test("PayPal recharge creates and captures a sandbox order once", async (context) => {
  const vehicleId = "EV001";
  const cardPath =
    `users/alice/vehicles/${vehicleId}/chargingCard/current`;
  const db = createFakeFirestore({
    "users/alice": { uid: "alice", vehicleId },
    [`users/alice/vehicles/${vehicleId}`]: { vehicleId },
    [`vehicles/${vehicleId}`]: { isActive: true },
    [cardPath]: { balance: 25, currency: "INR" },
  });
  const originalFetch = global.fetch;
  let captureRequests = 0;
  const requests = [];
  global.fetch = async (url, options) => {
    requests.push({ url: String(url), options });
    if (String(url).endsWith("/v1/oauth2/token")) {
      return jsonResponse({ access_token: "test-only-token" });
    }
    if (String(url).endsWith("/v2/checkout/orders")) {
      return jsonResponse({
        id: "SANDBOXORDER123",
        status: "CREATED",
        links: [{ rel: "approve", href: "https://sandbox.example/approve" }],
      });
    }
    if (String(url).endsWith("/v2/checkout/orders/SANDBOXORDER123/capture")) {
      captureRequests += 1;
      return jsonResponse({
        status: "COMPLETED",
        purchase_units: [{
          payments: {
            captures: [{
              id: "SANDBOXCATURE123",
              status: "COMPLETED",
              amount: { value: "1.20", currency_code: "USD" },
            }],
          },
        }],
      });
    }
    throw new Error(`Unexpected PayPal test URL: ${url}`);
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  const timestamp = { now: () => new Date("2026-10-08T00:00:00.000Z") };
  const credentials = {
    paypalClientId: "sandbox-client-id",
    paypalClientSecret: "sandbox-client-secret",
  };
  const order = await backend.createPayPalRechargeOrder({
    db,
    Timestamp: timestamp,
    uid: "alice",
    vehicleId,
    amount: 100,
    currency: "INR",
    paypalAmount: 9999,
    ...credentials,
  });

  assert.equal(order.orderId, "SANDBOXORDER123");
  assert.equal(order.demoMode, undefined);
  assert.equal(order.amount, 100);
  assert.equal(order.currency, "INR");
  assert.equal(order.paypalAmount, 1.2);
  assert.equal(order.paypalCurrency, "USD");
  assert.equal(order.conversionType, "demo_fixed_rate");
  assert.equal(order.demoExchangeRate, 0.012);
  assert.equal(order.paypalClientId, "sandbox-client-id");
  assert.equal(
    requests[0].url,
    "https://api-m.sandbox.paypal.com/v1/oauth2/token",
  );
  assert.ok(
    requests[0].options.headers.Authorization.startsWith("Basic "),
  );
  assert.equal(requests[0].options.method, "POST");
  assert.equal(
    requests[0].options.headers["Content-Type"],
    "application/x-www-form-urlencoded",
  );
  assert.equal(requests[0].options.body, "grant_type=client_credentials");
  assert.equal(requests[1].url, "https://api-m.sandbox.paypal.com/v2/checkout/orders");
  assert.equal(requests[1].options.method, "POST");
  assert.equal(requests[1].options.headers["Content-Type"], "application/json");
  assert.ok(
    requests[1].options.headers.Authorization.startsWith("Bearer "),
  );
  assert.match(requests[1].options.headers.Authorization, /^Bearer .+$/);
  const orderPayload = JSON.parse(requests[1].options.body);
  assert.deepEqual(orderPayload, {
    intent: "CAPTURE",
    purchase_units: [{
      reference_id: vehicleId,
      description: "EV Smart Companion charging-card recharge",
      amount: {
        currency_code: "USD",
        value: "1.20",
      },
    }],
    application_context: {
      brand_name: "EV Smart Companion",
      landing_page: "LOGIN",
      user_action: "PAY_NOW",
      return_url: "https://example.com/paypal-return",
      cancel_url: "https://example.com/paypal-cancel",
    },
  });
  assert.equal(orderPayload.intent, "CAPTURE");
  assert.equal(orderPayload.purchase_units.length, 1);
  assert.equal(orderPayload.purchase_units[0].amount.value, "1.20");
  assert.equal(orderPayload.purchase_units[0].amount.currency_code, "USD");
  const orderRecord = db.documents.get(
    `paypalRechargeOrders/${createHash("sha256").update(order.orderId).digest("hex")}`,
  );
  assert.equal(orderRecord.amount, 100);
  assert.equal(orderRecord.currency, "INR");
  assert.equal(orderRecord.paypalAmount, 1.2);
  assert.equal(orderRecord.paypalCurrency, "USD");
  assert.equal(orderRecord.conversionType, "demo_fixed_rate");
  assert.equal(orderRecord.demoExchangeRate, 0.012);
  assert.equal(requests[1].options.headers.Authorization, "Bearer test-only-token");

  const captured = await backend.capturePayPalRechargeOrder({
    db,
    Timestamp: timestamp,
    uid: "alice",
    vehicleId,
    orderId: order.orderId,
    ...credentials,
  });
  const repeatedCapture = await backend.capturePayPalRechargeOrder({
    db,
    Timestamp: timestamp,
    uid: "alice",
    vehicleId,
    orderId: order.orderId,
    ...credentials,
  });
  assert.equal(captured.success, true);
  assert.equal(repeatedCapture.alreadyCaptured, true);
  assert.equal(captureRequests, 1);
  assert.equal(db.documents.get(cardPath).balance, 125);

  const transactionRecords = [...db.documents.entries()].filter(([path]) =>
    path.startsWith(`${cardPath}/transactions/`),
  );
  assert.equal(transactionRecords.length, 1);
  assert.equal(transactionRecords[0][1].provider, "paypal");
  assert.equal(transactionRecords[0][1].paypalOrderId, order.orderId);
  assert.equal(transactionRecords[0][1].paypalCaptureId, "SANDBOXCATURE123");
  assert.equal(transactionRecords[0][1].amount, 100);
  assert.equal(transactionRecords[0][1].currency, "INR");
  assert.equal(transactionRecords[0][1].paypalAmount, 1.2);
  assert.equal(transactionRecords[0][1].paypalCurrency, "USD");
  assert.equal(transactionRecords[0][1].conversionType, "demo_fixed_rate");
  assert.equal(transactionRecords[0][1].demoExchangeRate, 0.012);
  assert.equal(transactionRecords[0][1].status, "completed");
  assert.equal(transactionRecords[0][1].cvv, undefined);
  assert.equal(captured.amount, 100);
  assert.equal(captured.currency, "INR");
  assert.equal(captured.paypalAmount, 1.2);
  assert.equal(captured.paypalCurrency, "USD");
});

test("fixed demo conversion maps supported INR presets to USD cents", () => {
  for (const [inr, usd] of [[100, 1.2], [250, 3], [500, 6], [1000, 12]]) {
    assert.equal(backend.convertInrToPaypalAmount(inr), usd);
  }
});

test("₹1000 order sends the exact USD 12.00 body to PayPal", async (context) => {
  const vehicleId = "EV001";
  const db = createFakeFirestore({
    "users/alice": { uid: "alice", vehicleId },
    [`users/alice/vehicles/${vehicleId}`]: { vehicleId },
    [`vehicles/${vehicleId}`]: { isActive: true },
    [`users/alice/vehicles/${vehicleId}/chargingCard/current`]: {
      balance: 1000,
      currency: "INR",
    },
  });
  const originalFetch = global.fetch;
  let serializedOrderBody;
  global.fetch = async (url, options) => {
    if (String(url).endsWith("/v1/oauth2/token")) {
      return jsonResponse({ access_token: "test-only-token" });
    }
    assert.equal(
      String(url),
      "https://api-m.sandbox.paypal.com/v2/checkout/orders",
    );
    serializedOrderBody = options.body;
    return jsonResponse({
      id: "SANDBOXORDER1000",
      status: "CREATED",
      links: [{ rel: "approve", href: "https://sandbox.example/approve" }],
    });
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  const order = await backend.createPayPalRechargeOrder({
    db,
    Timestamp: { now: () => new Date("2026-10-09T00:00:00.000Z") },
    uid: "alice",
    vehicleId,
    amount: 1000,
    currency: "INR",
    paypalClientId: "test-only-client-id",
    paypalClientSecret: "test-only-client-secret",
  });

  const sentBody = JSON.parse(serializedOrderBody);
  assert.deepEqual(sentBody.purchase_units[0].amount, {
    currency_code: "USD",
    value: "12.00",
  });
  assert.equal(order.amount, 1000);
  assert.equal(order.currency, "INR");
  assert.equal(order.paypalAmount, 12);
  assert.equal(order.paypalCurrency, "USD");
});

test("PayPal API errors retain only safe issue fields and debug ID", async (context) => {
  const db = createFakeFirestore({
    "users/alice": { uid: "alice", vehicleId: "EV001" },
    "users/alice/vehicles/EV001": { vehicleId: "EV001" },
    "vehicles/EV001": { isActive: true },
    "users/alice/vehicles/EV001/chargingCard/current": { balance: 1000 },
  });
  const originalFetch = global.fetch;
  global.fetch = async (url) => {
    if (String(url).endsWith("/v1/oauth2/token")) {
      return jsonResponse({ access_token: "test-only-token" });
    }
    return jsonResponse({
      name: "UNPROCESSABLE_ENTITY",
      details: [{
        issue: "INVALID_CURRENCY_CODE",
        field: "/purchase_units/@reference_id=='EV001'/amount/currency_code",
        description: "Test safe response description",
      }],
      message: "Test safe PayPal response message",
      debug_id: "SAFE-DEBUG-ID",
    }, 422);
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    backend.createPayPalRechargeOrder({
      db,
      Timestamp: { now: () => new Date() },
      uid: "alice",
      vehicleId: "EV001",
      amount: 100,
      currency: "INR",
      paypalClientId: "test-only-client-id",
      paypalClientSecret: "test-only-client-secret",
    }),
    (error) => {
      assert.equal(error.name, "PayPalApiError");
      assert.equal(error.status, 422);
      assert.equal(error.paypalErrorName, "UNPROCESSABLE_ENTITY");
      assert.equal(error.paypalMessage, "Test safe PayPal response message");
      assert.deepEqual(error.details, [{
        issue: "INVALID_CURRENCY_CODE",
        field: "/purchase_units/@reference_id=='EV001'/amount/currency_code",
        description: "Test safe response description",
      }]);
      assert.equal(error.debugId, "SAFE-DEBUG-ID");
      assert.equal(error.message.includes("test-only"), false);
      return true;
    },
  );
});

test("PayPal capture rejects missing credentials instead of faking success", async () => {
  await assert.rejects(
    backend.capturePayPalRechargeOrder({
      db: createFakeFirestore({}),
      uid: "alice",
      vehicleId: "EV001",
      orderId: "SANDBOXORDER123",
    }),
    /PayPal Sandbox credentials are not configured for the local emulator/,
  );
});

test("PayPal recharge rejects invalid and excessive amounts before contacting PayPal", async (context) => {
  const originalFetch = global.fetch;
  let requests = 0;
  global.fetch = async () => {
    requests += 1;
    throw new Error("Invalid amount reached PayPal.");
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  for (const amount of [0, -1, Number.NaN, 100.001, 10000.01]) {
    await assert.rejects(
      backend.createPayPalRechargeOrder({
        db: createFakeFirestore({}),
        uid: "alice",
        vehicleId: "EV001",
        amount,
        currency: "INR",
        paypalClientId: "test-only-client-id",
        paypalClientSecret: "test-only-client-secret",
      }),
      /Recharge amount/,
    );
  }
  assert.equal(requests, 0);
});

test("PayPal order currency must match the registered charging card", async (context) => {
  const originalFetch = global.fetch;
  let requests = 0;
  global.fetch = async () => {
    requests += 1;
    throw new Error("Currency mismatch reached PayPal.");
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  const db = createFakeFirestore({
    "users/alice": { uid: "alice", vehicleId: "EV001" },
    "users/alice/vehicles/EV001": { vehicleId: "EV001" },
    "vehicles/EV001": { isActive: true },
    "users/alice/vehicles/EV001/chargingCard/current": {
      balance: 1000,
      currency: "INR",
    },
  });

  await assert.rejects(
    backend.createPayPalRechargeOrder({
      db,
      uid: "alice",
      vehicleId: "EV001",
      amount: 100,
      currency: "USD",
      paypalClientId: "test-only-client-id",
      paypalClientSecret: "test-only-client-secret",
    }),
    /Recharge currency must match/,
  );
  assert.equal(requests, 0);
});

test("PayPal order cannot be captured by a different authenticated user", async (context) => {
  const originalFetch = global.fetch;
  let requests = 0;
  global.fetch = async () => {
    requests += 1;
    throw new Error("Foreign capture reached PayPal.");
  };
  context.after(() => {
    global.fetch = originalFetch;
  });
  const orderId = "SANDBOXORDER123";
  const orderDocumentId = createHash("sha256").update(orderId).digest("hex");
  const db = createFakeFirestore({
    [`paypalRechargeOrders/${orderDocumentId}`]: {
      orderId,
      uid: "alice",
      vehicleId: "EV001",
      amount: 100,
      currency: "INR",
      status: "PENDING",
    },
  });

  await assert.rejects(
    backend.capturePayPalRechargeOrder({
      db,
      uid: "bob",
      vehicleId: "EV001",
      orderId,
      paypalClientId: "test-only-client-id",
      paypalClientSecret: "test-only-client-secret",
    }),
    /does not belong to this account and vehicle/,
  );
  assert.equal(requests, 0);
});

test("PayPal pending capture never updates the charging-card balance", async (context) => {
  const vehicleId = "EV001";
  const cardPath = `users/alice/vehicles/${vehicleId}/chargingCard/current`;
  const orderId = "SANDBOXORDER123";
  const orderDocumentId = createHash("sha256").update(orderId).digest("hex");
  const db = createFakeFirestore({
    "users/alice": { uid: "alice", vehicleId },
    [`users/alice/vehicles/${vehicleId}`]: { vehicleId },
    [`vehicles/${vehicleId}`]: { isActive: true },
    [cardPath]: { balance: 1000, currency: "INR" },
    [`paypalRechargeOrders/${orderDocumentId}`]: {
      orderId,
      uid: "alice",
      vehicleId,
      amount: 100,
      currency: "INR",
      status: "PENDING",
    },
  });
  const originalFetch = global.fetch;
  global.fetch = async (url) => {
    if (String(url).endsWith("/v1/oauth2/token")) {
      return jsonResponse({ access_token: "test-only-token" });
    }
    return jsonResponse({
      status: "PENDING",
      purchase_units: [{
        payments: {
          captures: [{
            id: "SANDBOXCATURE123",
            status: "PENDING",
            amount: { value: "100.00", currency_code: "INR" },
          }],
        },
      }],
    });
  };
  context.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    backend.capturePayPalRechargeOrder({
      db,
      Timestamp: { now: () => new Date() },
      uid: "alice",
      vehicleId,
      orderId,
      paypalClientId: "test-only-client-id",
      paypalClientSecret: "test-only-client-secret",
    }),
    /did not confirm a completed capture/,
  );
  assert.equal(db.documents.get(cardPath).balance, 1000);
  assert.equal(
    [...db.documents.keys()].some((path) =>
      path.startsWith(`${cardPath}/transactions/`),
    ),
    false,
  );
});
