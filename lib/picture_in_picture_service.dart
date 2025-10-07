import 'dart:async';
import 'package:flutter/services.dart';

class PictureInPictureService {
  static const MethodChannel _channel =
      MethodChannel('picture_in_picture_service');
  static const EventChannel _eventChannel =
      EventChannel('picture_in_picture_service_events');

  /// Verifica si el dispositivo soporta Picture-in-Picture
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
  static Future<bool> enterPictureInPictureMode({
    required double width,
    required double height,
  }) async {
    try {
      print('[DEBUG] 🎯 Flutter: Llamando enterPictureInPictureMode...');
      print('[DEBUG] 📐 Flutter: Dimensiones: ${width}x$height');

      final bool success =
          await _channel.invokeMethod('enterPictureInPictureMode', {
        'width': width,
        'height': height,
      });

      print('[DEBUG] ✅ Flutter: Resultado PiP: $success');
      return success;
    } catch (e) {
      print('[DEBUG] ❌ Flutter: Error en PiP: $e');
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
