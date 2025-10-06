import Flutter
import UIKit
import AVKit

public class PictureInPicturePlugin: NSObject, FlutterPlugin, AVPictureInPictureControllerDelegate {
    private var pipController: AVPictureInPictureController?
    private var eventSink: FlutterEventSink?
    private var playerLayer: AVPlayerLayer?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "picture_in_picture_service", binaryMessenger: registrar.messenger())
        let instance = PictureInPicturePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "picture_in_picture_service_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isPictureInPictureSupported":
            result(isPictureInPictureSupported())
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
    
    private func isPictureInPictureSupported() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    private func enterPictureInPictureMode(width: Double, height: Double) -> Bool {
        if #available(iOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  windowScene.windows.first != nil else {
                return false
            }
        } else {
            guard UIApplication.shared.keyWindow != nil else {
                return false
            }
        }
        
        // Crear un AVPlayerLayer temporal para PiP
        let player = AVPlayer()
        playerLayer = AVPlayerLayer(player: player)
        
        guard let playerLayer = playerLayer else { return false }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        if let pipController = pipController {
            pipController.startPictureInPicture()
            return true
        }
        
        return false
    }
    
    private func exitPictureInPictureMode() -> Bool {
        pipController?.stopPictureInPicture()
        return true
    }
    
    private func isInPictureInPictureMode() -> Bool {
        return pipController?.isPictureInPictureActive ?? false
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        eventSink?(true)
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // PiP iniciado exitosamente
    }
    
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        eventSink?(false)
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // PiP detenido
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        eventSink?(false)
    }
}

// MARK: - FlutterStreamHandler

extension PictureInPicturePlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
