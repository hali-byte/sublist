import SwiftUI
import SwiftData

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
}

private let popularSubscriptions: [PopularSubscription] = [
    PopularSubscription(name: "Netflix",       emoji: "🎬", category: .entertainment, billingCycle: .monthly,  domain: "netflix.com"),
    PopularSubscription(name: "Spotify",       emoji: "🎵", category: .music,         billingCycle: .monthly,  domain: "spotify.com"),
    PopularSubscription(name: "Apple Music",   emoji: "🎶", category: .music,         billingCycle: .monthly,  domain: "music.apple.com"),
    PopularSubscription(name: "YouTube",       emoji: "▶️", category: .entertainment, billingCycle: .monthly,  domain: "youtube.com"),
    PopularSubscription(name: "Disney+",       emoji: "✨", category: .entertainment, billingCycle: .monthly,  domain: "disneyplus.com"),
    PopularSubscription(name: "Amazon Prime",  emoji: "📦", category: .entertainment, billingCycle: .yearly,   domain: "amazon.com"),
    PopularSubscription(name: "Apple TV+",     emoji: "🍿", category: .entertainment, billingCycle: .monthly,  domain: "tv.apple.com"),
    PopularSubscription(name: "Hulu",          emoji: "📺", category: .entertainment, billingCycle: .monthly,  domain: "hulu.com"),
    PopularSubscription(name: "iCloud+",       emoji: "☁️", category: .cloud,         billingCycle: .monthly,  domain: "icloud.com"),
    PopularSubscription(name: "Google One",    emoji: "🔵", category: .cloud,         billingCycle: .monthly,  domain: "one.google.com"),
    PopularSubscription(name: "ChatGPT Plus",  emoji: "🤖", category: .productivity,  billingCycle: .monthly,  domain: "openai.com"),
    PopularSubscription(name: "Notion",        emoji: "📝", category: .productivity,  billingCycle: .monthly,  domain: "notion.so"),
    PopularSubscription(name: "1Password",     emoji: "🔐", category: .security,      billingCycle: .yearly,   domain: "1password.com"),
    PopularSubscription(name: "NordVPN",       emoji: "🛡️", category: .security,      billingCycle: .yearly,   domain: "nordvpn.com"),
    PopularSubscription(name: "Duolingo",      emoji: "🦉", category: .education,     billingCycle: .monthly,  domain: "duolingo.com"),
    PopularSubscription(name: "NYT",           emoji: "📰", category: .news,          billingCycle: .monthly,  domain: "nytimes.com"),
]

// MARK: - View

struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @State private var name = ""
    @State private var amountText: String = ""
    @State private var billingCycle = BillingCycle.monthly
    @State private var nextRenewalDate = Date()
    @State private var category = Category.entertainment
    @State private var emoji = "📱"
    @State private var showEmojiPicker = false
    @State private var selectedPopular: PopularSubscription? = nil

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

                // MARK: Manual entry
                Section("Or Add Manually") {
                    HStack {
                        Button { showEmojiPicker = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                SubscriptionIconView(name: name, emoji: emoji, size: 22)
                                .frame(width: 44, height: 44)
                            }
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
                            Text(cat.rawValue).tag(cat)
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
                        Text("CNY — Chinese Yuan").tag("CNY")
                        Text("SGD — Singapore Dollar").tag("SGD")
                        Text("SEK — Swedish Krona").tag("SEK")
                        Text("PLN — Polish Złoty").tag("PLN")
                    }
                    HStack(spacing: 4) {
                        Text(currencySymbol(for: currency))
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.rawValue).tag(cycle)
                        }
                    }
                    DatePicker("Next Renewal", selection: $nextRenewalDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $emoji)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSubscription() }
                        .disabled(name.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
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
    }

    private func saveSubscription() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let sub = Subscription(
            name: name,
            amount: amount,
            billingCycle: billingCycle,
            nextRenewalDate: nextRenewalDate,
            category: category,
            emoji: emoji
        )
        modelContext.insert(sub)
        NotificationManager.shared.schedule(for: sub)
        dismiss()
    }
}

private func currencySymbol(for code: String) -> String {
    let symbols: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£",
        "AUD": "A$", "CNY": "¥", "SGD": "S$",
        "SEK": "kr", "PLN": "zł",
    ]
    return symbols[code] ?? code
}

