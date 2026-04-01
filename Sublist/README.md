# Sublist

A native iOS subscription tracker built with SwiftUI and SwiftData.

Track everything you pay for regularly — streaming, tools, memberships — in one place. Know what's renewing, how much you're spending, and never get caught off guard.

---

## Features

### Subscription Management
- Add subscriptions manually or pick from a grid of popular presets (Netflix, Spotify, iCloud+, ChatGPT Plus, and more)
- Bundled SVG icons for 13 popular services with emoji fallback for everything else
- Billing cycle support: monthly and yearly (yearly subscriptions show a monthly equivalent)
- Mark as Renewed advances the renewal date by one billing cycle

### Home Screen
- **Hero summary card** — monthly spend as the centrepiece, yearly total top-right, and a Category Breakdown link
- **Renewing Soon** section — subscriptions due within 7 days, with a "Due today" badge and inline Mark as Renewed CTA
- **Upcoming** section — all other subscriptions grouped in a single native card with dividers
- Custom empty state with a branded CTA to add a first subscription
- Swipe to delete on any row

### Spending Breakdown
- Donut chart grouped by category with tap-to-highlight
- Per-category spend, percentage share, and a progress bar
- Animated centre label showing total or selected category

### Notifications
- Day-before renewal reminders via local notifications
- Permission request handled in Settings with a direct link to iOS Settings if denied

### Settings
- Currency selector (USD, EUR, GBP, AUD, CNY, SGD, SEK, PLN)
- Notification management

### Widget
- Home screen widget (small) showing the next upcoming renewal with a countdown badge

---

## Design

- Native iOS inset-grouped layout throughout
- Floating card rows for renewing-soon subscriptions; standard grouped rows for upcoming
- Confetti + green overlay animation when marking a subscription as renewed
- Haptic feedback on save, delete, and mark as renewed
- No chevrons — full card tap navigates to the detail view
- Subscription detail view shows a prominent icon + name header above the edit form

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Data | SwiftData |
| Charts | Swift Charts |
| Widget | WidgetKit |
| Notifications | UserNotifications |
| Minimum target | iOS 17 |

---

## Project Structure

```
Sublist/
├── Subscription.swift          # @Model — data model, BillingCycle, Category enums
├── ContentView.swift           # Home screen — summary card, section split, list
├── SummaryCard.swift           # Hero monthly/yearly spend card
├── SubscriptionRow.swift       # Card and grouped row modes
├── SubscriptionDetailView.swift# Edit form with identity header
├── AddSubscriptionView.swift   # Add sheet with popular presets
├── SpendingChartView.swift     # Donut chart breakdown
├── EmptyStateView.swift        # Custom empty state
├── ConfettiView.swift          # Confetti delight animation
├── PopularCard.swift           # Preset grid card component
├── SubscriptionIcons.swift     # Bundled icon lookup + SubscriptionIconView
├── EmojiPickerView.swift       # Emoji picker sheet
├── NotificationManager.swift   # Local notification scheduling
├── SettingsView.swift          # Settings sheet
├── WidgetSync.swift            # App Group snapshot for widget
└── SublistWidget/              # WidgetKit extension
```

---

## Requirements

- Xcode 15+
- iOS 17+
- Swift 5.9+
