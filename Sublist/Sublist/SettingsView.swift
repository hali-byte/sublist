import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    private var notificationManager = NotificationManager.shared
    @Query private var allSubscriptions: [Subscription]
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @AppStorage(AppConstants.appearanceKey) private var appearance: String = "system"
    @AppStorage(AppConstants.countryCodeKey) private var countryCode: String = ""
    @AppStorage(AppConstants.backgroundPriceCheckEnabled) private var backgroundPriceCheckEnabled: Bool = false
    @AppStorage(AppConstants.showPriceChangeTags) private var showPriceChangeTags: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showCountryPicker = false

    private var countryDisplayName: String {
        guard !countryCode.isEmpty else { return String(localized: "Not Set", comment: "Country not configured yet") }
        return Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    notificationRow
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Sublist will remind you the day before any subscription renews.")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack {
                            Text("Your Country")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(countryDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }

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
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Your country is used to fetch accurate subscription pricing for your region.")
                }

                Section {
                    Toggle("Price Change Tags", isOn: $showPriceChangeTags)
                    Toggle("Background Price Checks", isOn: $backgroundPriceCheckEnabled)
                        .onChange(of: backgroundPriceCheckEnabled) { _, enabled in
                            if enabled {
                                BackgroundPriceChecker.scheduleNext()
                            }
                        }

                    if backgroundPriceCheckEnabled {
                        let eligible = allSubscriptions.filter { ProviderRegistry.provider(for: $0.name) != nil }
                        let ineligible = allSubscriptions.filter { ProviderRegistry.provider(for: $0.name) == nil }

                        if eligible.isEmpty && !allSubscriptions.isEmpty {
                            Text("None of your subscriptions are eligible for automatic price tracking yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(eligible) { sub in
                                HStack {
                                    Text(sub.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                        }

                        if !ineligible.isEmpty {
                            Text("^[\(ineligible.count) subscription](inflect: true) not eligible for automatic price tracking.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Price Intelligence")
                } footer: {
                    Text("Automatically checks for price changes on your eligible subscriptions weekly and notifies you of any updates.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    Button {
                        if let url = URL(string: "https://apps.apple.com/app/id6760260991?action=write-review") {
                            openURL(url)
                        }
                    } label: {
                        Label("Rate Sublist", systemImage: "star")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(initialCode: countryCode) { newCode in
                    countryCode = newCode
                }
            }
            .task {
                await notificationManager.refreshStatus()
            }
        }
    }

    @ViewBuilder
    private var notificationRow: some View {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            Button {
                Task {
                    await notificationManager.requestPermission()
                    notificationManager.scheduleAll(for: allSubscriptions)
                }
            } label: {
                Label("Enable Renewal Reminders", systemImage: "bell.badge")
            }

        case .authorized, .provisional, .ephemeral:
            Label("Renewal Reminders Enabled", systemImage: "bell.fill")
                .foregroundStyle(.green)

        case .denied:
            HStack {
                Label("Notifications Disabled", systemImage: "bell.slash.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.callout)
            }

        @unknown default:
            EmptyView()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Subscription.self, PriceRecord.self], inMemory: true)
}
