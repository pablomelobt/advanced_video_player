package com.example.example

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.advanced_video_player.PictureInPicturePlugin

class MainActivity: FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // El plugin se registrará automáticamente a través del GeneratedPluginRegistrant
        // No necesitamos registrarlo manualmente aquí
    }
    
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        
        if (isInPictureInPictureMode) {
            // La app entró en modo Picture-in-Picture
            // El video debería continuar reproduciéndose automáticamente
        } else {
            // La app salió del modo Picture-in-Picture
        }
    }
}
