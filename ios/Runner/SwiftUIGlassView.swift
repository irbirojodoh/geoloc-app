import SwiftUI

/// Liquid-glass container rendered with SwiftUI materials.
///
/// Uses the system `.clear` Liquid Glass variant when available so transparency
/// follows Display & Accessibility settings (Reduce Transparency, tinted glass, etc.).
struct SwiftUIGlassView: View {
  let title: String
  let subtitle: String
  let topLeadingRadius: CGFloat
  let topTrailingRadius: CGFloat
  let bottomLeadingRadius: CGFloat
  let bottomTrailingRadius: CGFloat

  private var showsText: Bool {
    !title.isEmpty || !subtitle.isEmpty
  }

  private var glassShape: UnevenContinuousRoundedRect {
    UnevenContinuousRoundedRect(
      topLeading: topLeadingRadius,
      topTrailing: topTrailingRadius,
      bottomLeading: bottomLeadingRadius,
      bottomTrailing: bottomTrailingRadius
    )
  }

  var body: some View {
    content
      .modifier(SystemLiquidGlassModifier(shape: glassShape))
      .overlay(
        glassShape.strokeBorder(
          LinearGradient(
            colors: [
              Color.white.opacity(0.35),
              Color.white.opacity(0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1.0
        )
      )
      .shadow(color: Color.black.opacity(0.08), radius: 12, y: 8)
      .ignoresSafeArea()
  }

  @ViewBuilder
  private var content: some View {
    if showsText {
      VStack(alignment: .leading, spacing: 6) {
        if !title.isEmpty {
          Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
        }
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      // Chrome-only mode: fill the platform-view bounds (nav / top bar).
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

/// Continuous rounded rect with independent corner radii (iOS 15+).
private struct UnevenContinuousRoundedRect: InsettableShape {
  var topLeading: CGFloat
  var topTrailing: CGFloat
  var bottomLeading: CGFloat
  var bottomTrailing: CGFloat
  var insetAmount: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
    let tl = max(0, topLeading - insetAmount)
    let tr = max(0, topTrailing - insetAmount)
    let bl = max(0, bottomLeading - insetAmount)
    let br = max(0, bottomTrailing - insetAmount)

    var path = Path()
    path.move(to: CGPoint(x: r.minX + tl, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
    path.addQuadCurve(
      to: CGPoint(x: r.maxX, y: r.minY + tr),
      control: CGPoint(x: r.maxX, y: r.minY)
    )
    path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
    path.addQuadCurve(
      to: CGPoint(x: r.maxX - br, y: r.maxY),
      control: CGPoint(x: r.maxX, y: r.maxY)
    )
    path.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
    path.addQuadCurve(
      to: CGPoint(x: r.minX, y: r.maxY - bl),
      control: CGPoint(x: r.minX, y: r.maxY)
    )
    path.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
    path.addQuadCurve(
      to: CGPoint(x: r.minX + tl, y: r.minY),
      control: CGPoint(x: r.minX, y: r.minY)
    )
    path.closeSubpath()
    return path
  }

  func inset(by amount: CGFloat) -> UnevenContinuousRoundedRect {
    var copy = self
    copy.insetAmount += amount
    return copy
  }
}

/// Applies the most transparent system glass that respects user settings.
private struct SystemLiquidGlassModifier<S: Shape>: ViewModifier {
  let shape: S

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      // `.clear` is the highest-transparency Liquid Glass variant.
      // System settings (Reduce Transparency / Liquid Glass tint) adapt automatically.
      content.glassEffect(.clear, in: shape)
    } else {
      // Thinnest pre-Liquid-Glass material; still respects Reduce Transparency.
      content.background(.ultraThinMaterial, in: shape)
    }
  }
}
