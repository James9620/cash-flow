//
//  BankConnectionViewModel.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import Foundation
import Observation
import SwiftData

@Observable
final class BankConnectionViewModel {
    // The view model owns the network layer that talks to your Railway backend.
    var networkService: NetworkService

    // The view watches this value to show or hide a ProgressView during network work.
    var isLoading = false

    // The view shows this message when a backend request or SwiftData save fails.
    var errorMessage: String?

    init(networkService: NetworkService = NetworkService()) {
        self.networkService = networkService
    }

    @MainActor
    func connectBank(context: ModelContext) async -> String? {
        // Start a loading state before asking the backend for a Plaid Link token.
        isLoading = true
        errorMessage = nil

        defer {
            // Always stop the spinner after this request finishes.
            isLoading = false
        }

        do {
            // Each install gets its own user ID so the backend can store tokens separately.
            return try await networkService.createLinkToken(userID: UserIdentity.currentUserID)
        } catch {
            // Store a readable message so the SwiftUI view can show the failure.
            errorMessage = error.localizedDescription
            markBankFailureIfPossible(error, context: context)
            return nil
        }
    }

    @MainActor
    func handlePublicToken(_ publicToken: String, context: ModelContext) async {
        // Start a loading state while the backend exchanges the Plaid public token.
        isLoading = true
        errorMessage = nil

        do {
            // The backend saves the long-lived access token under this install's user ID.
            try await networkService.exchangePublicToken(
                publicToken,
                userID: UserIdentity.currentUserID
            )

            try markBankConnected(context: context)
            try saveAndExportWidgetSnapshot(context: context)
        } catch {
            // If the exchange fails, there is no saved access token to fetch transactions with.
            errorMessage = error.localizedDescription
            markBankFailureIfPossible(error, context: context)
            isLoading = false
            return
        }

        // End the exchange loading state before the transaction load starts its own network work.
        isLoading = false

        // After a successful exchange, immediately fetch and import transactions.
        await loadTransactions(context: context)
    }

    @MainActor
    func loadTransactions(context: ModelContext) async {
        // Start a loading state while the app downloads and saves transactions.
        isLoading = true
        errorMessage = nil

        defer {
            // Always stop the spinner after fetching, importing, and saving finishes.
            isLoading = false
        }

        do {
            // Get the latest transaction JSON from the backend for this install's user ID.
            let transactionSync = try await networkService.fetchTransactions(
                userID: UserIdentity.currentUserID
            )

            // Remove local records Plaid says are no longer valid.
            for removedTransaction in transactionSync.removed {
                try removeTransaction(removedTransaction, context: context)
            }

            // Add brand-new transactions and update transactions Plaid has corrected since the last sync.
            for plaidTransaction in transactionSync.added + transactionSync.modified {
                try upsertTransaction(plaidTransaction, context: context)
            }

            // Save once after all additions, updates, removals, and income calculations are complete.
            try markBankSyncSucceeded(context: context)
            try saveAndExportWidgetSnapshot(context: context)
        } catch {
            // Store a readable message so the SwiftUI view can show the failure.
            errorMessage = error.localizedDescription
            markBankFailureIfPossible(error, context: context)
        }
    }

    @MainActor
    func loadTransactionsIfRefreshNeeded(context: ModelContext) async {
        do {
            // The server flips this flag when Plaid sends a transaction webhook for this user.
            let refreshNeeded = try await networkService.transactionsRefreshNeeded(
                userID: UserIdentity.currentUserID
            )

            guard refreshNeeded else {
                return
            }

            await loadTransactions(context: context)
        } catch {
            // A failed background status check should be visible, but it should not erase saved transactions.
            errorMessage = error.localizedDescription
            markBankFailureIfPossible(error, context: context)
        }
    }

