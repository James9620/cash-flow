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

    // Plaid's amount value for the transaction.
    let amount: Double

    // Plaid returns transaction dates as strings like "2026-06-14".
    let date: String

    // Plaid may return a category path, such as ["Food and Drink", "Restaurants"].
    let category: [String]?

    enum CodingKeys: String, CodingKey {
        // The JSON key is snake_case, while the Swift property uses the usual camelCase style.
        case transactionID = "transaction_id"
        case name
        case amount
        case date
        case category
    }
}
