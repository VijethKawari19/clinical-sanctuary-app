## Update (Android M83 connect crash fix, build 9)

- Fixes the issue where pressing "Connect" on the wireless M83 camera could
  exit the app on Android. The native VLC preview path is disabled in this
  build because some devices crashed at native-library load before any
  Kotlin code could intercept it.
- The wireless M83 preview on Android now uses the same JPEG-over-TCP
  pipeline as the desktop build, which is known to be stable.
- The cleartext-HTTP allowance for the local M83 camera IP is preserved.
- A re-enabled VLC preview will return in a follow-up build with extra
  diagnostics so the failure can be traced on real hardware.
- Windows release artifacts are intentionally not included in this test release.

### Android
- ClinicalCurator-v1.0.7-android-release.apk (build 9)
