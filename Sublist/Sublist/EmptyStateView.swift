import SwiftUI

struct EmptyStateView: View {
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(Color.accentColor.opacity(0.85))

            VStack(spacing: 6) {
                Text("Track your subscriptions")
                    .font(.title3.bold())
                Text("Add anything you pay for regularly — streaming, tools, memberships.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAddTapped) {
                Text("Add your first subscription")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(onAddTapped: {})
        .background(Color(.systemGroupedBackground))
}
