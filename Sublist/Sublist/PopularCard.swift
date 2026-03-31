import SwiftUI

struct PopularCard: View {
    let preset: PopularSubscription
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            EmojiView(emoji: preset.emoji, size: 28)
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
    }
}
