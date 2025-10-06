import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Botón nativo de transmisión (Google Cast)
class CastButton extends StatelessWidget {
  const CastButton({super.key, this.width = 40, this.height = 40});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return SizedBox(
        width: width,
        height: height,
        child: const AndroidView(
          viewType: 'advanced_video_player/cast_button',
          creationParamsCodec: StandardMessageCodec(),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
