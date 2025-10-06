package com.example.advanced_video_player;

import android.app.Activity;
import android.content.Context;
import android.util.Log;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastSession;
import com.google.android.gms.cast.framework.SessionManager;
import com.google.android.gms.cast.framework.SessionManagerListener;
import com.google.android.gms.cast.framework.CastButtonFactory;
import androidx.mediarouter.app.MediaRouteButton;
import androidx.mediarouter.app.MediaRouteChooserDialogFragment;
import androidx.mediarouter.media.MediaRouteSelector;
import androidx.mediarouter.media.MediaControlIntent;
import androidx.fragment.app.FragmentActivity;
import com.google.android.gms.cast.MediaInfo;
import com.google.android.gms.cast.MediaMetadata;
import com.google.android.gms.cast.framework.media.RemoteMediaClient;
import com.google.android.gms.cast.MediaLoadRequestData;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class AdvancedVideoPlayerPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static final String CHANNEL_NAME = "advanced_video_player";
    private static final String SCREEN_SHARING_CHANNEL = "screen_sharing";
    
    private MethodChannel channel;
    private MethodChannel screenSharingChannel;
    private Context context;
    private Activity activity;
    private CastContext castContext;
    private CastSession castSession;
    private SessionManager sessionManager;
    private SessionManagerListener<CastSession> sessionManagerListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        Log.d("AdvancedVideoPlayer", "🔍 Plugin attached to engine");
        context = flutterPluginBinding.getApplicationContext();
        
        // Canal principal
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        Log.d("AdvancedVideoPlayer", "🔍 Canal principal creado: " + CHANNEL_NAME);
        
        // Canal de compartir pantalla
        screenSharingChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), SCREEN_SHARING_CHANNEL);
        screenSharingChannel.setMethodCallHandler(this);
        Log.d("AdvancedVideoPlayer", "🔍 Canal screen sharing creado: " + SCREEN_SHARING_CHANNEL);
        
        // Registrar el botón de transmisión como PlatformView
        flutterPluginBinding.getPlatformViewRegistry().registerViewFactory(
            "advanced_video_player/cast_button",
            new CastButtonFactoryView(flutterPluginBinding.getApplicationContext(), activity)
        );
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d("AdvancedVideoPlayer", "Method call: " + call.method);
        // Verificar si es una llamada del canal de screen sharing
        if (call.method.equals("initialize") || 
            call.method.equals("isSupported") || 
            call.method.equals("discoverDevices") || 
            call.method.equals("connectToDevice") || 
            call.method.equals("shareVideo") || 
            call.method.equals("controlPlayback") || 
            call.method.equals("disconnect")) {
            handleScreenSharingCall(call, result);
        } else {
            handleMainCall(call, result);
        }
    }

    private void handleMainCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "initializeCast":
                initializeCast(result);
                break;
            case "castVideo":
                String url = call.argument("url");
                if (url != null) {
                    castVideo(url);
                }
                result.success(null);
                break;
            case "showCastDialog":
                showCastDialog();
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleScreenSharingCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d("AdvancedVideoPlayer", "🔍 Screen sharing call: " + call.method);
        switch (call.method) {
            case "initialize":
                Log.d("AdvancedVideoPlayer", "🔍 Inicializando screen sharing...");
                result.success(initializeScreenSharing());
                break;
            case "isSupported":
                Log.d("AdvancedVideoPlayer", "🔍 Verificando soporte...");
                boolean supported = isGoogleCastSupported();
                Log.d("AdvancedVideoPlayer", "🔍 Soporte: " + supported);
                result.success(supported);
                break;
            case "discoverDevices":
                discoverCastDevices(result);
                break;
            case "connectToDevice":
                Map<String, Object> args = call.arguments();
                String deviceId = (String) args.get("deviceId");
                String deviceName = (String) args.get("deviceName");
                connectToCastDevice(deviceId, deviceName, result);
                break;
            case "shareVideo":
                Map<String, Object> videoArgs = call.arguments();
                String videoUrl = (String) videoArgs.get("videoUrl");
                String title = (String) videoArgs.get("title");
                String description = (String) videoArgs.get("description");
                String thumbnailUrl = (String) videoArgs.get("thumbnailUrl");
                shareVideoToCast(videoUrl, title, description, thumbnailUrl, result);
                break;
            case "controlPlayback":
                Map<String, Object> controlArgs = call.arguments();
                String action = (String) controlArgs.get("action");
                Double position = (Double) controlArgs.get("position");
                controlCastPlayback(action, position, result);
                break;
            case "disconnect":
                disconnectFromCast(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private boolean initializeScreenSharing() {
        return isGoogleCastSupported();
    }

    private boolean isGoogleCastSupported() {
        // Simular soporte para testing
        Log.d("AdvancedVideoPlayer", "Google Cast support: SIMULATED (always true for testing)");
        return true;
    }

    private void discoverCastDevices(Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "🔍 Iniciando descubrimiento de dispositivos Chromecast");
            
            // Por ahora, devolver lista vacía ya que las APIs de descubrimiento han cambiado
            // En una implementación real, necesitarías usar las APIs más recientes de Google Cast
            List<Map<String, Object>> devices = new ArrayList<>();
            
            Log.d("AdvancedVideoPlayer", "✅ Descubrimiento completado. Encontrados " + devices.size() + " dispositivos");
            result.success(devices);
            
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error en descubrimiento de dispositivos: " + e.getMessage());
            result.success(new ArrayList<>()); // Devolver lista vacía en caso de error
        }
    }

    private void connectToCastDevice(String deviceId, String deviceName, Result result) {
        // Simular conexión exitosa
        Log.d("AdvancedVideoPlayer", "Connecting to device: " + deviceName);
        result.success(true);
    }

    private void shareVideoToCast(String videoUrl, String title, String description, String thumbnailUrl, Result result) {
        // Simular compartir video exitoso
        Log.d("AdvancedVideoPlayer", "Sharing video: " + title + " (" + videoUrl + ")");
        result.success(true);
    }

    private void controlCastPlayback(String action, Double position, Result result) {
        // Simular control de reproducción
        Log.d("AdvancedVideoPlayer", "Controlling playback: " + action + (position != null ? " at " + position : ""));
        result.success(true);
    }

    private void disconnectFromCast(Result result) {
        // Simular desconexión
        Log.d("AdvancedVideoPlayer", "Disconnecting from Cast");
        result.success(true);
    }

    // Métodos de Google Cast
    private void initializeCast(Result result) {
        try {
            if (activity != null) {
                castContext = CastContext.getSharedInstance(activity);
                result.success(true);
                Log.d("AdvancedVideoPlayer", "✅ Google Cast inicializado correctamente");
            } else {
                result.error("CAST_INIT", "Activity no disponible", null);
            }
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error al inicializar Cast: " + e.getMessage());
            result.error("CAST_INIT", e.getMessage(), null);
        }
    }

    private void castVideo(String url) {
        try {
            if (castContext == null) {
                Log.e("AdvancedVideoPlayer", "❌ CastContext no inicializado");
                return;
            }

            CastSession session = castContext.getSessionManager().getCurrentCastSession();
            if (session == null) {
                Log.e("AdvancedVideoPlayer", "❌ No hay sesión Cast activa");
                return;
            }

            RemoteMediaClient remoteMediaClient = session.getRemoteMediaClient();
            if (remoteMediaClient == null) {
                Log.e("AdvancedVideoPlayer", "❌ RemoteMediaClient no disponible");
                return;
            }

            MediaMetadata metadata = new MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE);
            metadata.putString(MediaMetadata.KEY_TITLE, "Video remoto");

            MediaInfo mediaInfo = new MediaInfo.Builder(url)
                    .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                    .setContentType("video/mp4")
                    .setMetadata(metadata)
                    .build();

            MediaLoadRequestData request = new MediaLoadRequestData.Builder()
                    .setMediaInfo(mediaInfo)
                    .setAutoplay(true)
                    .build();

            remoteMediaClient.load(request);
            Log.d("AdvancedVideoPlayer", "✅ Video enviado a Cast: " + url);
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error al enviar video: " + e.getMessage());
        }
    }

    private void showCastDialog() {
        try {
            if (castContext == null) {
                Log.e("AdvancedVideoPlayer", "❌ CastContext no inicializado");
                return;
            }

            // El CastContext se autoconfigura, no necesitamos categorías
            // El botón nativo ya maneja el diálogo automáticamente
            Log.d("AdvancedVideoPlayer", "✅ CastContext configurado - el botón nativo manejará el diálogo");
            
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error con CastContext: " + e.getMessage());
        }
    }

    // ActivityAware implementation
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        try {
            castContext = CastContext.getSharedInstance(activity.getApplicationContext());
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "Error inicializando CastContext: " + e.getMessage());
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        // No action needed
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        screenSharingChannel.setMethodCallHandler(null);
    }
}

