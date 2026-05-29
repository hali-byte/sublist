import SwiftData
import SwiftUI

struct OnboardingPreset: Identifiable {
    var id: String {
        name
    }

    let name: String
    let emoji: String
    let category: Category
    let price: Double
}

/// Typical monthly prices, used only to make the first-run spend reveal feel
/// real. Users can edit any of these afterwards.
let onboardingPresets: [OnboardingPreset] = [
    .init(name: "Netflix", emoji: "🎬", category: .entertainment, price: 15.49),
    .init(name: "Spotify", emoji: "🎵", category: .music, price: 11.99),
    .init(name: "YouTube", emoji: "▶️", category: .entertainment, price: 13.99),
    .init(name: "Disney+", emoji: "✨", category: .entertainment, price: 13.99),
    .init(name: "Apple Music", emoji: "🎶", category: .music, price: 10.99),
    .init(name: "iCloud+", emoji: "☁️", category: .cloud, price: 2.99),
    .init(name: "ChatGPT Plus", emoji: "🤖", category: .productivity, price: 20.00),
    .init(name: "Notion", emoji: "📝", category: .productivity, price: 10.00),
    .init(name: "Apple TV+", emoji: "🍿", category: .entertainment, price: 9.99),
    .init(name: "Hulu", emoji: "📺", category: .entertainment, price: 17.99),
    .init(name: "Amazon Prime", emoji: "📦", category: .entertainment, price: 14.99),
    .init(name: "Duolingo", emoji: "🦉", category: .education, price: 12.99),
]

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @AppStorage(AppConstants.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false

    @State private var selected: Set<String> = []
    @State private var revealed = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    private var monthlyTotal: Double {
        onboardingPresets.filter { selected.contains($0.name) }.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        VStack(spacing: 0) {
            if revealed {
                revealStep
            } else {
                pickStep
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: revealed)
    }

    // MARK: - Step 1: pick

    private var pickStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("What are you subscribed to?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Tap the ones you pay for. You can add more later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(onboardingPresets) { preset in
                        presetCard(preset)
                    }
                }
                .padding(20)
            }

            VStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    revealed = true
                } label: {
                    Text(selected.isEmpty ? "Skip for now" : "See my total")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
    }

    private func presetCard(_ preset: OnboardingPreset) -> some View {
        let isOn = selected.contains(preset.name)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isOn { selected.remove(preset.name) } else { selected.insert(preset.name) }
        } label: {
            VStack(spacing: 8) {
                SubscriptionIconView(name: preset.name, emoji: preset.emoji, size: 30)
                    .frame(width: 44, height: 44)
                Text(preset.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isOn ? Color.accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isOn ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableScaleStyle())
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - Step 2: spend-shock reveal

    private var revealStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(selected.isEmpty ? "Track every subscription in one place" : "You're spending")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if !selected.isEmpty {
                VStack(spacing: 4) {
                    Text("≈ \(monthlyTotal.formatted(.currency(code: currency)))")
                        .font(.system(size: 52, weight: .bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("per month")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("That's \("≈ " + (monthlyTotal * 12).formatted(.currency(code: currency))) a year")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
            }

            Spacer()

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                finish()
            } label: {
                Text(selected.isEmpty ? "Get started" : "Start tracking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Finish

    private func finish() {
        let calendar = Calendar.current
        let renewalDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        for preset in onboardingPresets where selected.contains(preset.name) {
            let sub = Subscription(
                name: preset.name,
                amount: preset.price,
                billingCycle: .monthly,
                nextRenewalDate: renewalDate,
                category: preset.category,
                emoji: preset.emoji
            )
            modelContext.insert(sub)
            NotificationManager.shared.schedule(for: sub)
        }
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Subscription.self, PriceRecord.self], inMemory: true)
}
