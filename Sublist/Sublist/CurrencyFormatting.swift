import Foundation

/// Single source of truth for currency display and precision.
///
/// Replaces the symbol/decimals logic that was previously duplicated across
/// `AddSubscriptionView` and `PriceChangeDetector`. Pure and side-effect free
/// so it can be unit-tested without a SwiftData container or network.
enum CurrencyFormatting {
    /// The currencies offered in the in-app pickers.
    static let supportedCodes: [String] = [
        "USD", "EUR", "GBP", "AUD", "CAD", "CNY", "SGD", "SEK",
        "PLN", "DKK", "NOK", "CHF", "BRL", "JPY", "KRW", "INR",
    ]

    /// ISO 4217 currencies that have no minor unit (no decimal places).
    private static let zeroDecimalCodes: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW",
        "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
    ]

    /// Curated, clean symbols for the currencies we surface. Preferred over the
    /// locale-derived symbol because `NumberFormatter` can return locale-prefixed
    /// forms like "US$" or "JP¥" depending on the device region.
    private static let curatedSymbols: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£", "AUD": "A$",
        "CAD": "C$", "CNY": "¥", "SGD": "S$", "SEK": "kr",
        "PLN": "zł", "DKK": "kr", "NOK": "kr", "CHF": "Fr",
        "BRL": "R$", "JPY": "¥", "KRW": "₩", "INR": "₹",
    ]

    /// Number of decimal places for the given currency code.
    /// JPY/KRW and other zero-decimal currencies return 0; default is 2.
    static func decimals(for code: String) -> Int {
        let upper = code.uppercased()
        if zeroDecimalCodes.contains(upper) { return 0 }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = upper
        let digits = formatter.maximumFractionDigits
        return digits >= 0 ? digits : 2
    }

    /// Smallest meaningful price difference for change detection.
    /// 0.005 for 2-decimal currencies, 0.5 for zero-decimal currencies.
    /// Below this threshold a change is treated as rounding noise.
    static func priceTolerance(for code: String) -> Double {
        let decimals = decimals(for: code)
        return pow(10.0, Double(-decimals)) / 2.0
    }

    /// Display symbol for the given currency code.
    /// Prefers our curated table, then the locale-derived symbol, then the code.
    static func symbol(for code: String) -> String {
        let upper = code.uppercased()
        if let curated = curatedSymbols[upper] { return curated }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = upper
        if let symbol = formatter.currencySymbol, !symbol.isEmpty, symbol != upper {
            return symbol
        }
        return upper
    }

    /// Formats an amount with the correct number of fraction digits for the currency,
    /// prefixed with its symbol (e.g. "$9.99", "¥1200").
    static func format(_ amount: Double, code: String) -> String {
        let digits = decimals(for: code)
        let number = String(format: "%.\(digits)f", amount)
        return "\(symbol(for: code))\(number)"
    }
}
