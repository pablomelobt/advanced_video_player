import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget que muestra el botón nativo de AirPlay en iOS
class AirPlayButton extends StatelessWidget {
  /// Ancho del botón (default: 40)
  final double width;

  /// Alto del botón (default: 40)
  final double height;

  /// Color del tinte del botón (solo iOS)
  final Color? tintColor;

  const AirPlayButton({
    super.key,
    this.width = 40,
    this.height = 40,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en iOS
    if (!(Theme.of(context).platform == TargetPlatform.iOS)) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: height,
      child: UiKitView(
        viewType: 'advanced_video_player/airplay_button',
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) {
          // Opcional: configurar el botón si necesitas pasar parámetros
          debugPrint('AirPlay button created with id: $id');
        },
      ),
    );
  }
}

/// Widget personalizable para mostrar el estado de AirPlay
class AirPlayStatusButton extends StatefulWidget {
  /// Ancho del botón
  final double width;

  /// Alto del botón
  final double height;

  /// Callback cuando cambia el estado de AirPlay
  final Function(bool isActive)? onAirPlayStateChanged;

  /// Callback cuando se presiona el botón
  final VoidCallback? onPressed;

  const AirPlayStatusButton({
    super.key,
    this.width = 40,
    this.height = 40,
    this.onAirPlayStateChanged,
    this.onPressed,
  });

  @override
  State<AirPlayStatusButton> createState() => _AirPlayStatusButtonState();
}

class _AirPlayStatusButtonState extends State<AirPlayStatusButton> {
  static const MethodChannel _channel = MethodChannel('advanced_video_player');
  bool _isAirPlayActive = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _startStatusMonitoring();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusMonitoring() {
    // Verificar el estado de AirPlay cada 2 segundos
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkAirPlayStatus();
    });

    // Verificación inicial
    _checkAirPlayStatus();
  }

  Future<void> _checkAirPlayStatus() async {
    try {
      final bool isActive =
          await _channel.invokeMethod('isAirPlayActive') ?? false;
      if (mounted && isActive != _isAirPlayActive) {
        setState(() {
          _isAirPlayActive = isActive;
        });
        widget.onAirPlayStateChanged?.call(isActive);
      }
    } catch (e) {
      debugPrint('Error checking AirPlay status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo mostrar en iOS
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _isAirPlayActive
              ? Colors.blue.withOpacity(0.8)
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Botón nativo de AirPlay
            const AirPlayButton(),

            // Indicador de estado
            if (_isAirPlayActive)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget que muestra una lista de dispositivos AirPlay disponibles
class AirPlayDevicesList extends StatefulWidget {
  /// Callback cuando se selecciona un dispositivo
  final Function(Map<String, dynamic> device)? onDeviceSelected;

  const AirPlayDevicesList({
    super.key,
    this.onDeviceSelected,
  });

  @override
  State<AirPlayDevicesList> createState() => _AirPlayDevicesListState();
}

class _AirPlayDevicesListState extends State<AirPlayDevicesList> {
  static const MethodChannel _channel = MethodChannel('advanced_video_player');
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final List<dynamic> devicesData =
          await _channel.invokeMethod('getAirPlayDevices') ?? [];

      final devices = devicesData.cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading AirPlay devices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.airplay,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay dispositivos AirPlay disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Asegúrate de que tu Apple TV o Smart TV esté en la misma red Wi-Fi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.airplay,
              color: Colors.blue,
              size: 24,
            ),
          ),
          title: Text(
            device['name'] ?? 'Dispositivo AirPlay',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'AirPlay',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
          onTap: () {
            widget.onDeviceSelected?.call(device);
          },
        );
      },
    );
  }
}
