import Foundation
import OSLog

// MARK: - Result type

struct GeolocationResult {
    let code: String  // ISO 3166-1 alpha-2, e.g. "ES"
    let name: String  // e.g. "Spain"
}

// MARK: - Service

@MainActor
final class IPGeolocationService {
    static let shared = IPGeolocationService()

    private var cached: GeolocationResult?

    private init() {}

    func resolve() async throws -> GeolocationResult {
        if let cached { return cached }

        var request = URLRequest(url: URL(string: "https://ipapi.co/json/")!)
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PricingError.geolocationFailed
        }

        struct GeoResponse: Decodable {
            let country_code: String
            let country_name: String
        }

        let geo: GeoResponse
        do {
            geo = try JSONDecoder().decode(GeoResponse.self, from: data)
        } catch {
            Logger.geo.error("Geolocation decode failed: \(error.localizedDescription)")
            throw PricingError.geolocationFailed
        }

        let code = geo.country_code.uppercased()
        guard CountryCode.isValid(code) else {
            Logger.geo.error("Invalid country_code from geolocation API: \(geo.country_code)")
            throw PricingError.geolocationFailed
        }

        let result = GeolocationResult(code: code, name: geo.country_name)
        cached = result
        return result
    }

    func clearCache() {
        cached = nil
    }
}
