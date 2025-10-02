import Flutter

@objc public class PictureInPicturePluginRegistrant: NSObject {
    @objc public static func register(with registrar: FlutterPluginRegistrar) {
        PictureInPicturePlugin.register(with: registrar)
        if #available(iOS 15.0, *) {
            ScreenSharingPlugin.register(with: registrar)
        }
    }
}
