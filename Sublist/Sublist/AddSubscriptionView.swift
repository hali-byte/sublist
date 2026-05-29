import SwiftUI
import SwiftData

// MARK: - Pricing state

enum PricingState {
    case idle
    case loading
    case loaded(plans: [SubscriptionPlan], countryName: String, countryCode: String)
    case fallback(reason: String)
}

// MARK: - Popular preset

#Preview {
      AddSubscriptionView()
          .modelContainer(for: Subscription.self, inMemory: true)
  }

struct PopularSubscription: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let emoji: String   // fallback when logo fails to load
    let category: Category
    let billingCycle: BillingCycle
    let domain: String  // used to fetch logo via Clearbit
    var pricingProvider: (any SubscriptionPricingProvider)? = nil

    static func == (lhs: PopularSubscription, rhs: PopularSubscription) -> Bool {
        lhs.id == rhs.id
    }
}

private let popularSubscriptions: [PopularSubscription] = [
    PopularSubscription(name: "Netflix",       emoji: "🎬", category: .entertainment, billingCycle: .monthly,  domain: "netflix.com",       pricingProvider: NetflixPricingProvider()),
    PopularSubscription(name: "Spotify",       emoji: "🎵", category: .music,         billingCycle: .monthly,  domain: "spotify.com",       pricingProvider: SpotifyPricingProvider()),
    PopularSubscription(name: "Apple Music",   emoji: "🎶", category: .music,         billingCycle: .monthly,  domain: "music.apple.com",   pricingProvider: AppleMusicPricingProvider()),
    PopularSubscription(name: "YouTube",       emoji: "▶️", category: .entertainment, billingCycle: .monthly,  domain: "youtube.com",       pricingProvider: YouTubePricingProvider()),
    PopularSubscription(name: "Disney+",       emoji: "✨", category: .entertainment, billingCycle: .monthly,  domain: "disneyplus.com",   pricingProvider: DisneyPlusPricingProvider()),
    PopularSubscription(name: "Amazon Prime",  emoji: "📦", category: .entertainment, billingCycle: .yearly,   domain: "amazon.com",       pricingProvider: AmazonPrimePricingProvider()),
    PopularSubscription(name: "Apple TV+",     emoji: "🍿", category: .entertainment, billingCycle: .monthly,  domain: "tv.apple.com",      pricingProvider: AppleTVPricingProvider()),
    PopularSubscription(name: "Hulu",          emoji: "📺", category: .entertainment, billingCycle: .monthly,  domain: "hulu.com",         pricingProvider: HuluPricingProvider()),
    PopularSubscription(name: "iCloud+",       emoji: "☁️", category: .cloud,         billingCycle: .monthly,  domain: "icloud.com",        pricingProvider: ICloudPricingProvider()),
    PopularSubscription(name: "Google One",    emoji: "🔵", category: .cloud,         billingCycle: .monthly,  domain: "one.google.com",    pricingProvider: GoogleOnePricingProvider()),
    PopularSubscription(name: "ChatGPT Plus",  emoji: "🤖", category: .productivity,  billingCycle: .monthly,  domain: "openai.com",        pricingProvider: ChatGPTPricingProvider()),
    PopularSubscription(name: "Notion",        emoji: "📝", category: .productivity,  billingCycle: .monthly,  domain: "notion.so",         pricingProvider: NotionPricingProvider()),
    PopularSubscription(name: "1Password",     emoji: "🔐", category: .security,      billingCycle: .yearly,   domain: "1password.com",     pricingProvider: OnePasswordPricingProvider()),
    PopularSubscription(name: "NordVPN",       emoji: "🛡️", category: .security,      billingCycle: .yearly,   domain: "nordvpn.com",      pricingProvider: NordVPNPricingProvider()),
    PopularSubscription(name: "Duolingo",      emoji: "🦉", category: .education,     billingCycle: .monthly,  domain: "duolingo.com",      pricingProvider: DuolingoPricingProvider()),
    PopularSubscription(name: "Crunchyroll",   emoji: "🎌", category: .entertainment, billingCycle: .monthly,  domain: "crunchyroll.com",   pricingProvider: CrunchyrollPricingProvider()),
    PopularSubscription(name: "NYT",           emoji: "📰", category: .news,          billingCycle: .monthly,  domain: "nytimes.com",       pricingProvider: NYTPricingProvider()),
]

