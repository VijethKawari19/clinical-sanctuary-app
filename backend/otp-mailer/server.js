const express = require("express");
const cors = require("cors");
const nodemailer = require("nodemailer");
require("dotenv").config();

const app = express();
app.use(express.json({ limit: "32kb" }));

const corsOrigins = (process.env.CORS_ORIGINS || "*").split(",").map((s) => s.trim()).filter(Boolean);
app.use(
  cors({
    origin: corsOrigins.includes("*") ? true : corsOrigins,
  })
);

function mustEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

function createTransport() {
  const host = mustEnv("SMTP_HOST");
  const port = Number(mustEnv("SMTP_PORT"));
  const secure = String(process.env.SMTP_SECURE || "false").toLowerCase() === "true";
  const user = mustEnv("SMTP_USER");
  const pass = mustEnv("SMTP_PASS");
  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });
}

const transport = createTransport();

app.get("/health", async (_req, res) => {
  res.json({ ok: true });
});

// Minimal endpoint: Flutter generates OTP code; backend sends it.
// In production, move OTP generation + storage server-side.
app.post("/otp/recovery", async (req, res) => {
  try {
    const email = String(req.body?.email || "").trim();
    const code = String(req.body?.code || "").trim();

    if (!email || !email.includes("@")) {
      return res.status(400).json({ error: "Invalid email" });
    }
    if (!/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: "Invalid code" });
    }

    const fromEmail = mustEnv("MAIL_FROM");
    const fromName = process.env.MAIL_FROM_NAME || "Clinical Curator";

    await transport.sendMail({
      from: `${fromName} <${fromEmail}>`,
      to: email,
      subject: "Password reset code",
      text: `Your Clinical Curator password reset code is: ${code}\n\nThis code expires in 15 minutes.`,
      html: `<div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2 style="margin:0 0 8px 0;">Password reset</h2>
        <p style="margin:0 0 16px 0;">Use this code to reset your password:</p>
        <div style="font-size:28px;font-weight:700;letter-spacing:4px;padding:12px 16px;background:#F2F4F7;display:inline-block;border-radius:10px;">${code}</div>
        <p style="margin:16px 0 0 0;color:#667085;">This code expires in 15 minutes.</p>
      </div>`,
    });

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e?.message || String(e) });
  }
});

const port = Number(process.env.PORT || 8787);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`OTP mailer listening on http://0.0.0.0:${port}`);
});

