import Flutter

@objc public class ScreenSharingPluginRegistrant: NSObject {
  @objc public static func register(with registrar: FlutterPluginRegistrar) {
    if #available(iOS 15.0, *) {
      ScreenSharingPlugin.register(with: registrar)
    }
  }
}
