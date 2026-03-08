import SwiftUI
import SwiftData
import WidgetKit

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subscription.nextRenewalDate) private var allSubscriptions: [Subscription]

    @AppStorage("currency") private var currency: String = "USD"
    @State private var isDeleted = false
    @State private var showEmojiPicker = false

    var body: some View {
        Form {
            Section("Details") {
                HStack {
                    Button {
                        showEmojiPicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            Text(subscription.emoji)
                                .font(.title2)
                        }
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
        let component: Calendar.Component = subscription.billingCycle == .monthly ? .month : .year
        if let newDate = Calendar.current.date(byAdding: component, value: 1, to: subscription.nextRenewalDate) {
            subscription.nextRenewalDate = newDate
            NotificationManager.shared.schedule(for: subscription)
            updateWidgetSnapshot()
        }
    }

    private func updateWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: "group.com.hugohodinka.Sublist"),
              let sub = allSubscriptions.first else { return }
        struct Snapshot: Codable {
            let name: String; let emoji: String
            let amount: Double; let billingCycle: String
            let nextRenewalDate: Date; let currency: String
        }
        if let data = try? JSONEncoder().encode(Snapshot(
            name: sub.name, emoji: sub.emoji,
            amount: sub.amount, billingCycle: sub.billingCycle.rawValue,
            nextRenewalDate: sub.nextRenewalDate, currency: currency
        )) {
            defaults.set(data, forKey: "widgetNextSubscription")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
