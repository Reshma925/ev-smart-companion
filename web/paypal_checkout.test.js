const assert = require("node:assert/strict");
const { readFile } = require("node:fs/promises");
const { join } = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

test("PayPal Web SDK v6 uses the existing order and popup session callbacks", async () => {
  const scriptText = await readFile(
    join(__dirname, "paypal_checkout.js"),
    "utf8",
  );
  const events = [];
  let sessionOptions;
  let startOptions;
  const sdk = {
    async createInstance(options) {
      assert.equal(options.clientId, "public-sandbox-client-id");
      assert.deepEqual(Array.from(options.components), ["paypal-payments"]);
      return {
        createPayPalOneTimePaymentSession(options) {
          sessionOptions = options;
          return {
            start(options) {
              startOptions = options;
              return Promise.resolve();
            },
          };
        },
      };
    },
  };
  const window = {
    evPaypalCheckout: undefined,
    paypal: undefined,
  };
  const document = {
    createElement(tag) {
      assert.equal(tag, "script");
      return {
        set src(value) {
          assert.equal(value, "https://www.sandbox.paypal.com/web-sdk/v6/core");
        },
        async: false,
        onload: null,
        onerror: null,
      };
    },
    head: {
      appendChild(script) {
        window.paypal = sdk;
        script.onload();
      },
    },
  };

  vm.runInNewContext(scriptText, { document, window, Promise });
  window.evPaypalCheckout.setEventCallback((event) => events.push(event));

  await window.evPaypalCheckout.prepare(
    "public-sandbox-client-id",
    "ORDER-100",
  );
  assert.equal(sessionOptions.orderId, "ORDER-100");

  window.evPaypalCheckout.start();
  await Promise.resolve();
  assert.equal(startOptions.presentationMode, "popup");

  let approved = false;
  const approval = sessionOptions.onApprove({ orderId: "ORDER-100" }).then(() => {
    approved = true;
  });
  assert.equal(approved, false);
  assert.equal(events.at(-1).status, "approved");
  assert.equal(events.at(-1).orderId, "ORDER-100");
  window.evPaypalCheckout.finishCapture(true);
  await approval;
  assert.equal(approved, true);

  sessionOptions.onCancel();
  assert.equal(events.at(-1).status, "cancelled");
  sessionOptions.onError(new Error("SDK checkout error"));
  assert.equal(events.at(-1).status, "failed");
  assert.equal(events.at(-1).message, "SDK checkout error");
});
