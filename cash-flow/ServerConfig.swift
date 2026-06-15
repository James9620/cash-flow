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

    // Must match API_SECRET_KEY in the server's .env on Railway.
    // This is an interim guard until real user authentication is added.
    static let apiSecretKey = "REPLACE_WITH_YOUR_API_SECRET_KEY"
}
