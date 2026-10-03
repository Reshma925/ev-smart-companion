const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  askLearningAssistant,
  validateContext,
  validateQuestion,
  validateTopic,
} = require("../learning_assistant");

test("rejects empty and excessively long assistant questions", () => {
  assert.throws(
    () => validateQuestion("  "),
    (error) => error.code === "invalid-argument",
  );
  assert.throws(
    () => validateQuestion("x".repeat(2001)),
    (error) => error.code === "invalid-argument",
  );
});

test("validates topic and optional learning context", () => {
  assert.equal(validateTopic(undefined), "EV learning");
  assert.equal(validateTopic(" Batteries "), "Batteries");
  assert.equal(validateContext(undefined), "");
  assert.equal(validateContext("  Current lesson: batteries  "), "Current lesson: batteries");
  assert.throws(
    () => validateTopic(" "),
    (error) => error.code === "invalid-argument",
  );
  assert.throws(
    () => validateContext({ battery: 50 }),
    (error) => error.code === "invalid-argument",
  );
  assert.throws(
    () => validateContext("x".repeat(2001)),
    (error) => error.code === "invalid-argument",
  );
});

test("uses the secure provider key and required message/topic/context contract", async () => {
  let request;
  const answer = await askLearningAssistant({
    message: "Why is my range lower today?",
    topic: "Battery and range",
    context: '{"batteryPercentage":54,"estimatedRangeKm":153}',
    apiKey: "test-secret",
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    { text: "Range estimates change with conditions." },
                  ],
                },
              },
            ],
          }),
      };
    },
  });

  assert.equal(answer, "Range estimates change with conditions.");
  assert.equal(request.options.headers["x-goog-api-key"], "test-secret");
  assert.equal(request.url.includes("test-secret"), false);
  const requestBody = JSON.parse(request.options.body);
  assert.equal(requestBody.systemInstruction.parts.length, 1);
  const prompt = requestBody.contents[0].parts[0].text;
  assert.match(prompt, /Learning topic: Battery and range/);
  assert.match(prompt, /batteryPercentage":54/);
  assert.match(
    requestBody.systemInstruction.parts[0].text,
    /educational tutor for electric-vehicle owners/i,
  );
});

test("sends a basic question without vehicle context and parses Gemini output", async () => {
  let request;
  const answer = await askLearningAssistant({
    message: "Explain regenerative braking in one short paragraph.",
    apiKey: "test-secret",
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [{ text: "Regenerative braking recovers energy." }],
                },
              },
            ],
          }),
      };
    },
  });

  const prompt = JSON.parse(request.options.body).contents[0].parts[0].text;
  assert.equal(answer, "Regenerative braking recovers energy.");
  assert.match(prompt, /Explain regenerative braking in one short paragraph/);
  assert.doesNotMatch(prompt, /Learning context:/);
});

test("logs provider error details without logging the API key", async () => {
  const logs = [];
  const originalInfo = console.info;
  const originalError = console.error;
  console.info = (...values) => logs.push(values.join(" "));
  console.error = (...values) => logs.push(values.join(" "));

  try {
    await assert.rejects(
      askLearningAssistant({
        message: "What is regenerative braking?",
        apiKey: "never-log-this-key",
        fetchImpl: async () => ({
          ok: false,
          status: 403,
          text: async () =>
            JSON.stringify({
              error: { message: "API key not valid: never-log-this-key" },
            }),
        }),
      }),
      (error) => error.code === "internal",
    );
  } finally {
    console.info = originalInfo;
    console.error = originalError;
  }

  const output = logs.join("\n");
  assert.match(output, /\[AI ERROR\] HTTP status: 403/);
  assert.match(output, /API key not valid: \[REDACTED\]/);
  assert.doesNotMatch(output, /never-log-this-key/);
});

test("reports provider failures and invalid output with safe error codes", async () => {
  await assert.rejects(
    askLearningAssistant({
      message: "What is AC charging?",
      apiKey: "test-secret",
      fetchImpl: async () => ({
        ok: false,
        status: 429,
        text: async () =>
          JSON.stringify({ error: { message: "Resource exhausted." } }),
      }),
    }),
    (error) => error.code === "unavailable",
  );
  await assert.rejects(
    askLearningAssistant({
      message: "What is AC charging?",
      apiKey: "test-secret",
      fetchImpl: async () => ({
        ok: true,
        status: 200,
        text: async () => JSON.stringify({ candidates: [] }),
      }),
    }),
    (error) => error.code === "unavailable",
  );
  await assert.rejects(
    askLearningAssistant({
      message: "What is AC charging?",
      apiKey: "",
    }),
    (error) => error.code === "failed-precondition",
  );
});
