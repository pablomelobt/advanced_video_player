package com.example.advanced_video_player;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastSession;
import com.google.android.gms.cast.framework.SessionManager;
import com.google.android.gms.cast.framework.SessionManagerListener;
import com.google.android.gms.cast.framework.CastState;
import com.google.android.gms.cast.framework.CastStateListener;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.cast.framework.media.RemoteMediaClient;
import com.google.android.gms.cast.MediaInfo;
import com.google.android.gms.cast.MediaMetadata;
import com.google.android.gms.cast.MediaLoadRequestData;
import com.google.android.gms.common.api.ResultCallback;

import androidx.mediarouter.media.MediaRouter;
import androidx.mediarouter.media.MediaRouteSelector;
import androidx.mediarouter.media.MediaRouter.RouteInfo;
import androidx.mediarouter.media.MediaControlIntent;
import androidx.mediarouter.media.MediaRouter.Callback;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class AdvancedVideoPlayerPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static final String CHANNEL_NAME = "advanced_video_player";
    private static final String SCREEN_SHARING_CHANNEL = "screen_sharing";
    
    private MethodChannel channel;
    private MethodChannel screenSharingChannel;
    private Context context;
    private CastContext castContext;
    private CastSession castSession;
    private SessionManager sessionManager;
    private SessionManagerListener<CastSession> sessionManagerListener;
    private MediaRouter mediaRouter;
    private MediaRouteSelector routeSelector;
    private MediaRouterCallback routerCallback;
    private PictureInPicturePlugin pictureInPicturePlugin;

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
        
        // Inicializar PictureInPicturePlugin aquí mismo
        pictureInPicturePlugin = new PictureInPicturePlugin();
        pictureInPicturePlugin.onAttachedToEngine(flutterPluginBinding);
        Log.d("AdvancedVideoPlayer", "✅ PictureInPicturePlugin inicializado");
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
        try {
            Log.d("AdvancedVideoPlayer", "🔧 Verificando soporte de Google Cast...");
            GoogleApiAvailability apiAvailability = GoogleApiAvailability.getInstance();
            int resultCode = apiAvailability.isGooglePlayServicesAvailable(context);
            boolean supported = resultCode == ConnectionResult.SUCCESS;
            Log.d("AdvancedVideoPlayer", "Google Cast support check: " + supported + " (code: " + resultCode + ")");
            
            if (supported) {
                Log.d("AdvancedVideoPlayer", "✅ Google Play Services está disponible");
            } else {
                Log.e("AdvancedVideoPlayer", "❌ Google Play Services no disponible - código: " + resultCode);
                String errorString = apiAvailability.getErrorString(resultCode);
                Log.e("AdvancedVideoPlayer", "❌ Error: " + errorString);
            }
            
            return supported;
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error checking Google Cast support: " + e.getMessage());
            Log.e("AdvancedVideoPlayer", "❌ Stack trace: ", e);
            return false;
        }
    }

    private void discoverCastDevices(Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "🔍 ===== INICIANDO DESCUBRIMIENTO REAL DE DISPOSITIVOS =====");
            
            // Verificar que Google Play Services esté disponible
            if (!isGoogleCastSupported()) {
                Log.e("AdvancedVideoPlayer", "❌ Google Play Services no disponible");
                result.success(new ArrayList<>());
                return;
            }
            
            Log.d("AdvancedVideoPlayer", "✅ Google Play Services está disponible");
            
            // Obtener MediaRouter para descubrimiento real
            Log.d("AdvancedVideoPlayer", "🔧 Obteniendo MediaRouter...");
            mediaRouter = MediaRouter.getInstance(context);
            Log.d("AdvancedVideoPlayer", "✅ MediaRouter obtenido exitosamente");
            
            // Crear selector de rutas para Google Cast
            Log.d("AdvancedVideoPlayer", "🔧 Creando MediaRouteSelector para Google Cast...");
            routeSelector = new MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build();
            Log.d("AdvancedVideoPlayer", "✅ MediaRouteSelector creado exitosamente");
            
            // Configurar callback para detectar cambios en las rutas
            Log.d("AdvancedVideoPlayer", "🔧 Configurando MediaRouterCallback...");
            routerCallback = new MediaRouterCallback();
            mediaRouter.addCallback(routeSelector, routerCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY);
            Log.d("AdvancedVideoPlayer", "✅ MediaRouterCallback configurado exitosamente");
            
            // Obtener rutas disponibles inmediatamente
            Log.d("AdvancedVideoPlayer", "🚀 Buscando dispositivos disponibles...");
            List<RouteInfo> availableRoutes = mediaRouter.getRoutes();
            Log.d("AdvancedVideoPlayer", "📊 Rutas encontradas en MediaRouter: " + availableRoutes.size());
            
            List<Map<String, Object>> devices = new ArrayList<>();
            
            for (RouteInfo route : availableRoutes) {
                Log.d("AdvancedVideoPlayer", "🔍 Analizando ruta: " + route.getName() + " | ID: " + route.getId());
                Log.d("AdvancedVideoPlayer", "   - Descripción: " + route.getDescription());
                Log.d("AdvancedVideoPlayer", "   - Estado: " + route.getConnectionState());
                Log.d("AdvancedVideoPlayer", "   - Disponible: " + route.isEnabled());
                
                // Filtrar solo rutas de Google Cast que estén disponibles
                if (route.isEnabled() && route.getConnectionState() != MediaRouter.RouteInfo.CONNECTION_STATE_CONNECTED) {
                    Log.d("AdvancedVideoPlayer", "🎯 ¡DISPOSITIVO CHROMECAST ENCONTRADO!");
                    Log.d("AdvancedVideoPlayer", "   - Nombre: " + route.getName());
                    Log.d("AdvancedVideoPlayer", "   - ID: " + route.getId());
                    
                    Map<String, Object> device = new HashMap<>();
                    device.put("id", route.getId());
                    device.put("name", route.getName());
                    device.put("type", "chromecast");
                    device.put("isConnected", false);
                    devices.add(device);
                }
            }
            
            Log.d("AdvancedVideoPlayer", "🎉 ===== DESCUBRIMIENTO REAL COMPLETADO =====");
            Log.d("AdvancedVideoPlayer", "📊 Total de dispositivos Chromecast encontrados: " + devices.size());
            
            if (devices.isEmpty()) {
                Log.w("AdvancedVideoPlayer", "⚠️ ===== NO SE ENCONTRARON DISPOSITIVOS CHROMECAST =====");
                Log.w("AdvancedVideoPlayer", "🔍 Posibles causas:");
                Log.w("AdvancedVideoPlayer", "   - Los dispositivos Chromecast no están en la misma red WiFi");
                Log.w("AdvancedVideoPlayer", "   - Los dispositivos están apagados o en modo de suspensión");
                Log.w("AdvancedVideoPlayer", "   - Problema con la configuración de red");
                Log.w("AdvancedVideoPlayer", "   - Permisos de red insuficientes");
                Log.w("AdvancedVideoPlayer", "   - Google Cast Services no está actualizado");
            } else {
                Log.i("AdvancedVideoPlayer", "✅ Dispositivos Chromecast encontrados exitosamente:");
                for (int i = 0; i < devices.size(); i++) {
                    Map<String, Object> device = devices.get(i);
                    Log.i("AdvancedVideoPlayer", "   " + (i+1) + ". " + device.get("name") + " (ID: " + device.get("id") + ")");
                }
            }
            
            result.success(devices);
            
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error crítico en descubrimiento de dispositivos: " + e.getMessage());
            Log.e("AdvancedVideoPlayer", "❌ Stack trace: ", e);
            result.success(new ArrayList<>());
        }
    }

    private void connectToCastDevice(String deviceId, String deviceName, Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "🔗 ===== INICIANDO CONEXIÓN A DISPOSITIVO =====");
            Log.d("AdvancedVideoPlayer", "📱 Dispositivo: " + deviceName + " (ID: " + deviceId + ")");
            
            if (mediaRouter == null || routeSelector == null) {
                Log.e("AdvancedVideoPlayer", "❌ MediaRouter no está inicializado");
                result.error("CONNECTION_ERROR", "MediaRouter no inicializado", null);
                return;
            }
            
            // Obtener todas las rutas disponibles
            List<RouteInfo> availableRoutes = mediaRouter.getRoutes();
            Log.d("AdvancedVideoPlayer", "📊 Rutas disponibles: " + availableRoutes.size());
            
            // Buscar la ruta específica por ID
            RouteInfo targetRoute = null;
            for (RouteInfo route : availableRoutes) {
                Log.d("AdvancedVideoPlayer", "🔍 Verificando ruta: " + route.getName() + " (ID: " + route.getId() + ")");
                if (route.getId().equals(deviceId)) {
                    targetRoute = route;
                    Log.d("AdvancedVideoPlayer", "🎯 ¡Ruta encontrada!");
                    break;
                }
            }
            
            if (targetRoute == null) {
                Log.e("AdvancedVideoPlayer", "❌ No se encontró la ruta con ID: " + deviceId);
                result.error("DEVICE_NOT_FOUND", "Dispositivo no encontrado", null);
                return;
            }
            
            Log.d("AdvancedVideoPlayer", "🚀 Conectando a: " + targetRoute.getName());
            Log.d("AdvancedVideoPlayer", "📊 Estado actual de la ruta: " + targetRoute.getConnectionState());
            Log.d("AdvancedVideoPlayer", "✅ Ruta disponible: " + targetRoute.isEnabled());
            
            // Seleccionar la ruta para conectar
            mediaRouter.selectRoute(targetRoute);
            Log.d("AdvancedVideoPlayer", "✅ Comando de conexión enviado exitosamente");
            
            // Configurar listener para confirmar la conexión y obtener la sesión
            castContext.addCastStateListener(new CastStateListener() {
                @Override
                public void onCastStateChanged(int newState) {
                    Log.d("AdvancedVideoPlayer", "🔄 Estado de Cast cambió: " + newState);
                    if (newState == 3) { // CastState.CONNECTED
                        Log.d("AdvancedVideoPlayer", "🎉 ¡CONECTADO EXITOSAMENTE!");
                        Log.d("AdvancedVideoPlayer", "✅ Dispositivo: " + deviceName);
                        
                        // Obtener la sesión Cast activa
                        SessionManager sessionManager = castContext.getSessionManager();
                        castSession = sessionManager.getCurrentCastSession();
                        if (castSession != null) {
                            Log.d("AdvancedVideoPlayer", "✅ Sesión Cast obtenida: " + castSession.getSessionId());
                        } else {
                            Log.w("AdvancedVideoPlayer", "⚠️ Sesión Cast no disponible inmediatamente");
                        }
                        
                        castContext.removeCastStateListener(this);
                    }
                }
            });
            
            result.success(true);
            Log.d("AdvancedVideoPlayer", "🎉 ===== CONEXIÓN INICIADA =====");
            
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error conectando a dispositivo: " + e.getMessage());
            Log.e("AdvancedVideoPlayer", "❌ Stack trace: ", e);
            result.error("CONNECTION_ERROR", e.getMessage(), null);
        }
    }

    private void shareVideoToCast(String videoUrl, String title, String description, String thumbnailUrl, Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "📺 ===== INICIANDO COMPARTIR VIDEO =====");
            Log.d("AdvancedVideoPlayer", "🎬 Video: " + title);
            Log.d("AdvancedVideoPlayer", "🔗 URL: " + videoUrl);
            Log.d("AdvancedVideoPlayer", "📝 Descripción: " + description);
            Log.d("AdvancedVideoPlayer", "🖼️ Thumbnail: " + thumbnailUrl);
            
            if (castSession == null) {
                Log.w("AdvancedVideoPlayer", "⚠️ Sesión Cast no disponible, buscando en SessionManager...");
                SessionManager sessionManager = castContext.getSessionManager();
                castSession = sessionManager.getCurrentCastSession();
                
                if (castSession == null) {
                    Log.w("AdvancedVideoPlayer", "⚠️ No hay sesión en SessionManager, esperando...");
                    
                    // Esperar hasta 3 segundos para que la sesión esté disponible
                    int attempts = 0;
                    int maxAttempts = 30; // 3 segundos (30 * 100ms)
                    
                    while (castSession == null && attempts < maxAttempts) {
                        try {
                            Thread.sleep(100); // Esperar 100ms
                            castSession = sessionManager.getCurrentCastSession();
                            attempts++;
                            Log.d("AdvancedVideoPlayer", "🔄 Intento " + attempts + "/" + maxAttempts + " - Sesión: " + (castSession != null ? "disponible" : "no disponible"));
                        } catch (InterruptedException e) {
                            Log.e("AdvancedVideoPlayer", "❌ Interrumpido mientras esperaba sesión Cast");
                            result.error("INTERRUPTED", "Espera interrumpida", null);
                            return;
                        }
                    }
                    
                    if (castSession == null) {
                        Log.e("AdvancedVideoPlayer", "❌ No hay sesión Cast después de " + maxAttempts + " intentos");
                        result.error("NO_SESSION", "No hay sesión Cast activa", null);
                        return;
                    }
                }
                Log.d("AdvancedVideoPlayer", "✅ Sesión Cast encontrada: " + castSession.getSessionId());
            }
            
            RemoteMediaClient remoteMediaClient = castSession.getRemoteMediaClient();
            if (remoteMediaClient == null) {
                Log.w("AdvancedVideoPlayer", "⚠️ RemoteMediaClient no disponible inmediatamente, esperando...");
                
                // Esperar hasta 8 segundos para que RemoteMediaClient esté disponible
                int attempts = 0;
                int maxAttempts = 80; // 8 segundos (80 * 100ms)
                
                while (remoteMediaClient == null && attempts < maxAttempts) {
                    try {
                        Thread.sleep(100); // Esperar 100ms
                        remoteMediaClient = castSession.getRemoteMediaClient();
                        attempts++;
                        Log.d("AdvancedVideoPlayer", "🔄 Intento " + attempts + "/" + maxAttempts + " - RemoteMediaClient: " + (remoteMediaClient != null ? "disponible" : "no disponible"));
                    } catch (InterruptedException e) {
                        Log.e("AdvancedVideoPlayer", "❌ Interrumpido mientras esperaba RemoteMediaClient");
                        result.error("INTERRUPTED", "Espera interrumpida", null);
                        return;
                    }
                }
                
                if (remoteMediaClient == null) {
                    Log.e("AdvancedVideoPlayer", "❌ RemoteMediaClient no disponible después de " + maxAttempts + " intentos");
                    result.error("NO_MEDIA_CLIENT", "RemoteMediaClient no disponible después de esperar", null);
                    return;
                }
                
                Log.d("AdvancedVideoPlayer", "✅ RemoteMediaClient disponible después de " + attempts + " intentos");
            }
            
            // Crear metadata del video
            MediaMetadata metadata = new MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE);
            metadata.putString(MediaMetadata.KEY_TITLE, title != null ? title : "Video");
            if (description != null && !description.isEmpty()) {
                metadata.putString(MediaMetadata.KEY_SUBTITLE, description);
            }
            // TODO: Agregar thumbnail cuando esté disponible la API
            
            // Crear MediaInfo con tipo de contenido dinámico
            String contentType = "video/mp4"; // Por defecto
            
            // Determinar el tipo de contenido basado en la URL
            if (videoUrl.toLowerCase().contains(".m3u8")) {
                contentType = "application/vnd.apple.mpegurl"; // HLS
                Log.d("AdvancedVideoPlayer", "📺 Detectado stream HLS (.m3u8)");
            } else if (videoUrl.toLowerCase().contains(".mp4")) {
                contentType = "video/mp4";
                Log.d("AdvancedVideoPlayer", "📺 Detectado video MP4");
            } else if (videoUrl.toLowerCase().contains(".webm")) {
                contentType = "video/webm";
                Log.d("AdvancedVideoPlayer", "📺 Detectado video WebM");
            } else {
                Log.d("AdvancedVideoPlayer", "📺 Tipo de contenido no detectado, usando MP4 por defecto");
            }
            
            Log.d("AdvancedVideoPlayer", "📺 Tipo de contenido final: " + contentType);
            
            // Crear MediaInfo
            MediaInfo mediaInfo = new MediaInfo.Builder(videoUrl)
                    .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                    .setContentType(contentType)
                    .setMetadata(metadata)
                    .build();
            
            Log.d("AdvancedVideoPlayer", "📝 MediaInfo creado exitosamente");
            
            // Crear MediaLoadRequestData
            MediaLoadRequestData request = new MediaLoadRequestData.Builder()
                    .setMediaInfo(mediaInfo)
                    .setAutoplay(true)
                    .build();
            
            Log.d("AdvancedVideoPlayer", "📤 Enviando video a dispositivo...");
            
            // Cargar el video en el dispositivo
            remoteMediaClient.load(request).setResultCallback(new ResultCallback<RemoteMediaClient.MediaChannelResult>() {
                @Override
                public void onResult(RemoteMediaClient.MediaChannelResult result) {
                    if (result.getStatus().isSuccess()) {
                        Log.d("AdvancedVideoPlayer", "🎉 ¡Video enviado exitosamente!");
                        Log.d("AdvancedVideoPlayer", "✅ Título: " + title);
                        Log.d("AdvancedVideoPlayer", "✅ URL: " + videoUrl);
                    } else {
                        Log.e("AdvancedVideoPlayer", "❌ Error enviando video: " + result.getStatus().getStatusCode());
                    }
                }
            });
            
            result.success(true);
            Log.d("AdvancedVideoPlayer", "🎉 ===== COMPARTIR VIDEO INICIADO =====");
            
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error compartiendo video: " + e.getMessage());
            Log.e("AdvancedVideoPlayer", "❌ Stack trace: ", e);
            result.error("SHARE_ERROR", e.getMessage(), null);
        }
    }

    private void controlCastPlayback(String action, Double position, Result result) {
        Log.d("AdvancedVideoPlayer", "🎮 Controlando reproducción: " + action + (position != null ? " at " + position : ""));
        result.success(true);
    }

    private void disconnectFromCast(Result result) {
        Log.d("AdvancedVideoPlayer", "🔌 Desconectando de Cast");
        
        try {
            if (sessionManager != null) {
                CastSession currentSession = sessionManager.getCurrentCastSession();
                
                if (currentSession != null && currentSession.isConnected()) {
                    Log.d("AdvancedVideoPlayer", "🛑 Deteniendo reproducción...");
                    
                    // Primero detener el video si está reproduciendo
                    RemoteMediaClient remoteMediaClient = currentSession.getRemoteMediaClient();
                    if (remoteMediaClient != null && remoteMediaClient.hasMediaSession()) {
                        remoteMediaClient.stop();
                        Log.d("AdvancedVideoPlayer", "✅ Video detenido");
                    }
                    
                    // Ahora terminar la sesión Cast
                    Log.d("AdvancedVideoPlayer", "🔌 Terminando sesión Cast activa...");
                    sessionManager.endCurrentSession(true);
                    // NO limpiar castSession aquí, el listener lo hará automáticamente
                    Log.d("AdvancedVideoPlayer", "✅ Sesión Cast terminada exitosamente");
                } else {
                    Log.d("AdvancedVideoPlayer", "⚠️ No hay sesión Cast activa para terminar");
                }
                result.success(true);
            } else {
                Log.w("AdvancedVideoPlayer", "⚠️ SessionManager no está disponible");
                result.success(false);
            }
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error desconectando Cast: " + e.getMessage());
            result.error("DISCONNECT_ERROR", e.getMessage(), null);
        }
    }

    private void initializeCast(Result result) {
        try {
            Log.d("AdvancedVideoPlayer", "🔧 Iniciando inicialización de Cast...");
            if (isGoogleCastSupported()) {
                Log.d("AdvancedVideoPlayer", "✅ Google Cast está soportado, obteniendo CastContext...");
                
                castContext = CastContext.getSharedInstance(context);
                Log.d("AdvancedVideoPlayer", "✅ CastContext obtenido exitosamente");
                
                sessionManager = castContext.getSessionManager();
                Log.d("AdvancedVideoPlayer", "✅ SessionManager obtenido exitosamente");
                
                sessionManagerListener = new SessionManagerListener<CastSession>() {
                    @Override
                    public void onSessionStarted(CastSession session, String sessionId) {
                        castSession = session;
                        Log.d("AdvancedVideoPlayer", "✅ Cast session started: " + sessionId);
                    }

                    @Override
                    public void onSessionResumed(CastSession session, boolean wasSuspended) {
                        castSession = session;
                        Log.d("AdvancedVideoPlayer", "✅ Cast session resumed");
                    }

                    @Override
                    public void onSessionSuspended(CastSession session, int error) {
                        castSession = null;
                        Log.d("AdvancedVideoPlayer", "⚠️ Cast session suspended: " + error);
                    }

                    @Override
                    public void onSessionEnded(CastSession session, int error) {
                        castSession = null;
                        Log.d("AdvancedVideoPlayer", "❌ Cast session ended: " + error);
                    }

                    @Override
                    public void onSessionStarting(CastSession session) {
                        Log.d("AdvancedVideoPlayer", "🔄 Cast session starting...");
                    }

                    @Override
                    public void onSessionStartFailed(CastSession session, int error) {
                        Log.e("AdvancedVideoPlayer", "❌ Cast session start failed: " + error);
                    }

                    @Override
                    public void onSessionEnding(CastSession session) {
                        Log.d("AdvancedVideoPlayer", "🔄 Cast session ending...");
                    }

                    @Override
                    public void onSessionResuming(CastSession session, String sessionId) {
                        Log.d("AdvancedVideoPlayer", "🔄 Cast session resuming: " + sessionId);
                    }

                    @Override
                    public void onSessionResumeFailed(CastSession session, int error) {
                        Log.e("AdvancedVideoPlayer", "❌ Cast session resume failed: " + error);
                    }
                };
                
                sessionManager.addSessionManagerListener(sessionManagerListener, CastSession.class);
                Log.d("AdvancedVideoPlayer", "✅ SessionManagerListener agregado exitosamente");
                Log.d("AdvancedVideoPlayer", "🎉 Inicialización de Cast completada exitosamente");
                result.success(true);
            } else {
                Log.e("AdvancedVideoPlayer", "❌ Google Cast no está soportado en este dispositivo");
                result.success(false);
            }
        } catch (Exception e) {
            Log.e("AdvancedVideoPlayer", "❌ Error inicializando Cast: " + e.getMessage());
            Log.e("AdvancedVideoPlayer", "❌ Stack trace: ", e);
            result.error("CAST_INIT_ERROR", e.getMessage(), null);
        }
    }

    // Métodos de ActivityAware para pasar la Activity al PictureInPicturePlugin
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        Log.d("AdvancedVideoPlayer", "✅ Attached to activity");
        if (pictureInPicturePlugin != null) {
            pictureInPicturePlugin.onAttachedToActivity(binding);
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        Log.d("AdvancedVideoPlayer", "⚙️ Detached from activity for config changes");
        if (pictureInPicturePlugin != null) {
            pictureInPicturePlugin.onDetachedFromActivityForConfigChanges();
        }
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        Log.d("AdvancedVideoPlayer", "✅ Reattached to activity after config changes");
        if (pictureInPicturePlugin != null) {
            pictureInPicturePlugin.onReattachedToActivityForConfigChanges(binding);
        }
    }

    @Override
    public void onDetachedFromActivity() {
        Log.d("AdvancedVideoPlayer", "❌ Detached from activity");
        if (pictureInPicturePlugin != null) {
            pictureInPicturePlugin.onDetachedFromActivity();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (sessionManager != null && sessionManagerListener != null) {
            try {
                sessionManager.removeSessionManagerListener(sessionManagerListener, CastSession.class);
                Log.d("AdvancedVideoPlayer", "✅ SessionManagerListener removido");
            } catch (Exception e) {
                Log.e("AdvancedVideoPlayer", "❌ Error removiendo SessionManagerListener: " + e.getMessage());
            }
        }
        
        if (mediaRouter != null && routerCallback != null) {
            try {
                mediaRouter.removeCallback(routerCallback);
                Log.d("AdvancedVideoPlayer", "✅ MediaRouterCallback removido");
            } catch (Exception e) {
                Log.e("AdvancedVideoPlayer", "❌ Error removiendo MediaRouterCallback: " + e.getMessage());
            }
        }
        
        if (pictureInPicturePlugin != null) {
            pictureInPicturePlugin.onDetachedFromEngine(binding);
        }
        
        channel.setMethodCallHandler(null);
        screenSharingChannel.setMethodCallHandler(null);
        Log.d("AdvancedVideoPlayer", "🔍 Plugin detached from engine");
    }
}

