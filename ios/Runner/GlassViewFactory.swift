import Flutter
import SwiftUI
import UIKit

/// Hosts [SwiftUIGlassView] inside a Flutter platform view.
final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let hostingController: UIHostingController<SwiftUIGlassView>

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let params = args as? [String: Any]
    let title = (params?["title"] as? String) ?? "Title"
    let subtitle = (params?["subtitle"] as? String) ?? "Subtitle"
    let cornerRadius = Self.cgFloat(params?["cornerRadius"]) ?? 24
    let topLeading =
      Self.cgFloat(params?["topLeadingRadius"]) ?? cornerRadius
    let topTrailing =
      Self.cgFloat(params?["topTrailingRadius"]) ?? cornerRadius
    let bottomLeading =
      Self.cgFloat(params?["bottomLeadingRadius"]) ?? cornerRadius
    let bottomTrailing =
      Self.cgFloat(params?["bottomTrailingRadius"]) ?? cornerRadius

    let glassView = SwiftUIGlassView(
      title: title,
      subtitle: subtitle,
      topLeadingRadius: topLeading,
      topTrailingRadius: topTrailing,
      bottomLeadingRadius: bottomLeading,
      bottomTrailingRadius: bottomTrailing
    )
    hostingController = UIHostingController(rootView: glassView)
    // Critical: clear background so materials sample Flutter underneath.
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false
    hostingController.view.insetsLayoutMarginsFromSafeArea = false
    hostingController.additionalSafeAreaInsets = .zero
    hostingController.view.frame = frame

    super.init()
  }

  func view() -> UIView {
    hostingController.view
  }

  private static func cgFloat(_ value: Any?) -> CGFloat? {
    if let number = value as? NSNumber {
      return CGFloat(truncating: number)
    }
    if let double = value as? Double {
      return CGFloat(double)
    }
    if let int = value as? Int {
      return CGFloat(int)
    }
    return nil
  }
}

/// Factory that creates [GlassPlatformView] instances.
final class SwiftUIGlassFactory: NSObject, FlutterPlatformViewFactory {
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
    GlassPlatformView(
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
