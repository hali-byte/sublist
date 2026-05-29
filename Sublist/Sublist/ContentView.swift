import SwiftUI
import SwiftData
import OSLog

struct ContentView: View {
    @Query(sort: \Subscription.nextRenewalDate) private var subscriptions: [Subscription]
    @Query private var priceRecords: [PriceRecord]
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @AppStorage(AppConstants.countryCodeKey) private var countryCode: String = ""
    @AppStorage(AppConstants.showPriceChangeTags) private var showPriceChangeTags: Bool = true
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var showingBreakdown = false
    @State private var showingCalendar = false
    @State private var selectedSubscription: Subscription? = nil
    @State private var renewingIDs: Set<UUID> = []
    @State private var showCountryPrompt = false
    @State private var detectedCountryCode = ""
    @State private var detectedCountryName = ""

    private var renewingSoon: [Subscription] {
        subscriptions.filter { $0.daysUntilRenewal <= 7 }
    }

    private var upcoming: [Subscription] {
        subscriptions.filter { $0.daysUntilRenewal > 7 }
    }

    private var priceChanges: [UUID: PriceChangeType] {
        guard showPriceChangeTags else { return [:] }
        var result: [UUID: PriceChangeType] = [:]
        for sub in subscriptions {
            if let change = PriceChangeDetector.detectFromRecords(for: sub, in: modelContext) {
                result[sub.id] = change
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    EmptyStateView { showingAddSheet = true }
                } else {
                    List {
                        Section {
                            SummaryCard(
                                subscriptions: subscriptions,
                                currency: currency,
                                onBreakdownTap: { showingBreakdown = true },
                                onCalendarTap: { showingCalendar = true }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }

                        if !renewingSoon.isEmpty {
                            Section {
                                ForEach(renewingSoon) { sub in
                                    renewingSoonRow(sub)
                                }
                            } header: {
                                Text("Renewing Soon")
                            }
                        }

                        if !upcoming.isEmpty {
                            Section {
                                ForEach(upcoming) { sub in
                                    upcomingRow(sub)
                                }
                            } header: {
                                Text("Upcoming")
                            }
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: subscriptions.count)
                }
            }
            .navigationTitle("Your subscriptions")
            .navigationDestination(isPresented: $showingBreakdown) {
                SpendingChartView(subscriptions: subscriptions)
            }
            .navigationDestination(isPresented: $showingCalendar) {
                RenewalCalendarView(subscriptions: subscriptions)
            }
            .navigationDestination(item: $selectedSubscription) { sub in
                SubscriptionDetailView(subscription: sub)
            }
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
            .alert("Set Your Country", isPresented: $showCountryPrompt) {
                Button("Confirm") {
                    countryCode = detectedCountryCode
                }
                Button("Change") {
                    showingSettings = true
                }
            } message: {
                Text("We detected you're in \(detectedCountryName). This is used to fetch accurate subscription pricing for your region.")
            }
            .task {
                await NotificationManager.shared.refreshStatus()
                NotificationManager.shared.scheduleAll(for: subscriptions)
                updateWidgetSnapshot(from: subscriptions, currency: currency)

                if countryCode.isEmpty {
                    do {
                        let geo = try await IPGeolocationService.shared.resolve()
                        detectedCountryCode = geo.code
                        detectedCountryName = geo.name
                        showCountryPrompt = true
                    } catch {
                        Logger.geo.info("Country auto-detection unavailable: \(error.localizedDescription). User can set it in Settings.")
                    }
                }
            }
            .onChange(of: subscriptions) { _, _ in
                updateWidgetSnapshot(from: subscriptions, currency: currency)
            }
        }
    }

    @ViewBuilder
    private func renewingSoonRow(_ sub: Subscription) -> some View {
        VStack(spacing: 0) {
            SubscriptionRow(subscription: sub, isGrouped: true, priceChange: priceChanges[sub.id])
                .contentShape(Rectangle())
                .onTapGesture { selectedSubscription = sub }

            if sub.daysUntilRenewal <= 0 {
                Divider()
                    .padding(.horizontal, 16)
                Button("Mark as Renewed") {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        _ = renewingIDs.insert(sub.id)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                            _ = renewingIDs.remove(sub.id)
                            markAsRenewed(sub)
                        }
                    }
                }
                .font(.body)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            if renewingIDs.contains(sub.id) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.green.opacity(0.10))
                    ConfettiView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .transition(
                    .asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.3)),
                        removal: .opacity.animation(.easeOut(duration: 0.4))
                    )
                )
            }
        }
        .scaleEffect(renewingIDs.contains(sub.id) ? 0.98 : 1.0)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .transition(.opacity.combined(with: .offset(y: 6)))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteButton(sub)
        }
    }

    @ViewBuilder
    private func upcomingRow(_ sub: Subscription) -> some View {
        Button {
            selectedSubscription = sub
        } label: {
            SubscriptionRow(subscription: sub, isGrouped: true, priceChange: priceChanges[sub.id])
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .transition(.opacity.combined(with: .offset(y: 6)))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteButton(sub)
        }
    }

    @ViewBuilder
    private func deleteButton(_ sub: Subscription) -> some View {
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            NotificationManager.shared.cancel(for: sub)
            modelContext.delete(sub)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func markAsRenewed(_ subscription: Subscription) {
        subscription.markAsRenewed()
        NotificationManager.shared.schedule(for: subscription)
        updateWidgetSnapshot(from: subscriptions, currency: currency)
    }
}

private struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Subscription.self, PriceRecord.self], inMemory: true)
}
