import Foundation
@testable import Sublist
import Testing

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

// MARK: - ReviewPromptManager gating

@MainActor
@Suite("Review prompt gating")
struct ReviewPromptGatingTests {
    private func makeManager() -> (ReviewPromptManager, UserDefaults) {
        let suite = "ReviewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (ReviewPromptManager(defaults: defaults, minPositiveActions: 3, minDaysSinceInstall: 5), defaults)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    @Test("below action threshold is not eligible") func belowActions() {
        let (m, _) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        m.recordPositiveAction()
        #expect(m.shouldRequestReview(now: date(2026, 6, 20)) == false)
    }

    @Test("below day threshold is not eligible") func belowDays() {
        let (m, _) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        for _ in 0 ..< 5 {
            m.recordPositiveAction()
        }
        #expect(m.shouldRequestReview(now: date(2026, 6, 2)) == false)
    }

    @Test("at threshold is eligible") func atThreshold() {
        let (m, _) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        for _ in 0 ..< 3 {
            m.recordPositiveAction()
        }
        #expect(m.shouldRequestReview(now: date(2026, 6, 10)) == true)
    }

    @Test("already prompted this version is not eligible") func alreadyPrompted() {
        let (m, defaults) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        for _ in 0 ..< 3 {
            m.recordPositiveAction()
        }
        defaults.set(AppConstants.appVersion, forKey: AppConstants.reviewLastPromptedVersion)
        #expect(m.shouldRequestReview(now: date(2026, 6, 10)) == false)
    }

    @Test("eligible again after a version change") func newVersion() {
        let (m, defaults) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        for _ in 0 ..< 3 {
            m.recordPositiveAction()
        }
        defaults.set("0.0-old", forKey: AppConstants.reviewLastPromptedVersion)
        #expect(m.shouldRequestReview(now: date(2026, 6, 10)) == true)
    }

    @Test("registerLaunch sets first-launch date only once") func firstLaunchOnce() {
        let (m, defaults) = makeManager()
        m.registerLaunch(now: date(2026, 6, 1))
        let first = defaults.double(forKey: AppConstants.reviewFirstLaunchDate)
        m.registerLaunch(now: date(2026, 6, 5))
        #expect(defaults.double(forKey: AppConstants.reviewFirstLaunchDate) == first)
    }
}

// MARK: - Trial reminder dates

@MainActor
@Suite("Trial reminder dates")
struct TrialReminderDatesTests {
    @Test("future trial yields 48h and 24h reminders") func twoReminders() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let trialEnd = now.addingTimeInterval(10 * 86400)
        let dates = NotificationManager.trialReminderDates(trialEnd: trialEnd, now: now)
        #expect(dates.count == 2)
        #expect(dates.allSatisfy { $0 > now && $0 < trialEnd })
    }

    @Test("trial within 24h falls back to one near-term reminder") func fallback() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let trialEnd = now.addingTimeInterval(12 * 3600)
        let dates = NotificationManager.trialReminderDates(trialEnd: trialEnd, now: now)
        #expect(dates.count == 1)
        #expect(dates[0] > now && dates[0] < trialEnd)
    }

    @Test("past trial yields no reminders") func pastTrial() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let trialEnd = now.addingTimeInterval(-3600)
        #expect(NotificationManager.trialReminderDates(trialEnd: trialEnd, now: now).isEmpty)
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
