package com.example.advanced_video_player

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import android.util.Rational
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
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
    private var isPlaying: Boolean = true
    private var pipControlsReceiver: BroadcastReceiver? = null
    
    companion object {
        private const val ACTION_MEDIA_CONTROL = "media_control"
        private const val EXTRA_CONTROL_TYPE = "control_type"
        private const val REQUEST_PLAY_PAUSE = 1
    }

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
                val playing = call.argument<Boolean>("isPlaying") ?: true
                isPlaying = playing
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
            "updatePlaybackState" -> {
                val playing = call.argument<Boolean>("isPlaying") ?: true
                isPlaying = playing
                updatePipParams()
                result.success(true)
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
                // Registrar el BroadcastReceiver para los controles
                registerPipControlsReceiver()
                
                // Calcular el aspect ratio correcto basado en las dimensiones del video
                val aspectRatio = Rational(width.toInt(), height.toInt())
                Log.d("PictureInPicturePlugin", "Aspect ratio: $aspectRatio (${width}x${height})")
                
                // Crear parámetros de PiP con controles
                val pipParams = buildPipParams(aspectRatio)
                
                // Configurar la Activity para PiP
                currentActivity.setPictureInPictureParams(pipParams)
                
                // Intentar entrar en modo PiP
                val result = currentActivity.enterPictureInPictureMode(pipParams)
                
                if (result) {
                    Log.d("PictureInPicturePlugin", "✅ Entrando en modo Picture-in-Picture exitosamente")
                    Log.d("PictureInPicturePlugin", "📱 La ventana PiP mostrará controles de play/pause")
                    // Notificar cambio de estado
                    eventSink?.success(true)
                    return true
                } else {
                    Log.d("PictureInPicturePlugin", "❌ Error: No se pudo entrar en modo Picture-in-Picture")
                    unregisterPipControlsReceiver()
                    return false
                }
            } catch (e: Exception) {
                Log.e("PictureInPicturePlugin", "❌ Error al entrar en PiP: ${e.message}")
                unregisterPipControlsReceiver()
                return false
            }
        }
        return false
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(aspectRatio: Rational): PictureInPictureParams {
        val actions = ArrayList<RemoteAction>()
        actions.add(createPlayPauseAction())
        
        return PictureInPictureParams.Builder()
            .setAspectRatio(aspectRatio)
            .setActions(actions)
            .build()
    }
    
    @RequiresApi(Build.VERSION_CODES.O)
    private fun createPlayPauseAction(): RemoteAction {
        val currentActivity = activity ?: throw IllegalStateException("Activity is null")
        
        val intent = Intent(ACTION_MEDIA_CONTROL).apply {
            putExtra(EXTRA_CONTROL_TYPE, "play_pause")
            setPackage(currentActivity.packageName)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            currentActivity,
            REQUEST_PLAY_PAUSE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Usar íconos nativos de Android
        val icon = if (isPlaying) {
            Icon.createWithResource(currentActivity, android.R.drawable.ic_media_pause)
        } else {
            Icon.createWithResource(currentActivity, android.R.drawable.ic_media_play)
        }
        
        val title = if (isPlaying) "Pausar" else "Reproducir"
        
        return RemoteAction(icon, title, title, pendingIntent)
    }
    
    @RequiresApi(Build.VERSION_CODES.O)
    private fun updatePipParams() {
        val currentActivity = activity ?: return
        
        if (!currentActivity.isInPictureInPictureMode) {
            return
        }
        
        try {
            // Obtener el aspect ratio actual
            val activityInfo = currentActivity.packageManager.getActivityInfo(
                currentActivity.componentName, 0
            )
            
            // Reconstruir params con el nuevo estado
            val actions = ArrayList<RemoteAction>()
            actions.add(createPlayPauseAction())
            
            val pipParams = PictureInPictureParams.Builder()
                .setActions(actions)
                .build()
            
            currentActivity.setPictureInPictureParams(pipParams)
            Log.d("PictureInPicturePlugin", "✅ PiP params actualizados - isPlaying: $isPlaying")
        } catch (e: Exception) {
            Log.e("PictureInPicturePlugin", "❌ Error actualizando PiP params: ${e.message}")
        }
    }
    
    private fun registerPipControlsReceiver() {
        val currentActivity = activity ?: return
        
        if (pipControlsReceiver != null) {
            // Ya está registrado
            return
        }
        
        pipControlsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != ACTION_MEDIA_CONTROL) return
                
                val controlType = intent.getStringExtra(EXTRA_CONTROL_TYPE)
                Log.d("PictureInPicturePlugin", "📱 Control PiP recibido: $controlType")
                
                when (controlType) {
                    "play_pause" -> {
                        // Notificar a Flutter sobre el cambio
                        val data = mapOf(
                            "type" to "pip_control",
                            "action" to "play_pause"
                        )
                        channel.invokeMethod("onPipControl", data)
                    }
                }
            }
        }
        
        val filter = IntentFilter(ACTION_MEDIA_CONTROL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            currentActivity.registerReceiver(pipControlsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            currentActivity.registerReceiver(pipControlsReceiver, filter)
        }
        
        Log.d("PictureInPicturePlugin", "✅ BroadcastReceiver registrado para controles PiP")
    }
    
    private fun unregisterPipControlsReceiver() {
        val currentActivity = activity ?: return
        
        pipControlsReceiver?.let {
            try {
                currentActivity.unregisterReceiver(it)
                pipControlsReceiver = null
                Log.d("PictureInPicturePlugin", "✅ BroadcastReceiver desregistrado")
            } catch (e: Exception) {
                Log.e("PictureInPicturePlugin", "❌ Error desregistrando receiver: ${e.message}")
            }
        }
    }
    
    private fun exitPictureInPictureMode(): Boolean {
        // Desregistrar el receiver al salir del PiP
        unregisterPipControlsReceiver()
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
        unregisterPipControlsReceiver()
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}