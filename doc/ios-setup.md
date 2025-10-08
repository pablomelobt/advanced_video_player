# Configuración iOS para Advanced Video Player

Esta guía te ayudará a configurar tu proyecto Flutter para usar todas las funcionalidades del Advanced Video Player en iOS.

## 📋 Requisitos

- **iOS**: 13.0+
- **Flutter**: >= 1.17.0
- **Xcode**: 12.0+
- **CocoaPods**: 1.10.0+

## ⚙️ Configuración Paso a Paso

### 1. Info.plist

Agrega las siguientes configuraciones en `ios/Runner/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Configuración básica de la app -->
    <key>CFBundleDisplayName</key>
    <string>Tu App</string>
    <key>CFBundleIdentifier</key>
    <string>com.tu_paquete.tu_app</string>
    
    <!-- Requisitos de iOS -->
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    
    <!-- Orientaciones soportadas -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    
    <!-- ⚙️ Configuración esencial para Video / PiP / AirPlay -->
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    
    <!-- Modos de fondo para PiP y audio -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>picture-in-picture</string>
    </array>
    
    <!-- Mejora la fluidez de video en dispositivos iPhone -->
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    
    <!-- Configuración de red para AirPlay -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    
    <!-- Soporte para AirPlay -->
    <key>AVAudioSessionCategory</key>
    <string>AVAudioSessionCategoryPlayback</string>
    
</dict>
</plist>
```

### 2. Podfile

Asegúrate de que tu `ios/Podfile` tenga la configuración correcta:

```ruby
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Configuración adicional para video
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
      ]
    end
  end
end
```

### 3. Instalación de Pods

Después de configurar el Podfile, ejecuta:

```bash
cd ios
pod install
cd ..
```

## 🔧 Configuraciones Específicas

### Para Picture-in-Picture (PiP)

- **Requisito**: `UIBackgroundModes` con `picture-in-picture`
- **iOS mínima**: iOS 14.0
- **Configuración**: Ya incluida en el Info.plist de arriba

### Para AirPlay

- **Requisitos**: 
  - `UIBackgroundModes` con `audio`
  - `AVAudioSessionCategory` configurado
  - `NSAppTransportSecurity` para redes
- **Configuración**: Ya incluida en el Info.plist de arriba

### Para Orientaciones

- **Configuración**: `UISupportedInterfaceOrientations` para iPhone
- **iPad**: `UISupportedInterfaceOrientations~ipad` para iPad
- **Configuración**: Ya incluida en el Info.plist de arriba

## 🚨 Solución de Problemas

### PiP no funciona
- Verifica que `UIBackgroundModes` contenga `picture-in-picture`
- Asegúrate de que la versión mínima de iOS sea 14.0+
- Verifica que el video no sea un asset local (PiP funciona mejor con URLs)

### AirPlay no aparece
- Verifica que `UIBackgroundModes` contenga `audio`
- Asegúrate de que `AVAudioSessionCategory` esté configurado
- Verifica que el dispositivo esté en la misma red Wi-Fi
- Asegúrate de que el dispositivo AirPlay esté configurado

### Orientación incorrecta
- Verifica `UISupportedInterfaceOrientations` en Info.plist
- Asegúrate de que las orientaciones deseadas estén incluidas
- Verifica que el dispositivo soporte las orientaciones configuradas

### Problemas de compilación
- Limpia el proyecto: `flutter clean`
- Reinstala pods: `cd ios && pod install && cd ..`
- Reconstruye: `flutter build ios`
- Verifica que todas las dependencias sean compatibles

### Problemas de red
- Verifica `NSAppTransportSecurity` en Info.plist
- Asegúrate de que `NSAllowsArbitraryLoads` esté en `true`
- Verifica que la URL del video sea HTTPS

## 📱 Pruebas

Para probar que todo funciona correctamente:

1. **Compila la app**: `flutter build ios`
2. **Instala en dispositivo**: `flutter install`
3. **Prueba PiP**: Reproduce un video y activa Picture-in-Picture
4. **Prueba AirPlay**: Intenta transmitir el video a un dispositivo AirPlay
5. **Prueba orientaciones**: Rota el dispositivo y verifica que funcione

## 🔗 Enlaces Útiles

- [Documentación oficial de AirPlay](https://developer.apple.com/documentation/avfoundation/avplayer)
- [Guía de Picture-in-Picture de iOS](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller)
- [Documentación de video_player](https://pub.dev/packages/video_player)
- [Guía de orientaciones de iOS](https://developer.apple.com/documentation/uikit/uiviewcontroller)
