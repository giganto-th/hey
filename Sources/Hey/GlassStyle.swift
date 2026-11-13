import AppKit
import SwiftUI
import HeyDomain

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
    // The Hub is light frosted glass over a soft pastel sky: peach, lavender and pale blue.
    static let deep = Color(red: 0.62, green: 0.72, blue: 0.94)
    static let sky = Color(red: 0.80, green: 0.76, blue: 0.97)
    static let glow = Color(red: 0.18, green: 0.48, blue: 0.95)      // the one main colour: blue
    static let accent = Color(red: 0.18, green: 0.48, blue: 0.95)
    static let peach = Color(red: 1.0, green: 0.76, blue: 0.62)

    /// The surface colour of cards and panels: white in light mode, a soft charcoal in dark mode (used with an opacity).
    static let surface = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.17, alpha: 1) : .white })
    /// The hairline around glass surfaces.
    static let edge = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.12) : NSColor(white: 1, alpha: 0.9) })
    /// The flat tint laid over the blurred desktop.
    static let backdrop = Color(nsColor: NSColor(name: nil) { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
                                                           : NSColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 1) })
}

/// Light, dark, or whatever macOS is set to. The Hub's own choice, kept in its settings.
enum HubAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
    var title: String {
        switch self {
        case .system: tr("ตามระบบ")
        case .light: tr("สว่าง")
        case .dark: tr("มืด")
        }
    }
}

/// The Hub's backdrop: what is behind the window, blurred, under one flat pale tint. No gradients.
struct HubBackdrop: View {
    /// How much of the tint covers the blur: lower lets more of the desktop show through.
    var opacity: Double = 0.35
    var part: DayPart = .afternoon

    var body: some View {
        ZStack {
            BehindWindowBlur()
            HeyLook.backdrop.opacity(0.6 * min(max(opacity, 0), 1))
        }
        .ignoresSafeArea()
    }
}

/// The desktop behind the window, blurred (a real vibrancy view, drawn by the system).
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        let env = ProcessInfo.processInfo.environment
        if env["HEY_DEV"] != nil, let raw = env["HEY_DEV_MATERIAL"].flatMap(Int.init), let m = NSVisualEffectView.Material(rawValue: raw) {
            v.material = m                                      // dev only: try another material
        } else {
            v.material = .fullScreenUI                 // the most see-through light material: the desktop shows, softly blurred
        }
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
    /// A rounded white panel that holds a page's content: flat white over the blurred backdrop, as clear as the "background opacity" setting says.
    func heyPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(HubPanel(cornerRadius: cornerRadius))
    }

    /// A small white pill (the coin and streak counters).
    func hubPill() -> some View {
        padding(.horizontal, 12).padding(.vertical, 6)
            .background(HeyLook.surface.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(HeyLook.edge, lineWidth: 1))
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
                Capsule().fill(HeyLook.accent)
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
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(hovering ? 0.75 : 0.5)))
            .frame(width: 62, height: 50)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(HeyLook.accent)
                        .shadow(color: HeyLook.accent.opacity(0.30), radius: 8, y: 3)
                        .matchedGeometryEffect(id: "rail", in: space)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 18).fill(HeyLook.surface.opacity(0.7))
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
        self.buttonStyle(.borderedProminent)
    }

    /// The secondary button look: glass on macOS 26, bordered before.
    @ViewBuilder
    func heySecondaryButton() -> some View {
        self.buttonStyle(.bordered)
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

private struct HubOpacityKey: EnvironmentKey { static let defaultValue = 0.35 }
extension EnvironmentValues {
    /// The Hub's "background opacity" setting (0.2...1), for the panels that sit on the backdrop.
    var hubOpacity: Double {
        get { self[HubOpacityKey.self] }
        set { self[HubOpacityKey.self] = newValue }
    }
}

private struct HubPanel: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.hubOpacity) private var opacity

    func body(content: Content) -> some View {
        content
            .clipShape(.rect(cornerRadius: cornerRadius))
            .background(HeyLook.surface.opacity(0.05 + 0.5 * opacity), in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(HeyLook.edge, lineWidth: 1))
    }
}
