# Configuración Android para Advanced Video Player

Esta guía te ayudará a configurar tu proyecto Flutter para usar todas las funcionalidades del Advanced Video Player en Android.

## 📋 Requisitos

- **Android API**: 21+ (Android 5.0+)
- **Flutter**: >= 1.17.0
- **Gradle**: 7.0+

## ⚙️ Configuración Paso a Paso

### 1. AndroidManifest.xml

Agrega los siguientes permisos y configuraciones en `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permisos necesarios para el reproductor -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    
    <application
        android:label="tu_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Actividad principal con soporte para PiP -->
        <activity
            android:name="com.tu_paquete.tu_app.MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:supportsPictureInPicture="true"
            android:resizeableActivity="true"
            android:showWhenLocked="true"
            android:turnScreenOn="true">
            
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- Actividad dedicada para Picture-in-Picture -->
        <activity
            android:name="com.tu_paquete.advanced_video_player.PictureInPictureActivity"
            android:supportsPictureInPicture="true"
            android:resizeableActivity="true"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:launchMode="singleTop"
            android:exported="false"
            android:screenOrientation="unspecified"
            android:theme="@android:style/Theme.Material.Light.NoActionBar" />
    </application>
    
    <!-- Queries para compatibilidad con Android 11+ -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>
```

### 2. build.gradle

Agrega las dependencias de Google Cast en `android/app/build.gradle`:

```gradle
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:$kotlin_version"
    implementation 'com.google.android.gms:play-services-cast-framework:21.4.0'
    implementation 'com.google.android.gms:play-services-base:18.2.0'
    implementation 'com.google.guava:guava:31.1-android'
}
```

### 3. Configuración de ProGuard (Opcional)

Si usas ProGuard, agrega estas reglas en `android/app/proguard-rules.pro`:

```proguard
# Google Cast
-keep class com.google.android.gms.cast.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.base.** { *; }

# Video Player
-keep class io.flutter.plugins.videoplayer.** { *; }
```

## 🔧 Configuraciones Específicas

### Para Picture-in-Picture (PiP)

- **Requisito**: `android:supportsPictureInPicture="true"` en la actividad
- **API mínima**: Android 7.0 (API 24)
- **Configuración**: Ya incluida en el AndroidManifest.xml de arriba

### Para Screen Sharing / Google Cast

- **Requisitos**: Permisos de red y dependencias de Google Cast
- **Configuración**: Ya incluida en los pasos anteriores

## 🚨 Solución de Problemas

### Error de permisos
- Verifica que todos los permisos estén en AndroidManifest.xml
- Asegúrate de que los permisos estén dentro del tag `<manifest>`

### Problemas de PiP
- Verifica que `supportsPictureInPicture="true"` esté en la actividad principal
- Asegúrate de que la API mínima sea 24+

### Google Cast no funciona
- Verifica que las dependencias estén en build.gradle
- Asegúrate de que el dispositivo esté en la misma red Wi-Fi
- Verifica que el dispositivo Chromecast esté configurado

### Problemas de compilación
- Limpia el proyecto: `flutter clean`
- Reconstruye: `flutter build apk`
- Verifica que todas las dependencias sean compatibles

## 📱 Pruebas

Para probar que todo funciona correctamente:

1. **Compila la app**: `flutter build apk`
2. **Instala en dispositivo**: `flutter install`
3. **Prueba PiP**: Reproduce un video y activa Picture-in-Picture
4. **Prueba Cast**: Intenta compartir el video a un dispositivo Chromecast

## 🔗 Enlaces Útiles

- [Documentación oficial de Google Cast](https://developers.google.com/cast/docs/android_sender)
- [Guía de Picture-in-Picture de Android](https://developer.android.com/guide/topics/ui/picture-in-picture)
- [Documentación de video_player](https://pub.dev/packages/video_player)
