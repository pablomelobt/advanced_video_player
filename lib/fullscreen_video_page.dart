import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'picture_in_picture_service.dart';

class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final Color primaryColor;
  final Color secondaryColor;
  final int skipDuration;
  final bool enablePictureInPicture;

  const FullscreenVideoPage({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    required this.skipDuration,
    this.enablePictureInPicture = true,
  });

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with TickerProviderStateMixin {
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isPictureInPictureSupported = false;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _setupFullscreen();
    _setupAnimations();
    _setupVideoListener();
    _checkPictureInPictureSupport();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Picture-in-Picture activado'),
              duration: Duration(seconds: 2),
            ),
          );
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
                    child: Column(
                      children: [
                        // Barra superior - botón de salida
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.enablePictureInPicture)
                                Container(
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
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.fullscreen_exit,
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: Icons.replay_10,
                              onPressed: _skipBackward,
                              tooltip: 'Retroceder ${widget.skipDuration}s',
                              size: 40,
                            ),
                            _buildControlButton(
                              icon: _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
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
                                  final RenderBox renderBox =
                                      context.findRenderObject() as RenderBox;
                                  final position = renderBox
                                      .globalToLocal(details.globalPosition);
                                  final width = renderBox.size.width - 32;
                                  final percentage = position.dx / width;
                                  final newPosition = Duration(
                                    milliseconds: (widget.controller.value
                                                .duration.inMilliseconds *
                                            percentage)
                                        .round(),
                                  );
                                  widget.controller.seekTo(newPosition);
                                },
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: widget.controller.value
                                                    .duration.inMilliseconds >
                                                0
                                            ? widget.controller.value.position
                                                    .inMilliseconds /
                                                widget.controller.value.duration
                                                    .inMilliseconds
                                            : 0.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
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
                                    _formatDuration(
                                        widget.controller.value.position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(
                                        widget.controller.value.duration),
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

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    super.dispose();
  }
}
