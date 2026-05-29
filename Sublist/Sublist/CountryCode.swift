import Foundation

/// Validation for ISO 3166-1 alpha-2 country codes.
///
/// Pure helper so the geolocation parsing path can reject malformed responses
/// (empty strings, lowercase, 3-letter codes) before caching them, and so the
/// rule can be unit-tested without the network.
enum CountryCode {
    /// True when `code` is exactly two ASCII uppercase letters (e.g. "US", "ES").
    static func isValid(_ code: String) -> Bool {
        code.count == 2 && code.allSatisfy { $0.isASCII && $0.isLetter && $0.isUppercase }
    }
}
