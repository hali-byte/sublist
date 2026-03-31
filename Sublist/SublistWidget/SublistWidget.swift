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
                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(s.amount, format: .currency(code: s.currency))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
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
                .foregroundStyle(.secondary)
            Text("No subscriptions")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func renewalBadge(days: Int) -> some View {
        let (label, color, urgent): (String, Color, Bool) = {
            switch days {
            case ..<0: return ("Overdue",          Color.red,      true)
            case 0:    return ("Today",             Color.red,      true)
            case 1:    return ("Tomorrow",          Color.orange,   true)
            default:   return ("In \(days) days",   Color.secondary, false)
            }
        }()

        Text(label)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(urgent ? color : Color.secondary)
    }
}

// MARK: - Widget declaration

struct SublistWidget: Widget {
    let kind = "SublistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SublistProvider()) { entry in
            SublistWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
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
