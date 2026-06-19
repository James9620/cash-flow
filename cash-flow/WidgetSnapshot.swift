//
//  WidgetSnapshot.swift
//  cash-flow
//
//  Created by Codex on 6/18/26.
//

import Foundation

struct SharedWidgetConfiguration {
    // This must match the App Group entitlement on both the app and widget targets.
    static let appGroupIdentifier = "group.com.jameslarkin.cashflow.widgets"

    // The future widget extension can read this file from the shared App Group container.
    static let snapshotFileName = "cash-flow-widget-snapshot.json"

    // The same encoded snapshot is also stored in shared UserDefaults for simple widget reads.
    static let snapshotUserDefaultsKey = "cashFlowWidgetSnapshot"
}

struct CashFlowWidgetSnapshot: Codable {
    // The write time helps widgets know whether the snapshot is fresh enough to display.
    let generatedAt: Date

    // This mirrors the explicit bank state so widgets do not infer connection from transaction counts.
    let bankStatus: BankConnectionStatus

    // Widgets can show the last successful import time when space allows.
    let lastSyncedAt: Date?

    // This is the app's saved discretionary amount after income and savings math.
    let discretionaryBalance: Double

    // Each item gives a widget enough budget math to draw without opening SwiftData.
    let widgets: [CashFlowWidgetSnapshotItem]
}

struct CashFlowWidgetSnapshotItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: WidgetType
    let period: BudgetPeriod
    let budget: Double
    let spent: Double
    let remaining: Double
    let progress: Double
}
