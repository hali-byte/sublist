import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    private var notificationManager = NotificationManager.shared
    @Query private var allSubscriptions: [Subscription]
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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

                Section("Preferences") {
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
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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
        .modelContainer(for: Subscription.self, inMemory: true)
}
