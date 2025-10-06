package com.example.advanced_video_player

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class PictureInPictureActivity : FlutterActivity() {
    private var isInPictureInPictureMode = false
    private var videoUrl: String? = null
    private var videoTitle: String? = null
    private var aspectRatio: Double = 16.0 / 9.0

    companion object {
        private const val TAG = "PictureInPictureActivity"
        private const val CHANNEL_NAME = "picture_in_picture_service"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Obtener parámetros del video
        videoUrl = intent.getStringExtra("video_url")
        videoTitle = intent.getStringExtra("video_title")
        aspectRatio = intent.getDoubleExtra("aspect_ratio", 16.0 / 9.0)
        
        Log.d(TAG, "PictureInPictureActivity creada - Video: $videoTitle, Aspect ratio: $aspectRatio")
        
        // Configurar para modo PiP
        setupPictureInPicture()
    }

    private fun setupPictureInPicture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val aspectRatio = Rational(
                (this.aspectRatio * 1000).toInt(),
                1000
            )
            
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .build()
            
            setPictureInPictureParams(pipParams)
            Log.d(TAG, "Parámetros de PiP configurados: $aspectRatio")
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        
        this.isInPictureInPictureMode = isInPictureInPictureMode
        
        if (isInPictureInPictureMode) {
            Log.d(TAG, "Entrando en modo Picture-in-Picture")
            // Ocultar controles y mostrar solo el video
            hideControls()
        } else {
            Log.d(TAG, "Saliendo del modo Picture-in-Picture")
            // Mostrar controles nuevamente
            showControls()
        }
    }

    private fun hideControls() {
        // En modo PiP, ocultar todos los controles y mostrar solo el video
        val rootView = findViewById<View>(android.R.id.content)
        if (rootView is FrameLayout) {
            // Aquí podrías implementar lógica para ocultar controles específicos
            Log.d(TAG, "Controles ocultados para modo PiP")
        }
    }

    private fun showControls() {
        // Restaurar controles cuando se sale del modo PiP
        val rootView = findViewById<View>(android.R.id.content)
        if (rootView is FrameLayout) {
            Log.d(TAG, "Controles restaurados")
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        
        // Cuando el usuario sale de la app, entrar automáticamente en modo PiP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !isInPictureInPictureMode) {
            val aspectRatio = Rational(
                (this.aspectRatio * 1000).toInt(),
                1000
            )
            
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .build()
            
            enterPictureInPictureMode(pipParams)
            Log.d(TAG, "Entrando automáticamente en modo PiP")
        }
    }

    override fun onBackPressed() {
        if (isInPictureInPictureMode) {
            // En modo PiP, no hacer nada al presionar back
            Log.d(TAG, "Back presionado en modo PiP - ignorado")
            return
        }
        super.onBackPressed()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "PictureInPictureActivity destruida")
    }
}
