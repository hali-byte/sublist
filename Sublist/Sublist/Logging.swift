import OSLog

/// Centralised OSLog categories for the app.
///
/// `Logger.pricing` already exists (defined in `PricingAnalytics.swift`); these
/// add the remaining areas so error paths stop using `print` or swallowing errors.
extension Logger {
    private static let subsystem = "com.hugohodinka.Sublist"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let geo = Logger(subsystem: subsystem, category: "Geolocation")
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
}
