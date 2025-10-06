package com.example.advanced_video_player

import io.flutter.embedding.engine.plugins.FlutterPlugin

object AdvancedVideoPlayerPluginRegistrant {
    fun registerWith(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val plugin = PictureInPicturePlugin()
        plugin.onAttachedToEngine(flutterPluginBinding)
    }
}
