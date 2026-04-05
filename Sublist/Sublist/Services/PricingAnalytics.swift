import Foundation
import OSLog

// MARK: - Logger

extension Logger {
    static let pricing = Logger(subsystem: "com.hugohodinka.Sublist", category: "Pricing")
}

// MARK: - Analytics

/// Logs pricing fetch events locally via OSLog and optionally to a remote webhook.
/// Set PRICING_ANALYTICS_WEBHOOK in Info.plist / Secrets.xcconfig to enable remote logging.
@MainActor
enum PricingAnalytics {

    enum Outcome {
        case success(planCount: Int)
        case empty
        case failure(step: String, error: String)
    }

    static func record(
        service: String,
        country: String,
        outcome: Outcome,
        durationMs: Int
    ) {
        switch outcome {
        case .success(let count):
            Logger.pricing.info("[\(service)] \(country) — \(count) plans in \(durationMs)ms")
        case .empty:
            Logger.pricing.warning("[\(service)] \(country) — 0 plans returned in \(durationMs)ms")
        case .failure(let step, let error):
            Logger.pricing.error("[\(service)] \(country) — failed at \(step) in \(durationMs)ms: \(error)")
        }

        // Remote webhook — fire and forget, no retry, never blocks the UI
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "PRICING_ANALYTICS_WEBHOOK") as? String,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        else { return }

        let payload: [String: Any] = [
            "service":     service,
            "country":     country,
            "outcome":     outcomeString(outcome),
            "duration_ms": durationMs,
            "timestamp":   ISO8601DateFormatter().string(from: Date()),
        ]

        Task.detached {
            guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            request.timeoutInterval = 5
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private static func outcomeString(_ outcome: Outcome) -> String {
        switch outcome {
        case .success(let n): return "success:\(n)"
        case .empty:          return "empty"
        case .failure(let step, _): return "failure:\(step)"
        }
    }
}
