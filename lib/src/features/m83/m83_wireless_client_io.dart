import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Raw TCP client for M83 Wi‑Fi camera streams (not HTTP/RTSP).
///
/// Protocol notes (from device integration spec):
/// - Wake: `[0x01, 0x00, 0x00, 0x00]` on connect; optional HTTP GET on same socket.
/// - Strip 12‑byte proprietary headers matching signature checks.
/// - Video: concatenated JPEGs (SOI `FF D8` … EOI `FF D9` or next SOI).
/// - Hardware shutter (optional): `0x55 0xAA` or lone `0x02` only in **small**
///   TCP reads (control-sized). Scanning full video chunks matches `55 AA`
///   inside JPEG entropy and fires false captures.
/// - Hardware "back / discard" (optional): distinct small-packet patterns such as
///   `0xAA 0x55` or `0x55 0xBB` (firmware-dependent) for the lower device keys.
class M83WirelessClient {
  M83WirelessClient({
    required this.host,
    required this.port,
    this.onJpegFrame,
    this.onHardwareShutter,
    this.onHardwareBack,
    this.onError,
    this.onDisconnected,
  });

  final String host;
  final int port;
  final void Function(Uint8List jpeg)? onJpegFrame;
  final void Function()? onHardwareShutter;
  /// Retake / discard review — separate from shutter; only small TCP reads.
  final void Function()? onHardwareBack;
  final void Function(Object error)? onError;
  final void Function()? onDisconnected;

  static const wakeBytes = <int>[0x01, 0x00, 0x00, 0x00];

  static String _httpStreamRequest(String hostHeader) =>
      'GET /?action=stream HTTP/1.1\r\nHost: $hostHeader\r\n\r\n';

  Socket? _socket;
  StreamSubscription<List<int>>? _sub;
  Timer? _httpFallbackTimer;
  final _assembler = _M83StreamAssembler();
  bool _sawFirstJpeg = false;
  bool _httpFallbackSent = false;
  int _lastShutterMs = 0;
  int _lastBackMs = 0;

  bool get isConnected => _socket != null;

  Future<void> connect() async {
    await disconnect();
    _sawFirstJpeg = false;
    _httpFallbackSent = false;
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 12),
      );
      // Reduce latency and keep the connection from going idle on some routers.
      try {
        socket.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}
      _socket = socket;
      socket.add(Uint8List.fromList(wakeBytes));
      await socket.flush();

      _httpFallbackTimer = Timer(const Duration(seconds: 3), () {
        if (_sawFirstJpeg || _httpFallbackSent) return;
        final s = _socket;
        if (s == null) return;
        _httpFallbackSent = true;
        try {
          s.add(utf8.encode(_httpStreamRequest(host)));
          unawaited(s.flush());
        } catch (_) {}
      });

      _sub = socket.listen(
        _onSocketData,
        onError: (Object e, StackTrace _) {
          onError?.call(e);
          unawaited(disconnect());
        },
        onDone: () {
          unawaited(disconnect());
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError?.call(e);
      await disconnect();
      rethrow;
    }
  }

  void _onSocketData(List<int> data) {
    final chunk = data is Uint8List ? data : Uint8List.fromList(data);
    final now = DateTime.now().millisecondsSinceEpoch;
    _detectShutter(chunk, now);

    _assembler.ingest(
      chunk,
      onJpeg: (jpeg) {
        _sawFirstJpeg = true;
        onJpegFrame?.call(jpeg);
      },
    );
  }

  static const _shutterDebounceMs = 450;
  static const _backDebounceMs = 350;

  /// Max bytes in one socket read to treat as a possible **control** packet.
  /// JPEG video arrives in larger reads; those must not be scanned for `55 AA`.
  static const _maxShutterChunkBytes = 32;

  void _detectShutter(Uint8List chunk, int nowMs) {
    if (chunk.length > _maxShutterChunkBytes) return;

    final hasShutter = onHardwareShutter != null;
    final hasBack = onHardwareBack != null;
    if (!hasShutter && !hasBack) return;

    void fireShutter() {
      if (!hasShutter) return;
      if (nowMs - _lastShutterMs < _shutterDebounceMs) return;
      _lastShutterMs = nowMs;
      onHardwareShutter?.call();
    }

    void fireBack() {
      if (!hasBack) return;
      if (nowMs - _lastBackMs < _backDebounceMs) return;
      _lastBackMs = nowMs;
      onHardwareBack?.call();
    }

    // "Back / delete" style keys often use a different pair than shutter `55 AA`.
    for (var i = 0; i + 1 < chunk.length; i++) {
      if (chunk[i] == 0xaa && chunk[i + 1] == 0x55) {
        fireBack();
        return;
      }
      if (chunk[i] == 0x55 && chunk[i + 1] == 0xbb) {
        fireBack();
        return;
      }
    }

    for (var i = 0; i + 1 < chunk.length; i++) {
      if (chunk[i] == 0x55 && chunk[i + 1] == 0xaa) {
        fireShutter();
        return;
      }
    }

    if (chunk.length == 1 && chunk[0] == 0x02) {
      fireShutter();
    }
  }

  Future<void> disconnect() async {
    final hadSocket = _socket != null;
    _httpFallbackTimer?.cancel();
    _httpFallbackTimer = null;
    await _sub?.cancel();
    _sub = null;
    final s = _socket;
    _socket = null;
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
    _assembler.clear();
    if (hadSocket) {
      onDisconnected?.call();
    }
  }
}

