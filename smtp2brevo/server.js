const { SMTPServer } = require("smtp-server");
const { simpleParser } = require("mailparser");
const fs = require("fs");

const BREVO_API_KEY = process.env.BREVO_API_KEY;
const FROM_EMAIL = process.env.FROM_EMAIL || "noreply@example.com";
const FROM_NAME = process.env.FROM_NAME || "Blindot API";
const REPLY_TO = process.env.REPLY_TO || "";
const SMTP_PORT = Number(process.env.SMTP_PORT || 8025);
const SMTP_AUTH_USER = process.env.SMTP_AUTH_USER || "sub2api";
const SMTP_AUTH_PASS = process.env.SMTP_AUTH_PASS || "";

if (!BREVO_API_KEY) {
  console.error("BREVO_API_KEY is required");
  process.exit(1);
}


async function sendByBrevo(parsed, recipients) {
  const payload = {
    sender: { email: FROM_EMAIL, name: FROM_NAME },
    to: recipients.map((email) => ({ email })),
    subject: parsed.subject || "Blindot API Verification Code",
    htmlContent: parsed.html || undefined,
    textContent: parsed.text || undefined,
    replyTo: REPLY_TO ? { email: REPLY_TO } : undefined
  };

  if (!payload.htmlContent && !payload.textContent) {
    payload.textContent = "This email contains no readable content.";
  }

  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "content-type": "application/json",
      "accept": "application/json"
    },
    body: JSON.stringify(payload)
  });

  const body = await res.text();

  if (!res.ok) {
    throw new Error(`Brevo API ${res.status}: ${body}`);
  }
}

const server = new SMTPServer({
  secure: true,
  authOptional: false,
  allowInsecureAuth: true,
  key: fs.readFileSync("/etc/letsencrypt/live/smtp.example.com/privkey.pem"),
  cert: fs.readFileSync("/etc/letsencrypt/live/smtp.example.com/fullchain.pem"),

  onAuth(auth, session, callback) {
    if (auth.username === SMTP_AUTH_USER && auth.password === SMTP_AUTH_PASS) {
      return callback(null, { user: auth.username });
    }

    return callback(new Error("Invalid SMTP username or password"));
  },

  onData(stream, session, callback) {
    simpleParser(stream)
      .then(async (parsed) => {
        const recipients = session.envelope.rcptTo
          .map((item) => item.address)
          .filter(Boolean);

        if (recipients.length === 0) {
          throw new Error("No recipients found");
        }

        await sendByBrevo(parsed, recipients);
        console.log(`sent mail to ${recipients.join(", ")} subject="${parsed.subject || ""}"`);
        callback();
      })
      .catch((error) => {
        console.error(error);
        callback(error);
      });
  }
});

server.listen(SMTP_PORT, "0.0.0.0", () => {
  console.log(`smtp2brevo listening on 0.0.0.0:${SMTP_PORT}`);
});
