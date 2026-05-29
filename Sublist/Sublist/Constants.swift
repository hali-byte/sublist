import Foundation

enum AppConstants {
    static let appGroupID = "group.com.hugohodinka.Sublist"
    static let currencyKey = "currency"
    static let widgetSnapshotKey = "widgetNextSubscription"
    static let appearanceKey = "appearance"
    static let countryCodeKey = "countryCode"
    static let lastBackgroundCheckKey = "lastBackgroundCheck"
    static let backgroundPriceCheckEnabled = "backgroundPriceCheckEnabled"
    static let showPriceChangeTags = "showPriceChangeTags"

    /// Onboarding
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let notificationNudgeDismissed = "notificationNudgeDismissed"

    // Review prompt gating
    static let reviewFirstLaunchDate = "reviewFirstLaunchDate"
    static let reviewAppOpenCount = "reviewAppOpenCount"
    static let reviewPositiveActionCount = "reviewPositiveActionCount"
    static let reviewLastPromptedVersion = "reviewLastPromptedVersion"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
