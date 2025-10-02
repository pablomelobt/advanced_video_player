import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'picture_in_picture_service.dart';
import 'screen_sharing_service.dart';

class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final Color primaryColor;
  final Color secondaryColor;
  final int skipDuration;
  final bool enablePictureInPicture;
  final bool enableScreenSharing;
  final String? videoTitle;
  final String? videoDescription;

  const FullscreenVideoPage({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    required this.skipDuration,
    this.enablePictureInPicture = true,
    this.enableScreenSharing = true,
    this.videoTitle,
    this.videoDescription,
  });

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with TickerProviderStateMixin {
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isPictureInPictureSupported = false;
  bool _isInPictureInPictureMode = false;
  bool _isScreenSharingSupported = false;
  ScreenSharingState _screenSharingState = ScreenSharingState.disconnected;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  Timer? _hideControlsTimer;
  Timer? _pipStateTimer;
  StreamSubscription<bool>? _pipModeSubscription;
  StreamSubscription<ScreenSharingState>? _screenSharingStateSubscription;
  StreamSubscription<String>? _screenSharingErrorSubscription;
  ScreenSharingService? _screenSharingService;

  @override
  void initState() {
    super.initState();
    _setupFullscreen();
    _setupAnimations();
    _setupVideoListener();
    _checkPictureInPictureSupport();
    _setupPictureInPictureListener();
    _initializeScreenSharing();
  }

  void _checkPictureInPictureSupport() async {
    final supported =
        await PictureInPictureService.isPictureInPictureSupported();
    if (mounted) {
      setState(() {
        _isPictureInPictureSupported = supported;
      });
    }
  }

  void _setupPictureInPictureListener() {
    _pipModeSubscription = PictureInPictureService.pictureInPictureModeStream
        .listen((isInPipMode) {
      if (mounted) {
        setState(() {
          _isInPictureInPictureMode = isInPipMode;
        });
      }
    });

    // Verificar el estado inicial
    _checkPictureInPictureState();

    // Configurar timer para verificar el estado periódicamente
    _pipStateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkPictureInPictureState();
    });
  }

  void _checkPictureInPictureState() async {
    try {
      final isInPip = await PictureInPictureService.isInPictureInPictureMode();
      if (mounted) {
        setState(() {
          _isInPictureInPictureMode = isInPip;
        });
      }
    } catch (e) {
      debugPrint('Error checking PiP state: $e');
    }
  }

  void _initializeScreenSharing() async {
    debugPrint('🔍 Inicializando screen sharing...');
    debugPrint('🔍 enableScreenSharing: ${widget.enableScreenSharing}');

    if (!widget.enableScreenSharing) {
      debugPrint('❌ Screen sharing deshabilitado en widget');
      return;
    }

    try {
      _screenSharingService = ScreenSharingService();
      debugPrint('🔍 Verificando soporte de screen sharing...');
      final supported = await ScreenSharingService.isScreenSharingSupported();
      debugPrint('🔍 Soporte de screen sharing: $supported');

      if (!mounted) return;
      setState(() {
        _isScreenSharingSupported = supported;
      });
      debugPrint(
          '🔍 Estado actualizado - _isScreenSharingSupported: $_isScreenSharingSupported');

      if (supported) {
        debugPrint('🔍 Inicializando servicio de screen sharing...');
        await _screenSharingService!.initialize();
        if (!mounted) return;
        _setupScreenSharingListeners();
        debugPrint('✅ Screen sharing inicializado correctamente');
      } else {
        debugPrint('❌ Screen sharing no soportado en este dispositivo');
      }
    } catch (e) {
      debugPrint('❌ Error inicializando screen sharing: $e');
    }
  }

  void _setupScreenSharingListeners() {
    _screenSharingStateSubscription =
        _screenSharingService!.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _screenSharingState = state;
      });
    });

    _screenSharingErrorSubscription =
        _screenSharingService!.errorStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compartiendo: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _setupFullscreen() async {
    if (!mounted) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
    _controlsAnimationController.forward();
  }

  void _setupVideoListener() {
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (!mounted) return;
    setState(() {
      _isPlaying = widget.controller.value.isPlaying;
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        widget.controller.pause();
        _isPlaying = false;
      } else {
        widget.controller.play();
        _isPlaying = true;
      }
    });
    _showControlsTemporarily();
  }

  void _skipBackward() {
    final newPosition = widget.controller.value.position -
        Duration(seconds: widget.skipDuration);
    widget.controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _showControlsTemporarily();
  }

  void _skipForward() {
    final newPosition = widget.controller.value.position +
        Duration(seconds: widget.skipDuration);
    final maxPosition = widget.controller.value.duration;
    widget.controller
        .seekTo(newPosition > maxPosition ? maxPosition : newPosition);
    _showControlsTemporarily();
  }

  void _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _enterPictureInPicture() async {
    if (!_isPictureInPictureSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Picture-in-Picture no es compatible con este dispositivo'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final aspectRatio = widget.controller.value.aspectRatio;
      const width = 300.0;
      final height = width / aspectRatio;

      final success = await PictureInPictureService.enterPictureInPictureMode(
        width: width,
        height: height,
      );

      if (mounted) {
        if (success) {
          debugPrint('Picture-in-Picture activado');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo activar Picture-in-Picture'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al activar Picture-in-Picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();

    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _onTapVideo() {
    // Verificar el estado de PiP cuando se toca el video
    _checkPictureInPictureState();

    if (_showControls) {
      setState(() {
        _showControls = false;
      });
      _controlsAnimationController.reverse();
    } else {
      _showControlsTemporarily();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapVideo,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video en pantalla completa
            VideoPlayer(widget.controller),

            // Controles overlay
            AnimatedBuilder(
              animation: _controlsAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      child: _isInPictureInPictureMode
                          ? _buildCompactControls()
                          : Column(
                              children: [
                                // Barra superior - botón de salida
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (widget.enableScreenSharing &&
                                          _isScreenSharingSupported)
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              _screenSharingState ==
                                                      ScreenSharingState
                                                          .connected
                                                  ? Icons.cast_connected
                                                  : Icons.cast,
                                              color: Colors.white,
                                            ),
                                            onPressed: _screenSharingState ==
                                                    ScreenSharingState.connected
                                                ? _disconnectScreenSharing
                                                : _showScreenSharingDialog,
                                          ),
                                        ),
                                      if (widget.enableScreenSharing &&
                                          _isScreenSharingSupported)
                                        const SizedBox(width: 8),
                                      if (widget.enablePictureInPicture)
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                                Icons.picture_in_picture_alt,
                                                color: Colors.white),
                                            onPressed: _enterPictureInPicture,
                                          ),
                                        ),
                                      if (widget.enablePictureInPicture)
                                        const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                              Icons.fullscreen_exit,
                                              color: Colors.white),
                                          onPressed: _exitFullscreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Controles centrales
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildControlButton(
                                      icon: Icons.replay_10,
                                      onPressed: _skipBackward,
                                      tooltip:
                                          'Retroceder ${widget.skipDuration}s',
                                      size: 40,
                                    ),
                                    _buildControlButton(
                                      icon: _isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      onPressed: _togglePlayPause,
                                      tooltip:
                                          _isPlaying ? 'Pausar' : 'Reproducir',
                                      size: 60,
                                      isPrimary: true,
                                    ),
                                    _buildControlButton(
                                      icon: Icons.forward_10,
                                      onPressed: _skipForward,
                                      tooltip:
                                          'Avanzar ${widget.skipDuration}s',
                                      size: 40,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Barra inferior
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      // Barra de progreso
                                      GestureDetector(
                                        onTapDown: (details) {
                                          final RenderBox renderBox = context
                                              .findRenderObject() as RenderBox;
                                          final position =
                                              renderBox.globalToLocal(
                                                  details.globalPosition);
                                          final width =
                                              renderBox.size.width - 32;
                                          final percentage =
                                              position.dx / width;
                                          final newPosition = Duration(
                                            milliseconds: (widget
                                                        .controller
                                                        .value
                                                        .duration
                                                        .inMilliseconds *
                                                    percentage)
                                                .round(),
                                          );
                                          widget.controller.seekTo(newPosition);
                                        },
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            color:
                                                Colors.white.withOpacity(0.3),
                                          ),
                                          child: Stack(
                                            children: [
                                              FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: widget
                                                            .controller
                                                            .value
                                                            .duration
                                                            .inMilliseconds >
                                                        0
                                                    ? widget
                                                            .controller
                                                            .value
                                                            .position
                                                            .inMilliseconds /
                                                        widget
                                                            .controller
                                                            .value
                                                            .duration
                                                            .inMilliseconds
                                                    : 0.0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        widget.primaryColor,
                                                        widget.secondaryColor
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Tiempo y duración
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(widget
                                                .controller.value.position),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(widget
                                                .controller.value.duration),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactControls() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: Icons.replay_10,
            onPressed: _skipBackward,
            tooltip: 'Retroceder ${widget.skipDuration}s',
            size: 32,
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: _isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            onPressed: _togglePlayPause,
            tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
            size: 48,
            isPrimary: true,
          ),
          const SizedBox(width: 16),
          _buildControlButton(
            icon: Icons.forward_10,
            onPressed: _skipForward,
            tooltip: 'Avanzar ${widget.skipDuration}s',
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 32,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.white.withOpacity(0.9)
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
        child: IconButton(
          icon: Icon(
            icon,
            size: size,
            color: isPrimary ? widget.primaryColor : Colors.white,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  // Métodos para compartir pantalla
  Future<void> _showScreenSharingDialog() async {
    if (_screenSharingService == null || !_isScreenSharingSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compartir pantalla no está disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {});

    try {
      final devices = await _screenSharingService!.discoverDevices();
      if (!mounted) return;
      setState(() {});

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron dispositivos disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _showDeviceSelectionDialog(devices);
    } catch (e) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error buscando dispositivos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeviceSelectionDialog(List<Map<String, dynamic>> devices) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Elige un dispositivo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            // Device options
            ...devices.map((deviceData) {
              final device = deviceData;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.grey[50],
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      device['type'] == 'chromecast' ? Icons.cast : Icons.cast,
                      color: widget.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    device['name'] ?? 'Dispositivo desconocido',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    device['type'] == 'chromecast'
                        ? 'Google Cast'
                        : 'SharePlay',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _connectToDevice(device);
                  },
                ),
              );
            }),
            // Additional options like YouTube
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.grey[50],
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tv,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Vincular con código de TV',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Usar código de vinculación',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showTvCodeDialog();
                },
              ),
            ),
            // More info option
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.grey[50],
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Más información',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Ayuda con la conexión',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInfoDialog();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToDevice(Map<String, dynamic> device) async {
    final deviceId = device['id'] as String;
    final deviceName = device['name'] as String;

    try {
      final success =
          await _screenSharingService!.connectToDevice(deviceId, deviceName);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conectado a $deviceName'),
            backgroundColor: Colors.green,
          ),
        );
        _shareCurrentVideo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error conectando al dispositivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareCurrentVideo() async {
    if (_screenSharingService == null ||
        _screenSharingState != ScreenSharingState.connected) {
      return;
    }

    try {
      final success = await _screenSharingService!.shareVideo(
        videoUrl: widget.controller.dataSource,
        title: widget.videoTitle ?? 'Video Compartido',
        description:
            widget.videoDescription ?? 'Compartido desde Advanced Video Player',
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video compartido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error compartiendo el video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnectScreenSharing() async {
    if (_screenSharingService != null) {
      await _screenSharingService!.disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desconectado del dispositivo'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showTvCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular con código de TV'),
        content: const Text(
          'Esta funcionalidad permite conectar tu dispositivo usando un código que aparece en la pantalla de tu TV.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Más información'),
        content: const Text(
          'Para compartir video con otros dispositivos:\n\n'
          '• Asegúrate de que ambos dispositivos estén en la misma red Wi-Fi\n'
          '• Los dispositivos Chromecast deben estar configurados\n'
          '• Para SharePlay en iOS, ambos dispositivos deben tener iOS 15.1 o superior',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _pipStateTimer?.cancel();
    _controlsAnimationController.dispose();
    _pipModeSubscription?.cancel();
    _screenSharingStateSubscription?.cancel();
    _screenSharingErrorSubscription?.cancel();
    _screenSharingService?.dispose();
    super.dispose();
  }
}
