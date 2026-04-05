import Foundation

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

        let geo = try JSONDecoder().decode(GeoResponse.self, from: data)
        let result = GeolocationResult(code: geo.country_code, name: geo.country_name)
        cached = result
        return result
    }

    func clearCache() {
        cached = nil
    }
}
