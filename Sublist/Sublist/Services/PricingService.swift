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
        case .geolocationFailed:  return "Could not determine your country."
        case .fetchFailed:        return "Could not fetch pricing data."
        case .parsingFailed:      return "Could not read pricing data."
        case .unsupportedCountry: return "Pricing unavailable for this country."
        }
    }
}

// MARK: - Service

@MainActor
final class PricingService {
    static let shared = PricingService()

    private var cache: [String: [SubscriptionPlan]] = [:]

    private let anthropicEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
              !key.isEmpty, key != "PASTE_YOUR_KEY_HERE" else {
            fatalError("ANTHROPIC_API_KEY is missing or unset in Info.plist / Secrets.xcconfig")
        }
        return key
    }()

    private init() {}

    func fetchPlans(
        for countryCode: String,
        using provider: any SubscriptionPricingProvider
    ) async throws -> [SubscriptionPlan] {
        let cacheKey = "\(provider.serviceName)_\(countryCode)"
        if let cached = cache[cacheKey] { return cached }

        let start = Date()

        do {
            let html = try await fetchHTMLWithRetry(from: provider.pricingURL(for: countryCode), provider: provider)
            let plans = try await extractPlans(from: html, provider: provider, countryCode: countryCode)
            let ms = Int(Date().timeIntervalSince(start) * 1000)

            PricingAnalytics.record(
                service: provider.serviceName,
                country: countryCode,
                outcome: plans.isEmpty ? .empty : .success(planCount: plans.count),
                durationMs: ms
            )

            cache[cacheKey] = plans
            return plans
        } catch let error as PricingError {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let step: String
            switch error {
            case .fetchFailed:        step = "htmlFetch"
            case .parsingFailed:      step = "claudeAPI"
            case .geolocationFailed:  step = "geolocation"
            case .unsupportedCountry: step = "unsupportedCountry"
            }
            PricingAnalytics.record(
                service: provider.serviceName,
                country: countryCode,
                outcome: .failure(step: step, error: error.localizedDescription),
                durationMs: ms
            )
            throw error
        }
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
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PricingError.fetchFailed
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PricingError.fetchFailed
        }
        return String(text.prefix(50_000))
    }

    // MARK: - Claude extraction

    private func extractPlans(
        from html: String,
        provider: any SubscriptionPricingProvider,
        countryCode: String
    ) async throws -> [SubscriptionPlan] {

        let systemPrompt = """
        You are a pricing data extractor. Given HTML from a subscription service pricing page, \
        extract all available paid plans as a JSON array. Each element must have exactly these keys:
        - "name": string (plan name, e.g. "Individual", "Duo", "Family")
        - "price": number (the numeric price, no currency symbol)
        - "currency": string (ISO 4217 code, e.g. "USD", "EUR", "SEK")
        - "billingPeriod": string (exactly "month" or "year")
        Include only purchasable plans. Do not include free tiers. \
        Return ONLY valid JSON — no markdown fences, no explanation. \
        If no pricing is found, return an empty array [].
        \(provider.extractionHint)
        """

        let userMessage = """
        Extract all subscription plans from this pricing page HTML for country code \(countryCode):

        \(html)
        """

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 500,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        var request = URLRequest(url: anthropicEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return try await callClaudeWithRetry(request: request, provider: provider)
    }

    // MARK: - Claude API call with retry

    private func callClaudeWithRetry(request: URLRequest, provider: any SubscriptionPricingProvider) async throws -> [SubscriptionPlan] {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 200 {
            return try parseClaudeResponse(data)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        Logger.pricing.warning("[\(provider.serviceName)] Claude returned \(statusCode), retrying once. Body: \(body.prefix(200))")

        // Retry once on transient errors (429 rate-limit, 529 overloaded, 5xx)
        guard statusCode == 429 || statusCode == 529 || statusCode >= 500 else {
            Logger.pricing.error("[\(provider.serviceName)] Claude returned \(statusCode) — not retrying. Body: \(body.prefix(500))")
            throw PricingError.parsingFailed
        }

        let delay: UInt64 = statusCode == 429 ? 3_000_000_000 : 1_000_000_000 // 3s for rate-limit, 1s for overload
        try await Task.sleep(nanoseconds: delay)

        let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
        let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0

        guard retryStatus == 200 else {
            Logger.pricing.error("[\(provider.serviceName)] Claude retry also failed with \(retryStatus)")
            throw PricingError.parsingFailed
        }

        return try parseClaudeResponse(retryData)
    }

    // MARK: - Response parsing

    private func parseClaudeResponse(_ data: Data) throws -> [SubscriptionPlan] {
        struct ClaudeResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
            }
            let content: [ContentBlock]
        }

        struct RawPlan: Decodable {
            let name: String
            let price: Decimal
            let currency: String
            let billingPeriod: String
        }

        let claudeResp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = claudeResp.content.first(where: { $0.type == "text" }),
              let jsonText = textBlock.text else {
            throw PricingError.parsingFailed
        }

        // Strip accidental markdown fences
        let cleaned = jsonText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cleanedData = cleaned.data(using: .utf8) else {
            throw PricingError.parsingFailed
        }

        let rawPlans = try JSONDecoder().decode([RawPlan].self, from: cleanedData)
        return rawPlans.map { raw in
            SubscriptionPlan(
                name: raw.name,
                price: raw.price,
                currency: raw.currency.uppercased(),
                billingPeriod: raw.billingPeriod
            )
        }
    }
}
