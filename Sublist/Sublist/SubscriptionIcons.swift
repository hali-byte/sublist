import SwiftUI

// Returns the xcassets name for a known subscription, or nil for unknowns.
// Matching is case-insensitive so manually typed names work too.
func bundledIconName(for name: String) -> String? {
    let lookup: [String: String] = [
        "netflix":      "icon_netflix",
        "spotify":      "icon_spotify",
        "apple music":  "icon_apple_music",
        "youtube":      "icon_youtube",
        "disney+":      "icon_disney_plus",
        "amazon prime": "icon_amazon_prime",
        "apple tv+":    "icon_apple_tv",
        "hulu":         "icon_hulu",
        "icloud+":      "icon_icloud",
        "google one":   "icon_google_one",
        "notion":       "icon_notion",
        "duolingo":     "icon_duolingo",
        "crunchyroll":  "icon_crunchyroll",
        "chatgpt plus": "icon_chatgpt",
    ]
    return lookup[name.lowercased().trimmingCharacters(in: .whitespaces)]
}

// Displays a bundled SVG icon when one exists for the subscription name,
// falling back to the emoji via EmojiView for everything else.
struct SubscriptionIconView: View {
    let name: String
    let emoji: String
    let size: CGFloat

    var body: some View {
        if let iconName = bundledIconName(for: name) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            EmojiView(emoji: emoji, size: size)
        }
    }
}
