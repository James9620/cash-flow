//
//  PlaidTransaction.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import Foundation

// This struct is only for decoding transaction JSON from your server.
// It is separate from the SwiftData Transaction model, which is the app's saved local database object.
struct PlaidTransaction: Codable {
    // Plaid's stable transaction identifier, used locally to avoid importing the same transaction twice.
    let transactionID: String

    // The merchant or transaction name returned by Plaid.
    let name: String

    // Plaid sometimes provides a cleaner merchant name separately from the raw transaction name.
    let merchantName: String?

    // Plaid's amount value for the transaction.
    let amount: Double

    // Plaid returns transaction dates as strings like "2026-06-14".
    let date: String

    // Plaid may return a category path, such as ["Food and Drink", "Restaurants"].
    let category: [String]?

    // Plaid's newer category object can help identify payroll or income deposits.
    let personalFinanceCategory: PlaidPersonalFinanceCategory?

    enum CodingKeys: String, CodingKey {
        // The JSON key is snake_case, while the Swift property uses the usual camelCase style.
        case transactionID = "transaction_id"
        case name
        case merchantName = "merchant_name"
        case amount
        case date
        case category
        case personalFinanceCategory = "personal_finance_category"
    }
}

struct PlaidPersonalFinanceCategory: Codable {
    // Broad category name, such as INCOME.
    let primary: String?

    // More specific category name, such as INCOME_WAGES.
    let detailed: String?
}

struct PlaidRemovedTransaction: Codable {
    // Plaid sends removed transaction IDs separately from full transaction objects.
    let transactionID: String

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
    }
}

struct PlaidTransactionSync: Codable {
    // New transactions Plaid has not sent to this server before.
    let added: [PlaidTransaction]

    // Existing transactions whose amount, merchant, date, or category changed.
    let modified: [PlaidTransaction]

    // Transactions Plaid says should be removed from local storage.
    let removed: [PlaidRemovedTransaction]

    // Plaid's status for the current transaction pull, useful for debugging early sandbox syncs.
    let transactionsUpdateStatus: String?

    enum CodingKeys: String, CodingKey {
        case added
        case modified
        case removed
        case transactionsUpdateStatus = "transactions_update_status"
    }
}
