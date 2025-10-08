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
                        Text('✅ Restauración automática al salir de PiP'),
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
