import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "No Subscriptions Yet",
                        systemImage: "creditcard",
                        description: Text("Tap + to add your first subscription")
                    )
                } else {
                    ForEach(subscriptions) { sub in
                        SubscriptionRow(subscription: sub)
                    }
                    .onDelete(perform: deleteSubscriptions)
                }
            }
            .navigationTitle("Sublist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionView()
            }
        }
    }

    private func deleteSubscriptions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(subscriptions[index])
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack {
            Text(subscription.emoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                Text(subscription.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.amount, format: .currency(code: "USD"))
                    .font(.headline)
                Text(subscription.billingCycle.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
