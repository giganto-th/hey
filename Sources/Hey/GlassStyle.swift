import SwiftUI

/// One place for how Liquid Glass is used, so every window feels the same.
extension View {
    /// A floating glass card (toasts, the player bar, the timer).
    func glassCard(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        heyGlass(.rect(cornerRadius: cornerRadius), tint: tint)
    }

    /// A small glass pill (counters, badges).
    func glassPill() -> some View {
        padding(.horizontal, 12).padding(.vertical, 6).heyGlass(.capsule)
    }
}

// MARK: Hub look: deep blue, soft bubbles, frosted glass panels, one bright pill action

enum HeyLook {
    static let deep = Color(red: 0.02, green: 0.10, blue: 0.27)
    static let sky = Color(red: 0.05, green: 0.34, blue: 0.64)
    static let glow = Color(red: 0.36, green: 0.66, blue: 1.0)
    static let accent = Color(red: 0.55, green: 0.42, blue: 0.95)
}

/// The Hub's backdrop: a gradient that follows the time of day, with two soft blurred blobs behind the glass. Static: it never animates.
struct HubBackdrop: View {
    /// 1 is the full colour; lower lets the desktop show through the window.
    var opacity: Double = 1
    var part: DayPart = .afternoon

    var body: some View {
        let c = part.colors
        ZStack {
            LinearGradient(colors: [c.top, c.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [c.glow.opacity(0.42), .clear], center: .init(x: 0.62, y: 0.16), startRadius: 10, endRadius: 440)
            Circle().fill(c.glow.opacity(0.14)).frame(width: 260).blur(radius: 30).offset(x: -260, y: 240)
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
            .heyGlass(.rect(cornerRadius: cornerRadius))
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

/// One button of the Hub's left rail: a symbol over a short label. The selected one sits in a glowing bubble that slides to the next.
struct RailButton: View {
    let symbol: String
    let title: String
    let selected: Bool
    var space: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .symbolVariant(selected ? .fill : .none)
                    .frame(height: 24)
                Text(title).font(.system(size: 10, weight: selected ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white.opacity(selected ? 1 : hovering ? 0.9 : 0.62))
            .frame(width: 62, height: 50)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [HeyLook.glow.opacity(0.5), HeyLook.accent.opacity(0.4)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: HeyLook.glow.opacity(0.5), radius: 7)
                        .matchedGeometryEffect(id: "rail", in: space)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.08))
                }
            }
            .frame(width: 76, height: 56)                   // the whole cell takes the click
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: macOS 15 and 26
// Liquid Glass exists from macOS 26. These wrappers use it there and a translucent material with a hairline edge on macOS 15,
// so every screen keeps working on both.

/// Dev only: `HEY_DEV=1 HEY_DEV_NO_GLASS=1` draws everything the way macOS 15 would, to check that look on a newer Mac.
enum GlassMode {
    static let useLiquidGlass: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["HEY_DEV"] != nil, env["HEY_DEV_NO_GLASS"] != nil { return false }
        if #available(macOS 26, *) { return true } else { return false }
    }()
}

extension View {
    /// A glass surface in `shape`: Liquid Glass on macOS 26, a blurred material before that.
    @ViewBuilder
    func heyGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *), GlassMode.useLiquidGlass {
            let base: Glass = interactive ? .regular.interactive() : .regular
            self.glassEffect(tint.map { base.tint($0) } ?? base, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .background(tint.map { $0.opacity(0.35) } ?? .clear, in: shape)
                .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 0.6))
        }
    }

    /// The prominent (filled) button look: glass on macOS 26, the standard prominent style before.
    @ViewBuilder
    func heyProminentButton() -> some View {
        if #available(macOS 26, *), GlassMode.useLiquidGlass { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.borderedProminent) }
    }

    /// The secondary button look: glass on macOS 26, bordered before.
    @ViewBuilder
    func heySecondaryButton() -> some View {
        if #available(macOS 26, *), GlassMode.useLiquidGlass { self.buttonStyle(.glass) } else { self.buttonStyle(.bordered) }
    }
}

/// Groups glass surfaces so they blend (macOS 26); a plain container before.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26, *), GlassMode.useLiquidGlass { GlassEffectContainer(spacing: spacing) { content() } } else { content() }
    }
}
