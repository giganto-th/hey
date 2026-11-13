import SwiftUI
import HeyDomain

/// Building blocks of the Hub's look. Everything here is static or springs once on a change: nothing loops, so an open Hub costs
/// nothing while you are not touching it.

// MARK: time of day

/// The Hub's mood follows the clock: the backdrop tint and the greeting.
enum DayPart {
    case morning, afternoon, evening, night

    init(hour: Int) {
        switch hour {
        case 5..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }

    static var now: DayPart { DayPart(hour: Calendar.current.component(.hour, from: Date())) }

    var greeting: String {
        switch self {
        case .morning: tr("อรุณสวัสดิ์")
        case .afternoon: tr("สวัสดีตอนบ่าย")
        case .evening: tr("สวัสดีตอนเย็น")
        case .night: tr("ดึกแล้วนะ")
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sun.horizon"
        case .afternoon: "sun.max"
        case .evening: "sunset"
        case .night: "moon.stars"
        }
    }

    /// One flat, very pale cool tint laid over the blurred backdrop (the time of day no longer changes the colour).
    var tint: Color { Color(red: 0.94, green: 0.96, blue: 1.0) }
}

// MARK: card

/// A glass card with an optional small title. It lifts a touch when the pointer is over it.
struct HubCard<Content: View>: View {
    var title: String? = nil
    var symbol: String? = nil
    var tint: Color? = nil
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 6) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(tint ?? HeyLook.glow) }
                    Text(title)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubSurface(hovering: hovering, tint: tint)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// A whole card that is one button: a symbol, a title, one line of state, and optional trailing controls.
struct HubTile<Trailing: View>: View {
    let symbol: String
    let title: String
    let value: String
    var tint: Color = HeyLook.glow
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 40, height: 40)
                        .background(tint.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text(value).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            trailing()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubSurface(hovering: hovering)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

extension HubTile where Trailing == EmptyView {
    init(symbol: String, title: String, value: String, tint: Color = HeyLook.glow, action: @escaping () -> Void) {
        self.init(symbol: symbol, title: title, value: value, tint: tint, action: action) { EmptyView() }
    }
}

// MARK: rings

/// A round gauge. It fills once with a spring, shifts from blue through amber to red as it drains, and a nearly empty one pulses its icon.
struct StatRing: View {
    let value: Double
    var total: Double = 100
    let symbol: String
    let title: String
    var lineWidth: CGFloat = 9
    var diameter: CGFloat = 84
    /// For gauges where a high value is the bad end (CPU, disk): the colour turns warm as it fills instead of as it drains.
    var inverted = false
    var unit = ""
    /// Live gauges (CPU, memory) change every couple of seconds; springing each time would keep the screen redrawing, so they just move.
    var animated = true
    @State private var shown = false

    private var fraction: Double { total > 0 ? min(max(value / total, 0), 1) : 0 }
    private var color: Color {
        let red = Color(red: 1.0, green: 0.38, blue: 0.36), amber = Color(red: 1.0, green: 0.72, blue: 0.30)
        // a draining gauge (needs) turns warm as it empties; a filling one (CPU, disk) as it fills
        if inverted { return fraction >= 0.9 ? red : fraction >= 0.75 ? amber : HeyLook.glow }
        return fraction < 0.2 ? red : fraction < 0.45 ? amber : HeyLook.glow
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.primary.opacity(0.08), lineWidth: lineWidth)
                Circle().trim(from: 0, to: shown ? fraction : 0)
                    .stroke(color.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round))      // a soft glow without a blur pass
                    .rotationEffect(.degrees(-90))
                Circle().trim(from: 0, to: shown ? fraction : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(color)
                        .symbolEffect(.pulse, isActive: animated && (inverted ? fraction >= 0.9 : fraction < 0.2))
                    Text("\(Int(value))\(unit)").font(.system(diameter < 80 ? .footnote : .callout, design: .rounded).weight(.semibold)).monospacedDigit()
                        .contentTransition(animated ? .numericText() : .identity)
                }
            }
            .frame(width: diameter, height: diameter)
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(animated ? .spring(response: 0.6, dampingFraction: 0.8) : nil, value: fraction)
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.05)) { shown = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value))")
    }
}

/// A thin capsule meter for quests, XP and similar.
struct SlimBar: View {
    let value: Double
    let total: Double
    var tint: Color = HeyLook.glow
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            let fraction = total > 0 ? min(max(value / total, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(tint)
                    .frame(width: max(shown ? proxy.size.width * fraction : 0, fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) { shown = true } }
    }
}

// MARK: tabs

/// The pages inside one rail destination, as chips; the highlight slides between them.
struct HubChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item
    @Namespace private var space

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let on = item == selection
                Button { withAnimation(.snappy(duration: 0.25)) { selection = item } } label: {
                    Text(title(item))
                        .font(.callout.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.6)))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background {
                            if on {
                                Capsule().fill(HeyLook.accent)
                                    .shadow(color: HeyLook.accent.opacity(0.28), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "chip", in: space)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(HeyLook.surface.opacity(0.5), in: Capsule())
    }
}

// MARK: pills

extension View {
    /// A tinted capsule label (stage, level, status).
    func chipLabel(_ tint: Color = HeyLook.glow) -> some View {
        font(.caption.weight(.semibold)).foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(tint.opacity(0.16), in: Capsule())
    }
}

extension View {
    /// A flat, softly lit card on the Hub's glass panel (glass on glass would look muddy, and is dearer to draw).
    func hubSurface(hovering: Bool = false, tint: Color? = nil) -> some View {
        modifier(HubSurface(hovering: hovering, tint: tint))
    }
}

private struct HubSurface: ViewModifier {
    let hovering: Bool
    let tint: Color?
    @Environment(\.hubOpacity) private var opacity

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(HeyLook.surface.opacity((hovering ? 0.42 : 0.30) + 0.5 * opacity))
                    .overlay { if let tint { RoundedRectangle(cornerRadius: 20).fill(tint.opacity(0.12)) } }
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(HeyLook.edge, lineWidth: 1))
    }
}
