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

    @Query(sort: \Widget.name) private var widgets: [Widget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var userSettings: [UserSettings]
    @Query private var bankConnections: [BankConnection]

    let session: BackendSession

    @State private var progressName = "Progress Budget"
    @State private var progressBudget = "500"
    @State private var progressCategories = "Dining, Groceries"
    @State private var progressPeriod: BudgetPeriod = .monthly

    @State private var billName = "Bill Stack"
    @State private var billBudget = "1200"
    @State private var billCategories = "Utilities, Rent"
    @State private var billPeriod: BudgetPeriod = .monthly

    @State private var savingsPercentage = "20"
    @State private var statusMessage: String?
    @State private var errorMessage: String?

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

                        WidgetBudgetEditor(
                            title: "Progress Bar",
                            name: $progressName,
                            budget: $progressBudget,
                            period: $progressPeriod,
                            categories: $progressCategories
                        )

                        WidgetBudgetEditor(
                            title: "Bill Stack",
                            name: $billName,
                            budget: $billBudget,
                            period: $billPeriod,
                            categories: $billCategories
                        )

                        savingsPanel

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
                    session.signOut()
                }
                .foregroundStyle(CashFlowHomeColors.accent)
            }
        }
        .task {
            loadDraftsFromSavedData()
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
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var savingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings")
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
        if let progressWidget = firstWidget(type: .progressBar) {
            progressName = progressWidget.name
            progressBudget = formattedNumber(progressWidget.budget)
            progressPeriod = progressWidget.period
            progressCategories = progressWidget.categories.joined(separator: ", ")
        }

        if let billWidget = firstWidget(type: .billStack) {
            billName = billWidget.name
            billBudget = formattedNumber(billWidget.budget)
            billPeriod = billWidget.period
            billCategories = billWidget.categories.joined(separator: ", ")
        }

        if let settings {
            savingsPercentage = formattedNumber(settings.savingsPercentage)
        }
    }

    private func saveHomeSettings() {
        do {
            let progressBudgetAmount = try amount(from: progressBudget, field: "Progress Bar budget")
            let billBudgetAmount = try amount(from: billBudget, field: "Bill Stack budget")
            let savingsAmount = min(max(try amount(from: savingsPercentage, field: "Savings percentage"), 0), 100)

            _ = ensureSingleWidget(
                type: .progressBar,
                name: progressName,
                budget: progressBudgetAmount,
                period: progressPeriod,
                categories: categories(from: progressCategories)
            )

            _ = ensureSingleWidget(
                type: .billStack,
                name: billName,
                budget: billBudgetAmount,
                period: billPeriod,
                categories: categories(from: billCategories)
            )

            let settings = try firstOrCreateSettings()
            settings.savingsPercentage = savingsAmount

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

    private func firstWidget(type: WidgetType) -> Widget? {
        widgets.first { $0.type == type }
    }

    private func ensureSingleWidget(
        type: WidgetType,
        name: String,
        budget: Double,
        period: BudgetPeriod,
        categories: [String]
    ) -> Widget {
        let matches = widgets.filter { $0.type == type }
        let widget = matches.first ?? Widget(
            name: trimmedName(name, fallback: defaultName(for: type)),
            type: type,
            budget: budget,
            period: period,
            categories: categories
        )

        if widget.modelContext == nil {
            modelContext.insert(widget)
        }

        widget.name = trimmedName(name, fallback: defaultName(for: type))
        widget.budget = budget
        widget.period = period
        widget.categories = categories

        // Keep one local budget per widget type so the widget extension has a single source of truth.
        for duplicate in matches.dropFirst() {
            modelContext.delete(duplicate)
        }

        return widget
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

    private func categories(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func trimmedName(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func defaultName(for type: WidgetType) -> String {
        switch type {
        case .progressBar:
            return "Progress Budget"
        case .billStack:
            return "Bill Stack"
        case .discretionaryNumber:
            return "Discretionary"
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }

        return String(format: "%.2f", value)
    }
}

private struct WidgetBudgetEditor: View {
    let title: String
    @Binding var name: String
    @Binding var budget: String
    @Binding var period: BudgetPeriod
    @Binding var categories: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(CashFlowHomeColors.primaryText)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Budget", text: $budget)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Picker("Period", selection: $period) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue.capitalized)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)

            TextField("Categories", text: $categories)
                .textFieldStyle(.roundedBorder)

            Text("Separate categories with commas.")
                .font(.caption)
                .foregroundStyle(CashFlowHomeColors.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private enum HomeSettingsError: LocalizedError {
    case invalidNumber(String)

    var errorDescription: String? {
        switch self {
        case .invalidNumber(let field):
            return "\(field) must be a positive number."
        }
    }
}

private enum CashFlowHomeColors {
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 15 / 255)
    static let surface = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255)
    static let accent = Color(red: 74 / 255, green: 158 / 255, blue: 255 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 176 / 255)
    static let success = Color(red: 0 / 255, green: 212 / 255, blue: 184 / 255)
    static let error = Color(red: 255 / 255, green: 95 / 255, blue: 116 / 255)
}

#Preview {
    HomeView(session: .previewSignedIn)
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
