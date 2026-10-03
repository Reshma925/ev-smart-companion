const MAX_QUESTION_LENGTH = 2000;
const PROVIDER = "Google Gemini";
const MODEL = "gemini-2.5-flash";
const ENDPOINT =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

function redact(value, apiKey) {
  const text = String(value ?? "");
  return apiKey ? text.split(apiKey).join("[REDACTED]") : text;
}

function logAiError(
  error,
  {
    apiKey,
    cause,
    httpStatus = "unavailable",
    responseBody = "unavailable",
  } = {},
) {
  console.error("[AI ERROR] Type:", error?.name || typeof error);
  console.error(
    "[AI ERROR] Message:",
    redact(
      [error?.message, cause?.message].filter(Boolean).join("; "),
      apiKey,
    ),
  );
  console.error("[AI ERROR] HTTP status:", httpStatus);
  console.error("[AI ERROR] Response body:", redact(responseBody, apiKey));
  console.error(
    "[AI ERROR] Stack trace:",
    redact(
      [error?.stack, cause?.stack && `Caused by: ${cause.stack}`]
        .filter(Boolean)
        .join("\n"),
      apiKey,
    ),
  );
}

function providerErrorMessage(body) {
  try {
    const payload = JSON.parse(body);
    return payload?.error?.message || payload?.message || body;
  } catch {
    return body;
  }
}

function validateQuestion(question) {
  if (typeof question !== "string" || question.trim().length === 0) {
    const error = new Error("Enter a question to continue.");
    error.code = "invalid-argument";
    throw error;
  }
  const normalized = question.trim();
  if (normalized.length > MAX_QUESTION_LENGTH) {
    const error = new Error("Question is too long.");
    error.code = "invalid-argument";
    throw error;
  }
  return normalized;
}

function validateTopic(topic) {
  if (topic === undefined) return "EV learning";
  if (typeof topic !== "string" || topic.trim().length === 0) {
    const error = new Error("Topic must be a non-empty string.");
    error.code = "invalid-argument";
    throw error;
  }
  if (topic.trim().length > 120) {
    const error = new Error("Topic is too long.");
    error.code = "invalid-argument";
    throw error;
  }
  return topic.trim();
}

function validateContext(context) {
  if (context === undefined || context === null || context === "") return "";
  if (typeof context !== "string" || context.length > 2000) {
    const error = new Error("Context must be a string of at most 2,000 characters.");
    error.code = "invalid-argument";
    throw error;
  }
  return context.trim();
}

async function askLearningAssistant({
  message,
  topic,
  context,
  apiKey,
  fetchImpl = fetch,
}) {
  const normalizedQuestion = validateQuestion(message);
  const normalizedTopic = validateTopic(topic);
  const normalizedContext = validateContext(context);
  if (!apiKey) {
    const error = new Error("Learning assistant is not configured.");
    error.code = "failed-precondition";
    logAiError(error);
    throw error;
  }

  const contents = [{
    role: "user",
    parts: [{
      text: [
        `Learning topic: ${normalizedTopic}`,
        normalizedContext ? `Learning context: ${normalizedContext}` : "",
        `Learner question: ${normalizedQuestion}`,
      ].filter(Boolean).join("\n\n"),
    }],
  }];
  const systemInstruction = {
    parts: [{
      text: [
        "You are an educational tutor for electric-vehicle owners.",
        "Explain EV concepts clearly, progressively, and in simple language when appropriate.",
        "Help learners understand EV technology, charging, batteries, motors, regenerative braking, range, charging standards, and basic EV maintenance.",
        "Use practical examples when helpful.",
        "Do not diagnose vehicle faults, control a vehicle, change settings, initiate charging, or perform maintenance actions.",
        "Do not provide unsafe instructions. For warning lights or possible faults, direct the learner to the vehicle manual and qualified support.",
        "Do not claim access to private information or live vehicle data beyond context explicitly supplied in this request.",
      ].join(" "),
    }],
  };

  console.info("[AI DEBUG] Request started");
  console.info("[AI DEBUG] Provider:", PROVIDER);
  console.info("[AI DEBUG] Endpoint:", ENDPOINT);
  console.info("[AI DEBUG] Request model:", MODEL);

  let response;
  try {
    const providerRequest = fetchImpl(ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents,
        systemInstruction,
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 700,
        },
      }),
      signal: AbortSignal.timeout(25000),
    });
    console.info("[AI DEBUG] Request started successfully");
    response = await providerRequest;
  } catch (cause) {
    const error = new Error("Learning assistant provider request failed.", {
      cause,
    });
    error.code = "unavailable";
    logAiError(error, { apiKey, cause });
    throw error;
  }

  console.info("[AI DEBUG] HTTP status:", response.status);
  console.info("[AI DEBUG] Response received");

  let responseBody;
  try {
    responseBody = await response.text();
  } catch (cause) {
    const error = new Error("Could not read the provider response body.", {
      cause,
    });
    error.code = "internal";
    logAiError(error, { apiKey, cause, httpStatus: response.status });
    throw error;
  }

  if (!response.ok) {
    const message = redact(providerErrorMessage(responseBody), apiKey);
    const error = new Error(
      message || `Provider rejected the request with HTTP ${response.status}.`,
    );
    error.name = "ProviderHttpError";
    error.code =
      response.status === 429 || response.status >= 500
        ? "unavailable"
        : "internal";
    logAiError(error, {
      apiKey,
      httpStatus: response.status,
      responseBody,
    });
    throw error;
  }

  let payload;
  try {
    console.info("[AI DEBUG] Response parsing started");
    payload = JSON.parse(responseBody);
  } catch (cause) {
    const error = new Error("Learning assistant returned an invalid response.", {
      cause,
    });
    error.code = "internal";
    logAiError(error, {
      apiKey,
      cause,
      httpStatus: response.status,
      responseBody,
    });
    throw error;
  }

  const answer = payload?.candidates?.[0]?.content?.parts
    ?.map((part) => (typeof part?.text === "string" ? part.text.trim() : ""))
    .filter(Boolean)
    .join("\n")
    .trim();
  if (!answer) {
    const error = new Error("Learning assistant returned an empty response.");
    error.code = "unavailable";
    logAiError(error, {
      apiKey,
      httpStatus: response.status,
      responseBody,
    });
    throw error;
  }
  console.info("[AI DEBUG] Response parsing succeeded");
  return answer;
}

module.exports = {
  askLearningAssistant,
  validateContext,
  validateQuestion,
  validateTopic,
};
