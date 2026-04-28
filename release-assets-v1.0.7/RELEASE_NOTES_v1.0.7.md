## Update (Android M83 wireless preview - glitch fix attempt)

This is an Android-only experimental build to evaluate whether the M83
wireless preview glitches can be eliminated without changing the
network protocol or pulling in a native player. The Windows build is
unchanged at v1.0.6.

### What changed (Android only)

- The wireless M83 preview now decodes each JPEG frame **once** on the
  Dart side and renders the resulting `ui.Image` directly via
  `RawImage`. Previously every frame was decoded twice on Android: once
  to validate it for corruption and again by `Image.memory` for
  display.
- The corruption check no longer materialises the entire frame to RGBA.
  It renders just the bottom ~12% of the image into a 60x12 offscreen
  bitmap and samples from that, so per-frame work is reduced from
  multiple megabytes of CPU/GC traffic to a few kilobytes.
- Frame buffering keeps a single pending frame so we always render the
  most recent valid frame instead of stale intermediate frames.
- All preview state (`ui.Image`) is disposed in lifecycle hooks
  (disconnect, error, dispose) so GPU memory is released cleanly.

### What is **not** changed

- Windows wireless preview path is untouched.
- The proprietary M83 TCP protocol and JPEG assembler are unchanged.
- No new dependencies, no native libraries, no APK size hit beyond the
  small Dart code addition.

### Android
- ClinicalCurator-v1.0.7-android-release.apk
