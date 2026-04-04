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
            // Identity header
            Section {
                VStack(spacing: 10) {
                    Button {
                        showEmojiPicker = true
                    } label: {
                        VStack(spacing: 5) {
                            SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 48)
                                .frame(width: 64, height: 64)
                            Text("Change icon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(subscription.name.isEmpty ? "Name" : subscription.name)
                        .font(.title2.bold())
                        .foregroundStyle(subscription.name.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Details") {
                TextField("Name", text: $subscription.name)
                Picker("Category", selection: $subscription.category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.localizedName).tag(cat)
                    }
                }
            }

            Section("Billing") {
                TextField("Amount", value: $subscription.amount, format: .currency(code: currency))
                    .keyboardType(.decimalPad)
                Picker("Billing Cycle", selection: $subscription.billingCycle) {
                    ForEach(BillingCycle.allCases, id: \.self) { cycle in
                        Text(cycle.localizedName).tag(cycle)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        subscription.markAsRenewed()
        NotificationManager.shared.schedule(for: subscription)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        updateWidgetSnapshot(from: allSubscriptions, currency: currency)
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailPreviewHelper()
    }
    .modelContainer(for: Subscription.self, inMemory: true)
}

private struct SubscriptionDetailPreviewHelper: View {
    @Query private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var context

    var body: some View {
        if let sub = subscriptions.first {
            SubscriptionDetailView(subscription: sub)
        } else {
            ProgressView()
                .task {
                    context.insert(Subscription(
                        name: "Spotify",
                        amount: 9.99,
                        billingCycle: .monthly,
                        nextRenewalDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)!,
                        category: .music,
                        emoji: "🎵"
                    ))
                }
        }
    }
}
