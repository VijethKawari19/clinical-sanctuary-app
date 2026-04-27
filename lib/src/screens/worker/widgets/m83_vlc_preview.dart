import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M83VlcPreview extends StatelessWidget {
  const M83VlcPreview({
    required this.streamUrl,
    required this.onViewCreated,
    super.key,
  });

  static const viewType = 'clinical_sanctuary/m83_vlc_player';
  static const channel = MethodChannel('clinical_sanctuary/m83_vlc_player');

  final String streamUrl;
  final ValueChanged<int> onViewCreated;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return AndroidView(
      viewType: viewType,
      creationParams: {'url': streamUrl},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onViewCreated,
    );
  }
}
