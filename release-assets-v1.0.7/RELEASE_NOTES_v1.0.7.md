## Update (Android M83 VLC preview test, build 8)

- Fixes a crash where pressing "Connect" on the wireless M83 camera could
  exit the app on some Android devices.
- Native VLC initialisation and playback are now wrapped in error handlers,
  so a failure surfaces a snackbar instead of killing the process.
- VLC is rendered through a TextureView inside Flutter's AndroidView for
  more compatible behaviour with the platform-view virtual display.
- If VLC still cannot start, the preview automatically falls back to the
  legacy JPEG-over-TCP path.
- Android cleartext HTTP remains enabled for the local M83 camera stream.
- Windows release artifacts are intentionally not included in this test release.

### Android
- ClinicalCurator-v1.0.7-android-release.apk (build 8)
