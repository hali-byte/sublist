import Foundation
import OSLog

// MARK: - Errors

enum PricingError: LocalizedError {
    case geolocationFailed
    case fetchFailed
    case parsingFailed
    case unsupportedCountry

    var errorDescription: String? {
        switch self {
        case .geolocationFailed: return "Could not determine your country."
        case .fetchFailed: return "Could not fetch pricing data."
        case .parsingFailed: return "Could not read pricing data."
        case .unsupportedCountry: return "Pricing unavailable for this country."
        }
    }
}

// MARK: - Service

@MainActor
final class PricingService {
    static let shared = PricingService()

    private var cache: [String: [SubscriptionPlan]] = [:]

    private let proxyEndpoint = URL(string: "https://sublist-api.vercel.app/api/pricing")!

    private let bearerToken: String = {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "SUBLIST_API_TOKEN") as? String,
              !token.isEmpty, token != "PASTE_YOUR_TOKEN_HERE"
        else {
            fatalError("SUBLIST_API_TOKEN is missing or unset in Info.plist / Secrets.xcconfig")
        }
        return token
    }()

    private init() {}

    func fetchPlans(
        for countryCode: String,
        using provider: any SubscriptionPricingProvider
    ) async throws -> [SubscriptionPlan] {
        let cacheKey = "\(provider.serviceName)_\(countryCode)"
        if let cached = cache[cacheKey] { return cached }

        let start = Date()

        let urlsToTry = [provider.pricingURL(for: countryCode)] + provider.fallbackURLs
        var lastError: Error = PricingError.fetchFailed

        for url in urlsToTry {
            do {
                let html = try await fetchHTMLWithRetry(from: url, provider: provider)
                let plans = try await extractPlansViaProxy(
                    html: html,
                    provider: provider,
                    countryCode: countryCode
                )
                let ms = Int(Date().timeIntervalSince(start) * 1000)

                if !plans.isEmpty {
                    PricingAnalytics.record(
                        service: provider.serviceName,
                        country: countryCode,
                        outcome: .success(planCount: plans.count),
                        durationMs: ms
                    )
                    cache[cacheKey] = plans
                    return plans
                }
            } catch {
                lastError = error
                Logger.pricing.info("[\(provider.serviceName)] URL \(url) failed, trying next fallback…")
                continue
            }
        }

        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let step: String
        if let pricingError = lastError as? PricingError {
            switch pricingError {
            case .fetchFailed: step = "htmlFetch"
            case .parsingFailed: step = "proxyAPI"
            case .geolocationFailed: step = "geolocation"
            case .unsupportedCountry: step = "unsupportedCountry"
            }
        } else {
            step = "unknown"
        }
        PricingAnalytics.record(
            service: provider.serviceName,
            country: countryCode,
            outcome: .failure(step: step, error: lastError.localizedDescription),
            durationMs: ms
        )
        throw lastError
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - HTML fetch

    private func fetchHTMLWithRetry(from url: URL, provider: any SubscriptionPricingProvider) async throws -> String {
        do {
            return try await fetchHTML(from: url)
        } catch {
            Logger.pricing.warning("[\(provider.serviceName)] First fetch failed, retrying once…")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return try await fetchHTML(from: url)
        }
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw PricingError.fetchFailed
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PricingError.fetchFailed
        }
        return String(text.prefix(50000))
    }

    // MARK: - Proxy extraction

    private func extractPlansViaProxy(
        html: String,
        provider: any SubscriptionPricingProvider,
        countryCode: String
    ) async throws -> [SubscriptionPlan] {
        let payload: [String: String] = [
            "html": html,
            "serviceName": provider.serviceName,
            "countryCode": countryCode,
            "extractionHint": provider.extractionHint,
        ]

        var request = URLRequest(url: proxyEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        return try await callProxyWithRetry(request: request, provider: provider)
    }

    // MARK: - Proxy call with retry

    private func callProxyWithRetry(request: URLRequest, provider: any SubscriptionPricingProvider) async throws -> [SubscriptionPlan] {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 200 {
            return try parseProxyResponse(data)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        Logger.pricing.warning("[\(provider.serviceName)] Proxy returned \(statusCode), retrying once. Body: \(body.prefix(200))")

        guard statusCode == 429 || statusCode == 502 || statusCode >= 500 else {
            Logger.pricing.error("[\(provider.serviceName)] Proxy returned \(statusCode) — not retrying. Body: \(body.prefix(500))")
            throw PricingError.parsingFailed
        }

        let delay: UInt64 = statusCode == 429 ? 3_000_000_000 : 1_000_000_000
        try await Task.sleep(nanoseconds: delay)

        let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
        let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0

        guard retryStatus == 200 else {
            Logger.pricing.error("[\(provider.serviceName)] Proxy retry also failed with \(retryStatus)")
            throw PricingError.parsingFailed
        }

        return try parseProxyResponse(retryData)
    }

    // MARK: - Response parsing

    private func parseProxyResponse(_ data: Data) throws -> [SubscriptionPlan] {
        struct ProxyResponse: Decodable {
            struct Plan: Decodable {
                let name: String
                let price: Decimal
                let currency: String
                let billingPeriod: String
            }

            let plans: [Plan]
        }

        let response: ProxyResponse
        do {
            response = try JSONDecoder().decode(ProxyResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            Logger.pricing.error("Proxy response decode failed: \(error.localizedDescription). Body: \(body)")
            throw PricingError.parsingFailed
        }
        return response.plans.map { plan in
            SubscriptionPlan(
                name: plan.name,
                price: plan.price,
                currency: plan.currency.uppercased(),
                billingPeriod: plan.billingPeriod
            )
        }
    }
}
