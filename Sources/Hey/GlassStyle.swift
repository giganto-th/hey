import SwiftUI

/// One place for how Liquid Glass is used, so every window feels the same.
extension View {
    /// A floating glass card (toasts, the player bar, the timer).
    func glassCard(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// A small glass pill (counters, badges).
    func glassPill() -> some View {
        padding(.horizontal, 12).padding(.vertical, 6).glassEffect(.regular, in: .capsule)
    }
}
