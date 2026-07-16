"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  buildBrevoPayload,
  constantTimeEqual,
  loadConfig,
  sendByBrevo
} = require("../server");

function validEnv(overrides = {}) {
  return {
    BREVO_API_KEY: "test-brevo-key",
    FROM_EMAIL: "noreply@example.com",
    SMTP_AUTH_PASS: "test-smtp-password",
    SMTP_HOSTNAME: "smtp.example.com",
    ...overrides
  };
}

test("loadConfig applies bounded production defaults", () => {
  const config = loadConfig(validEnv());

  assert.equal(config.smtpPort, 8025);
  assert.equal(config.smtpMaxMessageBytes, 10 * 1024 * 1024);
  assert.equal(config.smtpMaxRecipients, 1);
  assert.equal(config.smtpMaxClients, 20);
  assert.equal(config.brevoTimeoutMs, 15_000);
  assert.equal(
    config.tlsCertPath,
    "/etc/letsencrypt/live/smtp.example.com/fullchain.pem"
  );
});

test("loadConfig rejects missing secrets and invalid integers", () => {
  assert.throws(() => loadConfig(validEnv({ BREVO_API_KEY: "" })), /BREVO_API_KEY/);
  assert.throws(() => loadConfig(validEnv({ SMTP_AUTH_PASS: "" })), /SMTP_AUTH_PASS/);
  assert.throws(() => loadConfig(validEnv({ SMTP_PORT: "not-a-port" })), /SMTP_PORT/);
  assert.throws(() => loadConfig(validEnv({ SMTP_PORT: "65536" })), /SMTP_PORT/);
  assert.throws(
    () => loadConfig(validEnv({ SMTP_MAX_RECIPIENTS: "101" })),
    /SMTP_MAX_RECIPIENTS/
  );
  assert.throws(
    () => loadConfig(validEnv({ BREVO_TIMEOUT_MS: "999" })),
    /BREVO_TIMEOUT_MS/
  );
});

test("constantTimeEqual compares complete credentials", () => {
  assert.equal(constantTimeEqual("sub2api", "sub2api"), true);
  assert.equal(constantTimeEqual("sub2api", "sub2apj"), false);
  assert.equal(constantTimeEqual("short", "longer"), false);
});

test("buildBrevoPayload uses the configured sender and fallback content", () => {
  const config = loadConfig(validEnv({ REPLY_TO: "support@example.com" }));
  const payload = buildBrevoPayload({ subject: "Code" }, ["user@example.com"], config);

  assert.deepEqual(payload.sender, { email: "noreply@example.com", name: "Blindot API" });
  assert.deepEqual(payload.to, [{ email: "user@example.com" }]);
  assert.deepEqual(payload.replyTo, { email: "support@example.com" });
  assert.equal(payload.textContent, "This email contains no readable content.");
});

test("buildBrevoPayload rejects attachments instead of silently dropping them", () => {
  const config = loadConfig(validEnv());

  assert.throws(
    () =>
      buildBrevoPayload(
        { attachments: [{ filename: "private.txt", content: Buffer.from("secret") }] },
        ["user@example.com"],
        config
      ),
    (error) => {
      assert.equal(error.code, "SMTP_ATTACHMENTS_UNSUPPORTED");
      assert.equal(error.responseCode, 554);
      return true;
    }
  );
});

test("sendByBrevo sends JSON without exposing credentials in the body", async () => {
  const config = loadConfig(validEnv());
  let request;
  const fetchImpl = async (url, options) => {
    request = { url, options };
    return { ok: true, status: 201 };
  };

  await sendByBrevo(
    { subject: "Verification", text: "123456" },
    ["user@example.com"],
    config,
    fetchImpl
  );

  assert.equal(request.url, "https://api.brevo.com/v3/smtp/email");
  assert.equal(request.options.headers["api-key"], "test-brevo-key");
  assert.doesNotMatch(request.options.body, /test-brevo-key/);
  assert.deepEqual(JSON.parse(request.options.body).to, [{ email: "user@example.com" }]);
});

test("sendByBrevo reports only the upstream status on failure", async () => {
  const config = loadConfig(validEnv());
  let responseBodyRead = false;
  let responseBodyCanceled = false;
  const fetchImpl = async () => ({
    ok: false,
    status: 429,
    body: {
      cancel: async () => {
        responseBodyCanceled = true;
      }
    },
    text: async () => {
      responseBodyRead = true;
      return "provider response that must not be copied into logs";
    }
  });

  await assert.rejects(
    sendByBrevo({ text: "test" }, ["user@example.com"], config, fetchImpl),
    (error) => {
      assert.equal(error.message, "Brevo API request failed with status 429");
      assert.doesNotMatch(error.message, /provider response/);
      return true;
    }
  );
  assert.equal(responseBodyRead, false);
  assert.equal(responseBodyCanceled, true);
});
