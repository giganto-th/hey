import AppKit
import SwiftUI
import HeyDomain

/// The generated illustrations (food), looked up by name in `Resources/Icons/`. Anything missing falls back to a plain symbol.
@MainActor
enum IconLibrary {
    private static var cache: [String: NSImage] = [:]

    private static let roots: [URL] = {
        var paths: [String] = []
        if let res = Bundle.main.resourcePath { paths.append(res + "/Icons") }       // inside Hey.app
        paths.append(FileManager.default.currentDirectoryPath + "/Resources/Icons")  // swift run from the project folder
        return paths.map { URL(fileURLWithPath: $0) }
    }()

    static func foodImage(_ food: Food) -> NSImage {
        let key = "food_" + food.icon
        if let hit = cache[key] { return hit }
        let image = roots.lazy
            .map { $0.appendingPathComponent(key + ".png") }
            .compactMap { NSImage(contentsOf: $0) }
            .first ?? (NSImage(systemSymbolName: "fork.knife", accessibilityDescription: nil) ?? NSImage())
        cache[key] = image
        return image
    }

    /// A small copy for menus.
    static func foodMenuImage(_ food: Food, size: CGFloat = 18) -> NSImage {
        let source = foodImage(food)
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }
}

struct FoodIconView: View {
    let food: Food
    var size: CGFloat = 32
    var body: some View {
        Image(nsImage: IconLibrary.foodImage(food)).resizable().scaledToFit().frame(width: size, height: size)
    }
}
