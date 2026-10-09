(() => {
  const sdkUrl = "https://www.sandbox.paypal.com/web-sdk/v6/core";
  let sdkPromise;
  let paymentSession;
  let pendingApproval;
  let eventCallback = () => {};

  function emit(status, details = {}) {
    eventCallback({ status, ...details });
  }

  function safeMessage(error) {
    return typeof error?.message === "string"
      ? error.message.slice(0, 300)
      : "PayPal checkout could not be completed.";
  }

  function loadSdk() {
    if (window.paypal?.createInstance) return Promise.resolve(window.paypal);
    if (sdkPromise) return sdkPromise;

    sdkPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = sdkUrl;
      script.async = true;
      script.onload = () => {
        if (window.paypal?.createInstance) resolve(window.paypal);
        else reject(new Error("PayPal Web SDK did not initialize."));
      };
      script.onerror = () => reject(new Error("PayPal Web SDK failed to load."));
      document.head.appendChild(script);
    });
    return sdkPromise;
  }

  async function prepare(clientId, orderId) {
    if (!clientId || !orderId) {
      throw new Error("PayPal checkout is missing its public client ID or order ID.");
    }

    const paypal = await loadSdk();
    const sdkInstance = await paypal.createInstance({
      clientId,
      components: ["paypal-payments"],
      pageType: "checkout",
    });
    paymentSession = sdkInstance.createPayPalOneTimePaymentSession({
      orderId,
      onApprove: (data) =>
        new Promise((resolve, reject) => {
          pendingApproval = { orderId: data.orderId, resolve, reject };
          emit("approved", { orderId: data.orderId });
        }),
      onCancel: () => emit("cancelled"),
      onError: (error) => emit("failed", { message: safeMessage(error) }),
    });
  }

  function start() {
    if (!paymentSession) {
      throw new Error("PayPal checkout is not ready.");
    }
    paymentSession
      .start({ presentationMode: "popup" })
      .catch((error) => emit("failed", { message: safeMessage(error) }));
  }

  function finishCapture(success) {
    if (!pendingApproval) return;
    const approval = pendingApproval;
    pendingApproval = undefined;
    if (success) {
      approval.resolve();
    } else {
      approval.reject(new Error("The server did not confirm the PayPal capture."));
    }
  }

  window.evPaypalCheckout = {
    finishCapture,
    prepare,
    setEventCallback(callback) {
      eventCallback = callback;
    },
    start,
  };
})();
