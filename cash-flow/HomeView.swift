//
//  HomeView.swift
//  cash-flow
//
//  Created by Codex on 6/22/26.
//

import Foundation
import SwiftData
import SwiftUI
import WidgetKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var userSettings: [UserSettings]
    @Query private var bankConnections: [BankConnection]

    let session: BackendSession
    let subscriptionManager: SubscriptionManager

    @State private var savingsPercentage = "20"
    @State private var billsReservePercentage = "0"
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var presentedSheet: HomeSheet?

    private var settings: UserSettings? {
        userSettings.first
    }

    private var bankConnection: BankConnection? {
        bankConnections.first
    }

    private var discretionaryBalance: Double {
        settings?.discretionaryBalance ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CashFlowHomeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        balancePanel

                        savingsPanel
                        proSplitPanel
                        widgetGuidePanel

                        Button {
                            saveHomeSettings()
                        } label: {
                            Label("Save Home Settings", systemImage: "checkmark.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CashFlowHomeColors.accent)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CashFlowHomeColors.success)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(CashFlowHomeColors.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .toolbarBackground(CashFlowHomeColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                Button("Sign Out") {
                    subscriptionManager.clearForSignOut()
                    session.signOut()
                }
                .foregroundStyle(CashFlowHomeColors.accent)
            }
        }
        .task {
            loadDraftsFromSavedData()
        }
        .onChange(of: userSettingsSignature) {
            loadDraftsFromSavedData()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .pro:
                ProView(subscriptionManager: subscriptionManager)
            }
        }
    }

    private var balancePanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Discretionary")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CashFlowHomeColors.secondaryText)

                    Spacer()

                    CashFlowStatusPill(
                        subscriptionManager.isPro ? "Pro" : "Free",
                        color: subscriptionManager.isPro ? CashFlowHomeColors.success : CashFlowHomeColors.secondaryText
                    )
                }

                Text(discretionaryBalance, format: .currency(code: "USD"))
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(CashFlowHomeColors.primaryText)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                HStack {
                    Text(bankStatusText)
                    Spacer()
                    Text("\(transactions.count) txns")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CashFlowHomeColors.secondaryText)

                CashFlowMiniWidgetPreview(
                    balance: discretionaryBalance,
                    statusText: bankConnection?.lastSyncedAt == nil ? "Not synced" : "Synced"
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    private var savingsPanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Income Split")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CashFlowHomeColors.primaryText)

                CashFlowPercentageField(
                    title: "Savings Percentage",
                    caption: "Income deposits add the remaining percentage to discretionary balance.",
                    text: $savingsPercentage
                )

                CashFlowAllocationBar(
                    savingsPercentage: draftSavingsPercentage,
                    billsReservePercentage: subscriptionManager.isPro ? draftBillsReservePercentage : 0,
                    isPro: subscriptionManager.isPro
                )
            }
        }
    }

    private var proSplitPanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bills / Reserve")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CashFlowHomeColors.primaryText)

                    Spacer()

                    CashFlowStatusPill(
                        "Pro",
                        color: subscriptionManager.isPro ? CashFlowHomeColors.success : CashFlowHomeColors.accent
                    )
                }

                if subscriptionManager.isPro {
                    CashFlowPercentageField(
                        title: "Bills / Reserve Percentage",
                        caption: "Pro income deposits subtract savings and bills/reserve before updating discretionary balance.",
                        text: $billsReservePercentage
                    )
                } else {
                    Text("Upgrade to split income into savings, bills/reserve, and discretionary spending.")
                        .font(.subheadline)
                        .foregroundStyle(CashFlowHomeColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        presentedSheet = .pro
                    } label: {
                        Label("View Pro", systemImage: "creditcard")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(CashFlowHomeColors.accent)
                }
            }
        }
    }

    private var widgetGuidePanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Widget")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CashFlowHomeColors.primaryText)

                    Spacer()

                    CashFlowStatusPill("Discretionary Number", color: CashFlowHomeColors.accent)
                }

                Text("For v1, Cash Flow is focused on the Discretionary Number widget. Add it manually from the iOS Home Screen widget picker.")
                    .font(.subheadline)
                    .foregroundStyle(CashFlowHomeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bankStatusText: String {
        switch bankConnection?.status ?? .notConnected {
        case .notConnected:
            return "Bank not connected"
        case .connected:
            return "Bank connected"
        case .needsReconnect:
            return "Reconnect needed"
        case .error:
            return "Bank needs attention"
        }
    }

    private var draftSavingsPercentage: Double {
        Double(savingsPercentage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings?.savingsPercentage ?? 0
    }

    private var draftBillsReservePercentage: Double {
        Double(billsReservePercentage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings?.billsReservePercentage ?? 0
    }

    private func loadDraftsFromSavedData() {
        if let settings {
            savingsPercentage = formattedNumber(settings.savingsPercentage)
            billsReservePercentage = formattedNumber(settings.billsReservePercentage)
        }
    }

    private func saveHomeSettings() {
        do {
            let savingsAmount = min(max(try amount(from: savingsPercentage, field: "Savings percentage"), 0), 100)
            let settings = try firstOrCreateSettings()
            let billsReserveAmount = subscriptionManager.isPro
                ? min(max(try amount(from: billsReservePercentage, field: "Bills / Reserve percentage"), 0), 100)
                : settings.billsReservePercentage

            guard IncomeSplit.canSave(
                savingsPercentage: savingsAmount,
                billsReservePercentage: billsReserveAmount,
                subscriptionStatus: subscriptionManager.subscriptionStatus
            ) else {
                throw HomeSettingsError.splitOverLimit
            }

            settings.savingsPercentage = savingsAmount
            settings.subscriptionStatus = subscriptionManager.subscriptionStatus

            if subscriptionManager.isPro {
                settings.billsReservePercentage = billsReserveAmount
            }

            try modelContext.save()

            // Export after saving so WidgetKit reads the same data SwiftData just committed.
            try? WidgetSnapshotExporter().export(context: modelContext)
            WidgetCenter.shared.reloadAllTimelines()

            statusMessage = "Home settings saved."
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func firstOrCreateSettings() throws -> UserSettings {
        if let settings {
            return settings
        }

        let settings = UserSettings()
        modelContext.insert(settings)
        return settings
    }

    private func amount(from text: String, field: String) throws -> Double {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(normalized), amount >= 0 else {
            throw HomeSettingsError.invalidNumber(field)
        }

        return amount
    }

    private func formattedNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }

        return String(format: "%.2f", value)
    }

    private var userSettingsSignature: String {
        settings.map { settings in
            [
                String(settings.savingsPercentage),
                String(settings.billsReservePercentage),
                settings.subscriptionStatus.rawValue
            ].joined(separator: "|")
        } ?? "no-settings"
    }
}

private enum HomeSettingsError: LocalizedError {
    case invalidNumber(String)
    case splitOverLimit

    var errorDescription: String? {
        switch self {
        case .invalidNumber(let field):
            return "\(field) must be a positive number."
        case .splitOverLimit:
            return "Savings and bills/reserve cannot add up to more than 100%."
        }
    }
}

private enum HomeSheet: Identifiable {
    case pro

    var id: String {
        switch self {
        case .pro:
            return "pro"
        }
    }
}

typealias CashFlowHomeColors = CashFlowTheme

#Preview {
    HomeView(session: .previewSignedIn, subscriptionManager: SubscriptionManager())
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
