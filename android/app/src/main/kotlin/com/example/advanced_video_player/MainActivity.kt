package com.example.advanced_video_player

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.advanced_video_player.PictureInPicturePlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Registrar el plugin de Picture-in-Picture manualmente
        val pipPlugin = PictureInPicturePlugin()
        flutterEngine.plugins.add(pipPlugin)
    }
}
