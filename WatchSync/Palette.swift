import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Tracker colors, shared by the iPhone app, the widget and the Watch app.
enum Palette {
    /// (light, dark) pairs. Index 0 matches the web Tally's default blue.
    static let pairs: [(UInt32, UInt32)] = [
        (0x3547D4, 0x8A9BFF), // indigo
        (0x1E8A5A, 0x5FD39B), // green
        (0xB8367A, 0xF27DB8), // magenta
        (0xB7791F, 0xF2B860), // amber
        (0x0E7C8C, 0x4FC9D9), // teal
        (0x6A4BB5, 0xB59CF5), // violet
        (0xC2412D, 0xFF8A75), // red
        (0x2F7FC1, 0x7CBEF5), // sky
        (0x6B7A1F, 0xB8C95A), // olive
        (0x4A5868, 0xA3B0BE), // slate
    ]

    static var count: Int { pairs.count }

    static func color(_ index: Int) -> Color {
        let (light, dark) = pairs[((index % count) + count) % count]
        #if os(watchOS)
        // The watch is always dark.
        _ = light
        return Color(hex: dark)
        #else
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #endif
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

#if canImport(UIKit) && !os(watchOS)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif
