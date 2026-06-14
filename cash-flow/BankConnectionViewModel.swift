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
            // The sample app uses a hard-coded user ID until real authentication is added.
            return try await networkService.createLinkToken(userID: "user-001")
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
            // The backend saves the long-lived access token after this call succeeds.
            try await networkService.exchangePublicToken(publicToken)
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
            // Get the latest transaction JSON from the backend.
            let plaidTransactions = try await networkService.fetchTransactions()

            // Convert each decoded Plaid transaction into the app's SwiftData Transaction model.
            for plaidTransaction in plaidTransactions {
                let plaidID = plaidTransaction.transactionID

                // Check SwiftData for an existing local transaction with the same Plaid ID before inserting.
                let predicate = #Predicate<Transaction> { transaction in
                    transaction.plaidID == plaidID
                }
                var descriptor = FetchDescriptor<Transaction>(predicate: predicate)
                descriptor.fetchLimit = 1

                // Skip this Plaid transaction if it has already been imported.
                let existingTransactions = try context.fetch(descriptor)
                guard existingTransactions.isEmpty else {
                    continue
                }

                // Use Plaid's most specific category when available, and fall back to a simple default.
                let category = plaidTransaction.category?.last ?? "Uncategorized"

                // Build a SwiftData model object from the decoded Plaid transaction.
                let transaction = Transaction(
                    amount: plaidTransaction.amount,
                    date: date(from: plaidTransaction.date),
                    merchant: plaidTransaction.name,
                    category: category,
                    plaidID: plaidTransaction.transactionID
                )

                // Insert the new transaction into the current SwiftData context.
                context.insert(transaction)
            }

            // Save once after all new transactions have been inserted.
            try context.save()
        } catch {
            // Store a readable message so the SwiftUI view can show the failure.
            errorMessage = error.localizedDescription
        }
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
