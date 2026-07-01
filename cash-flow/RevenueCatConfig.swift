//
//  RevenueCatConfig.swift
//  cash-flow
//
//  Created by Codex on 6/24/26.
//

import Foundation

struct RevenueCatConfig {
    static let appleAPIKeyInfoPlistKey = "RevenueCatAppleAPIKey"
    static let appleAPIKeyEnvironmentKey = "REVENUECAT_APPLE_API_KEY"

    static var appleAPIKey: String {
        configuredValue(
            infoPlistKey: appleAPIKeyInfoPlistKey,
            environmentKey: appleAPIKeyEnvironmentKey
        )
    }

    private static func configuredValue(infoPlistKey: String, environmentKey: String) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           isUsableConfiguredValue(value) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let value = ProcessInfo.processInfo.environment[environmentKey],
           isUsableConfiguredValue(value) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    private static func isUsableConfiguredValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains("$(")
    }
}

