import AppKit
import Observation
import SwiftUI

/// What the speech bubble above the pet currently says.
@MainActor
@Observable
final class BubbleModel {
    var text: String?
    /// An SF Symbol shown before the text.
    var symbol: String?
    /// How far above the bottom of the pet window the sprite's head is (the bubble sits just over it).
    var spriteTop: CGFloat = 100
}

/// A Liquid Glass bubble drawn by SwiftUI on top of the SpriteKit view.
struct PetBubbleView: View {
    let model: BubbleModel

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let text = model.text {
                HStack(spacing: 6) {
                    if let symbol = model.symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 184)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    .id(text)
            }
        }
        .padding(.bottom, model.spriteTop + 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.3), value: model.text)
        .allowsHitTesting(false)
    }
}

/// A hosting view that never takes mouse events, so clicks and drags reach the pet underneath.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
