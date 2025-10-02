import 'dart:async';
import 'package:flutter/material.dart';
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
      debugPrint('Error checking PiP support: $e');
      return false;
    }
  }

  /// Activa el modo Picture-in-Picture
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
      debugPrint('Error entering PiP mode: $e');
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
      debugPrint('Error exiting PiP mode: $e');
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
      debugPrint('Error checking PiP mode: $e');
      return false;
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
}
