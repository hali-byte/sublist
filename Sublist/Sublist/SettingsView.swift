import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    private var notificationManager = NotificationManager.shared
    @Query private var allSubscriptions: [Subscription]
    @AppStorage("currency") private var currency: String = "USD"
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
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
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
