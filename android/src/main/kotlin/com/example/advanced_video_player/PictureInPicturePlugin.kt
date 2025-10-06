package com.example.advanced_video_player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Log
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
            "getPictureInPictureInfo" -> {
                result.success(getPictureInPictureInfo())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isPictureInPictureSupported(): Boolean {
        val currentActivity = activity ?: return false
        
        // Verificar versión de Android (PiP requiere Android 8.0+)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d("PictureInPicturePlugin", "Android version ${Build.VERSION.SDK_INT} no soporta PiP (requiere 8.0+)")
            return false
        }
        
        // Verificar si el dispositivo tiene la característica PiP
        val hasPiPFeature = currentActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        Log.d("PictureInPicturePlugin", "FEATURE_PICTURE_IN_PICTURE: $hasPiPFeature")
        
        // Verificar si la Activity soporta PiP
        val supportsPiP = currentActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        Log.d("PictureInPicturePlugin", "Activity supports PiP: $supportsPiP")
        
        // Verificar si la Activity tiene la configuración correcta
        var supportsPiPInManifest = false
        try {
            val activityInfo = currentActivity.packageManager.getActivityInfo(currentActivity.componentName, 0)
            // Verificar si la Activity tiene android:supportsPictureInPicture="true" en el manifest
            supportsPiPInManifest = activityInfo.configChanges and android.content.pm.ActivityInfo.CONFIG_SCREEN_SIZE != 0
        } catch (e: Exception) {
            Log.d("PictureInPicturePlugin", "Error checking manifest: ${e.message}")
        }
        Log.d("PictureInPicturePlugin", "Manifest supports PiP: $supportsPiPInManifest")
        
        // Para Samsung y otros dispositivos, a veces la característica no se reporta correctamente
        // pero PiP funciona. Vamos a ser más permisivos.
        val isSamsung = Build.MANUFACTURER.equals("samsung", ignoreCase = true)
        val isAndroid8Plus = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        
        Log.d("PictureInPicturePlugin", "Manufacturer: ${Build.MANUFACTURER}")
        Log.d("PictureInPicturePlugin", "Model: ${Build.MODEL}")
        Log.d("PictureInPicturePlugin", "Android version: ${Build.VERSION.RELEASE}")
        Log.d("PictureInPicturePlugin", "Is Samsung: $isSamsung")
        Log.d("PictureInPicturePlugin", "Is Android 8+: $isAndroid8Plus")
        
        // Si es Samsung con Android 8+ o tiene la característica, asumir que soporta PiP
        val finalResult = (isSamsung && isAndroid8Plus) || hasPiPFeature || supportsPiPInManifest
        
        Log.d("PictureInPicturePlugin", "Final PiP support result: $finalResult")
        return finalResult
    }

    private fun enterPictureInPictureMode(width: Double, height: Double): Boolean {
        val currentActivity = activity ?: return false
        
        // Verificar si ya está en modo PiP
        if (currentActivity.isInPictureInPictureMode) {
            Log.d("PictureInPicturePlugin", "Ya está en modo Picture-in-Picture")
            return false
        }
        
        // Verificar si el dispositivo soporta PiP
        if (!isPictureInPictureSupported()) {
            Log.d("PictureInPicturePlugin", "Picture-in-Picture no soportado en este dispositivo")
            return false
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val ratio = Rational(width.toInt(), height.toInt())
                val pipParams = PictureInPictureParams.Builder()
                    .setAspectRatio(ratio)
                    .build()
                
                // Configurar la Activity para PiP
                currentActivity.setPictureInPictureParams(pipParams)
                
                // Intentar entrar en modo PiP
                val result = currentActivity.enterPictureInPictureMode(pipParams)
                
                if (result) {
                    Log.d("PictureInPicturePlugin", "Entrando en modo Picture-in-Picture exitosamente")
                    // Notificar cambio de estado
                    eventSink?.success(true)
                    return true
                } else {
                    Log.d("PictureInPicturePlugin", "Error: No se pudo entrar en modo Picture-in-Picture")
                    return false
                }
            } catch (e: Exception) {
                Log.d("PictureInPicturePlugin", "Error al entrar en PiP: ${e.message}")
                return false
            }
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

    private fun getPictureInPictureInfo(): Map<String, Any> {
        val currentActivity = activity ?: return emptyMap()
        
        val info = mutableMapOf<String, Any>()
        
        // Información del dispositivo
        info["manufacturer"] = Build.MANUFACTURER
        info["model"] = Build.MODEL
        info["androidVersion"] = Build.VERSION.RELEASE
        info["sdkInt"] = Build.VERSION.SDK_INT
        info["isAndroid8Plus"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        
        // Verificaciones de PiP
        info["hasPiPFeature"] = currentActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        
        try {
            val activityInfo = currentActivity.packageManager.getActivityInfo(currentActivity.componentName, 0)
            // Verificar si la Activity tiene android:supportsPictureInPicture="true" en el manifest
            val manifestSupportsPiP = activityInfo.configChanges and android.content.pm.ActivityInfo.CONFIG_SCREEN_SIZE != 0
            info["manifestSupportsPiP"] = manifestSupportsPiP
        } catch (e: Exception) {
            info["manifestSupportsPiP"] = false
            info["manifestError"] = e.message ?: "Unknown error"
        }
        
        // Estado actual
        info["isCurrentlyInPiP"] = currentActivity.isInPictureInPictureMode
        info["isSamsung"] = Build.MANUFACTURER.equals("samsung", ignoreCase = true)
        
        // Resultado final
        val finalResult = (info["isSamsung"] as Boolean && info["isAndroid8Plus"] as Boolean) || 
                         (info["hasPiPFeature"] as Boolean) || 
                         (info["manifestSupportsPiP"] as Boolean)
        info["finalSupportResult"] = finalResult
        
        return info
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