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
        VStack(alignment: .leading, spacing: 12) {
            Text("Discretionary")
                .font(.caption.weight(.bold))
                .foregroundStyle(CashFlowHomeColors.secondaryText)

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

            Text(subscriptionManager.isPro ? "Cash Flow Pro" : "Free")
                .font(.caption.weight(.bold))
                .foregroundStyle(subscriptionManager.isPro ? CashFlowHomeColors.success : CashFlowHomeColors.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var savingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income Split")
                .font(.headline.weight(.bold))
                .foregroundStyle(CashFlowHomeColors.primaryText)

            TextField("Savings Percentage", text: $savingsPercentage)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Text("Income deposits add the remaining percentage to discretionary balance.")
                .font(.caption)
                .foregroundStyle(CashFlowHomeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var proSplitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bills / Reserve")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CashFlowHomeColors.primaryText)

                Spacer()

                Text("Pro")
                    .font(.caption.weight(.black))
                    .foregroundStyle(subscriptionManager.isPro ? CashFlowHomeColors.success : CashFlowHomeColors.accent)
            }

            if subscriptionManager.isPro {
                TextField("Bills / Reserve Percentage", text: $billsReservePercentage)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Text("Pro income deposits subtract savings and bills/reserve before updating discretionary balance.")
                    .font(.caption)
                    .foregroundStyle(CashFlowHomeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

enum CashFlowHomeColors {
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 15 / 255)
    static let surface = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255)
    static let accent = Color(red: 74 / 255, green: 158 / 255, blue: 255 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 176 / 255)
    static let success = Color(red: 0 / 255, green: 212 / 255, blue: 184 / 255)
    static let error = Color(red: 255 / 255, green: 95 / 255, blue: 116 / 255)
}

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
