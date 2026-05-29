import SwiftUI

/// A dismissible card nudging the user to enable renewal reminders.
/// Shown on the home screen whenever notifications aren't authorised.
struct NotificationNudgeCard: View {
    /// True when permission was previously denied (so the CTA opens Settings
    /// instead of requesting again, which the system would ignore).
    let isDenied: Bool
    let onEnable: () -> Void
    let onDismiss: () -> Void

    private let gradient = LinearGradient(
        colors: [Color(red: 0.48, green: 0.55, blue: 0.87), Color(red: 0.23, green: 0.31, blue: 0.63)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(gradient, in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Never miss a renewal")
                        .font(.headline)
                    Text("Get a reminder before a subscription renews or a free trial ends.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            Button(action: onEnable) {
                Text(isDenied ? "Open Settings" : "Turn on reminders")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(gradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressableScaleStyle(scale: 0.98))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .contain)
    }
}
