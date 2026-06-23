//
//  ServerConfig.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import Foundation

struct ServerConfig {
    // Replace this placeholder with your actual Railway app URL before testing the bank connection flow.
    static let baseURL = "https://cash-flow-production-341d.up.railway.app"

    // Keep this secret out of source control. It is only for local simulator runs
    // when the backend is explicitly set to AUTH_MODE=development-shared-secret.
    static let apiSecretKey = configuredValue(
        infoPlistKey: "CashFlowAPISecretKey",
        environmentKey: "CASH_FLOW_API_SECRET_KEY"
    )

    private static func configuredValue(infoPlistKey: String, environmentKey: String) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        if let value = ProcessInfo.processInfo.environment[environmentKey],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        return ""
    }
}
