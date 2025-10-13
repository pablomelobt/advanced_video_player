// Copyright 2025 Advanced Video Player. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Ejemplo de demostración del paquete Advanced Video Player
///
/// Este archivo demuestra el uso completo de todas las características del
/// [AdvancedVideoPlayer], incluyendo:
///
/// - Reproducción de video con controles personalizables
/// - Picture-in-Picture (PiP) para Android e iOS
/// - AirPlay para dispositivos Apple
/// - Screen Sharing con SharePlay (iOS) y Google Cast (Android)
/// - Personalización de colores y duración de saltos
/// - Preview/Thumbnail personalizado (v0.0.3+)
/// - Reproductor nativo optimizado para iOS (v0.0.3+)
///
/// ## Estructura de la Aplicación
///
/// La aplicación está compuesta por:
/// - [MyApp]: Widget raíz con configuración de tema
/// - [VideoPlayerDemo]: Página principal de demostración
/// - [_VideoPlayerDemoState]: Lógica de estado y configuración del reproductor
///
/// ## Requisitos
///
/// - Flutter >= 1.17.0
/// - Dart >= 3.4.4
/// - Android API 21+ (5.0+) o iOS 11.0+
/// - Para PiP: Android 8.0+ o iOS 14.0+
///
/// ## Configuración Adicional
///
/// Asegúrate de revisar las guías de configuración:
/// - Android: `doc/android-setup.md`
/// - iOS: `doc/ios-setup.md`
library;

import 'package:flutter/material.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

/// Punto de entrada principal de la aplicación de ejemplo.
///
/// Inicializa y ejecuta la aplicación Flutter con [MyApp] como widget raíz.
/// Esta función es llamada automáticamente al iniciar la aplicación.
void main() {
  runApp(const MyApp());
}

/// Widget raíz de la aplicación de ejemplo.
///
/// [MyApp] es el widget principal que configura la aplicación Material Design
/// con el tema personalizado y define [VideoPlayerDemo] como la página inicial.
///
/// ## Configuración del Tema
///
/// Utiliza un [MaterialApp] con:
/// - Color primario azul (Blue swatch)
/// - Densidad visual adaptativa a la plataforma
/// - Título descriptivo para la aplicación
///
/// ## Navegación
///
/// La página inicial es [VideoPlayerDemo], que muestra la demostración
/// completa del reproductor de video con todas sus funcionalidades.
class MyApp extends StatelessWidget {
  /// Crea una instancia de [MyApp].
  ///
  /// El parámetro [key] es opcional y se usa para controlar cómo un widget
  /// reemplaza a otro widget en el árbol.
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

/// Widget principal de demostración del reproductor de video.
///
/// [VideoPlayerDemo] es un [StatefulWidget] que muestra un ejemplo completo
/// de cómo implementar el [AdvancedVideoPlayer] con todas sus características
/// y opciones de personalización.
///
/// ## Características Demostradas
///
/// ### Reproducción de Video
/// - Carga desde URL remota (streaming)
/// - Preview/Thumbnail personalizado
/// - Controles de reproducción completos
///
/// ### Funcionalidades Avanzadas
/// - **Picture-in-Picture (PiP)**: Reproducción en ventana flotante
/// - **AirPlay**: Transmisión a dispositivos Apple (iOS)
/// - **Screen Sharing**: SharePlay (iOS) y Google Cast (Android)
///
/// ### Personalización
/// - Colores personalizados (naranja y coral)
/// - Duración de saltos configurable (10 segundos)
/// - Callbacks para eventos (fin de video y errores)
///
/// ## Implementación
///
/// El estado de este widget se maneja en [_VideoPlayerDemoState], que incluye:
/// - Inicialización de Google Cast
/// - Configuración del reproductor
/// - Manejo de eventos y callbacks
///
/// ## Ejemplo de Uso
///
/// ```dart
/// MaterialApp(
///   home: VideoPlayerDemo(),
/// )
/// ```
class VideoPlayerDemo extends StatefulWidget {
  /// Crea una instancia de [VideoPlayerDemo].
  const VideoPlayerDemo({super.key});

