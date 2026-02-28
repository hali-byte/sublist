import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Subscription.nextRenewalDate) private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currency") private var currency: String = "USD"
    @State private var showingAddSheet = false
    @State private var showingSettings = false

    private var monthlyTotal: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var body: some View {
        NavigationStack {
            List {
                if !subscriptions.isEmpty {
                    Section("Spending Summary") {
                        HStack {
                            Label("Per Month", systemImage: "calendar")
                            Spacer()
                            Text(monthlyTotal, format: .currency(code: currency))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Per Year", systemImage: "dollarsign.circle")
                            Spacer()
                            Text(monthlyTotal * 12, format: .currency(code: currency))
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink(destination: SpendingChartView(subscriptions: subscriptions)) {
                            Label("View Breakdown", systemImage: "chart.pie.fill")
                        }
                    }
                }

                Section {
                    ForEach(subscriptions) { sub in
                        NavigationLink(destination: SubscriptionDetailView(subscription: sub)) {
                            SubscriptionRow(subscription: sub)
                        }
                    }
                    .onDelete(perform: deleteSubscriptions)
                }
            }
            .overlay {
                if subscriptions.isEmpty {
                    ContentUnavailableView(
                        "No Subscriptions Yet",
                        systemImage: "creditcard",
                        description: Text("Tap + to add your first subscription")
                    )
                }
            }
            .navigationTitle("Sublist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                await NotificationManager.shared.refreshStatus()
                NotificationManager.shared.scheduleAll(for: subscriptions)
            }
        }
    }

    private func deleteSubscriptions(at offsets: IndexSet) {
        for index in offsets {
            NotificationManager.shared.cancel(for: subscriptions[index])
            modelContext.delete(subscriptions[index])
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    @AppStorage("currency") private var currency: String = "USD"

    private var renewalLabel: String {
        switch subscription.daysUntilRenewal {
        case ..<0: return "Overdue"
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        default:   return "In \(subscription.daysUntilRenewal)d"
        }
    }

    private var renewalColor: Color {
        switch subscription.daysUntilRenewal {
        case ..<2:  return .red
        case 2...7: return .orange
        default:    return .secondary
        }
    }

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
                Text(subscription.amount, format: .currency(code: currency))
                    .font(.headline)
                Text(renewalLabel)
                    .font(.caption)
                    .foregroundStyle(renewalColor)
            }
        }
        .padding(.vertical, 4)
    }
}
