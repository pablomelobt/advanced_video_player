# Advanced Video Player

Un reproductor de video avanzado para Flutter con controles modernos, diseño atractivo y funcionalidades completas.

## Características

- 🎬 **Reproductor de Video Completo**: Soporte para URLs de red y assets locales
- 🎮 **Controles Intuitivos**: Play/Pause, retroceder, avanzar y pantalla completa
- 📊 **Barra de Progreso Interactiva**: Haz clic para saltar a cualquier posición
- ⏰ **Indicador de Tiempo**: Muestra tiempo actual y duración total
- 🎨 **Diseño Moderno**: UI atractiva con gradientes y animaciones suaves
- 👁️ **Controles Automáticos**: Aparecen y desaparecen automáticamente
- 🎯 **Personalizable**: Colores y duración de salto configurables
- ⚡ **Estados Manejados**: Carga, error y finalización del video
- 📱 **Responsivo**: Optimizado para web y dispositivos

## Instalación

Agrega esta dependencia a tu archivo `pubspec.yaml`:

```yaml
dependencies:
  advanced_video_player: ^0.0.1
```

Luego ejecuta:

```bash
flutter pub get
```

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

## Parámetros de Configuración

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `videoSource` | `String` | **Requerido** | URL del video o ruta del asset |
| `isAsset` | `bool` | `false` | Si es `true`, trata `videoSource` como asset local |
| `onVideoEnd` | `VoidCallback?` | `null` | Callback cuando el video termina |
| `onError` | `Function(String)?` | `null` | Callback cuando ocurre un error |
| `skipDuration` | `int` | `10` | Segundos para retroceder/avanzar |
| `primaryColor` | `Color` | `Color(0xFF6366F1)` | Color principal del reproductor |
| `secondaryColor` | `Color` | `Color(0xFF8B5CF6)` | Color secundario del reproductor |

## Ejemplo Completo

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

## Controles Disponibles

- **▶️ Play/Pause**: Botón central para reproducir o pausar
- **⏪ Retroceder**: Retrocede 10 segundos (configurable)
- **⏩ Avanzar**: Avanza 10 segundos (configurable)
- **⛶ Pantalla Completa**: Alterna entre modo normal y pantalla completa
- **📊 Barra de Progreso**: Haz clic para saltar a cualquier posición

## Personalización

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

## Ejecutar el Ejemplo

Para ver el reproductor en acción:

```bash
cd example
flutter pub get
flutter run
```

## Contribuir

Las contribuciones son bienvenidas! Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## Changelog

### 0.0.1
- Versión inicial
- Reproductor de video básico con controles modernos
- Soporte para URLs de red y assets locales
- UI personalizable con gradientes
- Manejo de estados (carga, error, finalización)