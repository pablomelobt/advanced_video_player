import 'dart:async';
import 'package:flutter/services.dart';

/// Servicio para manejar Picture-in-Picture (PiP) en dispositivos móviles
///
/// Este servicio proporciona funcionalidades para activar y controlar
/// el modo Picture-in-Picture en videos, permitiendo que el usuario
/// continúe viendo el contenido mientras usa otras aplicaciones.
///
/// Ejemplo de uso:
/// ```dart
/// // Verificar si PiP está soportado
/// bool supported = await PictureInPictureService.isPictureInPictureSupported();
///
/// if (supported) {
///   // Activar PiP
///   bool success = await PictureInPictureService.enterPictureInPictureMode(
///     width: 400.0,
///     height: 225.0,
///   );
/// }
/// ```
class PictureInPictureService {
  static const MethodChannel _channel =
      MethodChannel('picture_in_picture_service');
  static const EventChannel _eventChannel =
      EventChannel('picture_in_picture_service_events');

  /// Verifica si el dispositivo soporta Picture-in-Picture
  ///
  /// Retorna `true` si el dispositivo y la versión del sistema operativo
  /// soportan Picture-in-Picture, `false` en caso contrario.
  ///
  /// En Android requiere API 24+ y en iOS requiere iOS 14+.
  static Future<bool> isPictureInPictureSupported() async {
    try {
      final bool supported =
          await _channel.invokeMethod('isPictureInPictureSupported');

      return supported;
    } catch (e) {
      return false;
    }
  }

  /// Activa el modo Picture-in-Picture
  ///
  /// [width] y [height] especifican las dimensiones de la ventana PiP.
  /// Se recomienda usar una proporción de aspecto 16:9 para videos.
  ///
  /// Retorna `true` si se activó exitosamente, `false` en caso contrario.
  static Future<bool> enterPictureInPictureMode({
    required double width,
    required double height,
  }) async {
    try {
      final bool success =
          await _channel.invokeMethod('enterPictureInPictureMode', {
        'width': width,
        'height': height,
      });

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Sale del modo Picture-in-Picture
  static Future<bool> exitPictureInPictureMode() async {
    try {
      final bool success =
          await _channel.invokeMethod('exitPictureInPictureMode');
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si está actualmente en modo Picture-in-Picture
  static Future<bool> isInPictureInPictureMode() async {
    try {
      final bool inPip =
          await _channel.invokeMethod('isInPictureInPictureMode');
      return inPip;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene información de debug sobre el soporte de Picture-in-Picture
  static Future<Map<String, dynamic>> getPictureInPictureInfo() async {
    try {
      final Map<dynamic, dynamic> info =
          await _channel.invokeMethod('getPictureInPictureInfo');
      return Map<String, dynamic>.from(info);
    } catch (e) {
      return {};
    }
  }

  /// Stream para escuchar cambios en el estado de Picture-in-Picture
  ///
  /// Emite `true` cuando se activa PiP y `false` cuando se desactiva.
  /// Útil para actualizar la UI según el estado actual de PiP.
  static Stream<bool> get pictureInPictureModeStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is bool) {
        return event;
      }
      return false;
    });
  }

  /// Stream para escuchar eventos de Picture-in-Picture (incluyendo navegación)
  static Stream<dynamic> get pictureInPictureEventStream {
    return _eventChannel.receiveBroadcastStream();
  }
}
