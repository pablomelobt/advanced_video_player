/// Ejemplo de uso del paquete Advanced Video Player
///
/// Este ejemplo demuestra todas las características principales del reproductor,
/// incluyendo controles personalizables, Picture-in-Picture, AirPlay,
/// y funcionalidades de compartir pantalla (SharePlay/Google Cast).
library;

import 'package:flutter/material.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

/// Punto de entrada de la aplicación de ejemplo
void main() {
  runApp(const MyApp());
}

/// Widget raíz de la aplicación de ejemplo
///
/// Configura el tema y la estructura básica de la aplicación,
/// incluyendo el título y la página principal de demostración.
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

/// Widget principal de demostración del reproductor de video
///
/// Muestra un ejemplo completo de cómo usar el [AdvancedVideoPlayer]
/// con todas sus características: controles personalizables, callbacks,
/// Picture-in-Picture, AirPlay y funcionalidades de compartir pantalla.
class VideoPlayerDemo extends StatefulWidget {
  const VideoPlayerDemo({super.key});

  @override
  State<VideoPlayerDemo> createState() => _VideoPlayerDemoState();
}

/// Estado del widget de demostración
///
/// Maneja la inicialización de Google Cast y la configuración
/// del reproductor de video con todas sus opciones.
class _VideoPlayerDemoState extends State<VideoPlayerDemo> {
  /// URL del video de demostración
  ///
  /// Se utiliza el video Big Buck Bunny de Google Cloud Storage,
  /// un video de dominio público ideal para pruebas.
  final String _videoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _initializeGoogleCast();
  }

  /// Inicializa Google Cast para Android
  ///
  /// Este método debe llamarse al iniciar la aplicación para habilitar
  /// la funcionalidad de transmisión a Chromecast y otros dispositivos Cast.
  /// Los errores se capturan silenciosamente para evitar problemas en iOS.
  void _initializeGoogleCast() async {
    try {
      await AdvancedVideoPlayerCast.initializeCast();
    } catch (e) {
      // Ignorar errores en iOS donde Google Cast no está disponible
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

            // ═══════════════════════════════════════════════════════════
            // REPRODUCTOR DE VIDEO
            // ═══════════════════════════════════════════════════════════
            // Configuración completa del AdvancedVideoPlayer con:
            // - Colores personalizados (naranja y coral)
            // - Callbacks para eventos (fin de video y errores)
            // - Picture-in-Picture habilitado
            // - Compartir pantalla (SharePlay/Google Cast)
            // - AirPlay para iOS
            // - Saltos de 10 segundos
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 800,
                maxHeight: 450,
              ),
              child: AdvancedVideoPlayer(
                // URL del video a reproducir
                videoSource: _videoUrl,

                // Callback cuando el video termina de reproducirse
                onVideoEnd: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Video terminado!'),
                      backgroundColor: Color(0xFF6366F1),
                    ),
                  );
                },

                // Callback para manejar errores durante la reproducción
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },

                // Personalización de colores
                primaryColor: const Color.fromARGB(255, 255, 81, 0),
                secondaryColor: const Color(0xFFED8C60),

                // Duración de los saltos adelante/atrás en segundos
                skipDuration: 10,

                // Habilitar características avanzadas
                enablePictureInPicture: true, // Android 8.0+ / iOS 14+
                enableScreenSharing:
                    true, // SharePlay (iOS) / Google Cast (Android)
                enableAirPlay: true, // Solo iOS

                // 🆕 NUEVO: Usar reproductor nativo en iOS para mejor PiP
                useNativePlayerOnIOS: true,

                // Metadatos del video
                videoTitle: 'Big Buck Bunny - Demostración',
                videoDescription:
                    'Un video de demostración para probar el reproductor avanzado con funcionalidades de compartir pantalla',
              ),
            ),

            const SizedBox(height: 40),

            // ═══════════════════════════════════════════════════════════
            // SECCIÓN DE CARACTERÍSTICAS
            // ═══════════════════════════════════════════════════════════
            // Lista visual de todas las funcionalidades del reproductor
            const Text(
              'Características',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Controles básicos del reproductor
            _buildFeatureCard(
              icon: Icons.play_circle_filled,
              title: 'Controles Intuitivos',
              description:
                  'Play/Pause, retroceder 10s, avanzar 10s, pantalla completa y Picture-in-Picture',
              color: const Color(0xFF6366F1),
            ),

            const SizedBox(height: 16),

            // Navegación temporal en el video
            _buildFeatureCard(
              icon: Icons.timeline,
              title: 'Barra de Progreso Interactiva',
              description:
                  'Haz clic en cualquier parte para saltar a esa posición',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 16),

            // Comportamiento automático de la interfaz
            _buildFeatureCard(
              icon: Icons.visibility,
              title: 'Controles Automáticos',
              description:
                  'Los controles aparecen y desaparecen automáticamente',
              color: const Color(0xFF10B981),
            ),

            const SizedBox(height: 16),

            // Personalización de la apariencia
            _buildFeatureCard(
              icon: Icons.palette,
              title: 'Diseño Personalizable',
              description:
                  'Colores personalizables y UI moderna con gradientes',
              color: const Color(0xFFF59E0B),
            ),

            const SizedBox(height: 16),

            // Funcionalidad Picture-in-Picture
            _buildFeatureCard(
              icon: Icons.picture_in_picture_alt,
              title: 'Picture-in-Picture',
              description:
                  'Ve videos en ventana flotante mientras usas otras apps (Android 8.0+ / iOS 14+)',
              color: const Color(0xFFEC4899),
            ),

            const SizedBox(height: 16),

            // Transmisión a otros dispositivos
            _buildFeatureCard(
              icon: Icons.cast,
              title: 'Compartir Pantalla',
              description:
                  'Comparte videos con otros dispositivos usando SharePlay (iOS) o Google Cast (Android)',
              color: const Color(0xFF06B6D4),
            ),

            const SizedBox(height: 16),

            // Compatibilidad con AirPlay (solo iOS)
            _buildFeatureCard(
              icon: Icons.airplay,
              title: 'AirPlay (iOS)',
              description:
                  'Reproduce videos en Apple TV y otros dispositivos compatibles con AirPlay',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 40),

            // ═══════════════════════════════════════════════════════════
            // INFORMACIÓN ADICIONAL
            // ═══════════════════════════════════════════════════════════
            // Panel informativo con detalles del video y nuevas funcionalidades
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información del Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Video de demostración: Big Buck Bunny',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Fuente: Google Cloud Storage',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nuevas funcionalidades:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '• SharePlay para iOS (compartir en tiempo real)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• Google Cast para Android (Chromecast)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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

  /// Construye una tarjeta de característica con diseño personalizado
  ///
  /// Crea una tarjeta visual que muestra una característica del reproductor
  /// con un icono, título y descripción.
  ///
  /// Parámetros:
  /// - [icon]: Icono de Material Design que representa la característica
  /// - [title]: Título principal de la característica
  /// - [description]: Descripción detallada de la funcionalidad
  /// - [color]: Color temático para el borde, icono y fondo del icono
  ///
  /// Retorna un [Widget] con diseño moderno que incluye:
  /// - Bordes redondeados con color temático
  /// - Icono con fondo circular semi-transparente
  /// - Texto con jerarquía visual clara
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
