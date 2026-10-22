import SwiftUI

/// Compatibility utility kept for older views in the project.
/// The core culling UI intentionally uses standard macOS materials rather than
/// a configurable visual-effect system.
struct LiquidGlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    var tint: Color?
    var baseColor: Color = .black
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content()
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(baseColor.opacity(0.22))
                    if let tint {
                        shape.fill(tint.opacity(0.06))
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.10))
            }
    }
}
