import Flutter
import UIKit
import AVFoundation
import AVKit

@available(iOS 13.0, *)
public class AdvancedVideoPlayerPlugin: NSObject, FlutterPlugin {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var eventSink: FlutterEventSink?
    private var routePickerView: AVRoutePickerView?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Registrar el plugin principal
        let channel = FlutterMethodChannel(name: "advanced_video_player", binaryMessenger: registrar.messenger())
        let instance = AdvancedVideoPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Canal de eventos para enviar datos a Flutter (opcional)
        let eventChannel = FlutterEventChannel(name: "advanced_video_player/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        // Registrar la vista AirPlay (para mostrar el botón)
        let factory = AirPlayButtonFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "advanced_video_player/airplay_button")
        
        // Registrar plugins específicos
        PictureInPicturePlugin.register(with: registrar)
        
        // Solo registrar ScreenSharingPlugin si está disponible (iOS 15.0+)
        if #available(iOS 15.0, *) {
            ScreenSharingPlugin.register(with: registrar)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "setUrl":
            if let args = call.arguments as? [String: Any],
               let urlStr = args["url"] as? String,
               let url = URL(string: urlStr) {
                setupPlayer(url: url)
                result(nil)
            } else {
                result(FlutterError(code: "bad_args", message: "URL inválida", details: nil))
            }

        case "play":
            player?.play()
            sendEvent(["event": "playing"])
            result(nil)

        case "pause":
            player?.pause()
            sendEvent(["event": "paused"])
            result(nil)

        case "startPiP":
            startPiP()
            result(nil)

        case "isAirPlayActive":
            result(isAirPlayActive())
            
        case "getAirPlayDevices":
            getAirPlayDevices(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Configuración AVPlayer
    private func setupPlayer(url: URL) {
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        
        // Configurar sesión de audio para AirPlay
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Error al configurar AVAudioSession: \(error)")
        }
    }

    private func startPiP() {
        guard let player = player else { return }
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        
        if #available(iOS 14.2, *) {
            vc.canStartPictureInPictureAutomaticallyFromInline = true
        }

        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(vc, animated: true) {
                    player.play()
                }
            }
        } else {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                rootVC.present(vc, animated: true) {
                    player.play()
                }
            }
        }
    }

    // MARK: - AirPlay
    private func isAirPlayActive() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains(where: { $0.portType == .airPlay })
    }
    
    private func getAirPlayDevices(result: @escaping FlutterResult) {
        // Obtener información de dispositivos AirPlay disponibles
        let outputs = AVAudioSession.sharedInstance().availableInputs ?? []
        let airPlayDevices = outputs.filter { $0.portType == .airPlay }
        
        let devices = airPlayDevices.map { output in
            return [
                "name": output.portName,
                "uid": output.uid,
                "type": "airplay"
            ]
        }
        
        result(devices)
    }

    // MARK: - Eventos
    private func sendEvent(_ data: [String: Any]) {
        eventSink?(data)
    }
}

// MARK: - FlutterStreamHandler (para eventos)
extension AdvancedVideoPlayerPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - AirPlayButtonFactory
class AirPlayButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        AirPlayButtonView()
    }
}

class AirPlayButtonView: NSObject, FlutterPlatformView {
    private let airPlayView: AVRoutePickerView

    override init() {
        airPlayView = AVRoutePickerView()
        super.init()
        if #available(iOS 13.0, *) {
            airPlayView.prioritizesVideoDevices = true
            airPlayView.tintColor = UIColor.white
        }
    }

    func view() -> UIView {
        return airPlayView
    }
}