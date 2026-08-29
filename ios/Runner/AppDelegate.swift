import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let glassRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "SwiftUIGlassPlugin")!
    let glassFactory = SwiftUIGlassFactory(messenger: glassRegistrar.messenger())
    glassRegistrar.register(glassFactory, withId: "com.example.native_liquid_glass")

    let appleRegistrar =
      engineBridge.pluginRegistry.registrar(forPlugin: "AppleSignInButtonPlugin")!
    let appleFactory = AppleSignInButtonFactory(messenger: appleRegistrar.messenger())
    appleRegistrar.register(appleFactory, withId: "com.irphotoarts.geoloc.apple_id_button")
  }
}
