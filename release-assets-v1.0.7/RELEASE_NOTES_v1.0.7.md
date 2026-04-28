## Clinical Curator v1.0.7

### Fixes
- **Forgot Password email:** Release builds now use the production OTP mailer
  (`https://clinicalcurator-otp-mailer.onrender.com`) by default when no
  `OTP_API_BASE_URL` or SMTP dart-defines are set, so password reset works in
  APK/MSIX without baking secrets into the app.

### Android
- ClinicalCurator-v1.0.7-android-release.apk

### Windows
- ClinicalCurator-v1.0.7-windows.msix
- ClinicalCurator-v1.0.7-windows-portable.zip (if generated)
