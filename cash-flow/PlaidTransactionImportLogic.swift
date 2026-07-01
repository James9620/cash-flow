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
    let discretionaryAmount: Double
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
        existingDiscretionaryAmount: Double? = nil,
        savingsPercentage: Double,
        billsReservePercentage: Double = 0,
        subscriptionStatus: SubscriptionStatus = .free
    ) -> PlaidIncomeEventImportPlan {
        guard isDirectDeposit(plaidTransaction) else {
            if let existingIncomeAmount {
                return .removeExisting(
                    balanceDelta: balanceDeltaForRemovedIncome(
                        amount: existingIncomeAmount,
                        savingsPercentage: savingsPercentage,
                        existingDiscretionaryAmount: existingDiscretionaryAmount,
                        billsReservePercentage: billsReservePercentage,
                        subscriptionStatus: subscriptionStatus
                    )
                )
            }

            return .noChange
        }

        let incomeAmount = abs(plaidTransaction.amount)
        let newDiscretionaryAmount = adjustedDiscretionaryAmount(
            fromIncome: incomeAmount,
            existingIncomeAmount: existingIncomeAmount,
            existingDiscretionaryAmount: existingDiscretionaryAmount,
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage,
            subscriptionStatus: subscriptionStatus
        )
        let values = incomeEventValues(
            from: plaidTransaction,
            incomeAmount: incomeAmount,
            discretionaryAmount: newDiscretionaryAmount
        )

        if let existingIncomeAmount {
            // Only return the difference so a corrected paycheck is not counted twice.
            let oldDiscretionaryAmount = existingDiscretionaryAmount
                ?? discretionaryAmount(
                    fromIncome: existingIncomeAmount,
                    savingsPercentage: savingsPercentage,
                    billsReservePercentage: billsReservePercentage,
                    subscriptionStatus: subscriptionStatus
                )

            return .upsert(
                values: values,
                balanceDelta: newDiscretionaryAmount - oldDiscretionaryAmount
            )
        }

        return .upsert(values: values, balanceDelta: newDiscretionaryAmount)
    }

    static func balanceDeltaForRemovedIncome(
        amount: Double,
        savingsPercentage: Double,
        existingDiscretionaryAmount: Double? = nil,
        billsReservePercentage: Double = 0,
        subscriptionStatus: SubscriptionStatus = .free
    ) -> Double {
        -(existingDiscretionaryAmount ?? discretionaryAmount(
            fromIncome: amount,
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage,
            subscriptionStatus: subscriptionStatus
        ))
    }

    static func discretionaryAmount(
        fromIncome incomeAmount: Double,
        savingsPercentage: Double,
        billsReservePercentage: Double = 0,
        subscriptionStatus: SubscriptionStatus = .free
    ) -> Double {
        IncomeSplit(
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage,
            subscriptionStatus: subscriptionStatus
        )
        .discretionaryAmount(fromIncome: incomeAmount)
    }

    private static func adjustedDiscretionaryAmount(
        fromIncome incomeAmount: Double,
        existingIncomeAmount: Double?,
        existingDiscretionaryAmount: Double?,
        savingsPercentage: Double,
        billsReservePercentage: Double,
        subscriptionStatus: SubscriptionStatus
    ) -> Double {
        guard let existingIncomeAmount,
              let existingDiscretionaryAmount,
              existingIncomeAmount > 0 else {
            return discretionaryAmount(
                fromIncome: incomeAmount,
                savingsPercentage: savingsPercentage,
                billsReservePercentage: billsReservePercentage,
                subscriptionStatus: subscriptionStatus
            )
        }

        // Existing income events keep their original split ratio so changing Pro settings does not rewrite history.
        let historicalDiscretionaryRate = min(max(existingDiscretionaryAmount / existingIncomeAmount, 0), 1)
        return incomeAmount * historicalDiscretionaryRate
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

    private static func incomeEventValues(
        from plaidTransaction: PlaidTransaction,
        incomeAmount: Double,
        discretionaryAmount: Double
    ) -> PlaidImportedIncomeEventValues {
        let depositedAt = date(from: plaidTransaction.date)

        return PlaidImportedIncomeEventValues(
            amount: incomeAmount,
            discretionaryAmount: discretionaryAmount,
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
