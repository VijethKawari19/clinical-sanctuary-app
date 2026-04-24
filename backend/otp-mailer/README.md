## OTP mailer backend (option 2)

This service sends password-recovery OTP emails **from the server**, so the Flutter APK/MSIX does **not** contain SMTP credentials.

### Setup
```bash
cd backend/otp-mailer
npm install
```

Create `.env` from `.env.example` and fill values (Gmail: use an App Password):
```bash
cp .env.example .env
```

Run:
```bash
npm start
```

Health check:
- `GET /health`

Send OTP email:
- `POST /otp/recovery`
  - body: `{ "email": "user@example.com", "code": "123456" }`

### Production note
This demo endpoint sends the code that the Flutter app generates.
For stronger security, generate + store OTP server-side and only accept the user identifier from the client.

