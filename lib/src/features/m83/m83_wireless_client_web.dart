import 'dart:typed_data';

/// Web build stub.
///
/// Flutter Web (Chrome) cannot open raw TCP sockets, so the M83 Wi‑Fi stream
/// feature is unavailable in browser builds.
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
  final void Function()? onHardwareBack;
  final void Function(Object error)? onError;
  final void Function()? onDisconnected;

  bool get isConnected => false;

  Future<void> connect() async {
    final err = UnsupportedError(
      'Wireless capture is not supported on Web. '
      'Please run the Windows or Android app for M83 Wi‑Fi camera streaming.',
    );
    onError?.call(err);
    throw err;
  }

  Future<void> disconnect() async {
    onDisconnected?.call();
  }
}

