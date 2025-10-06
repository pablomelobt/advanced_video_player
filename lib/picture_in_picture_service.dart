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
      debugPrint('Picture-in-Picture support check result: $supported');
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
      debugPrint(
          'Attempting to enter Picture-in-Picture mode with size: ${width}x${height}');
      final bool success =
          await _channel.invokeMethod('enterPictureInPictureMode', {
        'width': width,
        'height': height,
      });
      debugPrint('Picture-in-Picture mode result: $success');
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

  /// Obtiene información de debug sobre el soporte de Picture-in-Picture
  static Future<Map<String, dynamic>> getPictureInPictureInfo() async {
    try {
      final Map<dynamic, dynamic> info =
          await _channel.invokeMethod('getPictureInPictureInfo');
      return Map<String, dynamic>.from(info);
    } catch (e) {
      debugPrint('Error getting PiP info: $e');
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
}
