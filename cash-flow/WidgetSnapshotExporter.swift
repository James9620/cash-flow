//
//  WidgetSnapshotExporter.swift
//  cash-flow
//
//  Created by Codex on 6/18/26.
//

import Foundation
import SwiftData

struct WidgetSnapshotExporter {
    @MainActor
    func export(context: ModelContext, now: Date = Date()) throws {
        let widgets = try context.fetch(FetchDescriptor<Widget>(sortBy: [SortDescriptor(\.name)]))
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first

        var bankConnectionDescriptor = FetchDescriptor<BankConnection>()
        bankConnectionDescriptor.fetchLimit = 1
        let bankConnection = try context.fetch(bankConnectionDescriptor).first

        try export(
            widgets: widgets,
            transactions: transactions,
            settings: settings,
            bankConnection: bankConnection,
            now: now
        )
    }

    func export(
        widgets: [Widget],
        transactions: [Transaction],
        settings: UserSettings?,
        bankConnection: BankConnection?,
        now: Date = Date()
    ) throws {
        let snapshot = makeSnapshot(
            widgets: widgets,
            transactions: transactions,
            settings: settings,
            bankConnection: bankConnection,
            now: now
        )
        let encodedSnapshot = try makeEncoder().encode(snapshot)
        try write(encodedSnapshot)
    }

    private func makeSnapshot(
        widgets: [Widget],
        transactions: [Transaction],
        settings: UserSettings?,
        bankConnection: BankConnection?,
        now: Date
    ) -> CashFlowWidgetSnapshot {
        let snapshotItems = widgets.map { widget in
            snapshotItem(for: widget, transactions: transactions, now: now)
        }

        return CashFlowWidgetSnapshot(
            generatedAt: now,
            bankStatus: bankConnection?.status ?? .notConnected,
            lastSyncedAt: bankConnection?.lastSyncedAt,
            discretionaryBalance: settings?.discretionaryBalance ?? 0,
            widgets: snapshotItems
        )
    }

    private func snapshotItem(
        for widget: Widget,
        transactions: [Transaction],
        now: Date
    ) -> CashFlowWidgetSnapshotItem {
        let activePeriod = dateInterval(for: widget.period, now: now)
        let spent = transactions
            .filter { transaction in
                // Only count current-period spending that is linked to this widget or matches one of its categories.
                activePeriod.contains(transaction.date)
                    && transaction.amount > 0
                    && transactionBelongsToWidget(transaction, widget: widget)
            }
            .reduce(0) { total, transaction in
                total + transaction.amount
            }
        let remaining = widget.budget - spent

        // Clamp progress so a widget progress bar never draws below 0% or above 100%.
        let progress = widget.budget > 0 ? min(max(spent / widget.budget, 0), 1) : 0

        return CashFlowWidgetSnapshotItem(
            id: widget.id,
            name: widget.name,
            type: widget.type,
            period: widget.period,
            budget: widget.budget,
            spent: spent,
            remaining: remaining,
            progress: progress
        )
    }

    private func transactionBelongsToWidget(_ transaction: Transaction, widget: Widget) -> Bool {
        if transaction.widget?.id == widget.id {
            return true
        }

        return widget.categories.contains { category in
            category.localizedCaseInsensitiveCompare(transaction.category) == .orderedSame
        }
    }

    private func dateInterval(for period: BudgetPeriod, now: Date) -> DateInterval {
        let calendar = Calendar.current
        let component: Calendar.Component = period == .weekly ? .weekOfYear : .month

        if let interval = calendar.dateInterval(of: component, for: now) {
            return interval
        }

        // This fallback is unlikely, but it keeps export safe if the calendar cannot form a normal period.
        return DateInterval(start: now, duration: 0)
    }

    private func write(_ encodedSnapshot: Data) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedWidgetConfiguration.appGroupIdentifier
        ) else {
            throw WidgetSnapshotExportError.missingAppGroup(SharedWidgetConfiguration.appGroupIdentifier)
        }

        let snapshotURL = containerURL.appendingPathComponent(SharedWidgetConfiguration.snapshotFileName)
        try encodedSnapshot.write(to: snapshotURL, options: [.atomic])

        guard let defaults = UserDefaults(suiteName: SharedWidgetConfiguration.appGroupIdentifier) else {
            throw WidgetSnapshotExportError.missingSharedDefaults(SharedWidgetConfiguration.appGroupIdentifier)
        }

        defaults.set(encodedSnapshot, forKey: SharedWidgetConfiguration.snapshotUserDefaultsKey)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

enum WidgetSnapshotExportError: LocalizedError {
    case missingAppGroup(String)
    case missingSharedDefaults(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroup(let identifier):
            return "The shared App Group container is not available for \(identifier)."
        case .missingSharedDefaults(let identifier):
            return "The shared UserDefaults suite is not available for \(identifier)."
        }
    }
}
