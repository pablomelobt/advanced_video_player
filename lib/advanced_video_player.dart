library advanced_video_player;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'fullscreen_video_page.dart';
import 'picture_in_picture_service.dart';
import 'screen_sharing_service.dart';
import 'airplay_button.dart';
import 'native_video_player.dart';

export 'native_video_player.dart';

/// Un reproductor de video avanzado con controles modernos y atractivos
class AdvancedVideoPlayer extends StatefulWidget {
  /// La fuente del video (URL o asset)
  final String videoSource;

  /// Si es true, trata videoSource como asset local
  final bool isAsset;

  /// Callback cuando el video termina de reproducir
  final VoidCallback? onVideoEnd;

  /// Callback cuando el video inicia de reproducir
  final VoidCallback? onVideoStart;

  /// Callback cuando el video pausa
  final VoidCallback? onVideoPause;

  /// Callback cuando el video play
  final VoidCallback? onVideoPlay;

  /// Callback cuando ocurre un error
  final Function(String)? onError;

  /// Duración en segundos para retroceder/avanzar (default: 10)
  final int skipDuration;

  /// Si es true, habilita el botón de Picture-in-Picture (default: true)
  final bool enablePictureInPicture;

  /// Si es true, habilita el botón de compartir pantalla (default: true)
  final bool enableScreenSharing;

  /// Si es true, habilita el botón de AirPlay (default: true, solo iOS)
  final bool enableAirPlay;

  /// Título del video para compartir
  final String? videoTitle;

  /// Descripción del video para compartir
  final String? videoDescription;

  /// Color principal del reproductor
  final Color primaryColor;

  /// Color secundario del reproductor
  final Color secondaryColor;

  /// Si es true, usa el reproductor nativo en iOS (mejor para PiP)
  final bool useNativePlayerOnIOS;

  /// Si es true, abre automáticamente en pantalla completa al iniciar
  final bool autoEnterFullscreen;

  /// URL de la imagen de preview/thumbnail (opcional)
  /// Si se proporciona, se mostrará mientras el video carga
  final String? previewImageUrl;

  final Widget? playButton;

  const AdvancedVideoPlayer({
    super.key,
    required this.videoSource,
    this.isAsset = false,
    this.onVideoEnd,
    this.onVideoStart,
    this.onVideoPause,
    this.onVideoPlay,
    this.onError,
    this.skipDuration = 10,
    this.enablePictureInPicture = true,
    this.enableScreenSharing = true,
    this.enableAirPlay = true,
    this.videoTitle,
    this.videoDescription,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
    this.useNativePlayerOnIOS = false,
    this.autoEnterFullscreen = false,
    this.previewImageUrl,
    this.playButton,
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  NativeVideoPlayerController? _nativeController;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final bool _isFullscreen = false;
  bool _isPictureInPictureSupported = false;
  bool _isScreenSharingSupported = false;
  bool _isAirPlaySupported = false;
  bool _isDiscoveringDevices = false;
  // ignore: unused_field
  bool _isAirPlayActive = false;
  bool _isInPictureInPictureMode = false;
  // bool _isAirPlayActive = false; // Removed unused field
  ScreenSharingState _screenSharingState = ScreenSharingState.disconnected;
  double _lastNativeVideoPosition =
      0.0; // Guarda la última posición del video nativo
  Timer? _pairingTimer;
  bool _hasVideoStarted =
      false; // Para controlar si onVideoStart ya fue llamado
  bool _hasVideoEnded = false; // Para controlar si onVideoEnd ya fue llamado

  // Getter para saber si estamos usando el reproductor nativo
  bool get _useNativePlayer => widget.useNativePlayerOnIOS && Platform.isIOS;

  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Timer? _hideControlsTimer;
  StreamSubscription<ScreenSharingState>? _screenSharingStateSubscription;
  StreamSubscription<String>? _screenSharingErrorSubscription;
  ScreenSharingService? _screenSharingService;

  @override
  void initState() {
    super.initState();
    // Inicializar servicio PiP con callback
    PictureInPictureService.initialize();
    PictureInPictureService.setOnPipControlListener(_handlePipControlEvent);

    _initializeVideoPlayer();
    _setupAnimations();
    _checkPictureInPictureSupport();
    _initializeScreenSharing();
    _initializeAirPlay();
    _setupPictureInPictureListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeAirPlay();
    _initializeGoogleCast();
  }

  void _checkPictureInPictureSupport() async {
    final supported =
        await PictureInPictureService.isPictureInPictureSupported();

    // Obtener información de debug en Android
    if (Platform.isAndroid) {
      try {
        await PictureInPictureService.getPictureInPictureInfo();
      } catch (e) {
        debugPrint(
            '[AdvancedVideoPlayer] Error al obtener información de PiP: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isPictureInPictureSupported = supported;
    });
  }

  void _setupPictureInPictureListener() {
    // Escuchar cambios de estado de PiP y eventos de control
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
  }

  void _handlePipControlEvent(String action) {
    if (!mounted) return;

    debugPrint('[AdvancedVideoPlayer] Control PiP recibido: $action');

    // Si es reproductor nativo
    if (widget.useNativePlayerOnIOS && _nativeController != null) {
      switch (action) {
        case 'play':
          _nativeController!.play();
          setState(() => _isPlaying = true);
          _updatePipPlaybackState(true);
          break;
        case 'pause':
          _nativeController!.pause();
          setState(() => _isPlaying = false);
          _updatePipPlaybackState(false);
          break;
        case 'play_pause':
          // Toggle play/pause para controles nativos de Android
          if (_isPlaying) {
            _nativeController!.pause();
            setState(() => _isPlaying = false);
            _updatePipPlaybackState(false);
          } else {
            _nativeController!.play();
            setState(() => _isPlaying = true);
            _updatePipPlaybackState(true);
          }
          break;
        case 'replay10':
          // Para reproductor nativo, puedes implementar seek si está disponible
          break;
        case 'forward10':
          // Para reproductor nativo, puedes implementar seek si está disponible
          break;
      }
      return;
    }

    // Si es reproductor de video_player
    if (_controller != null && _controller!.value.isInitialized) {
      switch (action) {
        case 'play':
          _controller!.play();
          setState(() => _isPlaying = true);
          _updatePipPlaybackState(true);
          break;
        case 'pause':
          _controller!.pause();
          setState(() => _isPlaying = false);
          _updatePipPlaybackState(false);
          break;
        case 'play_pause':
          // Toggle play/pause para controles nativos de Android
          if (_isPlaying) {
            _controller!.pause();
            setState(() => _isPlaying = false);
            _updatePipPlaybackState(false);
          } else {
            _controller!.play();
            setState(() => _isPlaying = true);
            _updatePipPlaybackState(true);
          }
          break;
        case 'replay10':
          final currentPosition = _controller!.value.position;
          final newPosition =
              currentPosition - Duration(seconds: widget.skipDuration);
          _controller!.seekTo(
              newPosition < Duration.zero ? Duration.zero : newPosition);
          break;
        case 'forward10':
          final currentPosition = _controller!.value.position;
          final duration = _controller!.value.duration;
          final newPosition =
              currentPosition + Duration(seconds: widget.skipDuration);
          _controller!.seekTo(newPosition > duration ? duration : newPosition);
          break;
      }
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
      // En caso de error, asumir que está soportado para mostrar el botón
      if (!mounted) return;
      setState(() {
        _isScreenSharingSupported = true;
      });
    }
  }

  void _initializeGoogleCast() async {
    // Google Cast solo está disponible en Android
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await AdvancedVideoPlayerCast.initializeCast();
    } catch (e) {
      debugPrint('[AdvancedVideoPlayer] Error al inicializar Google Cast: $e');
    }
  }

  void _initializeAirPlay() async {
    if (!widget.enableAirPlay) {
      return;
    }

    // AirPlay solo está disponible en iOS
    if (!Platform.isIOS) {
      return;
    }

    try {
      // Verificar si AirPlay está disponible
      const channel = MethodChannel('advanced_video_player');
      await channel.invokeMethod('isAirPlayActive') ?? false;

      if (!mounted) return;
      setState(() {
        _isAirPlaySupported = true;
        // _isAirPlayActive = isActive; // Removed unused field
      });
    } catch (e) {
      // En caso de error, asumir que está soportado para mostrar el botón
      if (!mounted) return;
      setState(() {
        _isAirPlaySupported = true;
      });
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

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Si usamos el reproductor nativo, no inicializamos el VideoPlayerController
      if (_useNativePlayer) {
        // El NativeVideoPlayer se muestra en la vista normal también
        setState(() {
          _isLoading = false;
        });

        // Auto-abrir en fullscreen SI está habilitado
        if (widget.autoEnterFullscreen) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _toggleFullscreen();
            }
          });
        }
        return;
      }

