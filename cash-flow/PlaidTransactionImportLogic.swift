//
//  PlaidTransactionImportLogic.swift
//  cash-flow
//
//  Created by Codex on 6/18/26.
//

import Foundation

// Plain values the app should save for a Plaid transaction.
// Keeping this separate from SwiftData makes the import rules easy to test later.
struct PlaidImportedTransactionValues: Equatable {
    let amount: Double
    let date: Date
    let merchant: String
    let category: String
    let plaidID: String
}

// Plain values the app should save when a Plaid transaction is income.
struct PlaidImportedIncomeEventValues: Equatable {
    let amount: Double
    let date: Date
    let depositedAt: Date
    let plaidID: String
}

// Describes what should happen to the local IncomeEvent for one Plaid transaction.
enum PlaidIncomeEventImportPlan: Equatable {
    case noChange
    case removeExisting(balanceDelta: Double)
    case upsert(values: PlaidImportedIncomeEventValues, balanceDelta: Double)
}

struct PlaidTransactionImportLogic {
    static func transactionValues(from plaidTransaction: PlaidTransaction) -> PlaidImportedTransactionValues {
        PlaidImportedTransactionValues(
            amount: plaidTransaction.amount,
            date: date(from: plaidTransaction.date),
            merchant: merchantName(from: plaidTransaction),
            category: category(from: plaidTransaction),
            plaidID: plaidTransaction.transactionID
        )
    }

    static func incomeEventPlan(
        for plaidTransaction: PlaidTransaction,
        existingIncomeAmount: Double?,
        savingsPercentage: Double
    ) -> PlaidIncomeEventImportPlan {
        guard isDirectDeposit(plaidTransaction) else {
            if let existingIncomeAmount {
                return .removeExisting(
                    balanceDelta: balanceDeltaForRemovedIncome(
                        amount: existingIncomeAmount,
                        savingsPercentage: savingsPercentage
                    )
                )
            }

            return .noChange
        }

        let values = incomeEventValues(from: plaidTransaction)
        let newDiscretionaryAmount = discretionaryAmount(
            fromIncome: values.amount,
            savingsPercentage: savingsPercentage
        )

        if let existingIncomeAmount {
            // Only return the difference so a corrected paycheck is not counted twice.
            let oldDiscretionaryAmount = discretionaryAmount(
                fromIncome: existingIncomeAmount,
                savingsPercentage: savingsPercentage
            )

            return .upsert(
                values: values,
                balanceDelta: newDiscretionaryAmount - oldDiscretionaryAmount
            )
        }

        return .upsert(values: values, balanceDelta: newDiscretionaryAmount)
    }

    static func balanceDeltaForRemovedIncome(amount: Double, savingsPercentage: Double) -> Double {
        -discretionaryAmount(fromIncome: amount, savingsPercentage: savingsPercentage)
    }

    static func discretionaryAmount(fromIncome incomeAmount: Double, savingsPercentage: Double) -> Double {
        // Clamp the savings percentage so a bad setting cannot create negative or over-100% spending money.
        let clampedSavingsPercentage = min(max(savingsPercentage, 0), 100)
        return incomeAmount * ((100 - clampedSavingsPercentage) / 100)
    }

    static func isDirectDeposit(_ plaidTransaction: PlaidTransaction) -> Bool {
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

    private static func incomeEventValues(from plaidTransaction: PlaidTransaction) -> PlaidImportedIncomeEventValues {
        let depositedAt = date(from: plaidTransaction.date)

        return PlaidImportedIncomeEventValues(
            amount: abs(plaidTransaction.amount),
            date: depositedAt,
            depositedAt: depositedAt,
            plaidID: plaidTransaction.transactionID
        )
    }

    private static func merchantName(from plaidTransaction: PlaidTransaction) -> String {
        // Prefer Plaid's cleaned merchant name when available, then fall back to the raw transaction name.
        let merchantName = plaidTransaction.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let merchantName, !merchantName.isEmpty {
            return merchantName
        }

        return plaidTransaction.name
    }

    private static func category(from plaidTransaction: PlaidTransaction) -> String {
        // Use Plaid's most specific legacy category when available, then fall back to newer category labels.
        plaidTransaction.category?.last
            ?? plaidTransaction.personalFinanceCategory?.detailed
            ?? plaidTransaction.personalFinanceCategory?.primary
            ?? "Uncategorized"
    }

    private static func date(from plaidDate: String) -> Date {
        // Plaid transaction dates are plain calendar dates in yyyy-MM-dd format.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        // If parsing ever fails, use the current date so the import can still complete.
        return formatter.date(from: plaidDate) ?? Date()
    }
}
