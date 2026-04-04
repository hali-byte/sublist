import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model (mirrors ContentView's writer)

struct SubscriptionSnapshot: Codable {
    let name: String
    let emoji: String
    let iconName: String?
    let amount: Double
    let billingCycle: String
    let nextRenewalDate: Date
    let currency: String

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: nextRenewalDate)
        ).day ?? 0
    }
}

// MARK: - Timeline entry

struct SublistEntry: TimelineEntry {
    let date: Date
    let snapshot: SubscriptionSnapshot?
}

// MARK: - Provider

struct SublistProvider: TimelineProvider {
    private let appGroupID = "group.com.hugohodinka.Sublist"

    func placeholder(in context: Context) -> SublistEntry {
        SublistEntry(date: .now, snapshot: SubscriptionSnapshot(
            name: "Netflix", emoji: "🎬", iconName: "icon_netflix", amount: 15.99,
            billingCycle: "Monthly",
            nextRenewalDate: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now,
            currency: "USD"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SublistEntry) -> Void) {
        completion(SublistEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SublistEntry>) -> Void) {
        let entry = SublistEntry(date: .now, snapshot: loadSnapshot())
        let midnight = Calendar.current.startOfDay(for: Date.now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func loadSnapshot() -> SubscriptionSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: "widgetNextSubscription"),
            let snapshot = try? JSONDecoder().decode(SubscriptionSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}

// MARK: - Colour palette (matches new Sublist icon scheme)

private extension Color {
    /// Dark navy — matches the icon background #050F2F
    static let sublistBackground = Color(red: 0.020, green: 0.059, blue: 0.184)
    /// Medium periwinkle — lightest layer from icon #7989BF
    static let sublistPeriwinkle = Color(red: 0.475, green: 0.537, blue: 0.749)
    /// Mid-blue layer from icon #455DAC
    static let sublistMidBlue    = Color(red: 0.271, green: 0.365, blue: 0.675)
}

// MARK: - Widget view

struct SublistWidgetView: View {
    let entry: SublistEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            contentView(snapshot)
        } else {
            emptyView
        }
    }

    private func contentView(_ s: SubscriptionSnapshot) -> some View {
        VStack(alignment: .trailing, spacing: 2) {

            // Top right — context label
            Text("UP NEXT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.sublistPeriwinkle)
                .kerning(0.6)

            // Right below — renewal urgency
            renewalBadge(days: s.daysUntilRenewal)

            Spacer()

            // Bottom left — service identity + amount
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let iconName = s.iconName {
                        Image(iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else {
                        Text(s.emoji)
                            .font(.system(size: 18))
                    }
                    Text(s.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.sublistPeriwinkle)
                        .lineLimit(1)
                }

                Text(s.amount, format: .currency(code: s.currency))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.title2)
                .foregroundStyle(Color.sublistMidBlue)
            Text("No subscriptions")
                .font(.caption2)
                .foregroundStyle(Color.sublistPeriwinkle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func renewalBadge(days: Int) -> some View {
        let (label, color, urgent): (LocalizedStringKey, Color, Bool) = {
            switch days {
            case ..<0: return ("Overdue",          .red,              true)
            case 0:    return ("Today",             .red,              true)
            case 1:    return ("Tomorrow",          .orange,           true)
            default:   return ("In \(days) days",   .sublistPeriwinkle, false)
            }
        }()

        Text(label)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(urgent ? color : Color.sublistPeriwinkle)
    }
}

// MARK: - Widget declaration

struct SublistWidget: Widget {
    let kind = "SublistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SublistProvider()) { entry in
            SublistWidgetView(entry: entry)
                .containerBackground(Color("WidgetBackground"), for: .widget)
        }
        .configurationDisplayName("Next Renewal")
        .description("Your next upcoming subscription at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Bundle

@main
struct SublistWidgetBundle: WidgetBundle {
    var body: some Widget {
        SublistWidget()
    }
}