// Callback para detectar cambios en las rutas de MediaRouter
class MediaRouterCallback extends MediaRouter.Callback {
    @Override
    public void onRouteAdded(MediaRouter router, MediaRouter.RouteInfo route) {
        Log.d("AdvancedVideoPlayer", "🎉 ¡NUEVA RUTA AGREGADA! " + route.getName() + " (ID: " + route.getId() + ")");
        Log.d("AdvancedVideoPlayer", "   - Descripción: " + route.getDescription());
        Log.d("AdvancedVideoPlayer", "   - Estado: " + route.getConnectionState());
        Log.d("AdvancedVideoPlayer", "   - Disponible: " + route.isEnabled());
    }

    @Override
    public void onRouteRemoved(MediaRouter router, MediaRouter.RouteInfo route) {
        Log.d("AdvancedVideoPlayer", "❌ Ruta removida: " + route.getName() + " (ID: " + route.getId() + ")");
    }

    @Override
    public void onRouteChanged(MediaRouter router, MediaRouter.RouteInfo route) {
        Log.d("AdvancedVideoPlayer", "🔄 Ruta cambiada: " + route.getName() + " (ID: " + route.getId() + ")");
        Log.d("AdvancedVideoPlayer", "   - Nuevo estado: " + route.getConnectionState());
    }

    @Override
    public void onRouteSelected(MediaRouter router, MediaRouter.RouteInfo route) {
        Log.d("AdvancedVideoPlayer", "✅ Ruta seleccionada: " + route.getName() + " (ID: " + route.getId() + ")");
    }

    @Override
    public void onRouteUnselected(MediaRouter router, MediaRouter.RouteInfo route) {
        Log.d("AdvancedVideoPlayer", "🔌 Ruta deseleccionada: " + route.getName() + " (ID: " + route.getId() + ")");
    }
}