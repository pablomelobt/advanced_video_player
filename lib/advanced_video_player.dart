library advanced_video_player;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'fullscreen_video_page.dart';

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

  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _setupAnimations();
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
          ),
          fullscreenDialog: true,
        ),
      );
    }
    _showControlsTemporarily();
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
              widthFactor: _controller != null &&
                      _controller!.value.duration.inMilliseconds > 0
                  ? _controller!.value.position.inMilliseconds /
                      _controller!.value.duration.inMilliseconds
                  : 0.0,
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

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _controller?.dispose();
    // Restaurar orientación y UI cuando se dispone el widget
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }
}
