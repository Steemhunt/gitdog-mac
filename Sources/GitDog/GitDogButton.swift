import SwiftUI

/// Shared button styles matching the design tokens.
struct GitDogButton: ButtonStyle {
    enum Kind { case accent, money, ghost }
    let kind: Kind
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: kind == .ghost ? 12.5 : 13.5, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, fullWidth ? 0 : 15)
            .padding(.vertical, fullWidth ? 13 : 7)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .accent: Theme.navy
        case .money: Color(hex: 0x06250f)
        case .ghost: Theme.cream
        }
    }
    private var background: Color {
        switch kind {
        case .accent: Theme.orange
        case .money: Theme.green
        case .ghost: Theme.cream.opacity(0.08)
        }
    }
}
