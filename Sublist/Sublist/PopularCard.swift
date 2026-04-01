import SwiftUI

struct PopularCard: View {
    let preset: PopularSubscription
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            SubscriptionIconView(name: preset.name, emoji: preset.emoji, size: 28)
                .frame(width: 38, height: 38)
            Text(preset.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 76, height: 80)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color(.systemGray6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: Color.accentColor.opacity(isSelected ? 0.2 : 0),
            radius: 6, x: 0, y: 2
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