class _M83StreamAssembler {
  final List<int> _buf = [];

  void clear() => _buf.clear();

  void ingest(
    Uint8List chunk, {
    required void Function(Uint8List jpeg) onJpeg,
  }) {
    _buf.addAll(chunk);
    _extractJpegs(onJpeg);
    _trimIfHuge();
  }

  static bool _isProprietaryHeader(List<int> b, int i) {
    if (i + 12 > b.length) return false;
    return b[i + 2] == 0x00 &&
        b[i + 3] == 0x00 &&
        b[i + 8] == 0xf4 &&
        b[i + 9] == 0x3f &&
        b[i + 11] == 0x00;
  }

  static void _stripHeadersFromList(List<int> b) {
    var i = 0;
    while (i <= b.length - 12) {
      if (_isProprietaryHeader(b, i)) {
        b.removeRange(i, i + 12);
      } else {
        i++;
      }
    }
  }

  void _stripHeaders() => _stripHeadersFromList(_buf);

  static int? _lastMarkerInList(List<int> data, int a, int b, int start) {
    if (data.length < start + 2) return null;
    for (var i = data.length - 2; i >= start; i--) {
      if (data[i] == a && data[i + 1] == b) return i;
    }
    return null;
  }

  static Uint8List _trimToLastEoi(Uint8List frame) {
    for (var i = frame.length - 2; i >= 0; i--) {
      if (frame[i] == 0xff && frame[i + 1] == 0xd9) {
        final end = i + 2;
        if (end == frame.length) return frame;
        return Uint8List.sublistView(frame, 0, end);
      }
    }
    return frame;
  }

  static void _emitIfJpeg(Uint8List frame, void Function(Uint8List jpeg) onJpeg) {
    final f = _trimToLastEoi(frame);
    if (f.length < 10 || f[0] != 0xff || f[1] != 0xd8) return;
    onJpeg(f);
  }

  int? _findPair(int a, int b, int start) {
    for (var i = start; i + 1 < _buf.length; i++) {
      if (_buf[i] == a && _buf[i + 1] == b) return i;
    }
    return null;
  }

  void _extractJpegs(void Function(Uint8List jpeg) onJpeg) {
    while (true) {
      // Strip hardware headers before each frame; they often sit between JPEGs
      // and must not be concatenated into the bitmap (gray bands / smear).
      _stripHeaders();

      final soi = _findPair(0xff, 0xd8, 0);
      if (soi == null) {
        return;
      }
      if (soi > 0) {
        _buf.removeRange(0, soi);
      }

      final nextSoi = _findPair(0xff, 0xd8, 2);

      if (nextSoi != null) {
        // Headers often sit *between* SOI markers in the raw TCP merge. Stripping
        // only from the global buffer start misses those bytes. Copy the full
        // first-JPEG segment, strip headers inside the copy, then end at the
        // last EOI so trailing padding is not fed to the decoder.
        final slice = List<int>.from(_buf.sublist(0, nextSoi));
        _stripHeadersFromList(slice);
        final lastEoi = _lastMarkerInList(slice, 0xff, 0xd9, 2);
        final Uint8List frame;
        if (lastEoi != null) {
          frame = Uint8List.fromList(slice.sublist(0, lastEoi + 2));
        } else {
          frame = Uint8List.fromList(slice);
        }
        _buf.removeRange(0, nextSoi);
        _emitIfJpeg(frame, onJpeg);
        continue;
      }

      final eoi = _findPair(0xff, 0xd9, 2);
      if (eoi == null) {
        return;
      }

      final endExclusive = eoi + 2;
      if (endExclusive > _buf.length) return;

      final frame = Uint8List.fromList(_buf.sublist(0, endExclusive));
      _buf.removeRange(0, endExclusive);
      _emitIfJpeg(frame, onJpeg);
    }
  }

  void _trimIfHuge() {
    const max = 512 * 1024;
    if (_buf.length <= max) return;
    final cut = _buf.length - 64 * 1024;
    var keepFrom = 0;
    for (var i = cut; i + 1 < _buf.length; i++) {
      if (_buf[i] == 0xff && _buf[i + 1] == 0xd8) {
        keepFrom = i;
        break;
      }
    }
    if (keepFrom > 0) {
      _buf.removeRange(0, keepFrom);
    } else {
      _buf.removeRange(0, cut);
    }
  }
}

