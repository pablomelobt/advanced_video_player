import 'package:flutter/material.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

/// Ejemplo de uso del nuevo NativeVideoPlayer
///
/// Este ejemplo muestra cómo usar el reproductor nativo con PiP
/// sin dummy views, replicando el comportamiento nativo de iOS
class NativePlayerExample extends StatefulWidget {
  const NativePlayerExample({super.key});

  @override
  State<NativePlayerExample> createState() => _NativePlayerExampleState();
}

class _NativePlayerExampleState extends State<NativePlayerExample> {
  NativeVideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Video Player - PiP Nativo'),
        backgroundColor: const Color(0xFF6366F1),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Video Player
            Container(
              height: 250,
              color: Colors.black,
              child: NativeVideoPlayer(
                url:
                    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                autoplay: true,
                onViewCreated: (controller) {
                  setState(() {
                    _controller = controller;
                    _isPlaying = true;
                  });
                },
                onPipStarted: () {
                  debugPrint('[NativePlayerExample] 🎥 PiP iniciado');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PiP activado - Video flotante'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                onPipStopped: () {
                  debugPrint('[NativePlayerExample] ⏹️ PiP detenido');
                },
                onPipRestoreToFullscreen: () {
                  debugPrint(
                      '[NativePlayerExample] 🎬 Restaurando a fullscreen desde PiP');

                  // Mostrar mensaje de navegación
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('🎬 Navegando a fullscreen automáticamente'),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Navegar a pantalla fullscreen (como Disney+, Netflix, etc.)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => _FullscreenVideoPage(
                          controller: _controller,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            // Controles
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    '🎬 Reproductor Nativo con PiP',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Este reproductor usa la arquitectura nativa de iOS, sin dummy views y con control directo del AVPlayerLayer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Botones de control
                  _buildControlButton(
                    icon: Icons.picture_in_picture_alt,
                    label: 'Activar Picture-in-Picture',
                    color: const Color(0xFF6366F1),
                    onPressed: _controller != null
                        ? () {
                            _controller!.startPiP().then((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'PiP activado - Puedes navegar libremente'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildControlButton(
                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                    label: _isPlaying ? 'Pausar' : 'Reproducir',
                    color: const Color(0xFF8B5CF6),
                    onPressed: _controller != null
                        ? () async {
                            if (_isPlaying) {
                              await _controller!.pause();
                            } else {
                              await _controller!.play();
                            }
                            setState(() {
                              _isPlaying = !_isPlaying;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildControlButton(
                    icon: Icons.replay_10,
                    label: 'Retroceder 10s',
                    color: const Color(0xFF10B981),
                    onPressed: _controller != null
                        ? () async {
                            await _controller!
                                .seek(0); // Volver al inicio por simplicidad
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildControlButton(
                    icon: Icons.volume_up,
                    label: 'Volumen 50%',
                    color: const Color(0xFFF59E0B),
                    onPressed: _controller != null
                        ? () async {
                            await _controller!.setVolume(0.5);
                          }
                        : null,
                  ),

                  const SizedBox(height: 32),

                  // Información
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ventajas del sistema nativo:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text('✅ Sin dummy views fuera de pantalla'),
                        Text('✅ Comportamiento igual a apps nativas'),
                        Text('✅ PiP limpio y sin efectos secundarios'),
                        Text('✅ Múltiples videos independientes'),
                        Text('✅ Restauración automática a fullscreen'),
                        Text('✅ Navegación inteligente como Disney+/Netflix'),
                        Text('✅ Auto-fullscreen al volver de multitasking'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Pantalla de video en fullscreen (como Disney+, Netflix, etc.)
class _FullscreenVideoPage extends StatefulWidget {
  final NativeVideoPlayerController? controller;

  const _FullscreenVideoPage({this.controller});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _controlsVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _controlsVisible = !_controlsVisible;
          });
        },
        child: Stack(
          children: [
            // Video Player Fullscreen
            Center(
              child: NativeVideoPlayer(
                url:
                    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                autoplay: true,
                onViewCreated: (controller) {
                  // Video continúa reproduciéndose automáticamente
                  debugPrint(
                      '[Fullscreen] Video restaurado en pantalla completa');
                },
              ),
            ),

            // Controles overlay
            if (_controlsVisible)
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
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'Big Buck Bunny',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Controles de reproducción
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white, size: 40),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.pause,
                                color: Colors.white, size: 50),
                            onPressed: () {
                              widget.controller?.pause();
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white, size: 40),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Barra de progreso
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: 0.3,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6366F1)),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '1:23',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  '4:56',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
