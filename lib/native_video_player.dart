import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Widget de reproductor de video nativo con soporte PiP sin dummy views
///
/// Este widget usa la nueva arquitectura nativa que replica el comportamiento
/// de un ViewController normal de iOS, sin necesidad de vistas dummy.
///
/// Ejemplo de uso:
/// ```dart
/// NativeVideoPlayer(
///   url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
///   autoplay: true,
///   onViewCreated: (controller) {
///     // Controlar el player
///     controller.play();
///     controller.startPiP();
///   },
///   onPipRestoreToFullscreen: () {
///     // Navegar a fullscreen cuando el usuario vuelve desde PiP
///     Navigator.push(context, MaterialPageRoute(...));
///   },
/// )
/// ```
class NativeVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoplay;
  final void Function(NativeVideoPlayerController)? onViewCreated;
  final VoidCallback? onPipStarted;
  final VoidCallback? onPipStopped;
  final VoidCallback? onPipRestoreToFullscreen;

  const NativeVideoPlayer({
    super.key,
    required this.url,
    this.autoplay = true,
    this.onViewCreated,
    this.onPipStarted,
    this.onPipStopped,
    this.onPipRestoreToFullscreen,
  });

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  NativeVideoPlayerController? _controller;
  EventChannel? _eventChannel;

  void _setupEventListener(int viewId) {
    _eventChannel =
        EventChannel('advanced_video_player/native_view_events_$viewId');
    _eventChannel!.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final eventType = event['event'] as String?;
        debugPrint('[NativeVideoPlayer] Evento recibido: $eventType');

        switch (eventType) {
          case 'pip_started':
            widget.onPipStarted?.call();
            break;
          case 'pip_stopped':
            widget.onPipStopped?.call();
            break;
          case 'pip_restore_to_fullscreen':
            debugPrint(
                '[NativeVideoPlayer] 🎬 Usuario volvió desde PiP → navegando a fullscreen');
            widget.onPipRestoreToFullscreen?.call();
            break;
        }
      }
    }, onError: (dynamic error) {
      debugPrint('[NativeVideoPlayer] Error en stream de eventos: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'advanced_video_player/native_view',
        creationParams: {
          'url': widget.url,
          'autoplay': widget.autoplay,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int viewId) {
          _controller = NativeVideoPlayerController._(viewId);
          _setupEventListener(viewId);
          widget.onViewCreated?.call(_controller!);
        },
      );
    }

    // Para Android, puedes implementar una vista similar o usar otro enfoque
    return Container(
      color: const Color(0xFF000000),
      child: const Center(
        child: Text(
          'NativeVideoPlayer solo está disponible en iOS',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Controlador para el reproductor de video nativo
class NativeVideoPlayerController {
  final int viewId;
  late final MethodChannel _methodChannel;

  NativeVideoPlayerController._(this.viewId) {
    _methodChannel = MethodChannel('advanced_video_player/native_view_$viewId');
  }

  /// Inicia el modo Picture-in-Picture
  Future<void> startPiP() async {
    try {
      await _methodChannel.invokeMethod('startPiP');
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al iniciar PiP: $e');
      rethrow;
    }
  }

  /// Detiene el modo Picture-in-Picture
  Future<void> stopPiP() async {
    try {
      await _methodChannel.invokeMethod('stopPiP');
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al detener PiP: $e');
      rethrow;
    }
  }

  /// Reproduce el video
  Future<void> play() async {
    try {
      await _methodChannel.invokeMethod('play');
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al reproducir: $e');
      rethrow;
    }
  }

  /// Pausa el video
  Future<void> pause() async {
    try {
      await _methodChannel.invokeMethod('pause');
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al pausar: $e');
      rethrow;
    }
  }

  /// Busca a un tiempo específico en el video
  Future<void> seek(double time) async {
    try {
      await _methodChannel.invokeMethod('seek', {'time': time});
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al buscar: $e');
      rethrow;
    }
  }

  /// Establece el volumen del video (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al establecer volumen: $e');
      rethrow;
    }
  }

  /// Cambia la URL del video
  Future<void> setUrl(String url, {bool autoplay = true}) async {
    try {
      await _methodChannel.invokeMethod('setUrl', {
        'url': url,
        'autoplay': autoplay,
      });
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al cambiar URL: $e');
      rethrow;
    }
  }

  /// Limpia los recursos
  void dispose() {
    // Cleanup si es necesario
  }
}
