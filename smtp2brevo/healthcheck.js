"use strict";

const tls = require("tls");

const timeoutMs = 3_000;

function createTlsOptions(env = process.env) {
  const port = Number(env.SMTP_PORT || 8025);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65_535) {
    throw new Error("SMTP_PORT must be an integer between 1 and 65535");
  }

  return {
    host: "127.0.0.1",
    port,
    servername: env.SMTP_HOSTNAME || "smtp.example.com",
    rejectUnauthorized: true,
    timeout: timeoutMs
  };
}

function runHealthcheck(dependencies = {}) {
  const connect = dependencies.connect || tls.connect;
  const exit = dependencies.exit || process.exit;
  const env = dependencies.env || process.env;
  const socket = connect(createTlsOptions(env));

  let finished = false;
  function finish(exitCode) {
    if (finished) {
      return;
    }
    finished = true;
    socket.destroy();
    exit(exitCode);
  }

  socket.once("secureConnect", () => finish(0));
  socket.once("timeout", () => finish(1));
  socket.once("error", () => finish(1));
  return socket;
}

if (require.main === module) {
  runHealthcheck();
}

module.exports = { createTlsOptions, runHealthcheck };
