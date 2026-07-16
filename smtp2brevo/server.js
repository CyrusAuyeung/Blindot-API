"use strict";

const { timingSafeEqual } = require("crypto");
const fs = require("fs");
const { simpleParser } = require("mailparser");
const { SMTPServer } = require("smtp-server");

function requiredEnv(env, name) {
  const value = String(env[name] || "").trim();
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function integerInRange(env, name, defaultValue, minimum, maximum) {
  const raw = String(env[name] ?? defaultValue).trim();
  const value = Number(raw);
  if (
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return value;
}

function loadConfig(env = process.env) {
  const smtpHostname = String(env.SMTP_HOSTNAME || "smtp.example.com").trim();

  return Object.freeze({
    brevoApiKey: requiredEnv(env, "BREVO_API_KEY"),
    fromEmail: requiredEnv(env, "FROM_EMAIL"),
    fromName: String(env.FROM_NAME || "Blindot API").trim(),
    replyTo: String(env.REPLY_TO || "").trim(),
    smtpHostname,
    smtpPort: integerInRange(env, "SMTP_PORT", 8025, 1, 65_535),
    smtpAuthUser: String(env.SMTP_AUTH_USER || "sub2api").trim(),
    smtpAuthPass: requiredEnv(env, "SMTP_AUTH_PASS"),
    smtpMaxMessageBytes: integerInRange(
      env,
      "SMTP_MAX_MESSAGE_BYTES",
      10 * 1024 * 1024,
      1_024,
      25 * 1024 * 1024
    ),
    smtpMaxRecipients: integerInRange(env, "SMTP_MAX_RECIPIENTS", 1, 1, 100),
    smtpMaxClients: integerInRange(env, "SMTP_MAX_CLIENTS", 20, 1, 1_000),
    smtpSocketTimeoutMs: integerInRange(
      env,
      "SMTP_SOCKET_TIMEOUT_MS",
      60_000,
      1_000,
      300_000
    ),
    brevoTimeoutMs: integerInRange(
      env,
      "BREVO_TIMEOUT_MS",
      15_000,
      1_000,
      120_000
    ),
    tlsKeyPath:
      String(env.SMTP_TLS_KEY_PATH || "").trim() ||
      `/etc/letsencrypt/live/${smtpHostname}/privkey.pem`,
    tlsCertPath:
      String(env.SMTP_TLS_CERT_PATH || "").trim() ||
      `/etc/letsencrypt/live/${smtpHostname}/fullchain.pem`
  });
}

function constantTimeEqual(actual, expected) {
  const actualBuffer = Buffer.from(String(actual || ""));
  const expectedBuffer = Buffer.from(String(expected || ""));
  if (actualBuffer.length !== expectedBuffer.length) {
    return false;
  }
  return timingSafeEqual(actualBuffer, expectedBuffer);
}

function smtpError(message, responseCode, code) {
  const error = new Error(message);
  error.responseCode = responseCode;
  if (code) {
    error.code = code;
  }
  return error;
}

function buildBrevoPayload(parsed, recipients, config) {
  if (parsed.attachments?.length) {
    throw smtpError("Attachments are not supported", 554, "SMTP_ATTACHMENTS_UNSUPPORTED");
  }

  const payload = {
    sender: { email: config.fromEmail, name: config.fromName },
    to: recipients.map((email) => ({ email })),
    subject: parsed.subject || "Blindot API Verification Code",
    htmlContent: parsed.html || undefined,
    textContent: parsed.text || undefined,
    replyTo: config.replyTo ? { email: config.replyTo } : undefined
  };

  if (!payload.htmlContent && !payload.textContent) {
    payload.textContent = "This email contains no readable content.";
  }

  return payload;
}

async function sendByBrevo(parsed, recipients, config, fetchImpl = globalThis.fetch) {
  const response = await fetchImpl("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": config.brevoApiKey,
      "content-type": "application/json",
      accept: "application/json"
    },
    body: JSON.stringify(buildBrevoPayload(parsed, recipients, config)),
    signal: AbortSignal.timeout(config.brevoTimeoutMs)
  });

  // The response payload is not used. Explicitly cancel it on both success
  // and failure so undici can release the underlying connection promptly.
  if (response.body && typeof response.body.cancel === "function") {
    await response.body.cancel().catch(() => undefined);
  }

  if (!response.ok) {
    const error = new Error(`Brevo API request failed with status ${response.status}`);
    error.code = "BREVO_HTTP_ERROR";
    error.status = response.status;
    throw error;
  }
}

