import Foundation

/// Parses and validates the price text entered in the add/edit form.
///
/// Pure and side-effect free so it can be unit-tested independently of the View.
/// Accepts both "." and "," as the decimal separator. Rejects empty, non-numeric,
/// non-positive, non-finite, and implausibly large values.
enum AmountParser {
    /// Upper bound for a single subscription's price. Anything above this is
    /// almost certainly a typo (and guards against overflow/`inf` input).
    static let maximum = 1_000_000.0

    /// Returns the parsed amount, or `nil` if the input is not a valid price.
    static func parse(_ text: String) -> Double? {
        let normalised = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalised.isEmpty, let value = Double(normalised) else { return nil }
        guard value.isFinite, value > 0, value <= maximum else { return nil }
        return value
    }

    /// Whether `text` parses to a valid price.
    static func isValid(_ text: String) -> Bool {
        parse(text) != nil
    }
}
