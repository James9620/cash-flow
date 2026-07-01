//
//  IncomeSplit.swift
//  cash-flow
//
//  Created by Codex on 6/24/26.
//

import Foundation

struct IncomeSplit: Equatable {
    let savingsPercentage: Double
    let billsReservePercentage: Double
    let subscriptionStatus: SubscriptionStatus

    var effectiveSavingsPercentage: Double {
        Self.clampedPercentage(savingsPercentage)
    }

    var effectiveBillsReservePercentage: Double {
        guard subscriptionStatus == .pro else {
            return 0
        }

        return Self.clampedPercentage(billsReservePercentage)
    }

    var totalAllocatedPercentage: Double {
        min(effectiveSavingsPercentage + effectiveBillsReservePercentage, 100)
    }

    var discretionaryPercentage: Double {
        max(100 - totalAllocatedPercentage, 0)
    }

    func discretionaryAmount(fromIncome incomeAmount: Double) -> Double {
        incomeAmount * (discretionaryPercentage / 100)
    }

    static func canSave(
        savingsPercentage: Double,
        billsReservePercentage: Double,
        subscriptionStatus: SubscriptionStatus
    ) -> Bool {
        guard subscriptionStatus == .pro else {
            return true
        }

        // Pro users can split income between savings and bills/reserve, but those buckets cannot exceed the whole paycheck.
        return savingsPercentage + billsReservePercentage <= 100
    }

    private static func clampedPercentage(_ percentage: Double) -> Double {
        min(max(percentage, 0), 100)
    }
}

