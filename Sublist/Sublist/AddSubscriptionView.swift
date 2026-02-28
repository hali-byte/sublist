import SwiftUI
import SwiftData

// MARK: - Popular preset

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

    @AppStorage("currency") private var currency: String = "USD"
    @State private var name = ""
    @State private var amount = 0.0
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
                                PopularCard(
                                    preset: preset,
                                    isSelected: selectedPopular == preset
                                )
                                .onTapGesture { apply(preset) }
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
                                Text(emoji).font(.title2)
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
                    }
                    TextField("Amount", value: $amount, format: .currency(code: currency))
                        .keyboardType(.decimalPad)
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

// MARK: - Card

private struct PopularCard: View {
    let preset: PopularSubscription
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: "https://logo.clearbit.com/\(preset.domain)")) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(preset.emoji)
                        .font(.system(size: 28))
                        .frame(width: 38, height: 38)
                }
            }
            Text(preset.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 76, height: 80)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color(.systemGray6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}
