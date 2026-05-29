import OSLog
import SwiftData
import SwiftUI
import UserNotifications

@main
struct SublistApp: App {
    @AppStorage(AppConstants.appearanceKey) private var appearance = "system"

    let modelContainer: ModelContainer
    /// True when the on-disk store could not be opened and we fell back to an
    /// in-memory container, so the UI can warn that changes won't persist.
    private let didFailPersistentStore: Bool
    private let notificationDelegate: NotificationDelegate

    init() {
        let (container, failed) = Self.makeContainer()
        modelContainer = container
        didFailPersistentStore = failed
        notificationDelegate = NotificationDelegate(modelContainer: container)
        UNUserNotificationCenter.current().delegate = notificationDelegate

        BackgroundPriceChecker.register()
        BackgroundPriceChecker.scheduleNext()
    }

    /// Opens the persistent store, falling back to an in-memory container if it
    /// can't be created (e.g. a failed migration) so the app still launches
    /// instead of crashing. Only an unrecoverable failure of both traps.
    private static func makeContainer() -> (ModelContainer, Bool) {
        do {
            return try (ModelContainer(for: Subscription.self, PriceRecord.self), false)
        } catch {
            Logger.app.error("Persistent ModelContainer failed: \(error.localizedDescription)")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            if let memory = try? ModelContainer(
                for: Subscription.self, PriceRecord.self, configurations: config
            ) {
                return (memory, true)
            }
            fatalError("Unrecoverable ModelContainer failure: \(error)")
        }
    }

    private var resolvedScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedScheme)
                .safeAreaInset(edge: .top) {
                    if didFailPersistentStore {
                        Text("Your data couldn't be loaded this session. Changes won't be saved.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(.red, in: .rect)
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