      // Dispose del controller anterior si existe
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.dispose();
      }

      if (widget.isAsset) {
        _controller = VideoPlayerController.asset(widget.videoSource);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoSource),
        );
      }

      await _controller!.initialize();

      // Verificar que se inicializó correctamente
      if (!_controller!.value.isInitialized) {
        throw Exception('El video no se pudo inicializar correctamente');
      }

      // Configurar el reproductor nativo para PiP
      await _setupNativePlayer();

      // IMPORTANTE: Pausar el video en la vista preview (no reproducir automáticamente)
      await _controller!.pause();

      _controller!.addListener(_videoListener);

      setState(() {
        _isLoading = false;
        _isPlaying = false; // Siempre pausado en vista preview
      });

      _showControlsTemporarily();

      // Auto entrar en pantalla completa si está habilitado
      if (widget.autoEnterFullscreen && !_isFullscreen) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _toggleFullscreen();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      widget.onError?.call(_errorMessage);
    }
  }

  /// Configura el reproductor nativo para Picture-in-Picture
  Future<void> _setupNativePlayer() async {
    try {
      const platform = MethodChannel('advanced_video_player');
      await platform.invokeMethod('setUrl', {
        'url': widget.videoSource,
      });
    } catch (e) {
      debugPrint(
          '[AdvancedVideoPlayer] Error al configurar el reproductor nativo: $e');
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    if (_controller!.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage =
            _controller!.value.errorDescription ?? 'Error desconocido';
      });
      widget.onError?.call(_errorMessage);
      return;
    }

    // Verificar si el video terminó (con margen de tolerancia de 500ms)
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    final isNearEnd = duration.inMilliseconds > 0 &&
        (position.inMilliseconds >= duration.inMilliseconds - 500);

    if (isNearEnd && _isPlaying && !_hasVideoEnded) {
      setState(() {
        _isPlaying = false;
        _hasVideoEnded = true;
      });
      _updatePipPlaybackState(false);
      debugPrint(
          '[AdvancedVideoPlayer] 🏁 Video ended - Position: ${position.inSeconds}s, Duration: ${duration.inSeconds}s');
      widget.onVideoEnd?.call();
      return;
    }

    final newPlayingState = _controller!.value.isPlaying;

    // Detectar si el video está reproduciéndose y pasó de los primeros segundos
    if (newPlayingState && !_hasVideoStarted && position.inSeconds >= 1) {
      _hasVideoStarted = true;
      debugPrint(
          '[AdvancedVideoPlayer] ✨ Video started for first time (auto-detected at ${position.inSeconds}s)');
      widget.onVideoStart?.call();
    }

    if (_isPlaying != newPlayingState) {
      setState(() {
        _isPlaying = newPlayingState;
      });
      _updatePipPlaybackState(newPlayingState);

      // Callbacks basados en el cambio de estado
      if (newPlayingState) {
        // El video comenzó a reproducirse
        debugPrint('[AdvancedVideoPlayer] 🎬 Video playing');
        widget.onVideoPlay?.call();

        // Si es la primera vez, llamar onVideoStart
        if (!_hasVideoStarted) {
          _hasVideoStarted = true;
          debugPrint('[AdvancedVideoPlayer] ✨ Video started for first time');
          widget.onVideoStart?.call();
        }
      } else {
        // El video se pausó
        debugPrint('[AdvancedVideoPlayer] ⏸️ Video paused');
        widget.onVideoPause?.call();
      }
    }
  }

  void _updatePipPlaybackState(bool isPlaying) {
    // Solo actualizar en Android cuando está en modo PiP
    if (Platform.isAndroid && _isInPictureInPictureMode) {
      PictureInPictureService.updatePlaybackState(isPlaying: isPlaying);
    }
  }

  void _togglePlayPause() async {
    if (_useNativePlayer) {
      // Modo nativo
      if (_nativeController == null) {
        return;
      }

      setState(() {
        if (_isPlaying) {
          _nativeController!.pause();
          _isPlaying = false;
          _updatePipPlaybackState(false);
          // Callback de pausa (solo para reproductor nativo)
          widget.onVideoPause?.call();
        } else {
          _nativeController!.play();
          _isPlaying = true;
          _updatePipPlaybackState(true);
          // Callback de play (solo para reproductor nativo)
          widget.onVideoPlay?.call();
          // Callback de inicio (solo la primera vez y solo para reproductor nativo)
          if (!_hasVideoStarted) {
            _hasVideoStarted = true;
            widget.onVideoStart?.call();
          }
        }
      });
      _showControlsTemporarily();
      return;
    }

    // Modo estándar
    if (_controller == null || !_controller!.value.isInitialized) {
      _initializeVideoPlayer();
      return;
    }

    // IMPORTANTE: En vista preview SIEMPRE ir a pantalla completa
    // No permitir reproducción en la vista principal, solo en fullscreen y PiP
    if (!_isFullscreen) {
      // Entrar en pantalla completa y reproducir automáticamente
      _enterFullscreenAndPlay();
      return;
    }

    // Comportamiento normal solo cuando estamos en pantalla completa
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _isPlaying = false;
        _updatePipPlaybackState(false);
      } else {
        _controller!.play();
        _isPlaying = true;
        _updatePipPlaybackState(true);
      }
    });
    _showControlsTemporarily();
  }

  void _skipBackward() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newPosition =
        _controller!.value.position - Duration(seconds: widget.skipDuration);
    _controller!
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _showControlsTemporarily();
  }

  void _skipForward() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newPosition =
        _controller!.value.position + Duration(seconds: widget.skipDuration);
    final maxPosition = _controller!.value.duration;
    _controller!.seekTo(newPosition > maxPosition ? maxPosition : newPosition);
    _showControlsTemporarily();
  }

  void _toggleFullscreen() async {
    // Si estamos usando el reproductor nativo, abrir página fullscreen con NativeVideoPlayer
    if (_useNativePlayer) {
      // Guardar la posición actual si hay un controller
      if (_nativeController != null) {
        _lastNativeVideoPosition =
            await _nativeController!.getCurrentPosition();
      }

      if (!mounted) return;

      // Navegar a fullscreen y esperar el resultado (posición al cerrar)
      final navigator = Navigator.of(context);
      final result = await navigator.push<double>(
        MaterialPageRoute(
          builder: (context) => _NativeFullscreenPage(
            url: widget.videoSource,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            enablePictureInPicture: widget.enablePictureInPicture,
            initialPosition: _lastNativeVideoPosition,
            onVideoEnd: widget.onVideoEnd,
            onVideoStart: widget.onVideoStart,
            onVideoPause: widget.onVideoPause,
            onVideoPlay: widget.onVideoPlay,
          ),
          fullscreenDialog: true,
        ),
      );

      // Si se devuelve una posición al cerrar, guardarla
      if (result != null) {
        _lastNativeVideoPosition = result;
      }

      // Pausar el video cuando se vuelve a la vista principal
      if (_nativeController != null) {
        await _nativeController!.pause();
        setState(() {
          _isPlaying = false;
        });
        debugPrint(
            '[AdvancedVideoPlayer] ⏸️ Video pausado al volver a vista principal');
      }

      return;
    }

    if (!_isFullscreen) {
      // Navegar a pantalla completa
      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => FullscreenVideoPage(
            controller: _controller!,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            skipDuration: widget.skipDuration,
            enablePictureInPicture: widget.enablePictureInPicture,
            enableScreenSharing: widget.enableScreenSharing,
            enableAirPlay: widget.enableAirPlay,
            videoTitle: widget.videoTitle,
            videoDescription: widget.videoDescription,
            onVideoEnd: widget.onVideoEnd,
            onVideoStart: widget.onVideoStart,
            onVideoPause: widget.onVideoPause,
            onVideoPlay: widget.onVideoPlay,
          ),
          fullscreenDialog: true,
        ),
      );

      // Al regresar de fullscreen, pausar el video automáticamente
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.pause();
        setState(() {
          _isPlaying = false;
        });
        // El callback de pausa se llamará automáticamente por el listener
      }
    }
    _showControlsTemporarily();
  }

  void _enterFullscreenAndPlay() async {
    // Primero reproducir el video
    setState(() {
      _isPlaying = true;
    });
    _controller!.play();

    if (!mounted) return;

    // Luego entrar en pantalla completa
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPage(
          controller: _controller!,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          skipDuration: widget.skipDuration,
          enablePictureInPicture: widget.enablePictureInPicture,
          enableScreenSharing: widget.enableScreenSharing,
          enableAirPlay: widget.enableAirPlay,
          videoTitle: widget.videoTitle,
          videoDescription: widget.videoDescription,
          onVideoEnd: widget.onVideoEnd,
          onVideoStart: widget.onVideoStart,
          onVideoPause: widget.onVideoPause,
          onVideoPlay: widget.onVideoPlay,
        ),
        fullscreenDialog: true,
      ),
    );

    // Al regresar de fullscreen, pausar el video automáticamente
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
      // El callback de pausa se llamará automáticamente por el listener
    }
  }

  void _enterPictureInPicture() async {
    // Si estamos usando el reproductor nativo
    if (_useNativePlayer) {
      if (_nativeController == null) {
        return;
      }

      try {
        await _nativeController!.startPiP();

        // Esperar un momento para que PiP se active
        await Future.delayed(const Duration(milliseconds: 500));

        // Minimizar la app al background (ir al home) - Solo en iOS
        if (mounted && Platform.isIOS) {
          SystemNavigator.pop();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activando PiP: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Modo estándar
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (!_isPictureInPictureSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Picture-in-Picture no es compatible con este dispositivo'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final aspectRatio = _controller!.value.aspectRatio;
      // Usar dimensiones más apropiadas para PiP de video
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showControlsTemporarily() {
    if (_isPlaying) {
      setState(() {
        _showControls = true;
      });
      _controlsAnimationController.forward();

      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
          _controlsAnimationController.reverse();
        }
      });
    } else {
      setState(() {
        _showControls = true;
      });
      _controlsAnimationController.forward();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _onTapVideo() {
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
    if (_hasError) {
      return _buildErrorWidget();
    }

    final videoWidget = GestureDetector(
      onTap: _onTapVideo,
      child: Container(
        decoration: BoxDecoration(
          borderRadius:
              _isFullscreen ? BorderRadius.zero : BorderRadius.circular(12),
          boxShadow: _isFullscreen
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius:
              _isFullscreen ? BorderRadius.zero : BorderRadius.circular(12),
          child: _isFullscreen
              ? _buildFullscreenVideo()
              : SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: _buildVideoStack(),
                ),
        ),
      ),
    );

    // Si está en pantalla completa, mostrar como overlay
    if (_isFullscreen) {
      return Material(
        color: Colors.black,
        child: Stack(
          children: [
            videoWidget,
            // Botón de salida de pantalla completa
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    child: _buildControlButton(
                      icon: Icons.fullscreen_exit,
                      onPressed: _toggleFullscreen,
                      tooltip: 'Salir de pantalla completa',
                      isPictureInPicture: _isInPictureInPictureMode,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return videoWidget;
  }

  Widget _buildVideoStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo: Preview/thumbnail o gradiente
        if (widget.previewImageUrl != null &&
            widget.previewImageUrl!.isNotEmpty)
          Image.network(
            widget.previewImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.primaryColor, widget.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

        // Video - Reproductor nativo (iOS) o estándar (Android)
        if (_useNativePlayer && _isPlaying)
          // Reproductor nativo con eventos PiP - solo cuando está reproduciendo
          NativeVideoPlayer(
            url: widget.videoSource,
            autoplay: true,
            onViewCreated: (controller) {
              setState(() {
                _nativeController = controller;
                _isLoading = false;
                _isPictureInPictureSupported = true;
              });
            },
            onPipStarted: () {
              debugPrint(
                  '[AdvancedVideoPlayer] ✅ PiP iniciado desde vista normal');
              setState(() {
                _isInPictureInPictureMode = true;
              });
            },
            onPipStopped: () {
              debugPrint(
                  '[AdvancedVideoPlayer] ⏹️ PiP detenido desde vista normal');
              setState(() {
                _isInPictureInPictureMode = false;
              });
            },
            onPipRestoreToFullscreen: () {
              debugPrint(
                  '[AdvancedVideoPlayer] 🎬 PiP cerrado - continuando en la MISMA vista');

              // NO navegar a ningún lado, el video continúa en la misma vista
              setState(() {
                _isInPictureInPictureMode = false;
              });
            },
          )
        // Reproductor nativo invisible para inicializar el controller cuando no está reproduciendo
        else if (_useNativePlayer && !_isPlaying)
          // Reproductor nativo invisible para mantener el controller disponible
          Opacity(
            opacity: 0.0,
            child: NativeVideoPlayer(
              url: widget.videoSource,
              autoplay: false,
              onViewCreated: (controller) {
                if (_nativeController == null) {
                  setState(() {
                    _nativeController = controller;
                    _isPictureInPictureSupported = true;
                  });
                }
              },
              onPipStarted: () {
                debugPrint(
                    '[AdvancedVideoPlayer] ✅ PiP iniciado desde vista normal (invisible)');
                setState(() {
                  _isInPictureInPictureMode = true;
                });
              },
              onPipStopped: () {
                debugPrint(
                    '[AdvancedVideoPlayer] ⏹️ PiP detenido desde vista normal (invisible)');
                setState(() {
                  _isInPictureInPictureMode = false;
                });
              },
              onPipRestoreToFullscreen: () {
                debugPrint(
                    '[AdvancedVideoPlayer] 🎬 PiP cerrado - continuando en la MISMA vista (invisible)');

                // NO navegar a ningún lado, el video continúa en la misma vista
                setState(() {
                  _isInPictureInPictureMode = false;
                });
              },
            ),
          )
        // Reproductor estándar para Android
        else if (!_isLoading &&
            _controller != null &&
            _controller!.value.isInitialized &&
            // No mostrar VideoPlayer si hay preview disponible
            (widget.previewImageUrl == null || widget.previewImageUrl!.isEmpty))
          // Reproductor estándar para Android (solo cuando está inicializado y no hay preview)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

        // Overlay para reproductor nativo con botón de play
        if (_useNativePlayer && !_isPlaying)
          GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: widget.playButton ??
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.primaryColor.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 255, 0, 0)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
          ),

        // Indicador de carga cuando está inicializando (solo si no hay preview)
        if (!_useNativePlayer &&
            _controller != null &&
            !_controller!.value.isInitialized &&
            (widget.previewImageUrl == null || widget.previewImageUrl!.isEmpty))
          Container(
            color: Colors.black.withOpacity(0.6),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Cargando video...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Overlay sutil sobre el preview (estilo Disney+)
        if (!_isLoading &&
            !_useNativePlayer &&
            _controller != null &&
            _controller!.value.isInitialized)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

        // Controles overlay
        if (!_isLoading &&
            (!_useNativePlayer &&
                _controller != null &&
                _controller!.value.isInitialized))
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? 1.0 : 0.0,
                child: _buildControlsOverlay(),
              );
            },
          ),

        // Overlay de Picture-in-Picture cuando está activo
        if (_isInPictureInPictureMode) ...[
          // Debug: Mostrar estado actual
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PiP: $_isInPictureInPictureMode',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFullscreenVideo() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video en pantalla completa - Nativo o estándar
        if (_useNativePlayer)
          // Reproductor nativo
          NativeVideoPlayer(
            url: widget.videoSource,
            autoplay: true,
            onViewCreated: (controller) {
              if (_nativeController == null) {
                setState(() {
                  _nativeController = controller;
                  _isPlaying = true;
                  _isLoading = false;
                  _isPictureInPictureSupported = true;
                });
              }
            },
            onPipStarted: () {
              debugPrint(
                  '[AdvancedVideoPlayer] ✅ PiP iniciado - actualizando estado');
              setState(() {
                _isInPictureInPictureMode = true;
              });
            },
            onPipStopped: () {
              debugPrint(
                  '[AdvancedVideoPlayer] ⏹️ PiP detenido - actualizando estado');
              setState(() {
                _isInPictureInPictureMode = false;
              });
            },
            onPipRestoreToFullscreen: () {
              debugPrint(
                  '[AdvancedVideoPlayer] 🎬 PiP cerrado en fullscreen - continuando en la MISMA vista');

              // NO navegar a ningún lado, solo cerrar el PiP y continuar
              setState(() {
                _isInPictureInPictureMode = false;
                _showControls = true;
              });

              // Reiniciar el timer de ocultar controles
              _hideControlsTimer?.cancel();
              _startHideControlsTimer();
            },
          )
        else if (_isLoading ||
            _controller == null ||
            !_controller!.value.isInitialized)
          _buildLoadingWidget()
        else
          // Video con aspect ratio correcto
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

        // Controles overlay para pantalla completa
        if (!_isLoading &&
            (_useNativePlayer
                ? _nativeController != null
                : (_controller != null && _controller!.value.isInitialized)))
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? 1.0 : 0.0,
                child: _buildFullscreenControlsOverlay(),
              );
            },
          ),

        // Overlay de Picture-in-Picture cuando está activo en pantalla completa
        if (_isInPictureInPictureMode) ...[
          // Debug: Mostrar estado actual
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PiP Fullscreen: $_isInPictureInPictureMode',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen de preview si está disponible, sino gradiente
        if (widget.previewImageUrl != null &&
            widget.previewImageUrl!.isNotEmpty)
          Image.network(
            widget.previewImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Si falla la carga de la imagen, mostrar gradiente
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.primaryColor, widget.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

        // Overlay oscuro para que el indicador sea visible
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.5),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),

        // Indicador de carga
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Cargando video...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retryVideoLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    // En modo Picture-in-Picture, no mostrar ningún control
    if (_isInPictureInPictureMode) {
      return const SizedBox.shrink();
    }

    // Vista normal con gradiente
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPreviewCenterControls(),
        ],
      ),
    );
  }

  Widget _buildFullscreenControlsOverlay() {
    // En modo Picture-in-Picture, no mostrar ningún control
    if (_isInPictureInPictureMode) {
      return const SizedBox.shrink();
    }

    return Container(
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
      child: Column(
        children: [
          // Barra superior (solo botón de pantalla completa)
          _buildFullscreenTopBar(),
          const Spacer(),
          // Controles centrales
          _buildCenterControls(),
          const Spacer(),
          // Barra inferior
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildFullscreenTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.enableAirPlay && _isAirPlaySupported)
              AirPlayStatusButton(
                width: 20,
                height: 20,
                onAirPlayStateChanged: (isActive) {
                  if (mounted) {
                    setState(() {
                      _isAirPlayActive = isActive;
                    });
                  }
                },
              ),
            if (Platform.isIOS && widget.enableAirPlay && _isAirPlaySupported)
              const SizedBox(width: 6),
            if (Platform.isAndroid &&
                widget.enableScreenSharing &&
                _isScreenSharingSupported)
              _buildControlButton(
                icon: _screenSharingState == ScreenSharingState.connected
                    ? Icons.cast_connected
                    : _isDiscoveringDevices
                        ? Icons.search
                        : Icons.cast,
                onPressed: _screenSharingState == ScreenSharingState.connected
                    ? _disconnectScreenSharing
                    : _isDiscoveringDevices
                        ? () {}
                        : _showScreenSharingDialog,
                tooltip: _screenSharingState == ScreenSharingState.connected
                    ? 'Desconectar compartir pantalla'
                    : _isDiscoveringDevices
                        ? 'Buscando dispositivos...'
                        : 'Compartir pantalla',
                size: 40,
                isPictureInPicture: _isInPictureInPictureMode,
              ),
            if (widget.enableScreenSharing && _isScreenSharingSupported)
              const SizedBox(width: 6),
            if (widget.enablePictureInPicture)
              _buildControlButton(
                icon: Icons.picture_in_picture_alt,
                onPressed: _enterPictureInPicture,
                tooltip: 'Picture-in-Picture',
                size: 40,
                isPictureInPicture: _isInPictureInPictureMode,
              ),
            if (widget.enablePictureInPicture) const SizedBox(width: 6),
            _buildControlButton(
              icon: Icons.fullscreen_exit,
              onPressed: _toggleFullscreen,
              tooltip: 'Salir de pantalla completa',
              size: 40,
              isPictureInPicture: _isInPictureInPictureMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.replay_10,
          onPressed: _skipBackward,
          tooltip: 'Retroceder ${widget.skipDuration}s',
          size: 40,
          isPictureInPicture: _isInPictureInPictureMode,
        ),
        _buildControlButton(
          icon:
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          onPressed: _togglePlayPause,
          tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
          size: 60,
          isPrimary: true,
          isPictureInPicture: _isInPictureInPictureMode,
        ),
        _buildControlButton(
          icon: Icons.forward_10,
          onPressed: _skipForward,
          tooltip: 'Avanzar ${widget.skipDuration}s',
          size: 40,
          isPictureInPicture: _isInPictureInPictureMode,
        ),
      ],
    );
  }

  Widget _buildPreviewCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.play_circle_filled,
          onPressed: _togglePlayPause,
          tooltip: 'Reproducir en pantalla completa',
          size: 60,
          isPrimary: true,
          isPictureInPicture: _isInPictureInPictureMode,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // _buildProgressBar(),
          const SizedBox(height: 12),
          // Tiempo y duración
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_controller?.value.position ?? Duration.zero),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_controller?.value.duration ?? Duration.zero),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildProgressBar() {
  //   return LayoutBuilder(
  //     builder: (context, constraints) {
  //       return GestureDetector(
  //         onTapDown: (details) {
  //           final box = context.findRenderObject() as RenderBox;
  //           final localPosition = box.globalToLocal(details.globalPosition);
  //           final width = box.size.width;
  //           final percentage = (localPosition.dx.clamp(0, width)) / width;

  //           if (_controller != null) {
  //             final newPosition = Duration(
  //               milliseconds:
  //                   (_controller!.value.duration.inMilliseconds * percentage)
  //                       .round(),
  //             );
  //             _controller!.seekTo(newPosition);
  //           }
  //         },
  //         child: Container(
  //           height: 4,
  //           decoration: BoxDecoration(
  //             borderRadius: BorderRadius.circular(2),
  //             color: Colors.white.withOpacity(0.3),
  //           ),
  //           child: Row(
  //             children: [
  //               // Progreso reproducido
  //               Expanded(
  //                 flex: (_getProgressWidthFactor() * 100).round(),
  //                 child: Container(
  //                   height: 4,
  //                   decoration: BoxDecoration(
  //                     borderRadius: BorderRadius.circular(2),
  //                     gradient: LinearGradient(
  //                       colors: [widget.primaryColor, widget.secondaryColor],
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               // Espacio restante
  //               Expanded(
  //                 flex: ((1.0 - _getProgressWidthFactor()) * 100).round(),
  //                 child: const SizedBox(height: 4),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 32,
    bool isPrimary = false,
    bool isPictureInPicture = false,
  }) {
    // Diseño nativo para Picture-in-Picture
    if (isPictureInPicture) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(
            icon,
            size: size,
            color: Colors.white,
          ),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
        ),
      );
    }

    // Diseño nativo para botones normales
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(
          icon,
          size: size,
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.9),
        ),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isPrimary
              ? Colors.black.withOpacity(0.6)
              : Colors.black.withOpacity(0.4),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          // padding: EdgeInsets.all(size * 0.2),
        ),
      ),
    );
  }

  void _retryVideoLoad() {
    _initializeVideoPlayer();
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
    setState(() {
      _isDiscoveringDevices = true;
    });

    try {
      final devices = await _screenSharingService!.discoverDevices();
      if (!mounted) return;
      setState(() {
        _isDiscoveringDevices = false;
      });

      // Siempre mostrar el modal, incluso si no hay dispositivos
      _showDeviceSelectionDialog(devices);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDiscoveringDevices = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error buscando dispositivos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeviceSelectionDialog(List<Map<String, dynamic>> devices) {
    // Ya no necesitamos normalizar porque discoverDevices() devuelve el tipo correcto

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
                'Conectar a TV',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            // Message when no devices found
            if (devices.isEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No se encontraron dispositivos Chromecast en la red. Usa el código de vinculación para conectar tu TV.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Device options
            ...devices.map((device) {
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
        videoUrl: widget.videoSource,
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
    _pairingTimer?.cancel();
    _controlsAnimationController.dispose();
    _controller?.dispose();
    _nativeController?.dispose();
    _screenSharingStateSubscription?.cancel();
    _screenSharingErrorSubscription?.cancel();
    _screenSharingService?.dispose();
    // Restaurar orientación y UI cuando se dispone el widget
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }
}

/// Página de pantalla completa para el reproductor nativo
class _NativeFullscreenPage extends StatefulWidget {
  final String url;
  final Color primaryColor;
  final Color secondaryColor;
  final bool enablePictureInPicture;
  final double initialPosition; // Posición inicial del video en segundos
  final VoidCallback? onVideoEnd;
  final VoidCallback? onVideoStart;
  final VoidCallback? onVideoPause;
  final VoidCallback? onVideoPlay;

  const _NativeFullscreenPage({
    required this.url,
    required this.primaryColor,
    required this.secondaryColor,
    required this.enablePictureInPicture,
    this.initialPosition = 0.0, // Por defecto inicia en 0
    this.onVideoEnd,
    this.onVideoStart,
    this.onVideoPause,
    this.onVideoPlay,
  });

  @override
  State<_NativeFullscreenPage> createState() => _NativeFullscreenPageState();
}

class _NativeFullscreenPageState extends State<_NativeFullscreenPage> {
  NativeVideoPlayerController? _controller;
  bool _showControls = true;
  bool _isPlaying = true;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  double _currentPosition = 0.0;
  double _duration = 0.0;
  bool _isDragging = false;
  bool _isBuffering = true; // Inicia como true para mostrar loading inicial

  // Para debounce de los botones de avanzar/retroceder
  Timer? _seekDebounceTimer;
  bool _isSeeking = false;
  bool _hasVideoStarted =
      false; // Para controlar si onVideoStart ya fue llamado
  bool _hasVideoEnded = false; // Para controlar si onVideoEnd ya fue llamado

  @override
  void initState() {
    super.initState();
    // Configurar pantalla completa
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideControlsTimer();
    _startProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_controller != null && !_isDragging && !_isSeeking) {
        final position = await _controller!.getCurrentPosition();
        final duration = await _controller!.getDuration();
        final buffering = await _controller!.isBuffering();

        // Verificar si el video terminó (con margen de tolerancia de 500ms)
        final isNearEnd = duration > 0 && (position >= duration - 0.5);

        if (isNearEnd && _isPlaying && !_hasVideoEnded) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _hasVideoEnded = true;
            });
            debugPrint(
                '[NativeFullscreenPage] 🏁 Video ended - Position: ${position.toStringAsFixed(1)}s, Duration: ${duration.toStringAsFixed(1)}s');
            widget.onVideoEnd?.call();
          }
        }

        // Detectar si el video está reproduciéndose y pasó de los primeros segundos
        if (_isPlaying && !_hasVideoStarted && position >= 1.0) {
          _hasVideoStarted = true;
          debugPrint(
              '[NativeFullscreenPage] ✨ Video started for first time (auto-detected at ${position.toStringAsFixed(1)}s)');
          widget.onVideoStart?.call();
        }

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _duration = duration;
            _isBuffering = buffering;
          });
        }
      }
    });
  }

  /// Maneja el seek con debounce para permitir múltiples toques rápidos
  void _performDebouncedSeek(double offsetSeconds) {
    // Cancelar cualquier seek pendiente
    _seekDebounceTimer?.cancel();

    // Actualizar la posición visual inmediatamente (acumulando los offsets)
    setState(() {
      _currentPosition =
          (_currentPosition + offsetSeconds).clamp(0.0, _duration);
      _isSeeking = true;
    });

    // Programar el seek real después de 150ms de inactividad
    _seekDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
      if (_controller != null) {
        // Usar la posición visual acumulada (no obtener del video)
        final targetPosition = _currentPosition;

        // Ejecutar el seek a la posición visual acumulada
        await _controller!.seek(targetPosition);

        // Actualizar el estado
        if (mounted) {
          setState(() {
            _isSeeking = false;
          });
        }

        _startHideControlsTimer();
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          // La posición se devuelve en el Navigator.pop del botón de atrás
          // Este callback se ejecuta después del pop
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Reproductor nativo
            NativeVideoPlayer(
              url: widget.url,
              autoplay: true,
              onViewCreated: (controller) async {
                setState(() {
                  _controller = controller;
                });

                // Sincronizar el estado de reproducción con el reproductor nativo
                // Esto es especialmente importante cuando se vuelve desde PIP
                try {
                  final playing = await controller.isPlaying();
                  if (mounted) {
                    setState(() {
                      _isPlaying = playing;
                    });
                    debugPrint(
                        '[NativeFullscreenPage] 🎵 Estado de reproducción sincronizado: $_isPlaying');
                  }
                } catch (e) {
                  debugPrint(
                      '[NativeFullscreenPage] ⚠️ Error al sincronizar estado de reproducción: $e');
                }

                // Si hay una posición inicial, hacer seek a esa posición
                if (widget.initialPosition > 0) {
                  await Future.delayed(const Duration(
                      milliseconds: 500)); // Esperar a que el video cargue
                  await controller.seek(widget.initialPosition);
                  setState(() {
                    _currentPosition = widget.initialPosition;
                    _isBuffering = true; // Mostrar loading mientras busca
                  });
                }
              },
              onPipStarted: () {
                debugPrint('[NativeFullscreenPage] ✅ PiP iniciado');
              },
              onPipStopped: () async {
                debugPrint('[NativeFullscreenPage] ⏹️ PiP detenido');
                // Sincronizar el estado de reproducción después de cerrar PIP
                if (_controller != null) {
                  try {
                    final playing = await _controller!.isPlaying();
                    if (mounted) {
                      setState(() {
                        _isPlaying = playing;
                      });
                      debugPrint(
                          '[NativeFullscreenPage] 🎵 Estado sincronizado después de PIP: $_isPlaying');
                    }
                  } catch (e) {
                    debugPrint(
                        '[NativeFullscreenPage] ⚠️ Error al sincronizar después de PIP: $e');
                  }
                }
              },
              onPipRestoreToFullscreen: () async {
                debugPrint(
                    '[NativeFullscreenPage] 🎬 Restaurando a fullscreen desde PiP');
                // Ya estamos en fullscreen, no necesitamos navegar
                // Pero sí necesitamos sincronizar el estado de reproducción
                if (_controller != null) {
                  try {
                    final playing = await _controller!.isPlaying();
                    if (mounted) {
                      setState(() {
                        _isPlaying = playing;
                      });
                      debugPrint(
                          '[NativeFullscreenPage] 🎵 Estado sincronizado al restaurar desde PIP: $_isPlaying');
                    }
                  } catch (e) {
                    debugPrint(
                        '[NativeFullscreenPage] ⚠️ Error al sincronizar al restaurar desde PIP: $e');
                  }
                }
              },
            ),

            // Capa invisible para capturar toques
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

            // Indicador de loading/buffering (siempre visible cuando está cargando)
            if (_isBuffering)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.primaryColor),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cargando...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Controles overlay
            if (_showControls)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header - Botón atrás
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 28),
                              onPressed: () async {
                                // Obtener posición actual y devolverla al cerrar
                                final navigator = Navigator.of(context);
                                double currentPos = _currentPosition;
                                if (_controller != null) {
                                  currentPos =
                                      await _controller!.getCurrentPosition();
                                }
                                if (mounted) {
                                  navigator.pop(currentPos);
                                }
                              },
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                // Botón AirPlay nativo
                                if (Platform.isIOS)
                                  const AirPlayButton(
                                    width: 40,
                                    height: 40,
                                  ),
                                if (Platform.isIOS) const SizedBox(width: 8),
                                // Botón PiP
                                if (!Platform.isIOS &&
                                    widget.enablePictureInPicture)
                                  _buildActionButton(
                                    icon: Icons.picture_in_picture_alt,
                                    label: '',
                                    onPressed: () async {
                                      if (_controller != null) {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        try {
                                          await _controller!.startPiP();
                                          await Future.delayed(const Duration(
                                              milliseconds: 500));

                                          if (mounted && Platform.isIOS) {
                                            SystemNavigator.pop();
                                          }
                                        } catch (e) {
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Controles centrales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Retroceder 10 segundos
                          _buildCircularButton(
                            icon: Icons.replay_10,
                            onPressed: () {
                              if (_controller != null) {
                                _performDebouncedSeek(-10.0);
                              }
                            },
                          ),
                          const SizedBox(width: 40),
                          // Play/Pause
                          _buildCircularButton(
                            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 70,
                            onPressed: () async {
                              if (_controller != null) {
                                // Primero sincronizar con el estado real del reproductor
                                try {
                                  final actuallyPlaying =
                                      await _controller!.isPlaying();
                                  // Actualizar el estado local con el estado real
                                  if (mounted) {
                                    setState(() {
                                      _isPlaying = actuallyPlaying;
                                    });
                                  }
                                } catch (e) {
                                  debugPrint(
                                      '[NativeFullscreenPage] ⚠️ Error al sincronizar estado antes de toggle: $e');
                                }

                                // Ahora hacer el toggle con el estado sincronizado
                                if (_isPlaying) {
                                  _controller!.pause();
                                  // Callback de pausa (solo para reproductor nativo iOS)
                                  widget.onVideoPause?.call();
                                } else {
                                  _controller!.play();
                                  // Callback de play (solo para reproductor nativo iOS)
                                  widget.onVideoPlay?.call();
                                  // Callback de inicio (solo la primera vez y solo para reproductor nativo iOS)
                                  if (!_hasVideoStarted) {
                                    _hasVideoStarted = true;
                                    widget.onVideoStart?.call();
                                  }
                                }
                                setState(() {
                                  _isPlaying = !_isPlaying;
                                });
                                _startHideControlsTimer();
                              }
                            },
                          ),
                          const SizedBox(width: 40),
                          // Avanzar 10 segundos
                          _buildCircularButton(
                            icon: Icons.forward_10,
                            onPressed: () {
                              if (_controller != null) {
                                _performDebouncedSeek(10.0);
                              }
                            },
                          ),
                        ],
                      ),

                      // Footer - Barra de progreso
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Barra de progreso arrastrable
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8.0),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16.0),
                                activeTrackColor: widget.primaryColor,
                                inactiveTrackColor:
                                    Colors.white.withOpacity(0.3),
                                thumbColor: Colors.white,
                                overlayColor:
                                    widget.primaryColor.withOpacity(0.3),
                              ),
                              child: Slider(
                                value: _duration > 0
                                    ? (_currentPosition / _duration)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                onChanged: (value) {
                                  setState(() {
                                    _isDragging = true;
                                    _currentPosition = value * _duration;
                                  });
                                },
                                onChangeEnd: (value) async {
                                  setState(() {
                                    _isDragging = false;
                                    _isBuffering =
                                        true; // Mostrar loading al hacer seek
                                  });
                                  if (_controller != null) {
                                    await _controller!.seek(value * _duration);
                                    // Dar tiempo para que el player actualice su estado
                                    await Future.delayed(
                                        const Duration(milliseconds: 300));
                                    // El timer actualizará _isBuffering automáticamente
                                  }
                                  _startHideControlsTimer();
                                },
                              ),
                            ),
                            // Indicadores de tiempo
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_currentPosition),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: size * 0.5,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '0:00';
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _controller?.dispose();
    // Restaurar orientación
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}

/// Clase estática para métodos de Google Cast
class AdvancedVideoPlayerCast {
  static const _channel = MethodChannel('advanced_video_player');

  /// Inicializa el contexto de Cast
  static Future<void> initializeCast() async =>
      _channel.invokeMethod('initializeCast');

  /// Envía el video al dispositivo Cast conectado
  static Future<void> castVideo(String url) async =>
      _channel.invokeMethod('castVideo', {'url': url});

  /// Abre el Media Route Chooser Dialog nativo
  static Future<void> showCastDialog() async =>
      _channel.invokeMethod('showCastDialog');
}
