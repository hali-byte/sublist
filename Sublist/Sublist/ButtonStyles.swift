import SwiftUI

/// Subtle scale + dim press feedback for card-like tappable surfaces.
struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// List-row style press highlight: a faint fill while pressed, no scale.
/// Suited to full-width rows where scaling the whole row would look odd.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.06) : Color.clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
