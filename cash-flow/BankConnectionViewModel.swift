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
    func connectBank() async -> String? {
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
        } catch {
            // If the exchange fails, there is no saved access token to fetch transactions with.
            errorMessage = error.localizedDescription
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
            try context.save()
        } catch {
            // Store a readable message so the SwiftUI view can show the failure.
            errorMessage = error.localizedDescription
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
        }
    }

    private func upsertTransaction(_ plaidTransaction: PlaidTransaction, context: ModelContext) throws {
        if let existingTransaction = try transaction(with: plaidTransaction.transactionID, context: context) {
            // Plaid can correct pending transactions later, so keep the local copy in sync.
            existingTransaction.amount = plaidTransaction.amount
            existingTransaction.date = date(from: plaidTransaction.date)
            existingTransaction.merchant = merchantName(from: plaidTransaction)
            existingTransaction.category = category(from: plaidTransaction)
        } else {
            // Insert the Plaid transaction when this is the first time the app has seen its ID.
            let transaction = Transaction(
                amount: plaidTransaction.amount,
                date: date(from: plaidTransaction.date),
                merchant: merchantName(from: plaidTransaction),
                category: category(from: plaidTransaction),
                plaidID: plaidTransaction.transactionID
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
            settings.discretionaryBalance -= discretionaryAmount(fromIncome: incomeEvent.amount, settings: settings)
            context.delete(incomeEvent)
        }
    }

    private func upsertIncomeEvent(from plaidTransaction: PlaidTransaction, context: ModelContext) throws {
        let existingIncomeEvent = try incomeEvent(with: plaidTransaction.transactionID, context: context)

        guard isDirectDeposit(plaidTransaction) else {
            // If a corrected Plaid transaction is no longer income, undo the earlier income event.
            if let existingIncomeEvent {
                let settings = try userSettings(context: context)
                settings.discretionaryBalance -= discretionaryAmount(fromIncome: existingIncomeEvent.amount, settings: settings)
                context.delete(existingIncomeEvent)
            }

            return
        }

        let settings = try userSettings(context: context)
        let incomeAmount = abs(plaidTransaction.amount)
        let depositedAt = date(from: plaidTransaction.date)
        let newDiscretionaryAmount = discretionaryAmount(fromIncome: incomeAmount, settings: settings)

        if let existingIncomeEvent {
            // Adjust the balance by the difference so a Plaid correction does not double-count the deposit.
            let oldDiscretionaryAmount = discretionaryAmount(fromIncome: existingIncomeEvent.amount, settings: settings)
            existingIncomeEvent.amount = incomeAmount
            existingIncomeEvent.date = depositedAt
            existingIncomeEvent.depositedAt = depositedAt
            settings.discretionaryBalance += newDiscretionaryAmount - oldDiscretionaryAmount
        } else {
            let incomeEvent = IncomeEvent(
                amount: incomeAmount,
                date: depositedAt,
                depositedAt: depositedAt,
                plaidID: plaidTransaction.transactionID
            )

            context.insert(incomeEvent)
            settings.discretionaryBalance += newDiscretionaryAmount
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

    private func merchantName(from plaidTransaction: PlaidTransaction) -> String {
        // Prefer Plaid's cleaned merchant name when available, then fall back to the raw transaction name.
        let merchantName = plaidTransaction.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let merchantName, !merchantName.isEmpty {
            return merchantName
        }

        return plaidTransaction.name
    }

    private func category(from plaidTransaction: PlaidTransaction) -> String {
        // Use Plaid's most specific legacy category when available, then fall back to newer category labels.
        plaidTransaction.category?.last
            ?? plaidTransaction.personalFinanceCategory?.detailed
            ?? plaidTransaction.personalFinanceCategory?.primary
            ?? "Uncategorized"
    }

    private func isDirectDeposit(_ plaidTransaction: PlaidTransaction) -> Bool {
        // Plaid records incoming money as a negative amount, while purchases are usually positive.
        guard plaidTransaction.amount < 0 else {
            return false
        }

        let searchableText = [
            plaidTransaction.name,
            plaidTransaction.category?.joined(separator: " "),
            plaidTransaction.personalFinanceCategory?.primary,
            plaidTransaction.personalFinanceCategory?.detailed
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        let incomeKeywords = [
            "direct deposit",
            "income",
            "income_wages",
            "payroll",
            "salary",
            "wage"
        ]

        return incomeKeywords.contains { searchableText.contains($0) }
    }

    private func discretionaryAmount(fromIncome incomeAmount: Double, settings: UserSettings) -> Double {
        // Clamp the savings percentage so a bad setting cannot produce a negative or over-100% balance.
        let savingsPercentage = min(max(settings.savingsPercentage, 0), 100)
        return incomeAmount * ((100 - savingsPercentage) / 100)
    }

    private func date(from plaidDate: String) -> Date {
        // Plaid transaction dates are plain calendar dates in yyyy-MM-dd format.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        // If parsing ever fails, use the current date so the import can still complete.
        return formatter.date(from: plaidDate) ?? Date()
    }
}
