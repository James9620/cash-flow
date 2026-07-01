//
//  ContentView.swift
//  cash-flow
//
//  Created by James Larkin on 6/12/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Widget.name) private var widgets: [Widget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var userSettings: [UserSettings]
    @Query private var bankConnections: [BankConnection]

    let session: BackendSession
    let subscriptionManager: SubscriptionManager

    var body: some View {
        Group {
            if OnboardingGate.shouldShowOnboarding(settings: userSettings.first) {
                OnboardingView(session: session, subscriptionManager: subscriptionManager)
            } else {
                mainTabs
            }
        }
        .task {
            exportWidgetSnapshot()
        }
        .task(id: session.userID) {
            await subscriptionManager.configureIfPossible(userID: session.userID)
            syncLocalSubscriptionStatus()
        }
        .onChange(of: subscriptionManager.subscriptionStatus) {
            syncLocalSubscriptionStatus()
        }
        .onChange(of: widgetSnapshotSignature) {
            // Re-export when SwiftData changes so widgets can read the latest compact snapshot.
            exportWidgetSnapshot()
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView(session: session, subscriptionManager: subscriptionManager)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            BankConnectionView()
                .tabItem {
                    Label("Bank", systemImage: "building.columns")
                }

            SwiftDataDebugView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
    }

    private var widgetSnapshotSignature: String {
        let widgetSignature = widgets.map { widget in
            [
                widget.id.uuidString,
                widget.name,
                widget.type.rawValue,
                widget.period.rawValue,
                String(widget.budget),
                widget.categories.joined(separator: ",")
            ].joined(separator: "|")
        }
        .joined(separator: ";")

        let transactionSignature = transactions.map { transaction in
            [
                transaction.id.uuidString,
                transaction.plaidID,
                String(transaction.amount),
                String(transaction.date.timeIntervalSince1970),
                transaction.category,
                transaction.widget?.id.uuidString ?? ""
            ].joined(separator: "|")
        }
        .joined(separator: ";")

        let settingsSignature = userSettings.first.map { settings in
            [
                String(settings.savingsPercentage),
                String(settings.billsReservePercentage),
                String(settings.discretionaryBalance),
                String(settings.onboardingComplete),
                settings.subscriptionStatus.rawValue
            ].joined(separator: "|")
        } ?? "no-settings"

        let bankSignature = bankConnections.first.map { connection in
            [
                connection.status.rawValue,
                connection.connectedAt?.ISO8601Format() ?? "",
                connection.lastSyncedAt?.ISO8601Format() ?? "",
                connection.lastErrorMessage ?? ""
            ].joined(separator: "|")
        } ?? "no-bank-connection"

        return [widgetSignature, transactionSignature, settingsSignature, bankSignature].joined(separator: "#")
    }

    private func exportWidgetSnapshot() {
        // This is non-blocking product plumbing; setup problems are documented and should not stop the app UI.
        try? WidgetSnapshotExporter().export(
            widgets: widgets,
            transactions: transactions,
            settings: userSettings.first,
            bankConnection: bankConnections.first
        )
    }

    private func syncLocalSubscriptionStatus() {
        guard let settings = userSettings.first ?? settingsForNonFreeSubscription() else {
            return
        }

        if settings.modelContext == nil {
            modelContext.insert(settings)
        }

        guard settings.subscriptionStatus != subscriptionManager.subscriptionStatus else {
            return
        }

        settings.subscriptionStatus = subscriptionManager.subscriptionStatus
        try? modelContext.save()
    }

    private func settingsForNonFreeSubscription() -> UserSettings? {
        guard subscriptionManager.subscriptionStatus != .free else {
            return nil
        }

        return UserSettings()
    }
}

#Preview {
    ContentView(session: .previewSignedIn, subscriptionManager: SubscriptionManager())
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