  @override
  State<VideoPlayerDemo> createState() => _VideoPlayerDemoState();
}

/// Estado del widget de demostración [VideoPlayerDemo].
///
/// [_VideoPlayerDemoState] gestiona la lógica de negocio y el estado de la
/// página de demostración, incluyendo:
///
/// - Inicialización de servicios externos (Google Cast)
/// - Configuración de la URL del video
/// - Construcción de la interfaz de usuario
/// - Gestión de callbacks y eventos
///
/// ## Ciclo de Vida
///
/// 1. [initState]: Inicializa Google Cast al crear el widget
/// 2. [build]: Construye la UI con el reproductor y características
/// 3. [dispose]: Limpia recursos (manejado automáticamente)
class _VideoPlayerDemoState extends State<VideoPlayerDemo> {
  /// URL del video de demostración.
  ///
  /// Actualmente utiliza un stream HLS (.m3u8) de Vimeo para demostrar
  /// capacidades de streaming adaptativo.
  ///
  /// ### Alternativas Comentadas
  ///
  /// También puedes usar:
  /// - Big Buck Bunny de Google Cloud Storage (MP4):
  ///   `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4`
  ///
  /// ### Formatos Soportados
  ///
  /// El reproductor soporta múltiples formatos:
  /// - MP4 (H.264)
  /// - HLS (.m3u8) - Streaming adaptativo
  /// - DASH - Streaming adaptativo (limitado)
  final String _videoUrl =
      'https://player.vimeo.com/external/510520873.m3u8?s=2651efc084fb2c4ad19925e2b48044cdecdbebaf&oauth2_token_id=1795373245';

  @override
  void initState() {
    super.initState();
    _initializeGoogleCast();
  }

  /// Inicializa el servicio de Google Cast para Android.
  ///
  /// Este método debe ejecutarse al iniciar la aplicación para habilitar
  /// la funcionalidad de transmisión a dispositivos Chromecast y otros
  /// dispositivos compatibles con Google Cast.
  ///
  /// ## Comportamiento por Plataforma
  ///
  /// - **Android**: Inicializa el SDK de Google Cast y busca dispositivos
  /// - **iOS**: Lanza una excepción que se captura silenciosamente (usa SharePlay)
  ///
  /// ## Manejo de Errores
  ///
  /// Los errores se capturan y se ignoran silenciosamente para evitar
  /// problemas en plataformas no compatibles (como iOS, que no soporta
  /// Google Cast nativamente).
  ///
  /// ## Requisitos
  ///
  /// - Android: Google Play Services instalado
  /// - Dispositivo Chromecast en la misma red WiFi
  /// - Permisos de red configurados en AndroidManifest.xml
  void _initializeGoogleCast() async {
    try {
      await AdvancedVideoPlayerCast.initializeCast();
    } catch (e) {
      // Ignorar errores en iOS donde Google Cast no está disponible
      // iOS utiliza SharePlay como alternativa nativa
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
            // REPRODUCTOR DE VIDEO - CONFIGURACIÓN COMPLETA
            // ═══════════════════════════════════════════════════════════
            //
            // Esta sección demuestra la implementación completa del
            // AdvancedVideoPlayer con todas sus características y opciones.
            //
            // CARACTERÍSTICAS INCLUIDAS:
            //
            // 🎨 Personalización Visual:
            //   - Colores personalizados (naranja #FF5100 y coral #ED8C60)
            //   - Preview/Thumbnail personalizado (v0.0.3+)
            //   - Diseño responsivo con constraints
            //
            // 🎬 Funcionalidades de Reproducción:
            //   - Saltos de 10 segundos (adelante/atrás)
            //   - Controles automáticos (aparecen/desaparecen)
            //   - Barra de progreso interactiva
            //
            // 📱 Características Avanzadas:
            //   - Picture-in-Picture (Android 8.0+ / iOS 14.0+)
            //   - Screen Sharing con SharePlay (iOS) / Google Cast (Android)
            //   - AirPlay para dispositivos Apple (solo iOS)
            //   - Reproductor nativo optimizado para iOS (v0.0.3+)
            //
            // 🔔 Eventos y Callbacks:
            //   - onVideoEnd: Notificación cuando termina el video
            //   - onError: Manejo de errores durante la reproducción
            //
            // ═══════════════════════════════════════════════════════════
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 800,
                maxHeight: 450,
              ),
              child: AdvancedVideoPlayer(
                // ────────────────────────────────────────────────────────
                // CONFIGURACIÓN DE VIDEO
                // ────────────────────────────────────────────────────────

                /// URL del video a reproducir.
                /// Soporta URLs remotas (HTTP/HTTPS) y archivos locales (assets).
                videoSource: _videoUrl,

                /// 🆕 [v0.0.3+] Imagen de preview/thumbnail (OPCIONAL)
                ///
                /// Muestra una imagen mientras el video está cargando, mejorando
                /// la experiencia del usuario al evitar pantallas negras.
                ///
                /// Beneficios:
                /// - Reduce la percepción de tiempo de carga
                /// - Proporciona contexto visual del contenido
                /// - Mejora la UX en conexiones lentas
                previewImageUrl:
                    'https://i.vimeocdn.com/video/1056828543-d9012e5ba116e7e91acebb15be11a7845a638852472b3791d05e214638a0091e-d?region=us',

                // ────────────────────────────────────────────────────────
                // CALLBACKS Y EVENTOS
                // ────────────────────────────────────────────────────────

                /// Callback ejecutado cuando el video termina de reproducirse.
                ///
                /// Útil para:
                /// - Mostrar sugerencias de videos relacionados
                /// - Reproducir el siguiente video en una playlist
                /// - Actualizar estadísticas de visualización
                /// - Mostrar opciones de compartir o guardar
                onVideoEnd: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Video terminado!'),
                      backgroundColor: Color(0xFF6366F1),
                    ),
                  );
                },

