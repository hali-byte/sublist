import StoreKit
import SwiftUI
import Foundation

/// Decides when to ask for an App Store rating.
///
/// We only prompt at a genuine positive moment (after several meaningful
/// actions and a few days of use), once per app version, and let StoreKit
/// enforce its own 3-prompts-per-365-days cap. The gating logic is pure and
/// uses an injectable `UserDefaults` so it can be unit-tested in isolation.
@MainActor
final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    private let defaults: UserDefaults
    private let minPositiveActions: Int
    private let minDaysSinceInstall: Int

    init(
        defaults: UserDefaults = .standard,
        minPositiveActions: Int = 3,
        minDaysSinceInstall: Int = 5
    ) {
        self.defaults = defaults
        self.minPositiveActions = minPositiveActions
        self.minDaysSinceInstall = minDaysSinceInstall
    }

    /// Call once per launch. Records the first-launch date (once) and counts opens.
    func registerLaunch(now: Date = Date()) {
        if defaults.object(forKey: AppConstants.reviewFirstLaunchDate) == nil {
            defaults.set(now.timeIntervalSince1970, forKey: AppConstants.reviewFirstLaunchDate)
        }
        let opens = defaults.integer(forKey: AppConstants.reviewAppOpenCount)
        defaults.set(opens + 1, forKey: AppConstants.reviewAppOpenCount)
    }

    /// Call when the user does something meaningful and positive
    /// (adds a subscription, marks one renewed).
    func recordPositiveAction() {
        let count = defaults.integer(forKey: AppConstants.reviewPositiveActionCount)
        defaults.set(count + 1, forKey: AppConstants.reviewPositiveActionCount)
    }

    /// True when all gates pass and we haven't already prompted on this version.
    func shouldRequestReview(now: Date = Date()) -> Bool {
        guard defaults.integer(forKey: AppConstants.reviewPositiveActionCount) >= minPositiveActions else {
            return false
        }
        guard daysSinceInstall(now: now) >= minDaysSinceInstall else { return false }
        let lastPrompted = defaults.string(forKey: AppConstants.reviewLastPromptedVersion)
        return lastPrompted != AppConstants.appVersion
    }

    /// Requests a review if eligible, and records the prompt against this version.
    func requestReviewIfEligible(_ requestReview: RequestReviewAction, now: Date = Date()) {
        guard shouldRequestReview(now: now) else { return }
        defaults.set(AppConstants.appVersion, forKey: AppConstants.reviewLastPromptedVersion)
        requestReview()
    }

    private func daysSinceInstall(now: Date) -> Int {
        let stamp = defaults.double(forKey: AppConstants.reviewFirstLaunchDate)
        guard stamp > 0 else { return 0 }
        let installed = Date(timeIntervalSince1970: stamp)
        return Calendar.current.dateComponents([.day], from: installed, to: now).day ?? 0
    }
}
