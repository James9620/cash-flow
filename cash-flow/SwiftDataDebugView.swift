//
//  SwiftDataDebugView.swift
//  cash-flow
//
//  Created by James Larkin on 6/13/26.
//

import SwiftUI
import SwiftData

struct SwiftDataDebugView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Widget.name) private var widgets: [Widget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \IncomeEvent.depositedAt, order: .reverse) private var incomeEvents: [IncomeEvent]
    @Query private var userSettings: [UserSettings]
    @Query private var bankConnections: [BankConnection]

    // This view model gives the debug screen access to the same reset path used by bank recovery work.
    @State private var bankViewModel = BankConnectionViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        createSampleWidget()
                    } label: {
                        Label("Create Sample Widget", systemImage: "plus.square")
                    }

                    Button {
                        createSampleTransaction()
                    } label: {
                        Label("Create Transaction for Widget", systemImage: "creditcard")
                    }
                    .disabled(widgets.isEmpty)
                }

                Section("Stored Widgets") {
                    if widgets.isEmpty {
                        ContentUnavailableView(
                            "No Widgets",
                            systemImage: "tray",
                            description: Text("Create a sample widget to test SwiftData persistence.")
                        )
                    } else {
                        ForEach(widgets) { widget in
                            WidgetDebugRow(widget: widget)
                        }
                    }
                }

                Section("Imported Transactions") {
                    if allTransactions.isEmpty {
                        ContentUnavailableView("No transactions imported yet.", systemImage: "creditcard")
                    } else {
                        ForEach(allTransactions) { transaction in
                            ImportedTransactionDebugRow(transaction: transaction)
                        }
                    }
                }

                Section("Income & Balance") {
                    if let settings = userSettings.first {
                        HStack {
                            Text("Discretionary Balance")
                            Spacer()
                            Text(settings.discretionaryBalance, format: .currency(code: "USD"))
                        }
                    } else {
                        Text("No user settings saved yet.")
                            .foregroundStyle(.secondary)
                    }

                    if incomeEvents.isEmpty {
                        Text("No direct deposits detected yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(incomeEvents) { incomeEvent in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Direct Deposit")
                                    Text(incomeEvent.depositedAt, format: .dateTime.year().month().day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(incomeEvent.amount, format: .currency(code: "USD"))
                            }
                        }
                    }
                }

                Section("Bank Connection Debug") {
                    if let bankConnection = bankConnections.first {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(bankConnection.status.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        if let connectedAt = bankConnection.connectedAt {
                            HStack {
                                Text("Connected")
                                Spacer()
                                Text(connectedAt, format: .dateTime.year().month().day().hour().minute())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let lastSyncedAt = bankConnection.lastSyncedAt {
                            HStack {
                                Text("Last Sync")
                                Spacer()
                                Text(lastSyncedAt, format: .dateTime.year().month().day().hour().minute())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let lastErrorMessage = bankConnection.lastErrorMessage {
                            Text(lastErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("No bank connection status saved yet.")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        // Keep this reset in Debug so normal users see recovery/reconnect actions instead.
                        bankViewModel.resetLocalBankData(context: modelContext)
                    } label: {
                        Label("Reset Local Bank Data", systemImage: "trash")
                    }

                    if let errorMessage = bankViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("SwiftData Debug")
        }
    }

    private func createSampleWidget() {
        let widget = Widget(
            name: "Test Widget \(widgets.count + 1)",
            type: .progressBar,
            budget: 250,
            period: .monthly,
            categories: ["Groceries", "Dining"]
        )

        modelContext.insert(widget)
        saveContext()
    }

    private func createSampleTransaction() {
        let widget = widgets.first ?? Widget(
            name: "Test Widget 1",
            type: .progressBar,
            budget: 250,
            period: .monthly,
            categories: ["Groceries", "Dining"]
        )

        if widget.modelContext == nil {
            modelContext.insert(widget)
        }

        let transaction = Transaction(
            amount: 12.34,
            date: Date(),
            merchant: "Debug Coffee",
            category: "Dining",
            plaidID: "debug-\(UUID().uuidString)",
            widget: widget
        )

        modelContext.insert(transaction)
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()

            // Keep the widget-facing snapshot current when debug sample data changes.
            try? WidgetSnapshotExporter().export(context: modelContext)
        } catch {
            assertionFailure("Failed to save SwiftData debug data: \(error)")
        }
    }
}

private struct WidgetDebugRow: View {
    let widget: Widget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(widget.name)
                .font(.headline)

            Text("\(widget.type.rawValue) - \(widget.period.rawValue) - Budget: \(widget.budget, format: .currency(code: "USD"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if widget.transactions.isEmpty {
                Text("No transactions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(widget.transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(transaction.merchant)
                            Text(transaction.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transaction.amount, format: .currency(code: "USD"))
                            .font(.subheadline)
                    }
                    .padding(.leading)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ImportedTransactionDebugRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.headline)

                Text(transaction.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Use SwiftUI's built-in date formatting so the debug view follows the user's locale.
                Text(transaction.date, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SwiftDataDebugView()
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
