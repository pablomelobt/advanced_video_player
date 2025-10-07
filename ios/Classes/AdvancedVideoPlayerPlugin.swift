import Flutter
import UIKit
import AVFoundation
import AVKit

@available(iOS 13.0, *)
public class AdvancedVideoPlayerPlugin: NSObject, FlutterPlugin, AVPictureInPictureControllerDelegate {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    private var playerViewController: AVPlayerViewController?

    private var pipContainerView: UIView?

    // Propiedades para restaurar el layer original
    private weak var originalLayerSuperlayer: CALayer?
    private var originalLayerFrame: CGRect = .zero

    static var sharedPlayer: AVPlayer?
    static var sharedPlayerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?


    public static func register(with registrar: FlutterPluginRegistrar) {


        let instance = AdvancedVideoPlayerPlugin()


        let channel = FlutterMethodChannel(name: "advanced_video_player", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)



        let eventChannel = FlutterEventChannel(name: "advanced_video_player/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(NormalEvents.shared)

        let pipChannel = FlutterMethodChannel(name: "picture_in_picture_service", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: pipChannel)

        let pipEventChannel = FlutterEventChannel(name: "picture_in_picture_service_events", binaryMessenger: registrar.messenger())
        pipEventChannel.setStreamHandler(PiPEvents.shared)


        let factory = AirPlayButtonFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "advanced_video_player/airplay_button")


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


        case "isPictureInPictureSupported":
            let supported = AVPictureInPictureController.isPictureInPictureSupported()
            result(supported)

        case "enterPictureInPictureMode":
            let args = call.arguments as? [String: Any]
            let width = args?["width"] as? Double ?? 300.0
            let height = args?["height"] as? Double ?? 200.0
            result(enterPictureInPictureMode(width: width, height: height))

        case "exitPictureInPictureMode":
            result(exitPictureInPictureMode())

        case "isInPictureInPictureMode":
            result(isInPictureInPictureMode())

        default:
            result(FlutterMethodNotImplemented)
        }
    }


    private func setupPlayer(url: URL) {
        print("[DEBUG] 🎬 Configurando player con URL: \(url)")
        if pipController?.isPictureInPictureActive == true {
            print("[DEBUG] ⚠️ Ignorando setUrl, PiP activo (evita reinicio en 0)")
            return
        }


        if let shared = AdvancedVideoPlayerPlugin.sharedPlayer,
           let currentItem = shared.currentItem,
           let asset = currentItem.asset as? AVURLAsset,
           asset.url == url {
            print("[DEBUG] ♻️ Reutilizando player existente, no se reinicia video")
            self.player = shared
            self.playerLayer = AdvancedVideoPlayerPlugin.sharedPlayerLayer
            return
        }


        let playerItem = AVPlayerItem(url: url)
        let player = AdvancedVideoPlayerPlugin.sharedPlayer ?? AVPlayer()
        player.replaceCurrentItem(with: playerItem)

        let layer = AdvancedVideoPlayerPlugin.sharedPlayerLayer ?? AVPlayerLayer(player: player)
        layer.player = player
        layer.videoGravity = .resizeAspect

        AdvancedVideoPlayerPlugin.sharedPlayer = player
        AdvancedVideoPlayerPlugin.sharedPlayerLayer = layer
        self.player = player
        self.playerLayer = layer

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
        try? AVAudioSession.sharedInstance().setActive(true)
        
    }


    private func enterPictureInPictureMode(width: Double, height: Double) -> Bool {


        print("[DEBUG] 🎥 Activando PiP con player compartido...")

        guard let player = AdvancedVideoPlayerPlugin.sharedPlayer,
              let layer = AdvancedVideoPlayerPlugin.sharedPlayerLayer else {
            print("[DEBUG] ❌ No hay player o layer existente")
            return false
        }

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[DEBUG] ❌ PiP no soportado")
            return false
        }


        if pipController != nil {
            if pipController!.isPictureInPicturePossible {
                pipController!.startPictureInPicture()
                return true
            }
        }

        DispatchQueue.main.async {

            self.originalLayerSuperlayer = layer.superlayer
            self.originalLayerFrame = layer.frame


            let dummy = UIView(frame: CGRect(x: -200, y: -200, width: 200, height: 150))
            dummy.isUserInteractionEnabled = false
            dummy.backgroundColor = .black
            layer.removeFromSuperlayer()
            layer.frame = dummy.bounds
            dummy.layer.addSublayer(layer)
            UIApplication.shared.windows.first?.addSubview(dummy)
            self.pipContainerView = dummy

            self.pipController = AVPictureInPictureController(playerLayer: layer)
            self.pipController?.delegate = self
            self.pipController?.startPictureInPicture()
            print("[DEBUG] ✅ PiP iniciado con player compartido")
        }
        return true
    }






    private func exitPictureInPictureMode() -> Bool {
        pipController?.stopPictureInPicture()
        return true
    }

    private func isInPictureInPictureMode() -> Bool {
        return pipController?.isPictureInPictureActive ?? false
    }


    public func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[DEBUG] ✅ PiP iniciado correctamente")
        
        // NO reiniciar el video, mantener el estado actual
        if let player = AdvancedVideoPlayerPlugin.sharedPlayer {
            // Solo reanudar si estaba pausado, pero mantener el tiempo actual
            if player.rate == 0 {
                player.play()
                print("[DEBUG] ▶️ Video reanudado en PiP (manteniendo tiempo actual)")
            } else {
                print("[DEBUG] ▶️ Video ya estaba reproduciéndose, manteniendo estado")
            }
        }
        
        sendPiPEvent(["event": "pip_started"])
        

        if let player = AdvancedVideoPlayerPlugin.sharedPlayer {
            print("[DEBUG] 📺 Player time en PiP: \(player.currentTime())")
            print("[DEBUG] ▶️ Player playing en PiP: \(player.rate > 0)")
        }
        

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handlePiPNavigation()
        }
    }
    

    private func handlePiPNavigation() {
        print("[DEBUG] 🚀 Ejecutando navegación automática desde PiP...")
        

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            

            if let navigationController = findNavigationController(from: rootViewController) {
                print("[DEBUG] 📱 Haciendo pop desde NavigationController...")
                navigationController.popViewController(animated: true)
            } else {

                if let presentedVC = rootViewController.presentedViewController {
                    print("[DEBUG] 📱 Haciendo dismiss de modal...")
                    presentedVC.dismiss(animated: true, completion: nil)
                } else {

                    print("[DEBUG] 📱 Minimizando app al home...")
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                }
            }
        }
    }
    

    private func findNavigationController(from viewController: UIViewController) -> UINavigationController? {
        if let navController = viewController as? UINavigationController {
            return navController
        }
        
        for child in viewController.children {
            if let navController = findNavigationController(from: child) {
                return navController
            }
        }
        
        return nil
    }

    public func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[DEBUG] ⏹️ PiP se detendrá pronto")
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[DEBUG] 🧩 PiP detenido - restaurando layer original...")

        // Detener PiP limpio
        pipController?.delegate = nil
        pipController = nil

        // Restaurar el layer al mismo contenedor y frame
        if let layer = AdvancedVideoPlayerPlugin.sharedPlayerLayer {
            layer.removeFromSuperlayer()
            if let parent = self.originalLayerSuperlayer {
                parent.addSublayer(layer)
                layer.frame = self.originalLayerFrame
                print("[DEBUG] 🔁 Layer restaurado a su superlayer original")
            }
        }

        // Limpiar dummyView
        pipContainerView?.removeFromSuperview()
        pipContainerView = nil

        sendPiPEvent(["event": "pip_stopped"])
    }




    private func sendEvent(_ data: [String: Any]) {
        NormalEvents.shared.send(data)
    }

    private func sendPiPEvent(_ data: [String: Any]) {
        PiPEvents.shared.send(data)
    }
}




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

// MARK: - Event Stream Handlers
final class NormalEvents: NSObject, FlutterStreamHandler {
    static let shared = NormalEvents()
    private var sink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func send(_ data: [String: Any]) {
        sink?(data)
    }
}

final class PiPEvents: NSObject, FlutterStreamHandler {
    static let shared = PiPEvents()
    private var sink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func send(_ data: [String: Any]) {
        sink?(data)
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