                /// Callback ejecutado cuando ocurre un error durante la reproducción.
                ///
                /// Errores comunes:
                /// - Red no disponible (sin conexión)
                /// - URL inválida o recurso no encontrado (404)
                /// - Formato de video no soportado
                /// - Problemas de permisos o DRM
                ///
                /// Se recomienda proporcionar feedback claro al usuario.
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },

                // ────────────────────────────────────────────────────────
                // PERSONALIZACIÓN VISUAL
                // ────────────────────────────────────────────────────────

                /// Color principal usado en el reproductor.
                /// Aplica a: botones principales, barra de progreso (relleno)
                primaryColor: const Color.fromARGB(255, 255, 81, 0),

                /// Color secundario usado en el reproductor.
                /// Aplica a: gradientes, efectos hover, elementos secundarios
                secondaryColor: const Color(0xFFED8C60),

                // ────────────────────────────────────────────────────────
                // CONFIGURACIÓN DE CONTROLES
                // ────────────────────────────────────────────────────────

                /// Duración en segundos de los saltos adelante/atrás.
                ///
                /// Valores recomendados:
                /// - 10 segundos: Videos cortos o tutoriales
                /// - 15 segundos: Videos medianos
                /// - 30 segundos: Videos largos o películas
                skipDuration: 10,

                // ────────────────────────────────────────────────────────
                // FUNCIONALIDADES AVANZADAS
                // ────────────────────────────────────────────────────────

                /// Habilita el botón de Picture-in-Picture.
                ///
                /// Requisitos:
                /// - Android: 8.0+ (API 26+)
                /// - iOS: 14.0+
                ///
                /// Permite al usuario ver el video en una ventana flotante
                /// mientras usa otras aplicaciones.
                enablePictureInPicture: true,

                /// Habilita el botón de Screen Sharing.
                ///
                /// Funcionalidad por plataforma:
                /// - iOS: SharePlay (compartir con otros dispositivos Apple)
                /// - Android: Google Cast (transmitir a Chromecast)
                ///
                /// Permite compartir o transmitir el video a otros dispositivos.
                enableScreenSharing: true,

                /// Habilita el botón de AirPlay (solo iOS).
                ///
                /// Permite transmitir el video a:
                /// - Apple TV
                /// - HomePod
                /// - AirPlay 2 receivers
                /// - Smart TVs compatibles con AirPlay
                enableAirPlay: true,

                /// 🆕 [v0.0.3+] Usar reproductor nativo optimizado en iOS.
                ///
                /// Beneficios:
                /// - Mejor rendimiento de PiP sin dummy views
                /// - Restauración automática a fullscreen desde PiP
                /// - Experiencia similar a Disney+, Netflix, YouTube
                /// - Múltiples instancias independientes
                ///
                /// Requisitos:
                /// - iOS 15.0+ (recomendado para mejor soporte)
                ///
                /// Se recomienda habilitar para aplicaciones iOS.
                useNativePlayerOnIOS: true,
              ),
            ),

            const SizedBox(height: 40),

            // ═══════════════════════════════════════════════════════════
            // SECCIÓN DE CARACTERÍSTICAS
            // ═══════════════════════════════════════════════════════════
            //
            // Esta sección presenta visualmente todas las características
            // del reproductor utilizando tarjetas informativas (_buildFeatureCard).
            //
            // Cada tarjeta incluye:
            // - Icono representativo de la característica
            // - Título descriptivo
            // - Descripción detallada de la funcionalidad
            // - Color temático personalizado
            //
            // Las características se organizan por categorías:
            // 1. Controles básicos de reproducción
            // 2. Navegación y progreso
            // 3. Comportamiento automático de la UI
            // 4. Personalización visual
            // 5. Funcionalidades avanzadas (PiP, Cast, AirPlay)
            // 6. Nuevas características (v0.0.3+)
            //
            // ═══════════════════════════════════════════════════════════
            const Text(
              'Características',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            /// TARJETA 1: Controles Intuitivos
            ///
            /// Demuestra los controles básicos de reproducción que incluyen
            /// play/pause, navegación temporal (retroceder/avanzar) y modos
            /// de visualización (normal/pantalla completa).
            _buildFeatureCard(
              icon: Icons.play_circle_filled,
              title: 'Controles Intuitivos',
              description:
                  'Play/Pause, retroceder 10s, avanzar 10s, pantalla completa y Picture-in-Picture',
              color: const Color(0xFF6366F1),
            ),

            const SizedBox(height: 16),

            /// TARJETA 2: Barra de Progreso Interactiva
            ///
            /// Muestra cómo la barra de progreso permite navegación precisa
            /// haciendo clic o arrastrando en cualquier posición del video.
            _buildFeatureCard(
              icon: Icons.timeline,
              title: 'Barra de Progreso Interactiva',
              description:
                  'Haz clic en cualquier parte para saltar a esa posición',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 16),

            /// TARJETA 3: Controles Automáticos
            ///
            /// Explica el comportamiento inteligente de los controles que
            /// aparecen al interactuar y desaparecen después de 3 segundos
            /// de inactividad.
            _buildFeatureCard(
              icon: Icons.visibility,
              title: 'Controles Automáticos',
              description:
                  'Los controles aparecen y desaparecen automáticamente',
              color: const Color(0xFF10B981),
            ),

            const SizedBox(height: 16),

            /// TARJETA 4: Diseño Personalizable
            ///
            /// Destaca las opciones de personalización visual, incluyendo
            /// colores primarios/secundarios y gradientes modernos.
            _buildFeatureCard(
              icon: Icons.palette,
              title: 'Diseño Personalizable',
              description:
                  'Colores personalizables y UI moderna con gradientes',
              color: const Color(0xFFF59E0B),
            ),

            const SizedBox(height: 16),

            /// TARJETA 5: Picture-in-Picture
            ///
            /// Describe la funcionalidad PiP que permite ver el video en
            /// una ventana flotante mientras se usa otras aplicaciones.
            /// Incluye requisitos de versión del sistema operativo.
            _buildFeatureCard(
              icon: Icons.picture_in_picture_alt,
              title: 'Picture-in-Picture',
              description:
                  'Ve videos en ventana flotante mientras usas otras apps (Android 8.0+ / iOS 14+)',
              color: const Color(0xFFEC4899),
            ),

            const SizedBox(height: 16),

            /// TARJETA 6: Screen Sharing
            ///
            /// Explica las capacidades de compartir pantalla que varían por
            /// plataforma: SharePlay en iOS y Google Cast en Android.
            _buildFeatureCard(
              icon: Icons.cast,
              title: 'Compartir Pantalla',
              description:
                  'Comparte videos con otros dispositivos usando SharePlay (iOS) o Google Cast (Android)',
              color: const Color(0xFF06B6D4),
            ),

            const SizedBox(height: 16),

            /// TARJETA 7: AirPlay (Solo iOS)
            ///
            /// Presenta la integración con AirPlay para transmitir a
            /// dispositivos Apple como Apple TV, HomePod, etc.
            _buildFeatureCard(
              icon: Icons.airplay,
              title: 'AirPlay (iOS)',
              description:
                  'Reproduce videos en Apple TV y otros dispositivos compatibles con AirPlay',
              color: const Color(0xFF8B5CF6),
            ),

            const SizedBox(height: 16),

            /// TARJETA 8: Preview/Thumbnail (NUEVO v0.0.3+)
            ///
            /// 🆕 Nueva característica que permite mostrar una imagen de
            /// preview mientras el video carga, mejorando la UX.
            _buildFeatureCard(
              icon: Icons.image,
              title: 'Preview/Thumbnail Opcional',
              description:
                  'Puedes mostrar una imagen de preview personalizada mientras el video carga (opcional)',
              color: const Color(0xFFEC4899),
            ),

            const SizedBox(height: 40),

            // ═══════════════════════════════════════════════════════════
            // PANEL DE INFORMACIÓN
            // ═══════════════════════════════════════════════════════════
            //
            // Panel informativo que proporciona:
            // - Detalles del video de demostración utilizado
            // - Información sobre la fuente del contenido
            // - Lista de nuevas funcionalidades agregadas
            // - Características específicas por plataforma
            //
            // Este panel ayuda a los desarrolladores a entender qué video
            // se está usando en la demo y qué tecnologías están disponibles
            // en cada plataforma.
            //
            // ═══════════════════════════════════════════════════════════
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

  /// Construye una tarjeta de característica con diseño personalizado.
  ///
  /// Crea un [Widget] visual que presenta una característica del reproductor
  /// con un diseño moderno y profesional.
  ///
  /// ## Estructura Visual
  ///
  /// La tarjeta está compuesta por:
  /// 1. **Container exterior**: Fondo oscuro (#2D2D2D) con bordes redondeados
  /// 2. **Borde decorativo**: Color temático con opacidad del 30%
  /// 3. **Contenedor de icono**: Fondo circular semi-transparente (20% opacidad)
  /// 4. **Icono**: Icono de Material Design con color temático
  /// 5. **Texto**: Título en blanco (peso 600) y descripción en gris claro
  ///
  /// ## Parámetros
  ///
  /// - [icon]: Icono de Material Design que representa visualmente la característica
  /// - [title]: Título corto y descriptivo de la funcionalidad
  /// - [description]: Descripción detallada que explica la característica
  /// - [color]: Color temático usado en el borde, icono y fondo del contenedor
  ///
  /// ## Diseño Responsivo
  ///
  /// El texto de la descripción utiliza [Expanded] para adaptarse al espacio
  /// disponible y evitar desbordamientos en diferentes tamaños de pantalla.
  ///
  /// ## Ejemplo de Uso
  ///
  /// ```dart
  /// _buildFeatureCard(
  ///   icon: Icons.play_circle_filled,
  ///   title: 'Reproducción',
  ///   description: 'Controles intuitivos de video',
  ///   color: Colors.blue,
  /// )
  /// ```
  ///
  /// ## Retorna
  ///
  /// Un [Widget] [Container] configurado con el diseño de tarjeta completo.
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
