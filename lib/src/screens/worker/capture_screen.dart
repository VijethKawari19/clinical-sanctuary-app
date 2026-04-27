import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:camera_windows/camera_windows.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:go_router/go_router.dart';

import '../../features/m83/m83_wireless_client.dart';
import '../../features/session/session_controller.dart';
import '../../features/clinic/clinic_models.dart';
import '../../theme/app_theme.dart';
import '../../features/clinic/clinic_controller.dart';
import 'widgets/m83_wifi_guide_dialog.dart';
import 'widgets/m83_vlc_preview.dart';

enum CaptureSource { system, wireless, gallery }

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CaptureSource _source = CaptureSource.system;

  List<CameraDescription> _cams = const [];
  CameraLensDirection _lens = CameraLensDirection.back;
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _initializing = false;
  String? _systemError;

  /// Local-only capture before user confirms (not written to session until Confirm).
  Uint8List? _reviewBytes;
  CaptureMode? _reviewMode;

  bool get _inReview => _reviewBytes != null;

  M83WirelessClient? _m83;
  late final TextEditingController _m83HostCtrl;
  late final TextEditingController _m83PortCtrl;
  bool _m83Connecting = false;
  String? _m83Error;
  Uint8List? _m83LiveJpeg;
  int _m83LastPreviewMs = 0;
  int _m83LastFrameMs = 0;
  Timer? _m83Watchdog;
  final List<Uint8List> _m83FrameRing = [];
  static const int _m83RingMax = 28;
  bool _m83PreviewCheckInFlight = false;
  Uint8List? _m83PreviewPending;
  bool _m83AndroidVlcConnected = false;
  bool _m83AndroidVlcDisabled = false;
  String? _m83VlcPreviewUrl;
  int? _m83VlcViewId;

  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: false,
      enableClassification: false,
      enableContours: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool get _m83Streaming =>
      !_inReview &&
      ((_m83?.isConnected == true && _m83LiveJpeg != null) ||
          (_useAndroidVlcM83Preview && _m83AndroidVlcConnected));

  bool _isAllowedGalleryImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    // Accept only: png, jpg/jpeg, heif/heic
    return ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'heif' ||
        ext == 'heic';
  }

  bool _leavingScreen = false;

  @override
  void initState() {
    super.initState();
    _m83HostCtrl = TextEditingController(text: '192.168.1.1');
    _m83PortCtrl = TextEditingController(text: '40005');

    // Default to Gallery on desktop so first-run doesn't look "broken" if a
    // webcam is missing / blocked (common in Windows VMs, CI, locked-down PCs).
    if (_isDesktop) {
      _source = CaptureSource.gallery;
      unawaited(_pickFromGalleryForReview());
    } else {
      _source = CaptureSource.system;
      unawaited(_ensureSystemCamera());
    }
  }

  @override
  void dispose() {
    unawaited(_disconnectM83());
    _m83HostCtrl.dispose();
    _m83PortCtrl.dispose();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  bool get _mlkitFaceCheckSupported {
    if (kIsWeb) return false;
    // google_mlkit_* packages are mobile-only; keep the system camera usable on desktop.
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  bool get _useAndroidVlcM83Preview =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !_m83AndroidVlcDisabled;

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => c.complete(img));
    return c.future;
  }

  /// Reject system-camera captures that include a full face.
  ///
  /// Heuristic: if face occupies a large part of the frame (area/width/height),
  /// treat it as a "full-face" capture (not mouth/teeth focused).
  Future<bool> _isRejectedFullFaceSystemCapture({
    required Uint8List bytes,
    required String filePath,
  }) async {
    if (!_mlkitFaceCheckSupported) return false;

    final img = await _decodeImage(bytes);
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    img.dispose();

    final faces = await _faceDetector.processImage(
      InputImage.fromFilePath(filePath),
    );

    if (faces.isEmpty) return false;
    if (faces.length > 1) return true;

    final b = faces.first.boundingBox;
    final widthRatio = (b.width / iw).clamp(0, 1).toDouble();
    final heightRatio = (b.height / ih).clamp(0, 1).toDouble();
    final areaRatio = ((b.width * b.height) / (iw * ih)).clamp(0, 1).toDouble();
    final topRatio = (b.top / ih).clamp(0, 1).toDouble();

    // Tuned for "reject obvious face selfies", keep mouth close-ups.
    if (areaRatio > 0.18) return true;
    if (widthRatio > 0.45 && heightRatio > 0.45) return true;
    if (topRatio < 0.10 && heightRatio > 0.35) return true;

    return false;
  }

  Future<void> _ensureSystemCamera() async {
    if (_source != CaptureSource.system) return;
    if (_initializing) return;
    _initializing = true;
    try {
      // Register Windows implementation only on Windows.
      // (Importing/registering it on mobile can cause build issues.)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        CameraPlatform.instance = CameraWindows();
      }

      setState(() {
        _systemError = null;
      });
      _cams = await availableCameras();
      if (_cams.isEmpty) return;
      final cam = _cams.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => _cams.first,
      );
      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      setState(() {
        _controller = ctrl;
        _initFuture = ctrl.initialize();
      });
      await _initFuture;
      if (mounted) setState(() {});
    } catch (e) {
      final pretty = _prettifySystemCameraError(e);
      setState(() {
        _systemError = pretty;
      });
    } finally {
      _initializing = false;
    }
  }

  String _prettifySystemCameraError(Object e) {
    final raw = e.toString();
    final isWindowsCamChannel = raw.contains('camera_windows') ||
        raw.contains('CameraApi.getAvailableCameras');

    if (_isDesktop && isWindowsCamChannel) {
      return 'Camera unavailable on desktop. Use Gallery, or run on an Android device.';
    }

    // Keep a short error for UI; full details remain in logs.
    return 'Camera unavailable. Check permissions and try again.';
  }

  Future<void> _stopSystemCamera() async {
    final ctrl = _controller;
    _controller = null;
    _initFuture = null;
    if (ctrl != null) {
      try {
        await ctrl.dispose();
      } catch (_) {}
    }
  }

  Future<void> _pauseCameraPreview() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.pausePreview();
    } catch (_) {}
  }

  Future<void> _resumeCameraPreview() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.resumePreview();
    } catch (_) {}
  }

  Future<void> _setSource(CaptureSource s) async {
    if (_inReview) return;
    if (_source == s) return;
    setState(() => _source = s);
    if (s == CaptureSource.system) {
      await _ensureSystemCamera();
    } else {
      // System camera must be OFF unless System tab selected.
      await _stopSystemCamera();
    }

    // Gallery should open the file picker immediately on selection.
    if (s == CaptureSource.gallery) {
      unawaited(_pickFromGalleryForReview());
    }
    if (s != CaptureSource.wireless) {
      unawaited(_disconnectM83());
    }
  }

  Future<void> _flipCamera() async {
    if (_inReview) return;
    if (_source != CaptureSource.system) return;
    if (_cams.isEmpty) {
      await _ensureSystemCamera();
    }
    final hasFront = _cams.any(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final hasBack = _cams.any(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (!(hasFront && hasBack)) return;

    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _stopSystemCamera();
    await _ensureSystemCamera();
  }

  Future<void> _disconnectM83() async {
    _m83Watchdog?.cancel();
    _m83Watchdog = null;
    final c = _m83;
    _m83 = null;
    if (c != null) {
      await c.disconnect();
    }
    if (mounted) {
      setState(() {
        _m83LiveJpeg = null;
        _m83FrameRing.clear();
        _m83PreviewCheckInFlight = false;
        _m83PreviewPending = null;
        _m83Error = null;
        _m83Connecting = false;
        _m83LastFrameMs = 0;
        _m83AndroidVlcConnected = false;
        _m83VlcPreviewUrl = null;
        _m83VlcViewId = null;
      });
    }
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _onAndroidVlcError(String message) {
    if (!mounted) return;
    if (_m83AndroidVlcDisabled) return;
    setState(() {
      _m83AndroidVlcDisabled = true;
      _m83AndroidVlcConnected = false;
      _m83VlcPreviewUrl = null;
      _m83VlcViewId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Wireless preview switched to legacy mode (${message.split('\n').first}).',
        ),
      ),
    );
    unawaited(_connectM83());
  }

  String _m83HttpStreamUrl(String host, int port) {
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/',
      queryParameters: const {'action': 'stream'},
    );
    return uri.toString();
  }

  void _ingestM83PreviewFrame(Uint8List jpeg) {
    if (!mounted || _inReview) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _m83LastFrameMs = now;

    // Mobile: cap preview FPS to keep decoder/UI stable.
    final minDeltaMs = _isMobile ? 100 : 36; // ~10fps mobile, ~27fps desktop
    if (now - _m83LastPreviewMs < minDeltaMs) return;
    _m83LastPreviewMs = now;

    // Keep a rolling buffer for capture selection.
    _m83FrameRing.add(jpeg);
    if (_m83FrameRing.length > _m83RingMax) {
      _m83FrameRing.removeRange(0, _m83FrameRing.length - _m83RingMax);
    }

    if (!_isMobile) {
      setState(() {
        _m83LiveJpeg = jpeg;
        _m83Connecting = false;
      });
      return;
    }

    // Mobile: never display suspicious frames; validate asynchronously.
    if (_m83PreviewCheckInFlight) {
      _m83PreviewPending = jpeg;
      return;
    }

    _m83PreviewCheckInFlight = true;
    unawaited(() async {
      final isBad = await _hasBottomBandCorruption(jpeg);
      if (!mounted) return;
      if (!isBad) {
        setState(() {
          _m83LiveJpeg = jpeg;
          _m83Connecting = false;
        });
      }
      _m83PreviewCheckInFlight = false;
      final pending = _m83PreviewPending;
      _m83PreviewPending = null;
      if (pending != null) {
        _ingestM83PreviewFrame(pending);
      }
    }());
  }

  void _startM83Watchdog() {
    _m83Watchdog?.cancel();
    _m83Watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      final c = _m83;
      if (!mounted || c == null || c.isConnected != true) return;
      if (_inReview || _source != CaptureSource.wireless) return;

      // If we connected but aren't receiving frames, fail fast and prompt retry.
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _m83LastFrameMs;
      if (last == 0) return;
      if (now - last < 4500) return;

      setState(() {
        _m83Error =
            'No video frames received. Check Wi‑Fi (M83 network) and IP/port, then reconnect.';
      });
      unawaited(_disconnectM83());
    });
  }

  Future<void> _connectM83() async {
    if (_inReview || _source != CaptureSource.wireless) return;
    final host = _m83HostCtrl.text.trim();
    if (host.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the camera IP address.')),
        );
      }
      return;
    }
    final port = int.tryParse(_m83PortCtrl.text.trim()) ?? 40005;

    await _disconnectM83();

    if (_useAndroidVlcM83Preview) {
      setState(() {
        _m83Connecting = true;
        _m83Error = null;
        _m83AndroidVlcConnected = false;
        _m83VlcPreviewUrl = null;
        _m83VlcViewId = null;
      });

      // The M83 often needs a small TCP wake packet before its HTTP stream is
      // available. VLC owns playback after this; Windows keeps the Dart decoder.
      final wakeClient = M83WirelessClient(host: host, port: port);
      try {
        await wakeClient.connect();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        if (mounted) {
          setState(() {
            _m83Connecting = false;
            _m83Error = '$e';
          });
        }
        await wakeClient.disconnect();
        return;
      }
      await wakeClient.disconnect();

      if (!mounted) return;
      setState(() {
        _m83Connecting = false;
        _m83AndroidVlcConnected = true;
        _m83VlcPreviewUrl = _m83HttpStreamUrl(host, port);
        _m83LastFrameMs = DateTime.now().millisecondsSinceEpoch;
      });
      return;
    }

    final client = M83WirelessClient(
      host: host,
      port: port,
      onJpegFrame: (jpeg) {
        final copy = Uint8List.fromList(jpeg);
        _ingestM83PreviewFrame(copy);
      },
      onHardwareShutter: _onM83HardwareShutter,
      onHardwareBack: _onM83HardwareBack,
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _m83 = null;
          _m83Error = e.toString();
          _m83Connecting = false;
          _m83LiveJpeg = null;
        });
      },
      onDisconnected: () {
        if (!mounted) return;
        setState(() {
          _m83Connecting = false;
          _m83LiveJpeg = null;
        });
      },
    );

    setState(() {
      _m83 = client;
      _m83Connecting = true;
      _m83Error = null;
      _m83LiveJpeg = null;
      _m83LastFrameMs = 0;
    });

    try {
      await client.connect();
    } catch (e) {
      await client.disconnect();
      if (mounted) {
        setState(() {
          _m83 = null;
          _m83Connecting = false;
          _m83Error = '$e';
        });
      }
      return;
    }
    _m83LastFrameMs = DateTime.now().millisecondsSinceEpoch;
    _startM83Watchdog();
    if (mounted) setState(() {});
  }

  void _onM83HardwareShutter() {
    if (!mounted || _source != CaptureSource.wireless) return;
    // Same physical "capture" signal often means "discard / retake" while
    // reviewing; the third device key may share this code or use onHardwareBack.
    if (_inReview) {
      unawaited(_retakeReview());
      return;
    }
    unawaited(_snapshotM83ToReview());
  }

  /// Lower keys (back / trash) — only acts during review to match device UX.
  void _onM83HardwareBack() {
    if (!mounted || _source != CaptureSource.wireless) return;
    if (!_inReview) return;
    unawaited(_retakeReview());
  }

  Future<bool> _canDecodeJpeg(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasBottomBandCorruption(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final img = frame.image;
      final w = img.width;
      final h = img.height;
      if (w <= 0 || h <= 0) {
        img.dispose();
        return false;
      }

      // Inspect only the bottom ~12% of the image.
      final y0 = (h * 0.88).floor().clamp(0, h - 1);
      final bandH = (h - y0).clamp(1, h);

      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (data == null) return false;

      // Sample sparsely for performance.
      final strideX = (w / 40).ceil().clamp(1, 16);
      final strideY = (bandH / 10).ceil().clamp(1, 8);

      int n = 0;
      int uniformish = 0;
      int sumR = 0, sumG = 0, sumB = 0;

      int? r0, g0, b0;
      for (var y = y0; y < h; y += strideY) {
        for (var x = 0; x < w; x += strideX) {
          final idx = (y * w + x) * 4;
          final r = data.getUint8(idx);
          final g = data.getUint8(idx + 1);
          final b = data.getUint8(idx + 2);
          n++;
          sumR += r;
          sumG += g;
          sumB += b;
          r0 ??= r;
          g0 ??= g;
          b0 ??= b;
          // Treat as "uniform-ish" if close to first sampled pixel.
          final dr = (r - r0).abs();
          final dg = (g - g0).abs();
          final db = (b - b0).abs();
          if (dr + dg + db < 30) uniformish++;
        }
      }

      if (n == 0) return false;

      // If the bottom band is extremely uniform, it is likely a corrupted strip.
      // (Real intraoral images have texture/variation, not a flat band.)
      final ratio = uniformish / n;
      if (ratio > 0.92) return true;

      // A common corruption pattern is a green/teal band. Detect strong green bias.
      final meanR = sumR / n;
      final meanG = sumG / n;
      final meanB = sumB / n;
      if (meanG - meanR > 28 && meanG - meanB > 28) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _snapshotM83ToReview() async {
    if (_useAndroidVlcM83Preview) {
      final viewId = _m83VlcViewId;
      if (viewId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wireless preview is still starting.')),
        );
        return;
      }

      try {
        final bytes = await M83VlcPreview.channel.invokeMethod<Uint8List>(
          'takeSnapshot',
          {'viewId': viewId},
        );
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not capture the VLC frame.')),
          );
          return;
        }
        setState(() {
          _reviewBytes = bytes;
          _reviewMode = CaptureMode.wireless;
        });
      } on PlatformException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not capture VLC frame.')),
        );
      }
      return;
    }

    // Pick the most "complete" recent frame:
    // - must decode
    // - prefer larger byte size (missing bottom scan data often reduces size)
    // We sample from the last ~0.5–1s of frames.
    final candidates = List<Uint8List>.from(_m83FrameRing);
    final live = _m83LiveJpeg;
    if (live != null) candidates.add(live);

    Uint8List? best;
    var bestLen = -1;
    for (var i = candidates.length - 1; i >= 0; i--) {
      final c = candidates[i];
      if (c.length <= bestLen) continue;
      if (!await _canDecodeJpeg(c)) continue;
      if (await _hasBottomBandCorruption(c)) continue;
      best = c;
      bestLen = c.length;
    }

    // If no clean candidate found, wait for newer frames (up to ~1.6s).
    if (best == null) {
      const tries = 20;
      for (var i = 0; i < tries; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;
        final j = _m83LiveJpeg;
        if (j == null) continue;
        if (await _canDecodeJpeg(j) && !(await _hasBottomBandCorruption(j))) {
          best = j;
          break;
        }
      }
    }

    if (!mounted) return;
    if (best == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not capture a clean frame. Move closer to the camera Wi‑Fi and try again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _reviewBytes = Uint8List.fromList(best!);
      _reviewMode = CaptureMode.wireless;
    });
  }

  Future<void> _pickFromGalleryForReview() async {
    Uint8List? bytes;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
          ),
        ],
      );
      if (!mounted) return;
      if (file == null) return;
      if (!_isAllowedGalleryImagePath(file.name)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unsupported file. Use PNG, JPG/JPEG, or HEIF/HEIC.'),
            ),
          );
        }
        return;
      }
      bytes = await file.readAsBytes();
    } else {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (!_isAllowedGalleryImagePath(file.name)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unsupported file. Use PNG, JPG/JPEG, or HEIF/HEIC.'),
            ),
          );
        }
        return;
      }
      bytes = await file.readAsBytes();
    }

    if (!mounted) return;
    setState(() {
      _reviewBytes = bytes;
      _reviewMode = CaptureMode.gallery;
    });
  }

  Future<void> _retakeReview() async {
    setState(() {
      _reviewBytes = null;
      _reviewMode = null;
    });
    if (_source == CaptureSource.system) {
      await _resumeCameraPreview();
    } else if (_source == CaptureSource.gallery) {
      if (mounted) unawaited(_pickFromGalleryForReview());
    }
    // Wireless: live TCP stream keeps running; UI returns to preview.
    if (mounted) setState(() {});
  }

  void _openReviewFullscreen() {
    final bytes = _reviewBytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmReview() {
    final bytes = _reviewBytes;
    final mode = _reviewMode;
    if (bytes == null || mode == null) return;

    final draft = ref.read(sessionControllerProvider).patientDraft;
    if (draft == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter patient details first.')),
        );
        context.go('/w/patient-info');
      }
      return;
    }

    final b64 = base64Encode(bytes);
    final ctrl = ref.read(clinicControllerProvider.notifier);
    ctrl.createPendingCase(
      patientName: draft.patientName,
      patientAge: draft.patientAge,
      patientGender: switch (draft.patientGender) {
        'male' => PatientGender.male,
        'female' => PatientGender.female,
        _ => PatientGender.other,
      },
      bloodGroup: draft.bloodGroup,
      heightCm: draft.heightCm,
      weightKg: draft.weightKg,
      aadhaarNumber: draft.aadhaarNumber,
      tobaccoUse: draft.tobaccoUse,
      alcoholUse: draft.alcoholUse,
      contactPhone: draft.contactPhone,
      contactEmail: draft.contactEmail,
      imageBase64: b64,
      notes: draft.notes,
    );
    final createdId = ref.read(clinicControllerProvider).cases.first.id;

    _leavingScreen = true;
    setState(() {
      _reviewBytes = null;
      _reviewMode = null;
    });
    // Navigate first; clear draft after we leave this screen to avoid
    // the "details required" redirect firing during navigation.
    context.push('/w/processing/$createdId');
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).clearPatientDraft();
    });
  }

  Future<void> _capture() async {
    if (_source == CaptureSource.gallery) {
      await _pickFromGalleryForReview();
      return;
    }

    if (_source == CaptureSource.system) {
      final ctrl = _controller;
      if (ctrl == null || !(ctrl.value.isInitialized)) return;
      try {
        await _initFuture;
        final file = await ctrl.takePicture();
        final bytes = await file.readAsBytes();
        if (!mounted) return;

        // System-camera only: reject full-face captures (accept mouth/teeth only).
        final rejected = await _isRejectedFullFaceSystemCapture(
          bytes: bytes,
          filePath: file.path,
        );
        if (!mounted) return;
        if (rejected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Face detected. Please capture mouth/teeth only (no full face).',
              ),
            ),
          );
          return;
        }

        await _pauseCameraPreview();
        if (!mounted) return;
        setState(() {
          _reviewBytes = bytes;
          _reviewMode = CaptureMode.system;
        });
      } catch (_) {}
      return;
    }

    if (_source == CaptureSource.wireless) {
      _snapshotM83ToReview();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enforce flow: details first, then capture.
    final draft = ref.watch(sessionControllerProvider).patientDraft;
    if (draft == null && !_leavingScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/w/patient-info');
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: SafeArea(
        child: Column(
          children: [
            _TopStatusBar(
              source: _source,
              inReview: _inReview,
              m83Streaming: _m83Streaming,
              onBack: () {
                if (_inReview) {
                  unawaited(_retakeReview());
                  return;
                }
                // Always allow user to go back to edit patient details.
                context.go('/w/patient-info');
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: const Color(0xFF2B2F39),
                    child: Center(child: _preview()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _inReview ? 'REVIEW CAPTURE' : 'FOCUS ON AREA OF CONCERN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (!_inReview)
              _SourceTabs(source: _source, onChanged: _setSource)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ReviewActionButton(
                        label: 'Retake',
                        icon: Icons.refresh_rounded,
                        filled: false,
                        onPressed: () => unawaited(_retakeReview()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReviewActionButton(
                        label: 'View',
                        icon: Icons.fullscreen_rounded,
                        filled: false,
                        onPressed: _openReviewFullscreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReviewActionButton(
                        label: 'Confirm',
                        icon: Icons.check_rounded,
                        filled: true,
                        onPressed: _confirmReview,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (!_inReview && _source == CaptureSource.system)
              _BottomActions(
                mode: _source,
                onCapture: _capture,
                onSecondary: _flipCamera,
              )
            else if (!_inReview && _source == CaptureSource.wireless)
              _BottomActions(
                mode: _source,
                onCapture: _capture,
                onSecondary: null,
              )
            else if (!_inReview)
              const SizedBox.shrink()
            else
              const SizedBox(height: 78),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final review = _reviewBytes;
    if (review != null) {
      return Image.memory(
        review,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }

    if (_source == CaptureSource.wireless) {
      return _wirelessPreview();
    }
    if (_source == CaptureSource.gallery) {
      return _Placeholder(icon: Icons.photo_library_outlined, label: 'Gallery');
    }

    final ctrl = _controller;
    final init = _initFuture;
    if (ctrl == null || init == null) {
      return _Placeholder(
        icon: Icons.videocam_off_outlined,
        label: _systemError ?? 'Camera',
      );
    }

    return FutureBuilder(
      future: init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white70);
        }
        if (!ctrl.value.isInitialized) {
          return const _Placeholder(
            icon: Icons.videocam_off_outlined,
            label: 'Camera',
          );
        }
        return CameraPreview(ctrl);
      },
    );
  }

  Widget _wirelessPreview() {
    final err = _m83Error;
    if (err != null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                err,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => setState(() => _m83Error = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }

    final connected = _m83?.isConnected == true || _m83AndroidVlcConnected;
    final live = _m83LiveJpeg;
    final vlcUrl = _m83VlcPreviewUrl;

    if (connected && _useAndroidVlcM83Preview && vlcUrl != null) {
      return SizedBox.expand(
        child: M83VlcPreview(
          streamUrl: vlcUrl,
          onViewCreated: (id) => _m83VlcViewId = id,
          onError: _onAndroidVlcError,
        ),
      );
    }

    if (connected && live != null) {
      // Cover the preview area so letterboxing (often read as a "dark bar") is
      // not mistaken for stream corruption; center crop if aspect differs.
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          child: Image.memory(
            live,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    if (connected && live == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'Receiving video…',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => unawaited(_disconnectM83()),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            TextButton.icon(
              onPressed: () => showM83WifiGuideDialog(context),
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white70,
              ),
              label: const Text(
                'How to connect',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.white24),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Advanced (IP / Port)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                children: [
                  TextField(
                    controller: _m83HostCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Camera IP',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: '192.168.1.1',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _m83PortCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'TCP port (40001–40009)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: '40005',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_m83Connecting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _m83Connecting
                      ? null
                      : () => unawaited(_connectM83()),
                  child: const Text('Connect'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _m83Connecting
                  ? 'Opening TCP socket…'
                  : 'Connect after joining the M83 Wi‑Fi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewActionButton extends StatelessWidget {
  const _ReviewActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white70),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Colors.white38),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.source,
    required this.inReview,
    required this.m83Streaming,
    required this.onBack,
  });
  final CaptureSource source;
  final bool inReview;
  final bool m83Streaming;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hi, Health Worker',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text(
                    inReview
                        ? 'PAUSED · REVIEW'
                        : m83Streaming
                        ? 'LIVE · M83'
                        : source == CaptureSource.system
                        ? 'READY TO CAPTURE'
                        : source == CaptureSource.gallery
                        ? 'READY TO UPLOAD'
                        : 'READY TO CONNECT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            'ONLINE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.source, required this.onChanged});
  final CaptureSource source;
  final ValueChanged<CaptureSource> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(CaptureSource s, String label, IconData icon) {
      final selected = source == s;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(s),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFF1B2230),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Colors.white : const Color(0xFF2C364A),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.black : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2C364A)),
        ),
        child: Row(
          children: [
            tab(CaptureSource.system, 'SYSTEM', Icons.videocam_outlined),
            const SizedBox(width: 6),
            tab(CaptureSource.wireless, 'WIRELESS', Icons.wifi_rounded),
            const SizedBox(width: 6),
            tab(CaptureSource.gallery, 'GALLERY', Icons.photo_library_outlined),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.mode,
    required this.onCapture,
    required this.onSecondary,
  });

  final CaptureSource mode;
  final VoidCallback onCapture;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final showFlip = mode == CaptureSource.system && onSecondary != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showFlip) ...[
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
              border: Border.all(color: Colors.white24),
            ),
            child: IconButton(
              onPressed: onSecondary,
              icon: const Icon(
                Icons.cameraswitch_rounded,
                color: Colors.white70,
              ),
              tooltip: 'Flip camera',
            ),
          ),
          const SizedBox(width: 20),
        ],
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onCapture,
            icon: const Icon(
              Icons.photo_camera_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 64),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white60,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