// PlatformView que genera el botón nativo de Cast
class CastButtonFactoryView extends PlatformViewFactory {
    private final Context context;
    private final Activity activity;

    CastButtonFactoryView(Context context, Activity activity) {
        super(StandardMessageCodec.INSTANCE);
        this.context = context;
        this.activity = activity;
    }

    @Override
    public PlatformView create(Context context, int id, Object args) {
        return new CastButtonPlatformView(this.context, this.activity);
    }
}

class CastButtonPlatformView implements PlatformView {
    private final FrameLayout frame;
    private final Context context;
    private final Activity activity;

    CastButtonPlatformView(Context context, Activity activity) {
        this.context = context;
        this.activity = activity;
        frame = new FrameLayout(context);
        try {
            // Crear el MediaRouteButton nativo usando la API correcta de Java
            MediaRouteButton castButton = new MediaRouteButton(context);
            
            // Configurar el selector de rutas para Google Cast
            MediaRouteSelector selector = new MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build();
            
            castButton.setRouteSelector(selector);
            
            // Configurar el MediaRouteButton con CastButtonFactory
            CastButtonFactory.setUpMediaRouteButton(context, castButton);
            frame.addView(castButton);
            Log.d("AdvancedVideoPlayer", "✅ MediaRouteButton nativo creado y configurado correctamente");
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error creando MediaRouteButton: " + e.getMessage());
            // Fallback: crear un botón simple que abra el diálogo nativo
            android.widget.Button fallbackButton = new android.widget.Button(context);
            fallbackButton.setText("Cast");
            fallbackButton.setBackgroundColor(0xFF2196F3);
            fallbackButton.setTextColor(0xFFFFFFFF);
            fallbackButton.setOnClickListener(v -> {
                Log.d("AdvancedVideoPlayer", "Cast button clicked - abriendo diálogo nativo");
                showCastDialog();
            });
            frame.addView(fallbackButton);
        }
    }

