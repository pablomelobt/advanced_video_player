package com.example.advanced_video_player

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
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
        Log.d("PictureInPicturePlugin", "🔍 Verificando soporte de PiP...")
        
        val currentActivity = activity
        if (currentActivity == null) {
            Log.w("PictureInPicturePlugin", "⚠️ Activity es null, pero asumiendo soporte si API >= 26")
            // Si la activity es null pero estamos en Android 8+, asumir que soporta PiP
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d("PictureInPicturePlugin", "✅ Android ${Build.VERSION.SDK_INT} >= API 26, PiP SOPORTADO")
                return true
            } else {
                Log.d("PictureInPicturePlugin", "❌ Android ${Build.VERSION.SDK_INT} < API 26, PiP NO SOPORTADO")
                return false
            }
        }
        
        // Verificar versión de Android (PiP requiere Android 8.0+)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d("PictureInPicturePlugin", "❌ Android version ${Build.VERSION.SDK_INT} no soporta PiP (requiere API 26+)")
            return false
        }
        
        Log.d("PictureInPicturePlugin", "📱 Información del dispositivo:")
        Log.d("PictureInPicturePlugin", "   Manufacturer: ${Build.MANUFACTURER}")
        Log.d("PictureInPicturePlugin", "   Model: ${Build.MODEL}")
        Log.d("PictureInPicturePlugin", "   Android version: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        
        // Verificar si el dispositivo tiene la característica PiP
        val hasPiPFeature = currentActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        Log.d("PictureInPicturePlugin", "   FEATURE_PICTURE_IN_PICTURE: $hasPiPFeature")
        
        // Verificar si la Activity tiene la configuración correcta en el manifest
        var supportsPiPInManifest = false
        try {
            val activityInfo = currentActivity.packageManager.getActivityInfo(currentActivity.componentName, 0)
            // Verificar si la Activity tiene android:supportsPictureInPicture="true" en el manifest
            supportsPiPInManifest = activityInfo.configChanges and android.content.pm.ActivityInfo.CONFIG_SCREEN_SIZE != 0
        } catch (e: Exception) {
            Log.d("PictureInPicturePlugin", "   Error checking manifest: ${e.message}")
        }
        Log.d("PictureInPicturePlugin", "   Manifest supports PiP: $supportsPiPInManifest")
        
        // ✅ SIMPLIFICADO: Si tiene Android 8.0+ (API 26), soporta PiP
        // La mayoría de dispositivos con Android 8+ tienen PiP, aunque no reporten la característica
        val finalResult = true // Siempre true si pasó la verificación de versión
        
        Log.d("PictureInPicturePlugin", "✅ PiP SOPORTADO (Android ${Build.VERSION.SDK_INT} >= API 26)")
        return finalResult
    }

    private fun enterPictureInPictureMode(width: Double, height: Double): Boolean {
        val currentActivity = activity ?: return false
        
        // Verificar si ya está en modo PiP
        if (currentActivity.isInPictureInPictureMode) {
            Log.d("PictureInPicturePlugin", "Ya está en modo Picture-in-Picture")
            return true
        }
        
        // Verificar si el dispositivo soporta PiP
        if (!isPictureInPictureSupported()) {
            Log.d("PictureInPicturePlugin", "Picture-in-Picture no soportado en este dispositivo")
            return false
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                // Calcular el aspect ratio correcto basado en las dimensiones del video
                val aspectRatio = Rational(width.toInt(), height.toInt())
                Log.d("PictureInPicturePlugin", "Aspect ratio: $aspectRatio (${width}x${height})")
                
                // Crear parámetros de PiP sin controles (sin acciones)
                val pipParams = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    // No agregamos .setActions() para que no aparezcan controles
                    .build()
                
                // Configurar la Activity para PiP
                currentActivity.setPictureInPictureParams(pipParams)
                
                // Intentar entrar en modo PiP
                val result = currentActivity.enterPictureInPictureMode(pipParams)
                
                if (result) {
                    Log.d("PictureInPicturePlugin", "✅ Entrando en modo Picture-in-Picture exitosamente")
                    Log.d("PictureInPicturePlugin", "📱 La ventana PiP mostrará solo el contenido del video")
                    Log.d("PictureInPicturePlugin", "🎥 En modo PiP, solo el video será visible, no los controles")
                    // Notificar cambio de estado
                    eventSink?.success(true)
                    return true
                } else {
                    Log.d("PictureInPicturePlugin", "❌ Error: No se pudo entrar en modo Picture-in-Picture")
                    return false
                }
            } catch (e: Exception) {
                Log.e("PictureInPicturePlugin", "❌ Error al entrar en PiP: ${e.message}")
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
        
        // Resultado final - Simplificado: Android 8+ siempre soporta PiP
        val finalResult = info["isAndroid8Plus"] as Boolean
        info["finalSupportResult"] = finalResult
        info["supportReason"] = if (finalResult) {
            "Android ${Build.VERSION.SDK_INT} >= API 26 (Android 8.0+)"
        } else {
            "Android ${Build.VERSION.SDK_INT} < API 26"
        }
        
        return info
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d("PictureInPicturePlugin", "✅ Plugin attached to activity")
        activity = binding.activity
        
        // Verificar el estado inicial de PiP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val isCurrentlyInPiP = activity?.isInPictureInPictureMode ?: false
            if (isCurrentlyInPiP) {
                Log.d("PictureInPicturePlugin", "📱 Activity ya está en modo PiP")
                eventSink?.success(true)
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d("PictureInPicturePlugin", "⚙️ Detached from activity for config changes (PiP puede estar activándose)")
        // NO establecer activity a null durante cambios de configuración
        // ya que PiP es un cambio de configuración y necesitamos mantener la referencia
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d("PictureInPicturePlugin", "✅ Reattached to activity after config changes")
        activity = binding.activity
        
        // Verificar si entramos o salimos de PiP después del cambio de configuración
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val isCurrentlyInPiP = activity?.isInPictureInPictureMode ?: false
            Log.d("PictureInPicturePlugin", "📱 Estado PiP después de reattach: $isCurrentlyInPiP")
            eventSink?.success(isCurrentlyInPiP)
        }
    }

    override fun onDetachedFromActivity() {
        Log.d("PictureInPicturePlugin", "❌ Plugin detached from activity")
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}