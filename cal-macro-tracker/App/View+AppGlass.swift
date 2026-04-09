import SwiftUI

extension View {
    @ViewBuilder
    func appGlassCircle(interactive: Bool = true) -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: .circle)
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func appGlassRoundedRect(cornerRadius: CGFloat, interactive: Bool = true) -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(PlatformColors.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
