import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The app icons players can pick in Extras, by the name Dart calls them: the main one is nil, the others are the
  /// alternate icon sets in Assets.xcassets that ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES lists.
  private static let icons: [String: String?] = [
    "seawall": nil,
    "lookback": "AppIconLookback",
    "undelivered": "AppIconUndelivered",
  ]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SeawallAppIcon") {
      FlutterMethodChannel(name: "seawall/app_icon", binaryMessenger: registrar.messenger())
        .setMethodCallHandler(Self.handleAppIcon)
    }
  }

  /// "current" answers the icon in use, "set" switches to the one named. iOS switches it at once and shows the player
  /// its own alert saying so.
  private static func handleAppIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let app = UIApplication.shared
    switch call.method {
    case "current":
      let current = app.alternateIconName
      result(icons.first { $0.value == current }?.key ?? "seawall")
    case "set":
      guard let name = call.arguments as? String, let iconName = icons[name] else {
        result(FlutterError(code: "unknown_icon", message: "No app icon called \(call.arguments ?? "nil")", details: nil))
        return
      }
      guard app.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: "This device can't change the app icon", details: nil))
        return
      }
      if app.alternateIconName == iconName {
        result(nil)
        return
      }
      // The handler may run off the main thread, and Flutter wants its answer on it.
      app.setAlternateIconName(iconName) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