    @Override
    public View getView() {
        return frame;
    }

    @Override
    public void dispose() {
        // No action needed
    }
    
    private void showCastDialog() {
        try {
            if (activity == null) {
                Log.e("AdvancedVideoPlayer", "❌ Activity no disponible para mostrar Cast Dialog");
                return;
            }
            
            // Verificar que la Activity sea FragmentActivity
            if (!(activity instanceof FragmentActivity)) {
                Log.e("AdvancedVideoPlayer", "❌ Activity no es FragmentActivity, usando fallback");
                // Fallback: usar MediaRouteButton
                showCastDialogFallback();
                return;
            }
            
            FragmentActivity fragmentActivity = (FragmentActivity) activity;
            
            // Crear el selector de rutas para Google Cast
            MediaRouteSelector selector = new MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build();
            
            // Crear y mostrar el MediaRouteChooserDialogFragment oficial
            MediaRouteChooserDialogFragment dialogFragment = new MediaRouteChooserDialogFragment();
            dialogFragment.setRouteSelector(selector);
            dialogFragment.show(fragmentActivity.getSupportFragmentManager(), "media_chooser");
            
            Log.d("AdvancedVideoPlayer", "✅ Diálogo nativo de Google Cast abierto (como Disney+)");
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error abriendo diálogo nativo: " + e.getMessage());
            // Fallback en caso de error
            showCastDialogFallback();
        }
    }
    
    private void showCastDialogFallback() {
        try {
            // Crear el selector de rutas para Google Cast
            MediaRouteSelector selector = new MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build();
            
            // Crear un MediaRouteButton temporal para abrir el diálogo nativo
            MediaRouteButton tempButton = new MediaRouteButton(context);
            tempButton.setRouteSelector(selector);
            
            // Simular el clic para abrir el diálogo nativo (como Disney+)
            tempButton.performClick();
            
            Log.d("AdvancedVideoPlayer", "✅ Diálogo nativo de Google Cast abierto (fallback)");
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error en fallback: " + e.getMessage());
        }
    }
    
    private void showNativeCastDialog() {
        try {
            if (activity == null) {
                Log.e("AdvancedVideoPlayer", "❌ Activity no disponible para mostrar Cast Dialog");
                return;
            }
            
            // Verificar que la Activity sea FragmentActivity
            if (!(activity instanceof FragmentActivity)) {
                Log.e("AdvancedVideoPlayer", "❌ Activity no es FragmentActivity, usando fallback");
                // Fallback: usar MediaRouteButton
                showCastDialogFallback();
                return;
            }
            
            FragmentActivity fragmentActivity = (FragmentActivity) activity;
            
            // Crear el selector de rutas para Google Cast
            MediaRouteSelector selector = new MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build();
            
            // Crear y mostrar el MediaRouteChooserDialogFragment oficial
            MediaRouteChooserDialogFragment dialogFragment = new MediaRouteChooserDialogFragment();
            dialogFragment.setRouteSelector(selector);
            dialogFragment.show(fragmentActivity.getSupportFragmentManager(), "media_chooser");
            
            Log.d("AdvancedVideoPlayer", "✅ Diálogo nativo de Google Cast abierto (como Disney+)");
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error abriendo diálogo nativo: " + e.getMessage());
            // Fallback en caso de error
            showCastDialogFallback();
        }
    }
}