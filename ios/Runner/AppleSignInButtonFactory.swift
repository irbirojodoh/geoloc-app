import AuthenticationServices
import Flutter
import UIKit

/// Hosts Apple's [ASAuthorizationAppleIDButton] inside a Flutter platform view.
final class AppleSignInButtonPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let button: ASAuthorizationAppleIDButton
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let params = args as? [String: Any]
    let styleName = (params?["style"] as? String) ?? "white"
    let typeName = (params?["type"] as? String) ?? "signIn"
    let cornerRadius = (params?["cornerRadius"] as? NSNumber)?.doubleValue ?? 22

    let style: ASAuthorizationAppleIDButton.Style
    switch styleName {
    case "black":
      style = .black
    case "whiteOutline":
      style = .whiteOutline
    default:
      style = .white
    }

    let type: ASAuthorizationAppleIDButton.ButtonType
    switch typeName {
    case "signUp":
      type = .signUp
    case "continue":
      type = .continue
    default:
      type = .signIn
    }

    button = ASAuthorizationAppleIDButton(
      authorizationButtonType: type,
      authorizationButtonStyle: style
    )
    button.cornerRadius = cornerRadius
    button.translatesAutoresizingMaskIntoConstraints = false

    channel = FlutterMethodChannel(
      name: "com.irphotoarts.geoloc.apple_id_button/\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    container.frame = frame
    container.backgroundColor = .clear
    container.isOpaque = false
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    button.addTarget(self, action: #selector(pressed), for: .touchUpInside)
  }

  func view() -> UIView { container }

  @objc private func pressed() {
    channel.invokeMethod("onPressed", arguments: nil)
  }
}

/// Factory that creates [AppleSignInButtonPlatformView] instances.
final class AppleSignInButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AppleSignInButtonPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
