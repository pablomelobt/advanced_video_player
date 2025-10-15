# Advanced Video Player

[![pub package](https://img.shields.io/pub/v/advanced_video_player.svg)](https://pub.dev/packages/advanced_video_player)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.4.4+-blue.svg)](https://flutter.dev)

Un reproductor de video avanzado para Flutter con controles modernos, diseño atractivo y funcionalidades completas de streaming y compartir pantalla.

## ✨ Características Principales

### 🎬 Reproductor de Video Avanzado
- **Soporte Multi-fuente**: URLs de red, assets locales y streams
- **Controles Intuitivos**: Play/Pause, retroceder, avanzar y pantalla completa
- **Barra de Progreso Interactiva**: Navegación precisa por el video
- **Indicadores de Tiempo**: Tiempo actual y duración total
- **Estados Manejados**: Carga, error, reproducción y finalización

### 🎨 Diseño y UX
- **UI Moderna**: Diseño atractivo con gradientes y animaciones suaves
- **Controles Automáticos**: Aparecen y desaparecen inteligentemente
- **Personalización Completa**: Colores, duración de salto y más
- **Responsivo**: Optimizado para web, móvil y tablet

### 📱 Funcionalidades Avanzadas
- **Picture-in-Picture (PiP)**: Reproducción en ventana flotante
- **Screen Sharing**: Compartir video a Chromecast y dispositivos compatibles
- **AirPlay**: Soporte nativo para AirPlay en iOS
- **Google Cast**: Integración completa con Google Cast


## 🚀 Instalación

Agrega esta dependencia a tu archivo `pubspec.yaml`:

```yaml
dependencies:
  advanced_video_player: ^1.0.0
```

Luego ejecuta:

```bash
flutter pub get
```

### 📋 Requisitos

- **Flutter**: >= 1.17.0
- **Dart**: >= 3.4.4
- **Android**: API 21+ (Android 5.0+)
- **iOS**: 11.0+

### 📦 Dependencias Incluidas

El paquete incluye automáticamente:
- `video_player: ^2.8.1` - Reproductor de video base
- `url_launcher: ^6.2.2` - Apertura de URLs externas

## ⚙️ Configuración Requerida

> **⚠️ Importante**: Para usar todas las funcionalidades del reproductor, necesitas configurar tu proyecto Flutter con los permisos y configuraciones necesarias.

### 📋 Configuraciones Mínimas Requeridas

#### Android
- **Permisos de red** en `AndroidManifest.xml`
- **Soporte para Picture-in-Picture** en la actividad principal
- **Dependencias de Google Cast** en `build.gradle`

#### iOS  
- **Modos de fondo** para PiP y audio en `Info.plist`
- **Orientaciones soportadas** para pantalla completa
- **Configuración de red** para AirPlay

### 📖 Documentación de Configuración

Para ver las configuraciones detalladas paso a paso, consulta:

- **[Guía de Configuración Android](docs/android-setup.md)**
- **[Guía de Configuración iOS](docs/ios-setup.md)**

### 🚨 Solución de Problemas Comunes

#### Android
- **Error de permisos**: Verifica que todos los permisos estén en AndroidManifest.xml
- **Problemas de PiP**: Asegúrate de que `supportsPictureInPicture="true"`
- **Google Cast no funciona**: Verifica las dependencias en build.gradle

#### iOS
- **PiP no funciona**: Verifica `UIBackgroundModes` en Info.plist
- **AirPlay no aparece**: Asegúrate de tener `audio` en `UIBackgroundModes`
- **Orientación incorrecta**: Verifica `UISupportedInterfaceOrientations`

## Uso Básico

```dart
import 'package:advanced_video_player/advanced_video_player.dart';

AdvancedVideoPlayer(
  videoSource: 'https://example.com/video.mp4',
  onVideoEnd: () {
    print('Video terminado');
  },
  onError: (error) {
    print('Error: $error');
  },
)
```

## 📋 Parámetros de Configuración

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `videoSource` | `String` | **Requerido** | URL del video o ruta del asset |
| `isAsset` | `bool` | `false` | Si es `true`, trata `videoSource` como asset local |
| `onVideoEnd` | `VoidCallback?` | `null` | Callback cuando el video termina |
| `onError` | `Function(String)?` | `null` | Callback cuando ocurre un error |
| `skipDuration` | `int` | `10` | Segundos para retroceder/avanzar |
| `enablePictureInPicture` | `bool` | `true` | Habilita el botón de Picture-in-Picture |
| `enableScreenSharing` | `bool` | `true` | Habilita el botón de compartir pantalla |
| `enableAirPlay` | `bool` | `true` | Habilita el botón de AirPlay (solo iOS) |
| `videoTitle` | `String?` | `null` | Título del video para compartir |
| `videoDescription` | `String?` | `null` | Descripción del video para compartir |
| `primaryColor` | `Color` | `Color(0xFF6366F1)` | Color principal del reproductor |
| `secondaryColor` | `Color` | `Color(0xFF8B5CF6)` | Color secundario del reproductor |
| `previewImageUrl` | `String?` | `null` | 🆕 URL de imagen de preview/thumbnail mientras carga el video |
| `useNativePlayerOnIOS` | `bool` | `false` | 🆕 Usa reproductor nativo optimizado en iOS para mejor PiP |

## 🎯 Ejemplos de Uso

### Uso Básico

```dart
import 'package:flutter/material.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Reproductor')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800,
            maxHeight: 450,
          ),
          child: AdvancedVideoPlayer(
            videoSource: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            onVideoEnd: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Video terminado!')),
              );
            },
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $error')),
              );
            },
            primaryColor: Colors.blue,
            secondaryColor: Colors.purple,
            skipDuration: 15,
          ),
        ),
      ),
    );
  }
}
```

### Uso Avanzado con Todas las Funcionalidades

```dart
AdvancedVideoPlayer(
  videoSource: 'https://example.com/video.mp4',
  isAsset: false,
  onVideoEnd: () => print('Video terminado'),
  onError: (error) => print('Error: $error'),
  skipDuration: 30,
  
  // 🆕 Nuevas funcionalidades (v0.0.3)
  previewImageUrl: 'https://example.com/thumbnail.jpg', // Preview mientras carga
  useNativePlayerOnIOS: true, // Mejor PiP en iOS
  
  // Funcionalidades avanzadas
  enablePictureInPicture: true,
  enableScreenSharing: true,
  enableAirPlay: true,
  
  // Metadatos para compartir
  videoTitle: 'Mi Video Favorito',
  videoDescription: 'Un video increíble compartido desde mi app',
  
  // Personalización visual
  primaryColor: Colors.deepPurple,
  secondaryColor: Colors.orange,
)
```

### Video Local (Asset)

```dart
AdvancedVideoPlayer(
  videoSource: 'assets/videos/mi_video.mp4',
  isAsset: true,
  videoTitle: 'Video Local',
  enablePictureInPicture: false, // PiP puede no funcionar con assets
)
```

### Configuración Mínima para Streaming

```dart
AdvancedVideoPlayer(
  videoSource: 'https://stream.example.com/live.m3u8',
  previewImageUrl: 'https://example.com/stream-thumbnail.jpg', // 🆕 Preview del stream
  enableScreenSharing: true,
  enableAirPlay: true,
  videoTitle: 'Stream en Vivo',
  useNativePlayerOnIOS: true, // 🆕 Mejor rendimiento en iOS
)
```

## 🎮 Controles Disponibles

### Controles Básicos
- **▶️ Play/Pause**: Botón central para reproducir o pausar
- **⏪ Retroceder**: Retrocede X segundos (configurable con `skipDuration`)
- **⏩ Avanzar**: Avanza X segundos (configurable con `skipDuration`)
- **⛶ Pantalla Completa**: Alterna entre modo normal y pantalla completa

### Controles Avanzados
- **🖼️ Picture-in-Picture**: Reproduce el video en una ventana flotante
- **📺 Screen Sharing**: Comparte el video a Chromecast y dispositivos compatibles
- **📱 AirPlay**: Transmite el video a dispositivos Apple (solo iOS)

### Funcionalidades Automáticas
- **👁️ Controles Inteligentes**: Aparecen y desaparecen automáticamente
- **⏰ Indicadores de Tiempo**: Muestra tiempo actual y duración total
- **🔄 Estados Manejados**: Carga, error, reproducción y finalización
- **📱 Responsivo**: Se adapta automáticamente al tamaño de pantalla

## 🎨 Personalización

### Colores Personalizados

```dart
AdvancedVideoPlayer(
  videoSource: 'your_video_url',
  primaryColor: Colors.red,
  secondaryColor: Colors.orange,
)
```

### Duración de Salto Personalizada

```dart
AdvancedVideoPlayer(
  videoSource: 'your_video_url',
  skipDuration: 30, // 30 segundos
)
```

### Video Local (Asset)

```dart
AdvancedVideoPlayer(
  videoSource: 'assets/videos/my_video.mp4',
  isAsset: true,
)
```

## 🚀 Funcionalidades Avanzadas

### Picture-in-Picture (PiP)

El reproductor soporta Picture-in-Picture nativo en ambas plataformas con una experiencia mejorada:

**🎨 Vista Personalizada en iOS**: Cuando se activa PiP en iOS, se muestra una vista personalizada con icono y texto (similar a Disney+) en lugar de una pantalla negra. La vista incluye un icono de dos rectángulos superpuestos y el texto "Video reproduciéndose en imagen dentro de otra (PIP)."

```dart
AdvancedVideoPlayer(
  videoSource: 'your_video_url',
  enablePictureInPicture: true, // Habilitado por defecto
)
```

**Requisitos:**
- **Android**: API 24+ (Android 7.0+)
- **iOS**: iOS 14.0+

### Screen Sharing / Google Cast

Comparte videos a dispositivos Chromecast y compatibles:

```dart
AdvancedVideoPlayer(
  videoSource: 'your_video_url',
  enableScreenSharing: true, // Habilitado por defecto
  videoTitle: 'Mi Video',
  videoDescription: 'Descripción del video',
)
```

**Características:**
- Descubrimiento automático de dispositivos
- Soporte para múltiples tipos de dispositivos
- Reconexión automática

### AirPlay (iOS)

Transmite videos a dispositivos Apple:

```dart
AdvancedVideoPlayer(
  videoSource: 'your_video_url',
  enableAirPlay: true, // Habilitado por defecto en iOS
)
```

**Requisitos:**
- **iOS**: iOS 11.0+
- Dispositivos Apple compatibles (Apple TV, AirPlay speakers, etc.)

---

## 🎬 NativeVideoPlayer (iOS 15+)

### Reproductor Nativo con Arquitectura Avanzada

El `NativeVideoPlayer` es un nuevo widget que utiliza la arquitectura nativa de iOS sin dummy views.

#### ✨ Características Únicas

- ✅ **Sin dummy views** fuera de pantalla
- ✅ **Comportamiento 100% nativo** de iOS
- ✅ **PiP limpio** y sin efectos secundarios
- ✅ **Restauración automática a fullscreen** 
- ✅ **Navegación inteligente** cuando el usuario vuelve desde PiP
- ✅ **Múltiples instancias** de video independientes

#### 📖 Uso Básico

```dart
import 'package:advanced_video_player/native_video_player.dart';

NativeVideoPlayer(
  url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  autoplay: true,
  onViewCreated: (controller) {
    // Controlar el player
    controller.play();
    controller.pause();
    controller.seek(10.0);
    controller.startPiP();
  },
)
```

#### 🎯 Restauración Automática a Fullscreen

**La funcionalidad estrella**: Cuando el usuario toca la ventana PiP para volver a la app, automáticamente se navega a una pantalla fullscreen del video.

```dart
NativeVideoPlayer(
  url: 'https://example.com/video.mp4',
  autoplay: true,
  
  // Evento cuando se activa PiP
  onPipStarted: () {
    print('✅ PiP activado');
  },
  
  // Evento cuando se detiene PiP
  onPipStopped: () {
    print('⏹️ PiP detenido');
  },
  
  // ⭐ Evento cuando el usuario vuelve desde PiP
  onPipRestoreToFullscreen: () {
    print('🎬 Usuario volvió desde PiP → Navegando a fullscreen');
    

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPage(),
      ),
    );
  },
)
```

#### 🎮 Métodos del Controller

```dart
final controller = NativeVideoPlayerController._(...);

// Control de reproducción
await controller.play();           // Reproducir
await controller.pause();          // Pausar
await controller.seek(30.0);       // Saltar a 30 segundos
await controller.setVolume(0.5);   // Volumen al 50%

// Control de PiP
await controller.startPiP();       // Activar PiP
await controller.stopPiP();        // Detener PiP

// Cambiar video
await controller.setUrl(
  'https://example.com/new_video.mp4',
  autoplay: true,
);
```

#### 🎯 Ejemplo Completo

Ver el ejemplo completo en [`example/lib/native_player_example.dart`](example/lib/native_player_example.dart)

#### 📚 Documentación Adicional

Para entender cómo funciona internamente la restauración automática a fullscreen:
- **[Restauración Automática a Fullscreen](doc/pip-fullscreen-restoration.md)**

#### ⚠️ Requisitos

- **iOS**: 15.0+ (para arquitectura nativa sin dummy views)
- **PiP Support**: El dispositivo debe soportar Picture-in-Picture
- **Permisos**: Configuración correcta de `Info.plist` (ver [Guía iOS](doc/ios-setup.md))



## 🧪 Ejecutar el Ejemplo

Para ver el reproductor en acción:

```bash
cd example
flutter pub get
flutter run
```

### Plataformas Soportadas

- ✅ **Android** (API 21+)
- ✅ **iOS** (11.0+)


## 🤝 Contribuir

Las contribuciones son bienvenidas! Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

### Guías de Contribución

- Sigue las convenciones de código de Flutter
- Añade tests para nuevas funcionalidades
- Actualiza la documentación cuando sea necesario
- Verifica que funcione en ambas plataformas

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 📝 Changelog

### 0.0.3 (Actual)
- 🖼️ **NUEVO**: Preview/Thumbnail personalizado con `previewImageUrl`
- 🎬 **NUEVO**: Reproductor nativo iOS optimizado con `useNativePlayerOnIOS`
- 📚 Documentación profesional completa con DartDoc
- 🎨 Mejoras en la experiencia de usuario
- 🔧 Optimizaciones de código y performance
- 📖 Ejemplos actualizados con comentarios profesionales

### 0.0.2
- 🚀 Mejoras de calidad y optimización
- 📦 Dependencias actualizadas (video_player 2.9.5, url_launcher 6.3.1)
- 🐛 Correcciones de bugs y memory leaks
- 📊 Análisis de código optimizado (0 errores de linter)

### 0.0.1
- ✨ Versión inicial
- 🎬 Reproductor de video básico con controles modernos
- 🌐 Soporte para URLs de red y assets locales
- 🎨 UI personalizable con gradientes
- ⚡ Manejo de estados (carga, error, finalización)
- 🖼️ Picture-in-Picture nativo (Android/iOS)
- 📺 Screen Sharing con Google Cast
- 📱 Soporte para AirPlay (iOS)
- 🎮 Controles avanzados y personalizables

## 🆘 Soporte

Si encuentras algún problema o tienes preguntas:

1. Revisa la sección de [Solución de Problemas](#-solución-de-problemas-comunes)
2. Busca en los [Issues existentes](https://github.com/tu-usuario/advanced_video_player/issues)
3. Crea un nuevo issue con detalles del problema
4. Incluye logs y configuración de tu dispositivo

