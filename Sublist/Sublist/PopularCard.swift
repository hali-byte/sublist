import SwiftUI

struct PopularCard: View {
    let preset: PopularSubscription
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            SubscriptionIconView(name: preset.name, emoji: preset.emoji, size: 28)
                .frame(width: 38, height: 38)
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .rotationEffect(.degrees(isSelected ? -3 : 0))
            Text(preset.name)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 76, height: 80)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.14)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.system(size: 18))
                    .background(Circle().fill(.white).frame(width: 15, height: 15))
                    .offset(x: 7, y: -7)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(
            color: Color.accentColor.opacity(isSelected ? 0.35 : 0),
            radius: isSelected ? 10 : 0, x: 0, y: 3
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
    }
}

struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