// MARK: - View

struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @AppStorage(AppConstants.countryCodeKey) private var storedCountryCode: String = ""
    @State private var name = ""
    @State private var amountText: String = ""
    @State private var billingCycle = BillingCycle.monthly
    @State private var nextRenewalDate = Date()
    @State private var isTrial = false
    @State private var trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var category = Category.entertainment
    @State private var emoji = "📱"
    @State private var showEmojiPicker = false
    @State private var selectedPopular: PopularSubscription? = nil

    // Pricing state
    @State private var pricingState: PricingState = .idle
    @State private var selectedPlan: SubscriptionPlan? = nil
    @State private var countryOverrideCode: String? = nil
    @State private var showCountryPicker = false
    @State private var pricingTask: Task<Void, Never>? = nil
    @State private var pricingRetryCount = 0

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Popular subscriptions
                Section("Popular Subscriptions") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(popularSubscriptions) { preset in
                                Button { apply(preset) } label: {
                                    PopularCard(
                                        preset: preset,
                                        isSelected: selectedPopular == preset
                                    )
                                }
                                .buttonStyle(ScalePressButtonStyle())
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                // MARK: AI plan picker (Spotify and future supported services)
                switch pricingState {
                case .idle:
                    EmptyView()
                default:
                    Section {
                        pricingStateView
                    }
                }

                // MARK: Manual entry
                Section("Or Add Manually") {
                    HStack {
                        Button { showEmojiPicker = true } label: {
                            SubscriptionIconView(name: name, emoji: emoji, size: 32)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)

                        TextField("Name (e.g. Netflix)", text: $name)
                            .onChange(of: name) { _, newValue in
                                if let p = selectedPopular, newValue != p.name {
                                    selectedPopular = nil
                                }
                            }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { cat in
                            Text(cat.localizedName).tag(cat)
                        }
                    }
                }

                // MARK: Billing
                Section("Billing") {
                    Picker("Currency", selection: $currency) {
                        Text("USD — US Dollar").tag("USD")
                        Text("EUR — Euro").tag("EUR")
                        Text("GBP — British Pound").tag("GBP")
                        Text("AUD — Australian Dollar").tag("AUD")
                        Text("CAD — Canadian Dollar").tag("CAD")
                        Text("CNY — Chinese Yuan").tag("CNY")
                        Text("SGD — Singapore Dollar").tag("SGD")
                        Text("SEK — Swedish Krona").tag("SEK")
                        Text("PLN — Polish Złoty").tag("PLN")
                        Text("DKK — Danish Krone").tag("DKK")
                        Text("NOK — Norwegian Krone").tag("NOK")
                        Text("CHF — Swiss Franc").tag("CHF")
                        Text("BRL — Brazilian Real").tag("BRL")
                        Text("JPY — Japanese Yen").tag("JPY")
                        Text("KRW — South Korean Won").tag("KRW")
                        Text("INR — Indian Rupee").tag("INR")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(CurrencyFormatting.symbol(for: currency))
                                .foregroundStyle(.secondary)
                            TextField("Amount", text: $amountText)
                                .keyboardType(.decimalPad)
                        }
                        if !amountText.isEmpty && AmountParser.parse(amountText) == nil {
                            Text("Enter an amount between 0 and 1,000,000.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.localizedName).tag(cycle)
                        }
                    }
                    Toggle("Free trial", isOn: $isTrial.animation())
                    if isTrial {
                        DatePicker("Trial ends (first charge)", selection: $trialEndDate, in: Date()..., displayedComponents: .date)
                        Text("We'll remind you 48 and 24 hours before the trial ends so you can cancel before you're charged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        DatePicker("Next Renewal", selection: $nextRenewalDate, displayedComponents: .date)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $emoji)
            }
            .sheet(isPresented: $showCountryPicker) {
                if case .loaded(_, _, let code) = pricingState {
                    CountryPickerView(initialCode: countryOverrideCode ?? code) { newCode in
                        countryOverrideCode = newCode
                        pricingState = .loading
                        if let preset = selectedPopular {
                            pricingTask?.cancel()
                            pricingTask = Task { await loadPricing(for: preset) }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSubscription() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Pricing UI

    @ViewBuilder
    private var pricingStateView: some View {
        switch pricingState {
        case .idle:
            EmptyView()

        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Fetching pricing\u{2026}")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

        case .loaded(let plans, let countryName, _):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Prices for \(countryName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Wrong country?") {
                        showCountryPicker = true
                    }
                    .font(.footnote)
                }
                ForEach(plans) { plan in
                    Button {
                        applyPlan(plan)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                    .fontWeight(.medium)
                                Text(billingLabel(for: plan))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedPlan?.id == plan.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

        case .fallback:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text("Sorry! We could not fetch the latest pricing for \(selectedPopular?.name ?? "this service"), add the price manually.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if pricingRetryCount < 2, let preset = selectedPopular, preset.pricingProvider != nil {
                    Button {
                        pricingRetryCount += 1
                        pricingState = .loading
                        pricingTask?.cancel()
                        pricingTask = Task { await loadPricing(for: preset) }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.medium))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func billingLabel(for plan: SubscriptionPlan) -> String {
        let price  = NSDecimalNumber(decimal: plan.price).doubleValue
        let period = plan.billingPeriod.lowercased().hasPrefix("year") ? "year" : "month"
        return "\(CurrencyFormatting.format(price, code: plan.currency)) / \(period)"
    }

    // MARK: - Helpers

    private func apply(_ preset: PopularSubscription) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedPopular = preset
        }
        name         = preset.name
        emoji        = preset.emoji
        category     = preset.category
        billingCycle = preset.billingCycle

        pricingTask?.cancel()
        selectedPlan = nil
        pricingRetryCount = 0

        if preset.pricingProvider != nil {
            pricingState = .loading
            pricingTask = Task { await loadPricing(for: preset) }
        } else {
            pricingState = .idle
        }
    }

    private func loadPricing(for preset: PopularSubscription) async {
        guard let provider = preset.pricingProvider, !Task.isCancelled else { return }
        do {
            let code: String
            let name: String

            if let override = countryOverrideCode {
                code = override
                name = Locale.current.localizedString(forRegionCode: override) ?? override
            } else if !storedCountryCode.isEmpty {
                code = storedCountryCode
                name = Locale.current.localizedString(forRegionCode: storedCountryCode) ?? storedCountryCode
            } else {
                let geo = try await IPGeolocationService.shared.resolve()
                code = geo.code
                name = geo.name
            }
            guard !Task.isCancelled else { return }
            let plans = try await PricingService.shared.fetchPlans(for: code, using: provider)

            if !plans.isEmpty {
                PriceRecordService.store(
                    plans: plans,
                    serviceName: preset.name,
                    countryCode: code,
                    in: modelContext
                )
            }

            pricingState = plans.isEmpty
                ? .fallback(reason: "No plans found for \(name)")
                : .loaded(plans: plans, countryName: name, countryCode: code)
        } catch {
            pricingState = .fallback(reason: "Pricing unavailable")
        }
    }

    private func applyPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
        amountText   = NSDecimalNumber(decimal: plan.price).stringValue
        billingCycle = plan.billingPeriod.lowercased().hasPrefix("year") ? .yearly : .monthly
        currency     = mapCurrency(plan.currency)
    }

    private func mapCurrency(_ code: String) -> String {
        CurrencyFormatting.supportedCodes.contains(code.uppercased()) ? code.uppercased() : currency
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && AmountParser.isValid(amountText)
    }

    private func saveSubscription() {
        guard let amount = AmountParser.parse(amountText) else { return }
        let sub = Subscription(
            name: name,
            amount: amount,
            billingCycle: billingCycle,
            nextRenewalDate: isTrial ? trialEndDate : nextRenewalDate,
            category: category,
            emoji: emoji,
            trialEndDate: isTrial ? trialEndDate : nil
        )
        modelContext.insert(sub)

        if case .loaded = pricingState {
            PriceRecordService.linkUnlinkedRecords(
                serviceName: sub.name,
                to: sub,
                in: modelContext
            )
        }

        NotificationManager.shared.schedule(for: sub)
        ReviewPromptManager.shared.recordPositiveAction()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

