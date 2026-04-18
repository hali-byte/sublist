import Foundation

// MARK: - Protocol

protocol SubscriptionPricingProvider {
    var serviceName: String { get }
    func pricingURL(for countryCode: String) -> URL
    var extractionHint: String { get }
    var fallbackURLs: [URL] { get }
}

extension SubscriptionPricingProvider {
    var fallbackURLs: [URL] { [] }
}

// MARK: - Spotify

struct SpotifyPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Spotify"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.spotify.com/\(countryCode.lowercased())/premium/")!
    }

    var extractionHint: String {
        "Spotify may show a Premium Platinum tier in some markets — include it if present."
    }
}

// MARK: - Netflix

struct NetflixPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Netflix"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.netflix.com/signup/planform")!
    }

    var extractionHint: String {
        "Extract Standard with Ads, Standard, and Premium plan prices. Ignore free trial mentions."
    }
}

// MARK: - Apple Music

struct AppleMusicPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Apple Music"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.apple.com/\(countryCode.lowercased())/apple-music/")!
    }

    var extractionHint: String {
        "Extract Individual, Student, and Family plan prices. Ignore free trial mentions."
    }
}

// MARK: - YouTube Premium

struct YouTubePricingProvider: SubscriptionPricingProvider {
    let serviceName = "YouTube"

    func pricingURL(for countryCode: String) -> URL {
        // Google support article — server-rendered HTML with pricing tables by country
        URL(string: "https://support.google.com/youtube/answer/6385279")!
    }

    var extractionHint: String {
        "This is a Google support article listing YouTube Premium prices by country. Find the row for the relevant country and extract Individual, Student, and Family plan prices."
    }
}

// MARK: - Apple TV+

struct AppleTVPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Apple TV+"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.apple.com/\(countryCode.lowercased())/apple-tv-plus/")!
    }

    var extractionHint: String {
        "Extract the monthly and annual Apple TV+ subscription price."
    }
}

// MARK: - iCloud+

struct ICloudPricingProvider: SubscriptionPricingProvider {
    let serviceName = "iCloud+"

    func pricingURL(for countryCode: String) -> URL {
        // Apple support article 111912 — server-rendered, lists all storage tiers with prices
        let locale = Self.appleLocale(for: countryCode)
        return URL(string: "https://support.apple.com/\(locale)/111912")!
    }

    var extractionHint: String {
        "This is an Apple support article about iCloud storage plans. Extract the 50GB, 200GB, 2TB, 6TB, and 12TB plan prices as monthly subscriptions."
    }

    private static func appleLocale(for countryCode: String) -> String {
        let langMap: [String: String] = [
            "ES": "es", "MX": "es", "AR": "es", "CL": "es", "CO": "es",
            "DE": "de", "AT": "de", "CH": "de",
            "FR": "fr", "BE": "fr",
            "IT": "it",
            "JP": "ja",
            "CN": "zh-cn", "TW": "zh-tw", "HK": "zh-hk",
            "KR": "ko",
            "NL": "nl",
            "SE": "sv",
            "NO": "nb",
            "DK": "da",
            "PL": "pl",
            "PT": "pt", "BR": "pt",
            "RU": "ru",
            "TR": "tr",
            "SA": "ar", "AE": "ar",
        ]
        let lang = langMap[countryCode.uppercased()] ?? "en"
        return "\(lang)-\(countryCode.lowercased())"
    }
}

// MARK: - Google One

struct GoogleOnePricingProvider: SubscriptionPricingProvider {
    let serviceName = "Google One"

    func pricingURL(for countryCode: String) -> URL {
        // Google support article — server-rendered with storage plan pricing
        URL(string: "https://support.google.com/googleone/answer/9004014")!
    }

    var extractionHint: String {
        "This is a Google support article about Google One storage plans. Extract the 100GB, 200GB, and 2TB plan prices as monthly subscriptions."
    }
}

// MARK: - ChatGPT Plus

struct ChatGPTPricingProvider: SubscriptionPricingProvider {
    let serviceName = "ChatGPT Plus"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://openai.com/chatgpt/pricing/")!
    }

    var extractionHint: String {
        "Extract ChatGPT Plus and ChatGPT Pro plan prices. Prices appear as dollar amounts such as '$20' or '$200'. Return only the numeric value (e.g. 20, not '$20'). Ignore the free tier. If Plus is $20/month, return price: 20. If Pro is $200/month, return price: 200."
    }
}

