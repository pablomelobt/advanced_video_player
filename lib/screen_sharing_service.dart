import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Estados de la conexión de compartir pantalla
enum ScreenSharingState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Servicio para manejar el compartir pantalla (SharePlay en iOS, Google Cast en Android)
/// Implementado usando canales de método nativos sin dependencias externas
class ScreenSharingService {
  static const MethodChannel _channel = MethodChannel('screen_sharing');

  static final ScreenSharingService _instance =
      ScreenSharingService._internal();
  factory ScreenSharingService() => _instance;
  ScreenSharingService._internal();

  // Streams para notificar cambios de estado
  final StreamController<ScreenSharingState> _stateController =
      StreamController<ScreenSharingState>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _deviceController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters para los streams
  Stream<ScreenSharingState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get deviceStream => _deviceController.stream;

  ScreenSharingState _currentState = ScreenSharingState.disconnected;
  ScreenSharingState get currentState => _currentState;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de compartir pantalla
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Configurar el canal de método
      _channel.setMethodCallHandler(_handleMethodCall);

      // Inicializar según la plataforma
      final result = await _channel.invokeMethod('initialize');
      if (result == true) {
        _isInitialized = true;
        _updateState(ScreenSharingState.disconnected);
        debugPrint('ScreenSharingService inicializado correctamente');
        return true;
      } else {
        throw Exception('Error inicializando el servicio nativo');
      }
    } catch (e) {
      debugPrint('Error inicializando ScreenSharingService: $e');
      _errorController.add('Error al inicializar: $e');

      // Si es un MissingPluginException, usar fallback
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('🔍 Plugin nativo no disponible, usando fallback');
        _isInitialized = true;
        _updateState(ScreenSharingState.disconnected);
        return true;
      }

      return false;
    }
  }

  /// Busca dispositivos disponibles para compartir
  Future<List<Map<String, dynamic>>> discoverDevices() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _channel.invokeMethod('discoverDevices');
      if (result is List) {
        // Conversión segura de tipos mixtos desde Java
        return result.map((item) {
          if (item is Map) {
            // Convertir Map<Object?, Object?> a Map<String, dynamic>
            final Map<String, dynamic> convertedMap = {};
            item.forEach((key, value) {
              if (key is String) {
                convertedMap[key] = value;
              }
            });
            return convertedMap;
          }
          return <String, dynamic>{};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error descubriendo dispositivos: $e');
      _errorController.add('Error buscando dispositivos: $e');

      // Si es un MissingPluginException, usar fallback
      if (e.toString().contains('MissingPluginException')) {
        debugPrint(
            '🔍 Plugin nativo no disponible, usando dispositivos simulados');
        return [
          {
            "id": "shareplay_group",
            "name": "Compartir con Grupo",
            "type": "shareplay",
            "isConnected": false
          }
        ];
      }

      return [];
    }
  }

  /// Conecta a un dispositivo específico
  Future<bool> connectToDevice(String deviceId, String deviceName) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _updateState(ScreenSharingState.connecting);

      final result = await _channel.invokeMethod('connectToDevice', {
        'deviceId': deviceId,
        'deviceName': deviceName,
      });

      if (result == true) {
        _updateState(ScreenSharingState.connected);
        _deviceController.add({
          'id': deviceId,
          'name': deviceName,
          'connected': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        return true;
      } else {
        _updateState(ScreenSharingState.error);
        return false;
      }
    } catch (e) {
      debugPrint('Error conectando al dispositivo: $e');
      _errorController.add('Error conectando: $e');

      // Si es un MissingPluginException, usar fallback
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('🔍 Plugin nativo no disponible, simulando conexión');
        _updateState(ScreenSharingState.connected);
        _deviceController.add({
          'id': deviceId,
          'name': deviceName,
          'connected': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        return true;
      }

      _updateState(ScreenSharingState.error);
      return false;
    }
  }

  /// Comparte un video específico
  Future<bool> shareVideo({
    required String videoUrl,
    required String title,
    String? description,
    String? thumbnailUrl,
  }) async {
    if (_currentState != ScreenSharingState.connected) {
      _errorController.add('No hay dispositivo conectado');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('shareVideo', {
        'videoUrl': videoUrl,
        'title': title,
        'description': description ?? '',
        'thumbnailUrl': thumbnailUrl ?? '',
      });
      return result == true;
    } catch (e) {
      debugPrint('Error compartiendo video: $e');
      _errorController.add('Error compartiendo video: $e');

      // Si es un MissingPluginException, usar fallback
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('🔍 Plugin nativo no disponible, simulando compartir');
        return true;
      }

      return false;
    }
  }

  /// Controla la reproducción del video compartido
  Future<bool> controlPlayback({
    required String action, // 'play', 'pause', 'seek', 'stop'
    double? position,
  }) async {
    if (_currentState != ScreenSharingState.connected) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('controlPlayback', {
        'action': action,
        'position': position,
      });
      return result == true;
    } catch (e) {
      debugPrint('Error controlando reproducción: $e');
      return false;
    }
  }

  /// Desconecta del dispositivo actual
  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      if (result == true) {
        _updateState(ScreenSharingState.disconnected);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error desconectando: $e');
      _errorController.add('Error desconectando: $e');
      return false;
    }
  }

  /// Maneja las llamadas de método desde el código nativo
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceConnected':
        _deviceController.add(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onDeviceDisconnected':
        _updateState(ScreenSharingState.disconnected);
        break;
      case 'onError':
        _errorController.add(call.arguments.toString());
        _updateState(ScreenSharingState.error);
        break;
      case 'onStateChanged':
        final state = call.arguments as String;
        _updateState(_parseStateFromString(state));
        break;
      case 'onSessionJoined':
        // SharePlay: Se unió a una sesión de grupo
        final args = Map<String, dynamic>.from(call.arguments);
        debugPrint(
            'SharePlay: Sesión iniciada - ${args['sessionId']} con ${args['participants']} participantes');
        _updateState(ScreenSharingState.connected);
        break;
      case 'onPlaybackControl':
        // SharePlay: Recibió control de reproducción
        final args = Map<String, dynamic>.from(call.arguments);
        debugPrint(
            'SharePlay: Control recibido - ${args['action']} en posición ${args['position']}');
        break;
    }
  }

  /// Actualiza el estado actual
  void _updateState(ScreenSharingState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Parsea el estado desde string
  ScreenSharingState _parseStateFromString(String state) {
    switch (state.toLowerCase()) {
      case 'connected':
        return ScreenSharingState.connected;
      case 'connecting':
        return ScreenSharingState.connecting;
      case 'error':
        return ScreenSharingState.error;
      default:
        return ScreenSharingState.disconnected;
    }
  }

  /// Verifica si el compartir pantalla está soportado
  static Future<bool> isScreenSharingSupported() async {
    try {
      debugPrint('🔍 Verificando soporte de screen sharing...');
      debugPrint('🔍 Canal: $_channel');
      debugPrint('🔍 Plataforma: ${Platform.operatingSystem}');

      // Intentar llamar al método con timeout
      final result = await _channel.invokeMethod('isSupported').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⏰ Timeout verificando soporte');
          return false;
        },
      );

      debugPrint('🔍 Resultado de soporte: $result');
      debugPrint('🔍 Tipo de resultado: ${result.runtimeType}');

      // Asegurar que el resultado sea boolean
      final bool supported = result == true || result == 1 || result == 'true';
      debugPrint('🔍 Soporte final: $supported');

      return supported;
    } catch (e) {
      debugPrint('❌ Error verificando soporte: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // En caso de error, asumir que está soportado en iOS 15+
      if (Platform.isIOS) {
        debugPrint('🔍 Asumiendo soporte en iOS por defecto');
        return true;
      }

      return false;
    }
  }

  /// Obtiene el nombre de la plataforma actual
  static String getPlatformName() {
    if (Platform.isAndroid) {
      return 'Android Cast';
    } else if (Platform.isIOS) {
      return 'SharePlay';
    }
    return 'Desconocido';
  }

  /// Limpia los recursos
  void dispose() {
    _stateController.close();
    _errorController.close();
    _deviceController.close();
  }
}
