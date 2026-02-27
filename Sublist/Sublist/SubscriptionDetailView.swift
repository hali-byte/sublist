import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allSubscriptions: [Subscription]

    @State private var isDeleted = false

    var body: some View {
        Form {
            Section("Details") {
                HStack {
                    TextField("Emoji", text: $subscription.emoji)
                        .frame(width: 44)
                    TextField("Name", text: $subscription.name)
                }
                Picker("Category", selection: $subscription.category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }

            Section("Billing") {
                TextField("Amount", value: $subscription.amount, format: .currency(code: "USD"))
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
        }
    }
}
