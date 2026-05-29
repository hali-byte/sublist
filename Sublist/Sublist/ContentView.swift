import SwiftUI
import SwiftData
import OSLog

struct ContentView: View {
    @Query(sort: \Subscription.nextRenewalDate) private var subscriptions: [Subscription]
    @Query private var priceRecords: [PriceRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
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
    @State private var pendingDelete: PendingDelete?
    @State private var deleteCommitTask: Task<Void, Never>?

    private func isPendingDelete(_ sub: Subscription) -> Bool {
        pendingDelete?.id == sub.id
    }

    private var renewingSoon: [Subscription] {
        subscriptions.filter { $0.daysUntilRenewal <= 7 && !isPendingDelete($0) }
    }

    private var upcoming: [Subscription] {
        subscriptions.filter { $0.daysUntilRenewal > 7 && !isPendingDelete($0) }
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
            .overlay(alignment: .bottom) {
                if let pendingDelete {
                    undoBanner(pendingDelete)
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
                ReviewPromptManager.shared.registerLaunch()
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
                Button("Mark as Renewed") { triggerRenew(sub) }
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
                        .fill(Color.green.opacity(0.12))
                    ConfettiView()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .transition(.scale(scale: 0.25).combined(with: .opacity))
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
        .scaleEffect(renewingIDs.contains(sub.id) ? 1.02 : 1.0)
        .allowsHitTesting(!renewingIDs.contains(sub.id))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .transition(.opacity.combined(with: .offset(y: 6)))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            renewButton(sub)
        }
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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { renewNow(sub) } label: {
                Label("Renew", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            deleteButton(sub)
        }
    }

    @ViewBuilder
    private func renewButton(_ sub: Subscription) -> some View {
        Button { triggerRenew(sub) } label: {
            Label("Renew", systemImage: "checkmark.circle")
        }
        .tint(.green)
    }

    @ViewBuilder
    private func deleteButton(_ sub: Subscription) -> some View {
        Button(role: .destructive) {
            requestDelete(sub)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Deferred delete with undo

    /// Hides the row and starts a short timer before the actual delete, so an
    /// accidental swipe is recoverable. The model (and its price history) is
    /// only removed once the window passes without an undo.
    private func requestDelete(_ sub: Subscription) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commitPendingDeleteNow()
        NotificationManager.shared.cancel(for: sub)
        let pending = PendingDelete(id: sub.id, name: sub.name)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            pendingDelete = pending
        }
        deleteCommitTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            commitDelete(pending.id)
        }
    }

    private func commitPendingDeleteNow() {
        deleteCommitTask?.cancel()
        if let id = pendingDelete?.id { commitDelete(id) }
    }

    private func commitDelete(_ id: UUID) {
        if let sub = subscriptions.first(where: { $0.id == id }) {
            modelContext.delete(sub)
        }
        if pendingDelete?.id == id {
            withAnimation { pendingDelete = nil }
        }
        updateWidgetSnapshot(from: subscriptions, currency: currency)
    }

    private func undoDelete() {
        deleteCommitTask?.cancel()
        if let id = pendingDelete?.id, let sub = subscriptions.first(where: { $0.id == id }) {
            NotificationManager.shared.schedule(for: sub)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            pendingDelete = nil
        }
    }

    @ViewBuilder
    private func undoBanner(_ pending: PendingDelete) -> some View {
        HStack(spacing: 12) {
            Text("Deleted \(pending.name)")
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Undo") { undoDelete() }
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Color(.systemBackground))
        .tint(Color(.systemBackground))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.label), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deleted \(pending.name). Double tap Undo to restore.")
    }

    /// Celebratory renew used for due/overdue rows: confetti + checkmark, then
    /// the model advances exactly when the removal animation completes (no stale
    /// window where the row shows old data).
    private func triggerRenew(_ sub: Subscription) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            _ = renewingIDs.insert(sub.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                _ = renewingIDs.remove(sub.id)
            } completion: {
                markAsRenewed(sub)
                ReviewPromptManager.shared.requestReviewIfEligible(requestReview)
            }
        }
    }

    /// Quiet renew for not-yet-due rows (no celebration overlay on these).
    private func renewNow(_ sub: Subscription) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            markAsRenewed(sub)
        }
    }

    private func markAsRenewed(_ subscription: Subscription) {
        subscription.markAsRenewed()
        NotificationManager.shared.schedule(for: subscription)
        ReviewPromptManager.shared.recordPositiveAction()
        updateWidgetSnapshot(from: subscriptions, currency: currency)
    }
}

private struct PendingDelete: Identifiable, Equatable {
    let id: UUID
    let name: String
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
