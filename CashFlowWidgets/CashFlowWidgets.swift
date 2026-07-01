//
//  CashFlowWidgets.swift
//  CashFlowWidgets
//
//  Created by James Larkin on 6/18/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CashFlowWidgetEntry {
        CashFlowWidgetEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            snapshot: .placeholder
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CashFlowWidgetEntry {
        CashFlowWidgetEntry(
            date: Date(),
            configuration: configuration,
            snapshot: WidgetSnapshotReader.loadSnapshot() ?? .placeholder
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CashFlowWidgetEntry> {
        let entry = CashFlowWidgetEntry(
            date: Date(),
            configuration: configuration,
            snapshot: WidgetSnapshotReader.loadSnapshot()
        )

        // WidgetKit controls exact refresh timing, but this gives it a regular chance to re-read shared app data.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct CashFlowWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let snapshot: CashFlowWidgetSnapshot?
}

struct CashFlowWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: Provider.Entry

    var body: some View {
        ZStack {
            CashFlowWidgetColors.background

            content
                .padding(widgetFamily == .systemSmall ? 12 : 16)
        }
        .containerBackground(CashFlowWidgetColors.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot {
            switch snapshot.bankStatus {
            case .notConnected:
                WidgetStateView(title: "Connect Bank", message: "Open Cash Flow to start syncing.")
            case .needsReconnect:
                WidgetStateView(title: "Reconnect", message: "Open Cash Flow to refresh bank access.")
            case .error:
                WidgetStateView(title: "Needs Attention", message: "Open Cash Flow to retry sync.")
            case .connected:
                connectedContent(snapshot: snapshot)
            }
        } else {
            WidgetStateView(title: "No Data Yet", message: "Open Cash Flow once to prepare widgets.")
        }
    }

    @ViewBuilder
    private func connectedContent(snapshot: CashFlowWidgetSnapshot) -> some View {
        // v1 only exposes the Discretionary Number widget. The other renderers stay dormant until those widgets return to scope.
        DiscretionaryNumberWidget(snapshot: snapshot)
    }
}

struct DiscretionaryNumberWidget: View {
    let snapshot: CashFlowWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(CashFlowWidgetColors.accent)
                .frame(width: 34, height: 4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cash Flow")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(CashFlowWidgetColors.secondaryText)
                        .textCase(.uppercase)

                    Text("Discretionary")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CashFlowWidgetColors.primaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(syncText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CashFlowWidgetColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            Text(snapshot.discretionaryBalance, format: .currency(code: "USD"))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(CashFlowWidgetColors.primaryText)
                .minimumScaleFactor(0.55)
                .lineLimit(1)

            Text("Available now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CashFlowWidgetColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var syncText: String {
        guard let lastSyncedAt = snapshot.lastSyncedAt else {
            return "Not synced"
        }

        return lastSyncedAt.formatted(date: .omitted, time: .shortened)
    }
}

struct ProgressBarWidget: View {
    let item: CashFlowWidgetSnapshotItem
    let lastSyncedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: item.name, lastSyncedAt: lastSyncedAt)

            Spacer(minLength: 0)

            Text(item.remaining, format: .currency(code: "USD"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(CashFlowWidgetColors.primaryText)
                .minimumScaleFactor(0.68)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: min(max(item.progress, 0), 1))
                    .tint(CashFlowWidgetColors.accent)
                    .background(CashFlowWidgetColors.track)
                    .clipShape(Capsule())

                HStack {
                    Text("Spent")
                    Spacer()
                    Text(item.spent, format: .currency(code: "USD"))
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(CashFlowWidgetColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct BillStackWidget: View {
    let item: CashFlowWidgetSnapshotItem
    let lastSyncedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: item.name, lastSyncedAt: lastSyncedAt)

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                BillStackBar(label: "Budget", amount: item.budget, fill: CashFlowWidgetColors.surface)
                BillStackBar(label: "Spent", amount: item.spent, fill: CashFlowWidgetColors.accent.opacity(0.75))
                BillStackBar(label: "Left", amount: item.remaining, fill: CashFlowWidgetColors.teal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct BillStackBar: View {
    let label: String
    let amount: Double
    let fill: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(CashFlowWidgetColors.secondaryText)

            Spacer()

            Text(amount, format: .currency(code: "USD"))
                .foregroundStyle(CashFlowWidgetColors.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct WidgetHeader: View {
    let title: String
    let lastSyncedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(CashFlowWidgetColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(syncText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CashFlowWidgetColors.secondaryText)
                .lineLimit(1)
        }
    }

    private var syncText: String {
        guard let lastSyncedAt else {
            return "Not synced"
        }

        return lastSyncedAt.formatted(date: .omitted, time: .shortened)
    }
}

struct WidgetStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(CashFlowWidgetColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(CashFlowWidgetColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct CashFlowWidgets: Widget {
    let kind = "CashFlowWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CashFlowWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Discretionary Number")
        .description("Shows your latest discretionary spending snapshot.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private enum WidgetSnapshotReader {
    static let appGroupIdentifier = "group.com.jameslarkin.cashflow.widgets"
    static let snapshotUserDefaultsKey = "cashFlowWidgetSnapshot"

    static func loadSnapshot() -> CashFlowWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotUserDefaultsKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CashFlowWidgetSnapshot.self, from: data)
    }
}

private enum CashFlowWidgetColors {
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 15 / 255)
    static let surface = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255)
    static let track = Color(red: 42 / 255, green: 42 / 255, blue: 56 / 255)
    static let accent = Color(red: 74 / 255, green: 158 / 255, blue: 255 / 255)
    static let teal = Color(red: 0 / 255, green: 212 / 255, blue: 184 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 176 / 255)
}

struct CashFlowWidgetSnapshot: Codable {
    let generatedAt: Date
    let bankStatus: CashFlowBankConnectionStatus
    let lastSyncedAt: Date?
    let discretionaryBalance: Double
    let widgets: [CashFlowWidgetSnapshotItem]

    func item(for display: CashFlowWidgetDisplay) -> CashFlowWidgetSnapshotItem? {
        widgets.first { item in
            item.type.display == display
        }
    }
}

struct CashFlowWidgetSnapshotItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: CashFlowSnapshotWidgetType
    let period: CashFlowSnapshotBudgetPeriod
    let budget: Double
    let spent: Double
    let remaining: Double
    let progress: Double
}

enum CashFlowSnapshotWidgetType: String, Codable {
    case billStack
    case progressBar
    case discretionaryNumber

    var display: CashFlowWidgetDisplay {
        switch self {
        case .billStack:
            return .billStack
        case .progressBar:
            return .progressBar
        case .discretionaryNumber:
            return .discretionaryNumber
        }
    }
}

enum CashFlowSnapshotBudgetPeriod: String, Codable {
    case weekly
    case monthly
}

enum CashFlowBankConnectionStatus: String, Codable {
    case notConnected
    case connected
    case needsReconnect
    case error
}

extension CashFlowWidgetSnapshot {
    static let placeholder = CashFlowWidgetSnapshot(
        generatedAt: Date(),
        bankStatus: .connected,
        lastSyncedAt: Date(),
        discretionaryBalance: 420,
        widgets: [
            CashFlowWidgetSnapshotItem(
                id: UUID(),
                name: "Dining",
                type: .progressBar,
                period: .monthly,
                budget: 300,
                spent: 126,
                remaining: 174,
                progress: 0.42
            ),
            CashFlowWidgetSnapshotItem(
                id: UUID(),
                name: "Bills",
                type: .billStack,
                period: .monthly,
                budget: 900,
                spent: 540,
                remaining: 360,
                progress: 0.6
            )
        ]
    )
}

extension ConfigurationAppIntent {
    fileprivate static var discretionaryPreview: ConfigurationAppIntent {
        ConfigurationAppIntent()
    }
}

#Preview(as: .systemSmall) {
    CashFlowWidgets()
} timeline: {
    CashFlowWidgetEntry(date: .now, configuration: .discretionaryPreview, snapshot: .placeholder)
}
