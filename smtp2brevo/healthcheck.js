"use strict";

const tls = require("tls");

const port = Number(process.env.SMTP_PORT || 8025);
const servername = process.env.SMTP_HOSTNAME || "smtp.example.com";
const timeoutMs = 3_000;

const socket = tls.connect({
  host: "127.0.0.1",
  port,
  servername,
  rejectUnauthorized: false,
  timeout: timeoutMs
});

let finished = false;
function finish(exitCode) {
  if (finished) {
    return;
  }
  finished = true;
  socket.destroy();
  process.exit(exitCode);
}

socket.once("secureConnect", () => finish(0));
socket.once("timeout", () => finish(1));
socket.once("error", () => finish(1));