// MARK: - Notion

struct NotionPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Notion"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.notion.so/pricing")!
    }

    var extractionHint: String {
        "Extract Plus and Business plan prices per user per month. Ignore the free tier."
    }
}

// MARK: - 1Password

struct OnePasswordPricingProvider: SubscriptionPricingProvider {
    let serviceName = "1Password"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://1password.com/sign-up/")!
    }

    var extractionHint: String {
        "Extract Individual and Families plan prices. Monthly prices preferred."
    }
}

// MARK: - Duolingo

struct DuolingoPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Duolingo"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.duolingo.com/plus")!
    }

    var extractionHint: String {
        "Extract Duolingo Super (Plus) monthly and annual prices."
    }
}

// MARK: - Crunchyroll

struct CrunchyrollPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Crunchyroll"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.crunchyroll.com/welcome#plans")!
    }

    var extractionHint: String {
        "Extract Fan, Mega Fan, and Ultimate Fan plan prices."
    }
}

// MARK: - NYT

struct NYTPricingProvider: SubscriptionPricingProvider {
    let serviceName = "NYT"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.nytimes.com/subscription")!
    }

    var extractionHint: String {
        "Extract Basic News and All Access plan prices. Monthly prices preferred."
    }
}

// MARK: - Disney+

struct DisneyPlusPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Disney+"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.disneyplus.com/welcome/buy-now")!
    }

    var extractionHint: String {
        "Extract Disney+ plan prices including Basic, Standard, and Premium tiers. Include monthly and annual pricing where available."
    }

    var fallbackURLs: [URL] {
        [URL(string: "https://help.disneyplus.com/article/disneyplus-subscriptions-background")!]
    }
}

// MARK: - Amazon Prime

struct AmazonPrimePricingProvider: SubscriptionPricingProvider {
    let serviceName = "Amazon Prime"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://www.amazon.com/gp/help/customer/display.html?nodeId=G6LDPN7YJHYKH2J6")!
    }

    var extractionHint: String {
        "Extract Amazon Prime membership prices: monthly and annual plans. Include Prime Video standalone if available."
    }
}

// MARK: - Hulu

struct HuluPricingProvider: SubscriptionPricingProvider {
    let serviceName = "Hulu"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://help.hulu.com/article/hulu-plans-workspace")!
    }

    var extractionHint: String {
        "Extract Hulu plan prices: Basic (with ads), No Ads, and any bundle options. Monthly pricing preferred."
    }

    var fallbackURLs: [URL] {
        [URL(string: "https://www.hulu.com/welcome")!]
    }
}

// MARK: - NordVPN

struct NordVPNPricingProvider: SubscriptionPricingProvider {
    let serviceName = "NordVPN"

    func pricingURL(for countryCode: String) -> URL {
        URL(string: "https://support.nordvpn.com/general-info/billing/how-can-i-pay-for-my-nordvpn-subscription/")!
    }

    var extractionHint: String {
        "Extract NordVPN plan prices: Standard, Plus, and Complete tiers. Include monthly and yearly pricing if available."
    }
}

// MARK: - Registry

enum ProviderRegistry {
    static func provider(for serviceName: String) -> (any SubscriptionPricingProvider)? {
        switch serviceName.lowercased() {
        case "netflix":       return NetflixPricingProvider()
        case "spotify":       return SpotifyPricingProvider()
        case "apple music":   return AppleMusicPricingProvider()
        case "youtube":       return YouTubePricingProvider()
        case "apple tv+":     return AppleTVPricingProvider()
        case "icloud+":       return ICloudPricingProvider()
        case "google one":    return GoogleOnePricingProvider()
        case "chatgpt plus":  return ChatGPTPricingProvider()
        case "notion":        return NotionPricingProvider()
        case "1password":     return OnePasswordPricingProvider()
        case "duolingo":      return DuolingoPricingProvider()
        case "crunchyroll":   return CrunchyrollPricingProvider()
        case "nyt":           return NYTPricingProvider()
        case "disney+":       return DisneyPlusPricingProvider()
        case "amazon prime":  return AmazonPrimePricingProvider()
        case "hulu":          return HuluPricingProvider()
        case "nordvpn":       return NordVPNPricingProvider()
        default:              return nil
        }
    }
}
