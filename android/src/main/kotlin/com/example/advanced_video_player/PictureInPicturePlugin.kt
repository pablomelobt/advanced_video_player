package com.example.advanced_video_player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class PictureInPicturePlugin: FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "picture_in_picture_service")
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "picture_in_picture_service_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isPictureInPictureSupported" -> {
                result.success(isPictureInPictureSupported())
            }
            "enterPictureInPictureMode" -> {
                val width = call.argument<Double>("width") ?: 300.0
                val height = call.argument<Double>("height") ?: 200.0
                result.success(enterPictureInPictureMode(width, height))
            }
            "exitPictureInPictureMode" -> {
                result.success(exitPictureInPictureMode())
            }
            "isInPictureInPictureMode" -> {
                result.success(isInPictureInPictureMode())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isPictureInPictureSupported(): Boolean {
        return activity?.packageManager?.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE) ?: false
    }

    private fun enterPictureInPictureMode(width: Double, height: Double): Boolean {
        val currentActivity = activity ?: return false
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ratio = Rational(width.toInt(), height.toInt())
            val pipParams = PictureInPictureParams.Builder()
                .setAspectRatio(ratio)
                .build()
            
            // Configurar la Activity para PiP
            currentActivity.setPictureInPictureParams(pipParams)
            currentActivity.enterPictureInPictureMode(pipParams)
            
            // Notificar cambio de estado
            eventSink?.success(true)
            return true
        }
        return false
    }

    private fun exitPictureInPictureMode(): Boolean {
        // En Android, el usuario debe salir manualmente del modo PiP
        // No hay una API directa para forzar la salida
        return true
    }

    private fun isInPictureInPictureMode(): Boolean {
        return activity?.isInPictureInPictureMode ?: false
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}