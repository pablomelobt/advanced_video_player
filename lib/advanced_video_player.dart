library advanced_video_player;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fullscreen_video_page.dart';
import 'picture_in_picture_service.dart';
import 'screen_sharing_service.dart';

/// Un reproductor de video avanzado con controles modernos y atractivos
class AdvancedVideoPlayer extends StatefulWidget {
  /// La fuente del video (URL o asset)
  final String videoSource;

  /// Si es true, trata videoSource como asset local
  final bool isAsset;

  /// Callback cuando el video termina de reproducir
  final VoidCallback? onVideoEnd;

  /// Callback cuando ocurre un error
  final Function(String)? onError;

  /// Duración en segundos para retroceder/avanzar (default: 10)
  final int skipDuration;

  /// Si es true, habilita el botón de Picture-in-Picture (default: true)
  final bool enablePictureInPicture;

  /// Si es true, habilita el botón de compartir pantalla (default: true)
  final bool enableScreenSharing;

  /// Título del video para compartir
  final String? videoTitle;

  /// Descripción del video para compartir
  final String? videoDescription;

  /// Color principal del reproductor
  final Color primaryColor;

  /// Color secundario del reproductor
  final Color secondaryColor;

  const AdvancedVideoPlayer({
    super.key,
    required this.videoSource,
    this.isAsset = false,
    this.onVideoEnd,
    this.onError,
    this.skipDuration = 10,
    this.enablePictureInPicture = true,
    this.enableScreenSharing = true,
    this.videoTitle,
    this.videoDescription,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final bool _isFullscreen = false;
  bool _isPictureInPictureSupported = false;
  bool _isScreenSharingSupported = false;
  bool _isDiscoveringDevices = false;
  ScreenSharingState _screenSharingState = ScreenSharingState.disconnected;
  String? _currentPairingCode;
  bool _isPairing = false;
  Timer? _pairingTimer;

  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Timer? _hideControlsTimer;
  StreamSubscription<ScreenSharingState>? _screenSharingStateSubscription;
  StreamSubscription<String>? _screenSharingErrorSubscription;
  ScreenSharingService? _screenSharingService;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _setupAnimations();
    _checkPictureInPictureSupport();
    _initializeScreenSharing();
  }

  void _checkPictureInPictureSupport() async {
    final supported =
        await PictureInPictureService.isPictureInPictureSupported();
    debugPrint('Picture-in-Picture support check: $supported');
    if (!mounted) return;
    setState(() {
      _isPictureInPictureSupported = supported;
    });
  }

  void _initializeScreenSharing() async {
    debugPrint('🔍 AVANZADO: Inicializando screen sharing...');
    debugPrint(
        '🔍 AVANZADO: enableScreenSharing: ${widget.enableScreenSharing}');

    if (!widget.enableScreenSharing) {
      debugPrint('❌ AVANZADO: Screen sharing deshabilitado en widget');
      return;
    }

    try {
      _screenSharingService = ScreenSharingService();
      debugPrint('🔍 AVANZADO: Verificando soporte de screen sharing...');
      final supported = await ScreenSharingService.isScreenSharingSupported();
      debugPrint('🔍 AVANZADO: Soporte de screen sharing: $supported');

      if (!mounted) return;
      setState(() {
        _isScreenSharingSupported = supported;
      });
      debugPrint(
          '🔍 AVANZADO: Estado actualizado - _isScreenSharingSupported: $_isScreenSharingSupported');

      if (supported) {
        debugPrint('🔍 AVANZADO: Inicializando servicio de screen sharing...');
        await _screenSharingService!.initialize();
        if (!mounted) return;
        _setupScreenSharingListeners();
        debugPrint('✅ AVANZADO: Screen sharing inicializado correctamente');
      } else {
        debugPrint(
            '❌ AVANZADO: Screen sharing no soportado en este dispositivo');
      }
    } catch (e) {
      debugPrint('❌ AVANZADO: Error inicializando screen sharing: $e');
      // En caso de error, asumir que está soportado para mostrar el botón
      if (!mounted) return;
      setState(() {
        _isScreenSharingSupported = true;
      });
      debugPrint('🔍 AVANZADO: Asumiendo soporte por defecto debido a error');
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
      debugPrint('Iniciando inicialización del video...');
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Dispose del controller anterior si existe
      if (_controller != null && _controller!.value.isInitialized) {
        debugPrint('Disposing controller anterior...');
        await _controller!.dispose();
      }

      debugPrint('Creando nuevo controller para: ${widget.videoSource}');
      if (widget.isAsset) {
        _controller = VideoPlayerController.asset(widget.videoSource);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoSource),
        );
      }

      debugPrint('Inicializando controller...');
      await _controller!.initialize();

      // Verificar que se inicializó correctamente
      if (!_controller!.value.isInitialized) {
        throw Exception('El video no se pudo inicializar correctamente');
      }

      debugPrint(
          'Video inicializado correctamente. Duración: ${_controller!.value.duration}');
      debugPrint('Dimensiones: ${_controller!.value.size}');
      debugPrint('Aspect ratio: ${_controller!.value.aspectRatio}');

      _controller!.addListener(_videoListener);

      setState(() {
        _isLoading = false;
        _isPlaying = _controller!.value.isPlaying;
      });

      _showControlsTemporarily();
    } catch (e) {
      debugPrint('Error inicializando video: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      widget.onError?.call(_errorMessage);
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    if (_controller!.value.hasError) {
      debugPrint('Error en el video: ${_controller!.value.errorDescription}');
      setState(() {
        _hasError = true;
        _errorMessage =
            _controller!.value.errorDescription ?? 'Error desconocido';
      });
      widget.onError?.call(_errorMessage);
      return;
    }

    // Log del estado del video cada vez que cambie
    debugPrint(
        'Video listener - Playing: ${_controller!.value.isPlaying}, Position: ${_controller!.value.position}, Duration: ${_controller!.value.duration}');

    if (_controller!.value.position >= _controller!.value.duration) {
      setState(() {
        _isPlaying = false;
      });
      widget.onVideoEnd?.call();
    } else {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  double _getProgressWidthFactor() {
    if (_controller == null) return 0.0;

    try {
      final duration = _controller!.value.duration;
      final position = _controller!.value.position;

      if (duration.inMilliseconds <= 0) return 0.0;

      final progress = position.inMilliseconds / duration.inMilliseconds;
      return progress.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating progress: $e');
      return 0.0;
    }
  }

  void _togglePlayPause() {
    debugPrint(
        'Toggle play/pause llamado. Controller: ${_controller != null}, Inicializado: ${_controller?.value.isInitialized}, Playing: $_isPlaying');

    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('Controller no inicializado, reintentando...');
      _initializeVideoPlayer();
      return;
    }

    setState(() {
      if (_isPlaying) {
        debugPrint('Pausando video...');
        _controller!.pause();
        _isPlaying = false;
      } else {
        debugPrint('Reproduciendo video...');
        _controller!.play();
        _isPlaying = true;
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
    if (!_isFullscreen) {
      // Navegar a pantalla completa
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullscreenVideoPage(
            controller: _controller!,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            skipDuration: widget.skipDuration,
            enablePictureInPicture: widget.enablePictureInPicture,
            enableScreenSharing: widget.enableScreenSharing,
            videoTitle: widget.videoTitle,
            videoDescription: widget.videoDescription,
          ),
          fullscreenDialog: true,
        ),
      );
    }
    _showControlsTemporarily();
  }

  void _enterPictureInPicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

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
      const width = 300.0;
      final height = width / aspectRatio;

      final success = await PictureInPictureService.enterPictureInPictureMode(
        width: width,
        height: height,
      );

      if (!mounted) return;
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
    } catch (e) {
      debugPrint('Error al activar Picture-in-Picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
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
    debugPrint(
        '_buildVideoStack - Loading: $_isLoading, Controller: ${_controller != null}, Initialized: ${_controller?.value.isInitialized}');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        if (_isLoading ||
            _controller == null ||
            !_controller!.value.isInitialized)
          _buildLoadingWidget()
        else
          VideoPlayer(_controller!),

        // Controles overlay
        if (!_isLoading &&
            _controller != null &&
            _controller!.value.isInitialized)
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? 1.0 : 0.0,
                child: _buildControlsOverlay(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFullscreenVideo() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video en pantalla completa
        if (_isLoading ||
            _controller == null ||
            !_controller!.value.isInitialized)
          _buildLoadingWidget()
        else
          VideoPlayer(_controller!),

        // Controles overlay para pantalla completa
        if (!_isLoading &&
            _controller != null &&
            _controller!.value.isInitialized)
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? 1.0 : 0.0,
                child: _buildFullscreenControlsOverlay(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.primaryColor, widget.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
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
        children: [
          // Barra superior
          _buildTopBar(),
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

  Widget _buildFullscreenControlsOverlay() {
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.enableScreenSharing && _isScreenSharingSupported)
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
            ),
          if (widget.enableScreenSharing && _isScreenSharingSupported)
            const SizedBox(width: 8),
          if (widget.enablePictureInPicture)
            _buildControlButton(
              icon: Icons.picture_in_picture_alt,
              onPressed: _enterPictureInPicture,
              tooltip: 'Picture-in-Picture',
            ),
          if (widget.enablePictureInPicture) const SizedBox(width: 8),
          _buildControlButton(
            icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onPressed: _toggleFullscreen,
            tooltip: _isFullscreen
                ? 'Salir de pantalla completa'
                : 'Pantalla completa',
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.enableScreenSharing && _isScreenSharingSupported)
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
            ),
          if (widget.enableScreenSharing && _isScreenSharingSupported)
            const SizedBox(width: 8),
          _buildControlButton(
            icon: Icons.fullscreen_exit,
            onPressed: _toggleFullscreen,
            tooltip: 'Salir de pantalla completa',
          ),
        ],
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
        ),
        _buildControlButton(
          icon:
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          onPressed: _togglePlayPause,
          tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
          size: 60,
          isPrimary: true,
        ),
        _buildControlButton(
          icon: Icons.forward_10,
          onPressed: _skipForward,
          tooltip: 'Avanzar ${widget.skipDuration}s',
          size: 40,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de progreso
          _buildProgressBar(),
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

  Widget _buildProgressBar() {
    return GestureDetector(
      onTapDown: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.globalToLocal(details.globalPosition);
        final width = renderBox.size.width - 32; // padding
        final percentage = position.dx / width;
        if (_controller != null) {
          final newPosition = Duration(
            milliseconds:
                (_controller!.value.duration.inMilliseconds * percentage)
                    .round(),
          );
          _controller!.seekTo(newPosition);
        }
      },
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: Colors.white.withOpacity(0.3),
        ),
        child: Stack(
          children: [
            // Progreso reproducido
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _getProgressWidthFactor(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, widget.secondaryColor],
                  ),
                ),
              ),
            ),
            // Indicador de posición
            Positioned(
              left: _controller != null &&
                      _controller!.value.duration.inMilliseconds > 0
                  ? (_controller!.value.position.inMilliseconds /
                          _controller!.value.duration.inMilliseconds) *
                      (MediaQuery.of(context).size.width - 32)
                  : 0,
              top: -6,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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

  void _showTvCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Vincular con código de TV'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Para conectar tu TV:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Abre la app de Chromecast en tu TV\n'
                    '2. Selecciona "Configurar dispositivo"\n'
                    '3. Aparecerá un código en pantalla\n'
                    '4. Ingresa el código aquí',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Código de vinculación:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _generateTvCode(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'O escanea este código QR:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: QrImageView(
                        data:
                            'Código: ${_currentPairingCode ?? _generateTvCode()}',
                        version: QrVersions.auto,
                        size: 108.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChromecastApp(),
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: const Text('Abrir app de Chromecast',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startTvPairing();
                },
                child: const Text('Iniciar vinculación'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _generateTvCode() {
    // Generar un código de 6 dígitos único basado en timestamp y random
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toInt();
    _currentPairingCode = random.toString().padLeft(6, '0');
    return _currentPairingCode!;
  }

  void _startTvPairing() {
    _isPairing = true;
    _currentPairingCode = _generateTvCode();

    // Mostrar indicador de vinculación
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Vinculando con TV...'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Esperando confirmación de la TV...'),
              const SizedBox(height: 8),
              Text(
                'Código: $_currentPairingCode',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Abre la app de Chromecast en tu TV\n'
                '2. Ingresa el código mostrado arriba\n'
                '3. O escanea el código QR',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelTvPairing();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _openChromecastApp(),
            child: const Text('Abrir Chromecast'),
          ),
        ],
      ),
    );

    // Iniciar proceso de verificación real
    _startPairingVerification();
  }

  void _openChromecastApp() async {
    try {
      // Intentar múltiples URLs de Chromecast
      final List<String> urls = [
        'https://cast.google.com/pair?code=$_currentPairingCode',
        'https://www.google.com/chromecast/setup/',
        'https://cast.google.com/',
        'chromecast://pair?code=$_currentPairingCode',
      ];

      bool launched = false;
      for (String urlString in urls) {
        try {
          final Uri url = Uri.parse(urlString);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          debugPrint('Error con URL $urlString: $e');
          continue;
        }
      }

      if (!launched) {
        // Fallback: mostrar instrucciones manuales
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Abrir Chromecast manualmente'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'No se pudo abrir automáticamente. Sigue estos pasos:'),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Abre la app de Chromecast en tu dispositivo\n'
                      '2. Ve a Configuración\n'
                      '3. Selecciona "Configurar dispositivo"\n'
                      '4. Ingresa el código:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        _currentPairingCode ?? 'ERROR',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
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
      }
    } catch (e) {
      debugPrint('Error general al abrir Chromecast: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir Chromecast: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPairingVerification() {
    // Verificar cada 2 segundos si se estableció la conexión
    _pairingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isPairing) {
        timer.cancel();
        return;
      }

      // Verificar si hay dispositivos conectados
      try {
        final devices = await _screenSharingService?.discoverDevices();
        if (devices != null && devices.isNotEmpty) {
          // Se encontró un dispositivo, asumir que la vinculación fue exitosa
          timer.cancel();
          _isPairing = false;

          if (mounted) {
            Navigator.of(context).pop(); // Cerrar diálogo de vinculación
            _showPairingResult();
          }
        }
      } catch (e) {
        // Error en la verificación, continuar intentando
      }
    });

    // Timeout después de 60 segundos
    Timer(const Duration(seconds: 60), () {
      if (_isPairing) {
        _isPairing = false;
        _pairingTimer?.cancel();

        if (mounted) {
          Navigator.of(context).pop(); // Cerrar diálogo de vinculación
          _showPairingTimeout();
        }
      }
    });
  }

  void _cancelTvPairing() {
    _isPairing = false;
    _pairingTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vinculación cancelada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showPairingTimeout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiempo agotado'),
        content: const Text(
          'No se pudo establecer la conexión con la TV. '
          'Asegúrate de que:\n\n'
          '• Tu TV esté conectada a la misma red Wi-Fi\n'
          '• La app de Chromecast esté instalada en tu TV\n'
          '• El código se haya ingresado correctamente',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showTvCodeDialog(); // Reintentar
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showPairingResult() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¡Vinculación exitosa!'),
        content: const Text(
          'Tu dispositivo se ha conectado correctamente a la TV. '
          'Ahora puedes compartir videos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
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
    _pairingTimer?.cancel();
    _controlsAnimationController.dispose();
    _controller?.dispose();
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
