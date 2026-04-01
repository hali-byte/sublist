import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subscription.nextRenewalDate) private var allSubscriptions: [Subscription]

    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @State private var isDeleted = false
    @State private var showEmojiPicker = false

    var body: some View {
        Form {
            Section("Details") {
                HStack {
                    Button {
                        showEmojiPicker = true
                    } label: {
                        SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 32)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    TextField("Name", text: $subscription.name)
                }
                Picker("Category", selection: $subscription.category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }

            Section("Billing") {
                TextField("Amount", value: $subscription.amount, format: .currency(code: currency))
                    .keyboardType(.decimalPad)
                Picker("Billing Cycle", selection: $subscription.billingCycle) {
                    ForEach(BillingCycle.allCases, id: \.self) { cycle in
                        Text(cycle.rawValue).tag(cycle)
                    }
                }
                DatePicker("Next Renewal", selection: $subscription.nextRenewalDate, displayedComponents: .date)
            }

            Section {
                Button("Mark as Renewed") {
                    markAsRenewed()
                }
            } footer: {
                Text("Advances the renewal date by one billing cycle.")
            }

            Section {
                Button("Delete Subscription", role: .destructive) {
                    isDeleted = true
                    NotificationManager.shared.cancel(for: subscription)
                    modelContext.delete(subscription)
                    dismiss()
                }
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(selectedEmoji: $subscription.emoji)
        }
        .onDisappear {
            if !isDeleted {
                NotificationManager.shared.scheduleAll(for: allSubscriptions)
            }
        }
    }

    private func markAsRenewed() {
        subscription.markAsRenewed()
        NotificationManager.shared.schedule(for: subscription)
        updateWidgetSnapshot(from: allSubscriptions, currency: currency)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Subscription.self, configurations: config)
    let sub = Subscription(
        name: "Spotify",
        amount: 9.99,
        billingCycle: .monthly,
        nextRenewalDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)!,
        category: .music,
        emoji: "🎵"
    )
    container.mainContext.insert(sub)
    return NavigationStack {
        SubscriptionDetailView(subscription: sub)
    }
    .modelContainer(container)
}
