import Testing
import Foundation
@testable import Sublist

// MARK: - AmountParser

@Suite("AmountParser")
struct AmountParserTests {
    @Test("valid decimal") func validDecimal() {
        #expect(AmountParser.parse("9.99") == 9.99)
    }

    @Test("valid integer") func validInteger() {
        #expect(AmountParser.parse("10") == 10)
    }

    @Test("comma decimal separator") func commaDecimal() {
        #expect(AmountParser.parse("9,99") == 9.99)
    }

    @Test("zero is rejected") func zero() {
        #expect(AmountParser.parse("0") == nil)
    }

    @Test("negative is rejected") func negative() {
        #expect(AmountParser.parse("-5") == nil)
    }

    @Test("empty is rejected") func empty() {
        #expect(AmountParser.parse("") == nil)
    }

    @Test("whitespace only is rejected") func whitespace() {
        #expect(AmountParser.parse("   ") == nil)
    }

    @Test("non-numeric is rejected") func nonNumeric() {
        #expect(AmountParser.parse("abc") == nil)
    }

    @Test("above maximum is rejected") func aboveMax() {
        #expect(AmountParser.parse("99999999") == nil)
    }

    @Test("overflowing input is rejected") func overflow() {
        // "1e400" parses to Double.infinity, which is not finite.
        #expect(AmountParser.parse("1e400") == nil)
    }

    @Test("leading/trailing whitespace is trimmed") func trimmed() {
        #expect(AmountParser.parse("  12.50 ") == 12.50)
    }
}

// MARK: - CurrencyFormatting

@Suite("CurrencyFormatting")
struct CurrencyFormattingTests {
    @Test("USD has two decimals") func usdDecimals() {
        #expect(CurrencyFormatting.decimals(for: "USD") == 2)
    }

    @Test("JPY has no decimals") func jpyDecimals() {
        #expect(CurrencyFormatting.decimals(for: "JPY") == 0)
    }

    @Test("KRW has no decimals") func krwDecimals() {
        #expect(CurrencyFormatting.decimals(for: "KRW") == 0)
    }

    @Test("USD tolerance is sub-cent") func usdTolerance() {
        #expect(CurrencyFormatting.priceTolerance(for: "USD") < 0.01)
        #expect(CurrencyFormatting.priceTolerance(for: "USD") > 0)
    }

    @Test("JPY tolerance is at least half a unit") func jpyTolerance() {
        #expect(CurrencyFormatting.priceTolerance(for: "JPY") >= 0.5)
    }

    @Test("USD symbol") func usdSymbol() {
        #expect(CurrencyFormatting.symbol(for: "USD") == "$")
    }

    @Test("unknown currency falls back to its code") func unknownSymbol() {
        #expect(CurrencyFormatting.symbol(for: "ZZZ") == "ZZZ")
    }

    @Test("format respects currency decimals") func formatDecimals() {
        #expect(CurrencyFormatting.format(1200, code: "JPY") == "¥1200")
        #expect(CurrencyFormatting.format(9.99, code: "USD") == "$9.99")
    }
}

// MARK: - CountryCode

@Suite("CountryCode")
struct CountryCodeTests {
    @Test("valid uppercase code") func valid() {
        #expect(CountryCode.isValid("US"))
        #expect(CountryCode.isValid("GB"))
    }

    @Test("empty is invalid") func empty() {
        #expect(!CountryCode.isValid(""))
    }

    @Test("lowercase is invalid") func lowercase() {
        #expect(!CountryCode.isValid("us"))
    }

    @Test("three letters is invalid") func threeLetters() {
        #expect(!CountryCode.isValid("USA"))
    }

    @Test("one letter is invalid") func oneLetter() {
        #expect(!CountryCode.isValid("U"))
    }

    @Test("digits are invalid") func digits() {
        #expect(!CountryCode.isValid("U1"))
    }

    @Test("trailing space is invalid") func space() {
        #expect(!CountryCode.isValid("U "))
    }
}

// MARK: - NotificationManager.reminderFireDate

@Suite("Reminder fire date")
struct ReminderFireDateTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return calendar.date(from: c)!
    }

    @Test("far-future renewal fires day before at 09:00") func dayBeforeNineAM() {
        let now = date(2026, 6, 1, 12, 0)
        let renewal = date(2026, 6, 10, 0, 0)
        let fire = NotificationManager.reminderFireDate(forRenewal: renewal, now: now, calendar: calendar)
        #expect(fire == date(2026, 6, 9, 9, 0))
    }

    @Test("past renewal returns nil") func pastRenewal() {
        let now = date(2026, 6, 10, 12, 0)
        let renewal = date(2026, 6, 1, 0, 0)
        #expect(NotificationManager.reminderFireDate(forRenewal: renewal, now: now, calendar: calendar) == nil)
    }

    @Test("imminent renewal falls back to a near-term reminder") func imminentFallback() {
        // Renewal is tomorrow, but the day-before-09:00 slot is already in the past.
        let now = date(2026, 6, 9, 15, 0)
        let renewal = date(2026, 6, 10, 12, 0)
        let fire = NotificationManager.reminderFireDate(forRenewal: renewal, now: now, calendar: calendar)
        #expect(fire != nil)
        if let fire {
            #expect(fire > now)
            #expect(fire < renewal)
        }
    }
}
