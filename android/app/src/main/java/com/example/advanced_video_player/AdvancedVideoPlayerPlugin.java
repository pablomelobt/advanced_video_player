package com.example.advanced_video_player;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastSession;
import com.google.android.gms.cast.framework.SessionManager;
import com.google.android.gms.cast.framework.SessionManagerListener;
import com.google.android.gms.cast.MediaInfo;
import com.google.android.gms.cast.MediaMetadata;
import com.google.android.gms.cast.framework.media.RemoteMediaClient;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.cast.framework.CastDevice;
import com.google.android.gms.cast.framework.CastState;
import com.google.android.gms.cast.framework.CastStateListener;
import com.google.android.gms.cast.framework.discovery.DiscoveryManager;
import com.google.android.gms.cast.framework.discovery.DiscoveryManagerListener;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class AdvancedVideoPlayerPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL_NAME = "advanced_video_player";
    private static final String SCREEN_SHARING_CHANNEL = "screen_sharing";
    
    private MethodChannel channel;
    private MethodChannel screenSharingChannel;
    private Context context;
    private CastSession castSession;
    private SessionManager sessionManager;
    private SessionManagerListener<CastSession> sessionManagerListener;
    private DiscoveryManager discoveryManager;
    private List<CastDevice> discoveredDevices = new ArrayList<>();

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
        
        // Inicializar Google Cast
        initializeCast();
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
            case "isAirPlayActive":
                // AirPlay no está disponible en Android
                result.success(false);
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

    private void initializeCast() {
        try {
            if (isGoogleCastSupported()) {
                CastContext.getSharedInstance(context);
                sessionManager = CastContext.getSharedInstance(context).getSessionManager();
                
                sessionManagerListener = new SessionManagerListener<CastSession>() {
                    @Override
                    public void onSessionStarted(CastSession session, String sessionId) {
                        castSession = session;
                        Log.d("AdvancedVideoPlayer", "Cast session started");
                    }

                    @Override
                    public void onSessionResumed(CastSession session, boolean wasSuspended) {
                        castSession = session;
                        Log.d("AdvancedVideoPlayer", "Cast session resumed");
                    }

                    @Override
                    public void onSessionSuspended(CastSession session, int error) {
                        castSession = null;
                        Log.d("AdvancedVideoPlayer", "Cast session suspended");
                    }

                    @Override
                    public void onSessionEnded(CastSession session, int error) {
                        castSession = null;
                        Log.d("AdvancedVideoPlayer", "Cast session ended");
                    }
                };
                
                sessionManager.addSessionManagerListener(sessionManagerListener);
            }
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "Error initializing Cast: " + e.getMessage());
        }
    }

    private boolean initializeScreenSharing() {
        return isGoogleCastSupported();
    }

    private boolean isGoogleCastSupported() {
        // Por ahora, siempre reportar soporte para testing
        // En producción, puedes descomentar las líneas de abajo para verificar Google Play Services
        /*
        GoogleApiAvailability apiAvailability = GoogleApiAvailability.getInstance();
        int resultCode = apiAvailability.isGooglePlayServicesAvailable(context);
        boolean supported = resultCode == ConnectionResult.SUCCESS;
        Log.d("AdvancedVideoPlayer", "Google Cast support check: " + supported + " (code: " + resultCode + ")");
        return supported;
        */
        Log.d("AdvancedVideoPlayer", "Google Cast support: SIMULATED (always true for testing)");
        return true;
    }

    private void discoverCastDevices(Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "🔍 Iniciando descubrimiento real de dispositivos Chromecast");
            
            // Limpiar lista anterior
            discoveredDevices.clear();
            
            // Obtener el DiscoveryManager
            discoveryManager = CastContext.getSharedInstance(context).getDiscoveryManager();
            
            // Configurar listener para dispositivos descubiertos
            discoveryManager.setDiscoveryManagerListener(new DiscoveryManagerListener() {
                @Override
                public void onDeviceAdded(CastDevice device) {
                    Log.d("AdvancedVideoPlayer", "📱 Dispositivo encontrado: " + device.getFriendlyName());
                    discoveredDevices.add(device);
                }
                
                @Override
                public void onDeviceRemoved(CastDevice device) {
                    Log.d("AdvancedVideoPlayer", "📱 Dispositivo removido: " + device.getFriendlyName());
                    discoveredDevices.remove(device);
                }
            });
            
            // Iniciar descubrimiento
            discoveryManager.startDiscovery();
            
            // Esperar un poco para que se descubran dispositivos
            new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
                discoveryManager.stopDiscovery();
                
                // Convertir dispositivos descubiertos a formato para Flutter
                List<Map<String, Object>> devices = new ArrayList<>();
                for (CastDevice device : discoveredDevices) {
                    Map<String, Object> deviceMap = new HashMap<>();
                    deviceMap.put("id", device.getDeviceId());
                    deviceMap.put("name", device.getFriendlyName());
                    deviceMap.put("type", "chromecast");
                    deviceMap.put("isConnected", false);
                    devices.add(deviceMap);
                }
                
                Log.d("AdvancedVideoPlayer", "✅ Descubrimiento completado. Encontrados " + devices.size() + " dispositivos reales");
                result.success(devices);
            }, 3000); // Esperar 3 segundos para descubrimiento
            
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
        if (castSession == null) {
            result.success(false);
            return;
        }

        try {
            MediaMetadata metadata = new MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE);
            metadata.putString(MediaMetadata.KEY_TITLE, title);
            metadata.putString(MediaMetadata.KEY_SUBTITLE, description);
            
            MediaInfo mediaInfo = new MediaInfo.Builder(videoUrl)
                    .setContentType("video/mp4")
                    .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                    .setMetadata(metadata)
                    .build();

            RemoteMediaClient remoteMediaClient = castSession.getRemoteMediaClient();
            if (remoteMediaClient != null) {
                remoteMediaClient.load(mediaInfo);
                result.success(true);
            } else {
                result.success(false);
            }
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "Error sharing video: " + e.getMessage());
            result.success(false);
        }
    }

    private void controlCastPlayback(String action, Double position, Result result) {
        if (castSession == null) {
            result.success(false);
            return;
        }

        try {
            RemoteMediaClient remoteMediaClient = castSession.getRemoteMediaClient();
            if (remoteMediaClient == null) {
                result.success(false);
                return;
            }

            switch (action) {
                case "play":
                    remoteMediaClient.play();
                    break;
                case "pause":
                    remoteMediaClient.pause();
                    break;
                case "seek":
                    if (position != null) {
                        remoteMediaClient.seek((long) (position * 1000)); // Convert to milliseconds
                    }
                    break;
                case "stop":
                    remoteMediaClient.stop();
                    break;
            }
            result.success(true);
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "Error controlling playback: " + e.getMessage());
            result.success(false);
        }
    }

    private void disconnectFromCast(Result result) {
        if (sessionManager != null && sessionManagerListener != null) {
            sessionManager.removeSessionManagerListener(sessionManagerListener);
        }
        castSession = null;
        result.success(true);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        screenSharingChannel.setMethodCallHandler(null);
        
        if (sessionManager != null && sessionManagerListener != null) {
            sessionManager.removeSessionManagerListener(sessionManagerListener);
        }
    }
}
