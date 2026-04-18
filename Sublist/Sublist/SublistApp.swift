import SwiftUI
import SwiftData
import UserNotifications

@main
struct SublistApp: App {
    @AppStorage(AppConstants.appearanceKey) private var appearance = "system"

    let modelContainer: ModelContainer
    private let notificationDelegate: NotificationDelegate

    init() {
        let container = try! ModelContainer(for: Subscription.self, PriceRecord.self)
        self.modelContainer = container
        self.notificationDelegate = NotificationDelegate(modelContainer: container)
        UNUserNotificationCenter.current().delegate = notificationDelegate

        BackgroundPriceChecker.register()
        BackgroundPriceChecker.scheduleNext()
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
        }
        .modelContainer(modelContainer)
    }
}