function createServer(config, dependencies = {}) {
  const readFile = dependencies.readFile || fs.readFileSync;
  const parseMail = dependencies.parseMail || simpleParser;
  const deliver = dependencies.deliver || sendByBrevo;
  const fetchImpl = dependencies.fetch || globalThis.fetch;

  return new SMTPServer({
    name: config.smtpHostname,
    secure: true,
    minVersion: "TLSv1.2",
    authOptional: false,
    authMethods: ["PLAIN", "LOGIN"],
    disableReverseLookup: true,
    size: config.smtpMaxMessageBytes,
    maxClients: config.smtpMaxClients,
    socketTimeout: config.smtpSocketTimeoutMs,
    key: readFile(config.tlsKeyPath),
    cert: readFile(config.tlsCertPath),

    onAuth(auth, session, callback) {
      const userMatches = constantTimeEqual(auth.username, config.smtpAuthUser);
      const passwordMatches = constantTimeEqual(auth.password, config.smtpAuthPass);
      if (userMatches && passwordMatches) {
        callback(null, { user: config.smtpAuthUser });
        return;
      }
      callback(smtpError("Invalid SMTP credentials", 535, "SMTP_AUTH_FAILED"));
    },

    onRcptTo(address, session, callback) {
      const acceptedRecipients = session.envelope.rcptTo?.length || 0;
      if (acceptedRecipients >= config.smtpMaxRecipients) {
        callback(smtpError("Too many recipients", 452, "SMTP_RECIPIENT_LIMIT"));
        return;
      }
      callback();
    },

    onData(stream, session, callback) {
      parseMail(stream, {
        skipHtmlToText: true,
        skipTextToHtml: true,
        skipImageLinks: true,
        maxHtmlLengthToParse: config.smtpMaxMessageBytes
      })
        .then(async (parsed) => {
          if (stream.sizeExceeded) {
            throw smtpError("Message too large", 552, "SMTP_MESSAGE_TOO_LARGE");
          }

          const recipients = session.envelope.rcptTo
            .map((item) => item.address)
            .filter(Boolean);

          if (recipients.length === 0) {
            throw smtpError("No recipients found", 554, "SMTP_NO_RECIPIENTS");
          }

          await deliver(parsed, recipients, config, fetchImpl);
          console.log(
            JSON.stringify({
              level: "info",
              event: "mail_sent",
              recipient_count: recipients.length
            })
          );
          callback(null, "Message accepted");
        })
        .catch((error) => {
          const responseCode = Number.isInteger(error.responseCode) ? error.responseCode : 451;
          console.error(
            JSON.stringify({
              level: "error",
              event: "mail_failed",
              error_code: error.code || "MAIL_DELIVERY_FAILED",
              upstream_status: error.status || undefined
            })
          );
          callback(smtpError(responseCode === 552 ? "Message too large" : "Mail delivery failed", responseCode));
        });
    }
  });
}

function start() {
  let config;
  let server;

  try {
    config = loadConfig();
    server = createServer(config);
  } catch (error) {
    console.error(
      JSON.stringify({ level: "error", event: "startup_failed", message: error.message })
    );
    process.exitCode = 1;
    return null;
  }

  server.on("error", (error) => {
    console.error(
      JSON.stringify({ level: "error", event: "smtp_server_error", error_code: error.code })
    );
  });

  server.listen(config.smtpPort, "0.0.0.0", () => {
    console.log(
      JSON.stringify({
        level: "info",
        event: "smtp_server_started",
        port: config.smtpPort,
        hostname: config.smtpHostname
      })
    );
  });

  let shuttingDown = false;
  const shutdown = (signal) => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    console.log(JSON.stringify({ level: "info", event: "shutdown_started", signal }));

    const forceExit = setTimeout(() => process.exit(1), 10_000);
    forceExit.unref();
    server.close(() => {
      clearTimeout(forceExit);
      process.exit(0);
    });
  };

  process.once("SIGTERM", () => shutdown("SIGTERM"));
  process.once("SIGINT", () => shutdown("SIGINT"));
  return server;
}

if (require.main === module) {
  start();
}

module.exports = {
  buildBrevoPayload,
  constantTimeEqual,
  createServer,
  loadConfig,
  sendByBrevo,
  start
};
