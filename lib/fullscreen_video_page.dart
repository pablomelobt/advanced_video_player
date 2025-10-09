import 'dart:async';
import 'dart:io';
import 'package:advanced_video_player/airplay_button.dart';
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
  final bool enableAirPlay;
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
    this.enableAirPlay = true,
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
  bool _isAirPlaySupported = false;
  // ignore: unused_field
  bool _isAirPlayActive = false;
  ScreenSharingState _screenSharingState = ScreenSharingState.disconnected;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  Timer? _hideControlsTimer;
  Timer? _pipStateTimer;
  Timer? _hideAirPlayTimer;
  StreamSubscription<dynamic>? _pipModeSubscription;
  StreamSubscription<ScreenSharingState>? _screenSharingStateSubscription;
  StreamSubscription<String>? _screenSharingErrorSubscription;
  ScreenSharingService? _screenSharingService;

  // Variables para el arrastre de la barra de progreso
  bool _isDraggingProgressBar = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Inicializar servicio PiP con callback
    PictureInPictureService.initialize();
    PictureInPictureService.setOnPipControlListener(_handlePipControlEvent);

    _setupFullscreen();
    _setupAnimations();
    _setupVideoListener();
    _checkPictureInPictureSupport();
    _setupPictureInPictureListener();
    _initializeScreenSharing();
    _initializeAirPlay();
    _startAirPlayTimer();
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
    // Escuchar eventos de PiP (cambios de estado y controles)
    _pipModeSubscription =
        PictureInPictureService.pictureInPictureEventStream.listen((event) {
      if (!mounted) return;

      // Si es un boolean simple, es un cambio de estado de PiP
      if (event is bool) {
        setState(() {
          _isInPictureInPictureMode = event;
        });
        return;
      }

      // Si es un Map, puede ser un evento de control (desde Android)
      if (event is Map) {
        final type = event['type'] as String?;
        final action = event['action'] as String?;

        if (type == 'control' && action != null) {
          _handlePipControlEvent(action);
        }
      }
    });

    // Verificar el estado inicial
    _checkPictureInPictureState();

    // Configurar timer para verificar el estado periódicamente
    _pipStateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkPictureInPictureState();
    });

    // La navegación automática ahora se maneja desde iOS nativo
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
      debugPrint(
          '[FullscreenVideoPage] Error al verificar el estado de PiP: $e');
    }
  }

  void _initializeScreenSharing() async {
    if (!widget.enableScreenSharing) {
      return;
    }

    try {
      _screenSharingService = ScreenSharingService();

      final supported = await ScreenSharingService.isScreenSharingSupported();

      if (!mounted) return;
      setState(() {
        _isScreenSharingSupported = supported;
      });

      if (supported) {
        await _screenSharingService!.initialize();
        if (!mounted) return;
        _setupScreenSharingListeners();
      } else {}
    } catch (e) {
      debugPrint(
          '[FullscreenVideoPage] Error al inicializar Screen Sharing: $e');
    }
  }

  void _initializeAirPlay() async {
    if (!widget.enableAirPlay) return;
    if (!Platform.isIOS) return;

    try {
      const channel = MethodChannel('advanced_video_player');
      final isActive = await channel.invokeMethod('isAirPlayActive') ?? false;
      if (!mounted) return;
      setState(() {
        _isAirPlaySupported = true;
        _isAirPlayActive = isActive;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAirPlaySupported = true;
      });
    }
  }

  void _startAirPlayTimer() {
    // Ocultar botones de AirPlay después de 2 segundos
    _hideAirPlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {});
      }
    });
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
    final newPlayingState = widget.controller.value.isPlaying;
    if (_isPlaying != newPlayingState) {
      setState(() {
        _isPlaying = newPlayingState;
      });
      _updatePipPlaybackState(newPlayingState);
    }
  }

  void _handlePipControlEvent(String action) {
    if (!mounted) return;

    debugPrint('[FullscreenVideoPage] Control PiP recibido: $action');

    switch (action) {
      case 'play':
        widget.controller.play();
        setState(() => _isPlaying = true);
        _updatePipPlaybackState(true);
        break;
      case 'pause':
        widget.controller.pause();
        setState(() => _isPlaying = false);
        _updatePipPlaybackState(false);
        break;
      case 'play_pause':
        // Toggle play/pause para controles nativos de Android
        if (_isPlaying) {
          widget.controller.pause();
          setState(() => _isPlaying = false);
          _updatePipPlaybackState(false);
        } else {
          widget.controller.play();
          setState(() => _isPlaying = true);
          _updatePipPlaybackState(true);
        }
        break;
      case 'replay10':
        final currentPosition = widget.controller.value.position;
        final newPosition =
            currentPosition - Duration(seconds: widget.skipDuration);
        widget.controller
            .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
        break;
      case 'forward10':
        final currentPosition = widget.controller.value.position;
        final duration = widget.controller.value.duration;
        final newPosition =
            currentPosition + Duration(seconds: widget.skipDuration);
        widget.controller
            .seekTo(newPosition > duration ? duration : newPosition);
        break;
    }
  }

  void _updatePipPlaybackState(bool isPlaying) {
    // Solo actualizar en Android cuando está en modo PiP
    if (Platform.isAndroid && _isInPictureInPictureMode) {
      PictureInPictureService.updatePlaybackState(isPlaying: isPlaying);
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        widget.controller.pause();
        _isPlaying = false;
        _updatePipPlaybackState(false);
      } else {
        widget.controller.play();
        _isPlaying = true;
        _updatePipPlaybackState(true);
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
      const width = 400.0;
      final height = width / aspectRatio;

      final success = await PictureInPictureService.enterPictureInPictureMode(
        width: width,
        height: height,
        isPlaying:
            _isPlaying, // Pasar estado de reproducción para controles nativos
      );

      if (!mounted) return;
      if (success) {
        debugPrint(
            'Picture-in-Picture activado con controles nativos (Android)');
      } else {
        debugPrint('No se pudo activar Picture-in-Picture');
      }
    } catch (e) {
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
    // No mostrar controles si está en modo PiP
    if (_isInPictureInPictureMode) {
      return;
    }

    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();

    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _onTapVideo() {
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
            // Video en pantalla completa - centrado y con aspect ratio correcto
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Indicador de carga cuando el video está inicializando o buffering
            if (!widget.controller.value.isInitialized ||
                widget.controller.value.isBuffering)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.controller.value.isBuffering
                            ? 'Cargando...'
                            : 'Cargando video...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Controles overlay
            // No mostrar controles en modo PiP para evitar overflow
            if (!_isInPictureInPictureMode)
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
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Botón de regresar en la izquierda (solo Android)
                                  if (Platform.isAndroid)
                                    _buildControlButton(
                                      icon: Icons.arrow_back,
                                      onPressed: _exitFullscreen,
                                      tooltip: 'Regresar',
                                      size: 40,
                                    ),
                                  // Controles de la derecha
                                  Row(
                                    children: [
                                      if (Platform.isIOS)
                                        AirPlayStatusButton(
                                          width: 40,
                                          height: 40,
                                          onAirPlayStateChanged: (isActive) {
                                            if (mounted) {
                                              setState(() {
                                                _isAirPlayActive = isActive;
                                              });
                                            }
                                          },
                                        ),
                                      if (Platform.isAndroid &&
                                          widget.enableAirPlay &&
                                          _isAirPlaySupported)
                                        const SizedBox(width: 8),
                                      if (Platform.isAndroid &&
                                          widget.enableScreenSharing &&
                                          _isScreenSharingSupported)
                                        _buildControlButton(
                                          icon: _screenSharingState ==
                                                  ScreenSharingState.connected
                                              ? Icons.cast_connected
                                              : Icons.cast,
                                          onPressed: _screenSharingState ==
                                                  ScreenSharingState.connected
                                              ? _disconnectScreenSharing
                                              : _showScreenSharingDialog,
                                          tooltip: _screenSharingState ==
                                                  ScreenSharingState.connected
                                              ? 'Desconectar compartir pantalla'
                                              : 'Compartir pantalla',
                                          size: 40,
                                        ),
                                      if (widget.enableScreenSharing &&
                                          _isScreenSharingSupported)
                                        const SizedBox(width: 8),
                                      if (widget.enablePictureInPicture)
                                        _buildControlButton(
                                          icon: Icons.picture_in_picture_alt,
                                          onPressed: _enterPictureInPicture,
                                          tooltip: 'Picture-in-Picture',
                                          size: 40,
                                        ),
                                      if (widget.enablePictureInPicture)
                                        const SizedBox(width: 8),
                                      _buildControlButton(
                                        icon: Icons.fullscreen_exit,
                                        onPressed: _exitFullscreen,
                                        tooltip: 'Salir de pantalla completa',
                                        size: 40,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Controles centrales
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildControlButton(
                                  icon: Icons.replay_10,
                                  onPressed: _skipBackward,
                                  tooltip: 'Retroceder ${widget.skipDuration}s',
                                  size: 45,
                                  iconSize: 40,
                                ),
                                _buildControlButton(
                                  icon: _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  onPressed: _togglePlayPause,
                                  tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                                  size: 65,
                                  iconSize: 60,
                                ),
                                _buildControlButton(
                                  icon: Icons.forward_10,
                                  onPressed: _skipForward,
                                  tooltip: 'Avanzar ${widget.skipDuration}s',
                                  size: 45,
                                  iconSize: 40,
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Barra inferior
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  LayoutBuilder(
                                    builder: (layoutContext, constraints) {
                                      final width = constraints.maxWidth;

                                      return GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onHorizontalDragStart: (details) {
                                          setState(() {
                                            _isDraggingProgressBar = true;
                                            final localDx = details
                                                .localPosition.dx
                                                .clamp(0.0, width);
                                            _dragProgress = (localDx / width)
                                                .clamp(0.0, 1.0);
                                          });
                                          // Cancelar el timer de ocultar controles mientras se arrastra
                                          _hideControlsTimer?.cancel();
                                        },
                                        onHorizontalDragUpdate: (details) {
                                          setState(() {
                                            final localDx = details
                                                .localPosition.dx
                                                .clamp(0.0, width);
                                            _dragProgress = (localDx / width)
                                                .clamp(0.0, 1.0);
                                          });
                                        },
                                        onHorizontalDragEnd: (details) {
                                          final duration =
                                              widget.controller.value.duration;
                                          if (duration.inMilliseconds > 0) {
                                            widget.controller.seekTo(
                                                duration * _dragProgress);
                                          }
                                          setState(() {
                                            _isDraggingProgressBar = false;
                                          });
                                          // Reiniciar el timer para ocultar controles
                                          _showControlsTemporarily();
                                        },
                                        onTapDown: (details) {
                                          final localDx = details
                                              .localPosition.dx
                                              .clamp(0.0, width);
                                          final relative =
                                              (localDx / width).clamp(0.0, 1.0);
                                          final duration =
                                              widget.controller.value.duration;
                                          if (duration.inMilliseconds > 0) {
                                            widget.controller
                                                .seekTo(duration * relative);
                                          }
                                        },
                                        child: ValueListenableBuilder<
                                            VideoPlayerValue>(
                                          valueListenable: widget.controller,
                                          builder: (context, value, _) {
                                            final position = value.position;
                                            final duration = value.duration;
                                            final videoProgress =
                                                duration.inMilliseconds > 0
                                                    ? (position.inMilliseconds /
                                                            duration
                                                                .inMilliseconds)
                                                        .clamp(0.0, 1.0)
                                                    : 0.0;

                                            // Usar el progreso del arrastre si está arrastrando,
                                            // de lo contrario usar el progreso del video
                                            final displayProgress =
                                                _isDraggingProgressBar
                                                    ? _dragProgress
                                                    : videoProgress;

                                            return Container(
                                              height: 28,
                                              alignment: Alignment.bottomCenter,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 0,
                                                      vertical: 8),
                                              child: Stack(
                                                alignment: Alignment.centerLeft,
                                                children: [
                                                  // Fondo gris translúcido
                                                  Container(
                                                    height: 3,
                                                    width: width,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              2),
                                                      color: Colors.white
                                                          .withOpacity(0.25),
                                                    ),
                                                  ),
                                                  // Progreso naranja (YouTube-style)
                                                  FractionallySizedBox(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    widthFactor:
                                                        displayProgress,
                                                    child: Container(
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(2),
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            widget.primaryColor,
                                                            widget
                                                                .secondaryColor
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Thumb circular - más grande cuando se arrastra
                                                  Positioned(
                                                    left: (width *
                                                            displayProgress) -
                                                        (_isDraggingProgressBar
                                                            ? 8
                                                            : 6),
                                                    bottom:
                                                        _isDraggingProgressBar
                                                            ? -6
                                                            : -4,
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                          milliseconds: 100),
                                                      width:
                                                          _isDraggingProgressBar
                                                              ? 16
                                                              : 12,
                                                      height:
                                                          _isDraggingProgressBar
                                                              ? 16
                                                              : 12,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 3,
                                                            offset:
                                                                const Offset(
                                                                    0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 12),
                                  // Tiempo y duración
                                  ValueListenableBuilder<VideoPlayerValue>(
                                    valueListenable: widget.controller,
                                    builder: (context, value, _) {
                                      final currentPosition =
                                          _isDraggingProgressBar
                                              ? value.duration * _dragProgress
                                              : value.position;

                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(currentPosition),
                                            style: TextStyle(
                                              color: _isDraggingProgressBar
                                                  ? widget.primaryColor
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(value.duration),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 32,
    double iconSize = 20,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          alignment: Alignment.center,
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

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
    _hideAirPlayTimer?.cancel();
    _controlsAnimationController.dispose();
    _pipModeSubscription?.cancel();
    _screenSharingStateSubscription?.cancel();
    _screenSharingErrorSubscription?.cancel();
    _screenSharingService?.dispose();
    super.dispose();
  }
}
