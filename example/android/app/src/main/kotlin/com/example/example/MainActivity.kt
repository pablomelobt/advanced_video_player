package com.example.example

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    private val TAG = "MainActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity creada")
    }
    
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        Log.d(TAG, "PiP mode changed: $isInPictureInPictureMode")
        
        // El PictureInPicturePlugin escuchará estos cambios automáticamente
        // a través de su implementación de ActivityAware
    }
    
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Si está en modo PiP, no hacer nada con el botón back
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
            // No llamar a super, para que no cierre el PiP
            return
        }
        super.onBackPressed()
    }
}