//
//  NetworkService.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import Foundation

final class NetworkService {
    // URLSession does the actual HTTP work for each call to the backend.
    private let session: URLSession

    // JSONEncoder turns small Swift request structs into the JSON bodies your server expects.
    private let encoder = JSONEncoder()

    // JSONDecoder turns the server's JSON responses back into Swift values.
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func createLinkToken(userID: String) async throws -> String {
        // Build the POST request for the backend route that creates a Plaid Link token.
        var request = try makeRequest(path: "/create-link-token", method: "POST")

        // The server expects this exact JSON shape: { "user_id": "..." }.
        request.httpBody = try encoder.encode(CreateLinkTokenRequest(userID: userID))

        // Send the request and wait for the server response.
        let (data, response) = try await session.data(for: request)

        // Treat non-2xx status codes as failures before trying to use the response body.
        try validate(response: response, data: data)

        // Decode the link_token field and hand the raw token back to the SwiftUI view.
        let decodedResponse = try decoder.decode(CreateLinkTokenResponse.self, from: data)
        return decodedResponse.linkToken
    }

    func exchangePublicToken(_ publicToken: String, userID: String) async throws {
        // Build the POST request that trades Plaid's temporary public_token for a server-side access token.
        var request = try makeRequest(path: "/exchange-public-token", method: "POST")

        // The server stores the access token under this user ID.
        request.httpBody = try encoder.encode(
            ExchangePublicTokenRequest(publicToken: publicToken, userID: userID)
        )

        // Send the public token to the backend.
        let (data, response) = try await session.data(for: request)

        // A non-2xx response means the exchange failed.
        try validate(response: response, data: data)

        // The backend returns { "success": true }, so false should be treated as an application-level failure.
        let decodedResponse = try decoder.decode(ExchangePublicTokenResponse.self, from: data)
        guard decodedResponse.success else {
            throw NetworkServiceError.exchangeFailed
        }
    }

    func fetchTransactions(userID: String) async throws -> PlaidTransactionSync {
        // The server uses user_id to look up the correct saved Plaid access token.
        var components = URLComponents(string: ServerConfig.baseURL + "/fetch-transactions")
        components?.queryItems = [URLQueryItem(name: "user_id", value: userID)]

        guard let url = components?.url else {
            throw NetworkServiceError.invalidURL(ServerConfig.baseURL + "/fetch-transactions")
        }

        let request = try makeRequest(url: url, method: "GET")

        // Ask the backend for the latest transactions linked to the saved Plaid access token.
        let (data, response) = try await session.data(for: request)

        // Stop early if the server says the request failed.
        try validate(response: response, data: data)

        // The server returns Plaid's transaction sync shape so the app can add, update, and delete local rows.
        return try decoder.decode(PlaidTransactionSync.self, from: data)
    }

    func transactionsRefreshNeeded(userID: String) async throws -> Bool {
        // Ask the backend whether a Plaid webhook has marked this user's transactions as stale.
        var components = URLComponents(string: ServerConfig.baseURL + "/transactions-refresh-status")
        components?.queryItems = [URLQueryItem(name: "user_id", value: userID)]

        guard let url = components?.url else {
            throw NetworkServiceError.invalidURL(ServerConfig.baseURL + "/transactions-refresh-status")
        }

        let request = try makeRequest(url: url, method: "GET")

        // Send the status check to the backend.
        let (data, response) = try await session.data(for: request)

        // Stop early if the backend rejects the request.
        try validate(response: response, data: data)

        // The server returns true only after Plaid tells it new transaction data may be available.
        let decodedResponse = try decoder.decode(TransactionsRefreshStatusResponse.self, from: data)
        return decodedResponse.refreshNeeded
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: ServerConfig.baseURL + path) else {
            throw NetworkServiceError.invalidURL(ServerConfig.baseURL + path)
        }

        return try makeRequest(url: url, method: method)
    }

    private func makeRequest(url: URL, method: String) throws -> URLRequest {
        // Set up the request once so every endpoint uses the same JSON headers.
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // The backend rejects protected routes without this shared secret.
        let apiSecretKey = ServerConfig.apiSecretKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiSecretKey.isEmpty else {
            throw NetworkServiceError.missingAPISecret
        }

        request.setValue("Bearer \(apiSecretKey)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        // URLSession gives a generic URLResponse, but HTTP status codes only exist on HTTPURLResponse.
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkServiceError.invalidResponse
        }

        // Anything outside 200...299 should become a thrown error for the view model to show.
        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = try? decoder.decode(ServerErrorResponse.self, from: data).error
            throw NetworkServiceError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
        }
    }
}

private struct CreateLinkTokenRequest: Encodable {
    // This property maps to the user_id key required by the Node backend.
    let userID: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct CreateLinkTokenResponse: Decodable {
    // This property maps to the link_token key returned by the Node backend.
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

private struct ExchangePublicTokenRequest: Encodable {
    // This property maps to the public_token key required by the Node backend.
    let publicToken: String
    let userID: String

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case userID = "user_id"
    }
}

private struct ExchangePublicTokenResponse: Decodable {
    // The backend sends success true after it saves the exchanged access token.
    let success: Bool
}

private struct TransactionsRefreshStatusResponse: Decodable {
    // This property maps to the refresh_needed key returned by the backend.
    let refreshNeeded: Bool

    enum CodingKeys: String, CodingKey {
        case refreshNeeded = "refresh_needed"
    }
}

private struct ServerErrorResponse: Decodable {
    // The Node server returns { "error": "..." } for many failures.
    let error: String?
}

private enum NetworkServiceError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case exchangeFailed
    case missingAPISecret

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "The server URL is not valid: \(url)"
        case .invalidResponse:
            return "The server returned a response the app could not read."
        case .serverError(let statusCode, let message):
            return message ?? "The server returned status code \(statusCode)."
        case .exchangeFailed:
            return "The server did not confirm the public token exchange."
        case .missingAPISecret:
            return "Missing CASH_FLOW_API_SECRET_KEY. Add it to your local run environment before connecting a bank."
        }
    }
}
