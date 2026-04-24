## Goal
Send real password-reset OTP emails **from** your chosen sender address (example: `no-reply@yourdomain.com`) to **any** recipient (Gmail/Outlook/custom domain) using **Google Workspace** (or Gmail) as the mail provider.

This project sends OTP emails via SMTP from the Flutter app (good for demos). For production, move email sending to a backend to avoid shipping SMTP credentials in the client.

---

## What you must have
- **Google Workspace Admin access** for your domain (if you want `no-reply@yourdomain.com`)
- **DNS access** for your domain (GoDaddy / Namecheap / Cloudflare / etc.)

Without DNS access, email delivery and authentication (SPF/DKIM/DMARC) cannot be completed.

---

## Step 1 — Create the sender mailbox
In Google Admin Console:
- Create user: `no-reply@yourdomain.com`
- Set a strong password
- (Recommended) Turn on **2‑Step Verification** for the account

### SMTP password
You need one of the following:
- **App Password** (recommended): requires 2‑Step Verification enabled for that account.
- Or a regular password (not recommended; often blocked by security policies).

If your Workspace policy blocks App Passwords, you must allow them in Admin security settings or use a backend mail service.

---

## Step 2 — Configure domain DNS (required)
### 2.1 MX records (route inbound mail to Google)
In your domain DNS, add Google Workspace MX records (priority values matter).
Use Google’s official list for your region. Commonly:
- `ASPMX.L.GOOGLE.COM` (priority 1)
- `ALT1.ASPMX.L.GOOGLE.COM` (priority 5)
- `ALT2.ASPMX.L.GOOGLE.COM` (priority 5)
- `ALT3.ASPMX.L.GOOGLE.COM` (priority 10)
- `ALT4.ASPMX.L.GOOGLE.COM` (priority 10)

If you already have MX records from another provider, replace them only when you’re ready to move email to Google.

### 2.2 SPF (improve delivery, reduce spam)
Add a TXT record:
- **Name/Host**: `@`
- **Value**: `v=spf1 include:_spf.google.com ~all`

### 2.3 DKIM (strongly recommended)
In Google Admin Console:
- Apps → Google Workspace → Gmail → Authenticate email (DKIM)
- Generate a DKIM key (usually 2048-bit)
- Google will tell you a DNS TXT record to add (selector + value)
- After it propagates, click **Start authentication**

### 2.4 DMARC (recommended)
Add a TXT record:
- **Name/Host**: `_dmarc`
- **Value** (start permissive):
  - `v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com; adkim=s; aspf=s`

Later you can change to `p=quarantine` or `p=reject` after confirming everything works.

---

## Step 3 — Run this app with SMTP enabled
Use STARTTLS on port 587:
- Host: `smtp.gmail.com`
- Port: `587`
- SSL: `false` (STARTTLS)

Run (Windows):
```powershell
flutter run -d windows `
  --dart-define=SMTP_HOST=smtp.gmail.com `
  --dart-define=SMTP_PORT=587 `
  --dart-define=SMTP_USERNAME=no-reply@yourdomain.com `
  --dart-define=SMTP_PASSWORD=PASTE_APP_PASSWORD_HERE `
  --dart-define=SMTP_FROM=no-reply@yourdomain.com `
  --dart-define=SMTP_FROM_NAME="Clinical Curator" `
  --dart-define=SMTP_SSL=false
```

---

## Quickstart (no domain yet): send from a plain Gmail address
If you don't own a domain yet, you can still send OTP emails from a normal Gmail account:
- Create a Gmail sender (example: `yourapp.noreply@gmail.com`)
- Enable 2‑Step Verification → create an App Password
- Run using the helper script in this repo:

```powershell
.\scripts\run_windows_with_smtp.ps1 -SmtpUsername "yourapp.noreply@gmail.com" -SmtpPassword "PASTE_APP_PASSWORD_HERE"
```

---

## Common issues
### “Unable to send email right now…”
- SMTP values not provided (or wrong)
- App Password not enabled/invalid
- Domain not fully set up, mailbox not active

### OTP goes to spam
- Missing SPF/DKIM/DMARC
- Using a brand new domain/mailbox with no reputation

---

## Production note (security)
Sending SMTP from the Flutter client means SMTP credentials can be extracted from the app.
For production, create an API endpoint (server) that sends OTP emails and keep credentials on the server.

