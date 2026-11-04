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

// MARK: Hub look: deep blue, soft bubbles, frosted glass panels, one bright pill action

enum HeyLook {
    static let deep = Color(red: 0.02, green: 0.10, blue: 0.27)
    static let sky = Color(red: 0.05, green: 0.34, blue: 0.64)
    static let glow = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let accent = Color(red: 0.55, green: 0.42, blue: 0.95)
}

/// The Hub's backdrop: a blue gradient with a few blurred bubbles drifting behind the glass.
struct HubBackdrop: View {
    /// 1 is the full deep blue; lower lets the desktop show through the window.
    var opacity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(colors: [HeyLook.deep, HeyLook.sky], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [HeyLook.glow.opacity(0.45), .clear], center: .init(x: 0.62, y: 0.18), startRadius: 10, endRadius: 420)
            Circle().fill(HeyLook.glow.opacity(0.16)).frame(width: 260).blur(radius: 30).offset(x: -260, y: 240)
            Circle().fill(HeyLook.accent.opacity(0.18)).frame(width: 220).blur(radius: 36).offset(x: 300, y: 260)
        }
        .opacity(opacity)
        .ignoresSafeArea()
    }
}

extension View {
    /// A rounded Liquid Glass panel that holds a page's content.
    func heyPanel(cornerRadius: CGFloat = 24) -> some View {
        clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// The single bright call to action, like "Review & Remove": a violet-to-blue capsule with a soft glow.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.55))
            .padding(.horizontal, 20).padding(.vertical, 9)
            .background(
                Capsule().fill(LinearGradient(colors: [HeyLook.accent, HeyLook.sky], startPoint: .leading, endPoint: .trailing))
                    .opacity(enabled ? 1 : 0.45))
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: HeyLook.accent.opacity(enabled ? 0.45 : 0), radius: 10, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// One round button of the Hub's left rail; the selected one sits in a glowing bubble.
struct RailButton: View {
    let symbol: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.7))
                .frame(width: 44, height: 44)
                .background {
                    if selected {
                        Circle().fill(LinearGradient(colors: [HeyLook.glow.opacity(0.55), HeyLook.accent.opacity(0.45)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                            .shadow(color: HeyLook.glow.opacity(0.6), radius: 8)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}
