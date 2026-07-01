//
//  SubscriptionEntitlements.swift
//  cash-flow
//
//  Created by Codex on 6/24/26.
//

import Foundation

enum SubscriptionEntitlements {
    static let proIdentifier = "pro"

    static func status(activeEntitlementIDs: Set<String>) -> SubscriptionStatus {
        activeEntitlementIDs.contains(proIdentifier) ? .pro : .free
    }

    static func status(isProActive: Bool) -> SubscriptionStatus {
        isProActive ? .pro : .free
    }
}

