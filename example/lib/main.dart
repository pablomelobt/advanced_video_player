import 'package:flutter/material.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Video Player Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VideoPlayerDemo(),
    );
  }
}

class VideoPlayerDemo extends StatefulWidget {
  const VideoPlayerDemo({super.key});

  @override
  State<VideoPlayerDemo> createState() => _VideoPlayerDemoState();
}

class _VideoPlayerDemoState extends State<VideoPlayerDemo> {
  final String _videoUrl =
      'https://player.vimeo.com/external/510520873.m3u8?s=2651efc084fb2c4ad19925e2b48044cdecdbebaf&oauth2_token_id=1795373245';
  // final String _videoUrl =
  //     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _initializeGoogleCast();
  }

  void _initializeGoogleCast() async {
    // Inicializar Google Cast automáticamente en Android
    try {
      await AdvancedVideoPlayerCast.initializeCast();
      debugPrint('✅ Google Cast inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando Google Cast: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Advanced Video Player',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text(
              'Reproductor de Video Avanzado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un reproductor moderno con controles intuitivos y diseño atractivo',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),

            // Video Player
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 800,
                maxHeight: 450,
              ),
              child: AdvancedVideoPlayer(
                videoSource: _videoUrl,
                onVideoEnd: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Video terminado!'),
                      backgroundColor: Color(0xFF6366F1),
                    ),
                  );
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                primaryColor: const Color.fromARGB(255, 255, 81, 0),
                secondaryColor: const Color(0xFFED8C60),
                skipDuration: 10,
                enablePictureInPicture: true,
                enableScreenSharing: true,
                enableAirPlay: true,
                videoTitle: 'Big Buck Bunny - Demostración',
                videoDescription:
                    'Un video de demostración para probar el reproductor avanzado con funcionalidades de compartir pantalla',
              ),
            ),

            const SizedBox(height: 40),

            // Características
            const Text(
              'Características',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _buildFeatureCard(
              icon: Icons.play_circle_filled,
              title: 'Controles Intuitivos',
              description:
                  'Play/Pause, retroceder 10s, avanzar 10s, pantalla completa y Picture-in-Picture',
              color: const Color(0xFF6366F1),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.timeline,
              title: 'Barra de Progreso Interactiva',
              description:
                  'Haz clic en cualquier parte para saltar a esa posición',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.visibility,
              title: 'Controles Automáticos',
              description:
                  'Los controles aparecen y desaparecen automáticamente',
              color: const Color(0xFF10B981),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.palette,
              title: 'Diseño Personalizable',
              description:
                  'Colores personalizables y UI moderna con gradientes',
              color: const Color(0xFFF59E0B),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.picture_in_picture_alt,
              title: 'Picture-in-Picture',
              description:
                  'Ve videos en ventana flotante mientras usas otras apps (Android 8.0+ / iOS 14+)',
              color: const Color(0xFFEC4899),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.cast,
              title: 'Compartir Pantalla',
              description:
                  'Comparte videos con otros dispositivos usando SharePlay (iOS) o Google Cast (Android)',
              color: const Color(0xFF06B6D4),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              icon: Icons.airplay,
              title: 'AirPlay (iOS)',
              description:
                  'Reproduce videos en Apple TV y otros dispositivos compatibles con AirPlay',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 40),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información del Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Video de demostración: Big Buck Bunny',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    'Fuente: Google Cloud Storage',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nuevas funcionalidades:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    '• SharePlay para iOS (compartir en tiempo real)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    '• Google Cast para Android (Chromecast)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Aquí podrías agregar funcionalidad para cambiar el video
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Funcionalidad de cambio de video próximamente'),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.video_library),
                    label: const Text('Cambiar Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