    @MainActor
    func resetLocalBankData(context: ModelContext) {
        do {
            // Remove imported bank rows from this simulator so the app can show the connect button again.
            try deleteAllTransactions(context: context)
            try deleteAllIncomeEvents(context: context)

            // Keep the user's settings row, but clear money that came from the removed bank data.
            if let settings = try existingUserSettings(context: context) {
                settings.discretionaryBalance = 0
            }

            try markBankNotConnected(context: context)
            try saveAndExportWidgetSnapshot(context: context)
            errorMessage = nil
        } catch {
            // Show reset problems in the same place as network and import errors.
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markBankConnected(context: ModelContext) throws {
        let connection = try bankConnection(context: context)
        let now = Date()

        connection.status = .connected
        connection.connectedAt = now
        connection.lastErrorMessage = nil
    }

    @MainActor
    private func markBankSyncSucceeded(context: ModelContext) throws {
        let connection = try bankConnection(context: context)
        let now = Date()

        connection.status = .connected
        connection.lastSyncedAt = now
        connection.lastErrorMessage = nil

        if connection.connectedAt == nil {
            // Older local installs may sync before this status row existed, so fill this date gently.
            connection.connectedAt = now
        }
    }

    @MainActor
    private func markBankNotConnected(context: ModelContext) throws {
        let connection = try bankConnection(context: context)

        connection.status = .notConnected
        connection.connectedAt = nil
        connection.lastSyncedAt = nil
        connection.lastErrorMessage = nil
    }

    @MainActor
    private func markBankFailureIfPossible(_ error: Error, context: ModelContext) {
        do {
            let connection = try bankConnection(context: context)

            connection.status = status(for: error)
            connection.lastErrorMessage = error.localizedDescription
            try saveAndExportWidgetSnapshot(context: context)
        } catch {
            // If saving the recovery state fails, keep the original bank error visible to the user.
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }

    @MainActor
    private func bankConnection(context: ModelContext) throws -> BankConnection {
        var descriptor = FetchDescriptor<BankConnection>()
        descriptor.fetchLimit = 1

        if let existingConnection = try context.fetch(descriptor).first {
            return existingConnection
        }

        // Create one status row on demand so the app no longer uses transaction count as connection state.
        let connection = BankConnection()
        context.insert(connection)
        return connection
    }

    @MainActor
    private func saveAndExportWidgetSnapshot(context: ModelContext) throws {
        try context.save()

        // Widget export is best-effort here; bank sync should not fail just because the App Group is not enabled yet.
        try? WidgetSnapshotExporter().export(context: context)
    }

    private func status(for error: Error) -> BankConnectionStatus {
        let message = error.localizedDescription.lowercased()
        let reconnectKeywords = [
            "access token",
            "credentials",
            "expired",
            "item_login_required",
            "login_required",
            "reauth",
            "reconnect"
        ]

        if reconnectKeywords.contains(where: { message.contains($0) }) {
            return .needsReconnect
        }

        return .error
    }

    private func upsertTransaction(_ plaidTransaction: PlaidTransaction, context: ModelContext) throws {
        let importedValues = PlaidTransactionImportLogic.transactionValues(from: plaidTransaction)

        if let existingTransaction = try transaction(with: plaidTransaction.transactionID, context: context) {
            // Plaid can correct pending transactions later, so keep the local copy in sync.
            existingTransaction.amount = importedValues.amount
            existingTransaction.date = importedValues.date
            existingTransaction.merchant = importedValues.merchant
            existingTransaction.category = importedValues.category
        } else {
            // Insert the Plaid transaction when this is the first time the app has seen its ID.
            let transaction = Transaction(
                amount: importedValues.amount,
                date: importedValues.date,
                merchant: importedValues.merchant,
                category: importedValues.category,
                plaidID: importedValues.plaidID
            )

            context.insert(transaction)
        }

        try upsertIncomeEvent(from: plaidTransaction, context: context)
    }

    private func removeTransaction(_ removedTransaction: PlaidRemovedTransaction, context: ModelContext) throws {
        if let transaction = try transaction(with: removedTransaction.transactionID, context: context) {
            context.delete(transaction)
        }

        if let incomeEvent = try incomeEvent(with: removedTransaction.transactionID, context: context) {
            // If Plaid removes a paycheck transaction, subtract the discretionary portion that was previously added.
            let settings = try userSettings(context: context)
            settings.discretionaryBalance += PlaidTransactionImportLogic.balanceDeltaForRemovedIncome(
                amount: incomeEvent.amount,
                savingsPercentage: settings.savingsPercentage,
                existingDiscretionaryAmount: incomeEvent.discretionaryAmount,
                billsReservePercentage: settings.billsReservePercentage,
                subscriptionStatus: settings.subscriptionStatus
            )
            context.delete(incomeEvent)
        }
    }

    private func upsertIncomeEvent(from plaidTransaction: PlaidTransaction, context: ModelContext) throws {
        let existingIncomeEvent = try incomeEvent(with: plaidTransaction.transactionID, context: context)

        // If this is not income and there is no previous income event, avoid creating a settings row just to do nothing.
        guard PlaidTransactionImportLogic.isDirectDeposit(plaidTransaction) || existingIncomeEvent != nil else {
            return
        }

        let settings = try userSettings(context: context)

        let plan = PlaidTransactionImportLogic.incomeEventPlan(
            for: plaidTransaction,
            existingIncomeAmount: existingIncomeEvent?.amount,
            existingDiscretionaryAmount: existingIncomeEvent?.discretionaryAmount,
            savingsPercentage: settings.savingsPercentage,
            billsReservePercentage: settings.billsReservePercentage,
            subscriptionStatus: settings.subscriptionStatus
        )

        switch plan {
        case .noChange:
            return

        case let .removeExisting(balanceDelta):
            // If a corrected Plaid transaction is no longer income, undo the earlier income event.
            if let existingIncomeEvent {
                settings.discretionaryBalance += balanceDelta
                context.delete(existingIncomeEvent)
            }

        case let .upsert(values, balanceDelta):
            if let existingIncomeEvent {
                existingIncomeEvent.amount = values.amount
                existingIncomeEvent.discretionaryAmount = values.discretionaryAmount
                existingIncomeEvent.date = values.date
                existingIncomeEvent.depositedAt = values.depositedAt
                settings.discretionaryBalance += balanceDelta
                return
            }

            let incomeEvent = IncomeEvent(
                amount: values.amount,
                discretionaryAmount: values.discretionaryAmount,
                date: values.date,
                depositedAt: values.depositedAt,
                plaidID: values.plaidID
            )

            context.insert(incomeEvent)
            settings.discretionaryBalance += balanceDelta
        }
    }

    private func transaction(with plaidID: String, context: ModelContext) throws -> Transaction? {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.plaidID == plaidID
        }
        var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func incomeEvent(with plaidID: String, context: ModelContext) throws -> IncomeEvent? {
        let predicate = #Predicate<IncomeEvent> { incomeEvent in
            incomeEvent.plaidID == plaidID
        }
        var descriptor = FetchDescriptor<IncomeEvent>(predicate: predicate)
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func userSettings(context: ModelContext) throws -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1

        if let existingSettings = try context.fetch(descriptor).first {
            return existingSettings
        }

        // Create default settings on demand so direct deposits have a place to update the balance.
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }

    private func existingUserSettings(context: ModelContext) throws -> UserSettings? {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    private func deleteAllTransactions(context: ModelContext) throws {
        // Fetch first, then delete each row. This is easy to understand and safe for the small dev database.
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        for transaction in transactions {
            context.delete(transaction)
        }
    }

    private func deleteAllIncomeEvents(context: ModelContext) throws {
        // Income events created from Plaid deposits should be reset with the imported transactions.
        let descriptor = FetchDescriptor<IncomeEvent>()
        let incomeEvents = try context.fetch(descriptor)

        for incomeEvent in incomeEvents {
            context.delete(incomeEvent)
        }
    }

}
