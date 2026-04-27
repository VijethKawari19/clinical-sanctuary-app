import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android-only VLC preview for the M83 wireless camera.
///
/// On every other platform this widget renders nothing. It also reports
/// native VLC errors back via [onError] so the host screen can fall back
/// to the existing JPEG TCP path instead of crashing the process.
class M83VlcPreview extends StatefulWidget {
  const M83VlcPreview({
    required this.streamUrl,
    required this.onViewCreated,
    this.onError,
    super.key,
  });

  static const viewType = 'clinical_sanctuary/m83_vlc_player';
  static const channel = MethodChannel('clinical_sanctuary/m83_vlc_player');

  final String streamUrl;
  final ValueChanged<int> onViewCreated;
  final ValueChanged<String>? onError;

  @override
  State<M83VlcPreview> createState() => _M83VlcPreviewState();
}

class _M83VlcPreviewState extends State<M83VlcPreview> {
  int? _viewId;

  @override
  void initState() {
    super.initState();
    M83VlcPreview.channel.setMethodCallHandler(_onNativeCall);
  }

  @override
  void dispose() {
    // Leave the channel handler in place; if another preview is opened later
    // it will reattach. Setting null here would silently disable error
    // delivery for any handler that might have already swapped in.
    super.dispose();
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method != 'vlcError') return null;
    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    final id = args?['viewId'] as int?;
    if (id != null && id != _viewId) return null;
    final message = (args?['message'] as String?) ?? 'VLC playback failed.';
    widget.onError?.call(message);
    return null;
  }

  void _handleViewCreated(int id) {
    _viewId = id;
    widget.onViewCreated(id);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return AndroidView(
      viewType: M83VlcPreview.viewType,
      creationParams: {'url': widget.streamUrl},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _handleViewCreated,
    );
  }
}
