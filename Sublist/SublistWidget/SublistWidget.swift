import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model (mirrors ContentView's writer)

private struct SubscriptionSnapshot: Codable {
    let name: String
    let emoji: String
    let amount: Double
    let billingCycle: String
    let daysUntilRenewal: Int
    let currency: String
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
            name: "Netflix", emoji: "🎬", amount: 15.99,
            billingCycle: "Monthly", daysUntilRenewal: 3, currency: "USD"
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
        VStack(alignment: .leading, spacing: 0) {
            Text("UP NEXT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1)

            Spacer()

            Text(s.emoji)
                .font(.system(size: 40))

            Spacer(minLength: 8)

            Text(s.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(s.amount, format: .currency(code: s.currency))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            renewalBadge(days: s.daysUntilRenewal)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        let (label, color): (String, Color) = {
            switch days {
            case ..<0: return ("Overdue", .red)
            case 0:    return ("Today", .red)
            case 1:    return ("Tomorrow", .orange)
            default:   return ("In \(days) days", .secondary)
            }
        }()

        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color == .secondary ? .secondary : color.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(color == .secondary ? 0 : 0.12), in: Capsule())
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
