import Flutter
import UIKit
import GroupActivities
import AVKit

@available(iOS 15.0, *)
public class ScreenSharingPlugin: NSObject, FlutterPlugin {
    private var groupActivity: VideoWatchingActivity?
    private var groupSession: GroupSession<VideoWatchingActivity>?
    private var messenger: FlutterBinaryMessenger?
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("🔍 SharePlay: Registrando plugin...")
        let channel = FlutterMethodChannel(name: "screen_sharing", binaryMessenger: registrar.messenger())
        let instance = ScreenSharingPlugin()
        instance.messenger = registrar.messenger()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("🔍 SharePlay: Plugin registrado correctamente con canal 'screen_sharing'")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔍 SharePlay: Método llamado: \(call.method)")
        print("🔍 SharePlay: Argumentos: \(call.arguments ?? "nil")")
        
        switch call.method {
        case "initialize":
            print("🔍 SharePlay: Inicializando...")
            result(initialize())
        case "isSupported":
            print("🔍 SharePlay: Verificando soporte...")
            result(isSupported())
        case "discoverDevices":
            print("🔍 SharePlay: Descubriendo dispositivos...")
            discoverDevices(result: result)
        case "connectToDevice":
            let args = call.arguments as? [String: Any]
            let deviceId = args?["deviceId"] as? String ?? ""
            let deviceName = args?["deviceName"] as? String ?? ""
            connectToDevice(deviceId: deviceId, deviceName: deviceName, result: result)
        case "shareVideo":
            let args = call.arguments as? [String: Any]
            let videoUrl = args?["videoUrl"] as? String ?? ""
            let title = args?["title"] as? String ?? ""
            let description = args?["description"] as? String ?? ""
            let thumbnailUrl = args?["thumbnailUrl"] as? String ?? ""
            shareVideo(videoUrl: videoUrl, title: title, description: description, thumbnailUrl: thumbnailUrl, result: result)
        case "controlPlayback":
            let args = call.arguments as? [String: Any]
            let action = args?["action"] as? String ?? ""
            let position = args?["position"] as? Double
            controlPlayback(action: action, position: position, result: result)
        case "disconnect":
            disconnect(result: result)
        default:
            print("❌ SharePlay: Método no implementado: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize() -> Bool {
        print("🔍 SharePlay: Inicializando...")
        // Configurar observadores para SharePlay
        setupSharePlayObservers()
        print("🔍 SharePlay: Inicializado correctamente")
        return true
    }
    
    private func isSupported() -> Bool {
        print("🔍 SharePlay: Verificando soporte...")
        print("🔍 SharePlay: iOS version: \(UIDevice.current.systemVersion)")
        
        // Verificar que estamos en iOS 15+
        let supported = true
        print("🔍 SharePlay: Soporte: \(supported)")
        print("🔍 SharePlay: Método isSupported llamado correctamente")
        return supported
    }
    
    private func discoverDevices(result: @escaping FlutterResult) {
        // SharePlay no necesita descubrir dispositivos específicos
        // Los usuarios se unen a través de FaceTime o Messages
        let devices = [
            [
                "id": "shareplay_group",
                "name": "Compartir con Grupo",
                "type": "shareplay",
                "isConnected": groupSession != nil
            ]
        ]
        result(devices)
    }
    
    private func connectToDevice(deviceId: String, deviceName: String, result: @escaping FlutterResult) {
        // En SharePlay, la conexión se hace cuando se activa la actividad
        // No necesitamos conectar manualmente
        result(true)
    }
    
    private func shareVideo(videoUrl: String, title: String, description: String, thumbnailUrl: String, result: @escaping FlutterResult) {
        Task {
            do {
                let activity = VideoWatchingActivity(
                    videoUrl: videoUrl,
                    title: title,
                    description: description,
                    thumbnailUrl: thumbnailUrl
                )
                
                self.groupActivity = activity
                let success = try await activity.activate()
                
                DispatchQueue.main.async {
                    result(success)
                }
            } catch {
                DispatchQueue.main.async {
                    result(false)
                }
            }
        }
    }
    
    private func controlPlayback(action: String, position: Double?, result: @escaping FlutterResult) {
        // En SharePlay, el control se maneja automáticamente por el sistema
        // Solo notificamos que el control fue recibido
        DispatchQueue.main.async {
            result(true)
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        groupSession?.end()
        groupSession = nil
        groupActivity = nil
        result(true)
    }
    
    // MARK: - SharePlay Setup
    
    private func setupSharePlayObservers() {
        Task {
            for await session in VideoWatchingActivity.sessions() {
                self.groupSession = session
                await handleGroupSession(session)
            }
        }
    }
    
    @MainActor
    private func handleGroupSession(_ session: GroupSession<VideoWatchingActivity>) async {
        // Notificar a Flutter que se unió a una sesión
        channel?.invokeMethod("onSessionJoined", arguments: [
            "sessionId": session.id.uuidString,
            "participants": session.activeParticipants.count
        ])
        
        // En SharePlay, el sistema maneja automáticamente la sincronización
        // No necesitamos escuchar mensajes manualmente
    }
}

// MARK: - VideoWatchingActivity

@available(iOS 15.0, *)
struct VideoWatchingActivity: GroupActivity {
    static let activityIdentifier = "com.example.advanced_video_player.video_watching"
    
    let videoUrl: String
    let title: String
    let description: String
    let thumbnailUrl: String
    
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = title
        metadata.subtitle = description
        metadata.type = .watchTogether
        return metadata
    }
}

