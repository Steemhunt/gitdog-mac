import SwiftUI

/// GitDog brand tokens (design/README.md). Pixel art is the brand everywhere
/// except the 18pt menu bar; these drive the popover UI.
enum Theme {
    static let navy = Color(hex: 0x1a2440)
    static let navyDeep = Color(hex: 0x131b31)
    static let navyCard = Color(hex: 0x222e52)
    static let cream = Color(hex: 0xf5ead9)
    static let creamDim = Color(hex: 0xb9b2d4)
    static let orange = Color(hex: 0xe8943d)
    static let orangeSoft = Color(hex: 0xf0b269)
    static let green = Color(hex: 0x3fae6a)
    static let greenBright = Color(hex: 0x5ec98a)
    static let pink = Color(hex: 0xf2a9b6)
    static let red = Color(hex: 0xe06a6a)

    static let pixelFont = "Press Start 2P"
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// Money string from the API ("7.000000") → "$7" / "$7.50" for display.
func formatUsd(_ raw: String) -> String {
    let value = Double(raw) ?? 0
    if value == value.rounded() {
        return "$\(Int(value))"
    }
    return "$" + String(format: "%.2f", value)
}
