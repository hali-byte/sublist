import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Subscription.nextRenewalDate) private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var confirmedRenewalIDs: Set<UUID> = []

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
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Per Year", systemImage: "dollarsign.circle")
                            Spacer()
                            Text(monthlyTotal * 12, format: .currency(code: currency))
                                .font(.body.monospacedDigit())
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
                        .transition(.opacity.combined(with: .offset(y: 6)))
                        .listRowSeparator(sub.daysUntilRenewal <= 0 ? .hidden : .automatic, edges: .bottom)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                NotificationManager.shared.cancel(for: sub)
                                modelContext.delete(sub)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if sub.daysUntilRenewal <= 0 {
                            Button {
                                confirmedRenewalIDs.insert(sub.id)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    withAnimation(.easeOut(duration: 0.4)) {
                                        markAsRenewed(sub)
                                    }
                                }
                            } label: {
                                Label("Mark as Renewed", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                            }
                            .buttonStyle(RenewedButtonStyle(isConfirmed: confirmedRenewalIDs.contains(sub.id)))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                            .listRowSeparator(.hidden, edges: .top)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .transition(.opacity)
                        }
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: subscriptions.count)
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
                updateWidgetSnapshot(from: subscriptions, currency: currency)
            }
            .onChange(of: subscriptions) { _, _ in
                updateWidgetSnapshot(from: subscriptions, currency: currency)
            }
        }
    }

    private func markAsRenewed(_ subscription: Subscription) {
        subscription.markAsRenewed()
        confirmedRenewalIDs.remove(subscription.id)
        NotificationManager.shared.schedule(for: subscription)
        updateWidgetSnapshot(from: subscriptions, currency: currency)
    }
}

private struct RenewedButtonStyle: ButtonStyle {
    let isConfirmed: Bool

    func makeBody(configuration: Configuration) -> some View {
        let filled = configuration.isPressed || isConfirmed
        return configuration.label
            .foregroundStyle(filled ? .white : .green)
            .background(
                Capsule()
                    .fill(filled ? Color.green : Color.clear)
                    .overlay(Capsule().strokeBorder(Color.green, lineWidth: 1.5))
                    .shadow(
                        color: Color.green.opacity(filled ? 0.35 : 0.15),
                        radius: filled ? 6 : 0,
                        x: 0, y: filled ? 2 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: filled)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
