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
      debugPrint('[NativeVideoPlayer] 🔔 Evento recibido completo: $event');

      if (event is Map) {
        final eventType = event['event'] as String?;
        final viewId = event['viewId'];
        debugPrint(
            '[NativeVideoPlayer] 📱 Evento: $eventType, ViewId: $viewId');

        switch (eventType) {
          case 'pip_started':
            debugPrint(
                '[NativeVideoPlayer] ✅ PiP iniciado - llamando callback');
            widget.onPipStarted?.call();
            break;
          case 'pip_stopped':
            debugPrint(
                '[NativeVideoPlayer] ⏹️ PiP detenido - llamando callback');
            widget.onPipStopped?.call();
            break;
          case 'pip_restore_fullscreen':
            final reason = event['reason'] as String? ?? 'unknown';
            debugPrint(
                '[NativeVideoPlayer] 🎬 Restaurando fullscreen desde PiP (razón: $reason) - llamando callback');
            widget.onPipRestoreToFullscreen?.call();
            break;
          case 'pip_will_start':
            debugPrint('[NativeVideoPlayer] 🎥 PiP por iniciar...');
            break;
          case 'pip_will_stop':
            debugPrint('[NativeVideoPlayer] ⏹️ PiP por detener...');
            break;
          case 'pip_error':
            final message = event['message'] as String? ?? 'Error desconocido';
            debugPrint('[NativeVideoPlayer] ❌ Error en PiP: $message');
            break;
          default:
            debugPrint('[NativeVideoPlayer] ❓ Evento desconocido: $eventType');
        }
      } else {
        debugPrint(
            '[NativeVideoPlayer] ⚠️ Evento no es un Map: $event (tipo: ${event.runtimeType})');
      }
    }, onError: (dynamic error) {
      debugPrint('[NativeVideoPlayer] ❌ Error en stream de eventos: $error');
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

  /// Obtiene la posición actual del video en segundos
  Future<double> getCurrentPosition() async {
    try {
      final position = await _methodChannel.invokeMethod('getCurrentPosition');
      return (position as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al obtener posición: $e');
      return 0.0;
    }
  }

  /// Obtiene la duración total del video en segundos
  Future<double> getDuration() async {
    try {
      final duration = await _methodChannel.invokeMethod('getDuration');
      return (duration as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al obtener duración: $e');
      return 0.0;
    }
  }

  /// Verifica si el video está buffering/cargando
  Future<bool> isBuffering() async {
    try {
      final buffering = await _methodChannel.invokeMethod('isBuffering');
      return buffering as bool? ?? false;
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al verificar buffering: $e');
      return false;
    }
  }

  /// Verifica si el video está reproduciéndose
  Future<bool> isPlaying() async {
    try {
      final playing = await _methodChannel.invokeMethod('isPlaying');
      return playing as bool? ?? false;
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al verificar reproducción: $e');
      return false;
    }
  }

  /// Limpia los recursos
  void dispose() {
    // Cleanup si es necesario
  }

  /// Limpia el cache de players compartidos (iOS solamente)
  ///
  /// Este método libera todos los players compartidos que mantienen
  /// el estado entre navegaciones. Úsalo cuando quieras liberar memoria
  /// o cuando cambies completamente de contexto en tu aplicación.
  ///
  /// Nota: Después de llamar este método, los videos volverán a empezar
  /// desde el inicio la próxima vez que se reproduzcan.
  static Future<bool> clearSharedPlayersCache() async {
    try {
      const channel = MethodChannel('advanced_video_player');
      final result = await channel.invokeMethod('clearNativePlayersCache');
      debugPrint(
          '[NativeVideoPlayer] 🧹 Cache de players compartidos limpiado: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Error al limpiar cache: $e');
      return false;
    }
  }
}
