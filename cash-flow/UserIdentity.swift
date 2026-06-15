//
//  UserIdentity.swift
//  cash-flow
//
//  Created by James Larkin on 6/15/26.
//

import Foundation

enum UserIdentity {
    private static let userDefaultsKey = "cashflow_user_id"

    // Each install gets its own stable ID so the backend can store Plaid tokens per user.
    static var currentUserID: String {
        if let existingID = UserDefaults.standard.string(forKey: userDefaultsKey) {
            return existingID
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: userDefaultsKey)
        return newID
    }
}
