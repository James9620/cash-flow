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

    func exchangePublicToken(_ publicToken: String) async throws {
        // Build the POST request that trades Plaid's temporary public_token for a server-side access token.
        var request = try makeRequest(path: "/exchange-public-token", method: "POST")

        // The server expects this exact JSON shape: { "public_token": "..." }.
        request.httpBody = try encoder.encode(ExchangePublicTokenRequest(publicToken: publicToken))

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

    func fetchTransactions() async throws -> [PlaidTransaction] {
        // Build the GET request for the server route that returns Plaid transactions.
        let request = try makeRequest(path: "/fetch-transactions", method: "GET")

        // Ask the backend for the latest transactions linked to the saved Plaid access token.
        let (data, response) = try await session.data(for: request)

        // Stop early if the server says the request failed.
        try validate(response: response, data: data)

        // The server wraps the Plaid array in { "transactions": [...] }.
        let decodedResponse = try decoder.decode(FetchTransactionsResponse.self, from: data)
        return decodedResponse.transactions
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        // Combine the shared Railway base URL with the specific backend endpoint path.
        guard let url = URL(string: ServerConfig.baseURL + path) else {
            throw NetworkServiceError.invalidURL(ServerConfig.baseURL + path)
        }

        // Set up the request once so every endpoint uses the same JSON headers.
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
    }
}

private struct ExchangePublicTokenResponse: Decodable {
    // The backend sends success true after it saves the exchanged access token.
    let success: Bool
}

private struct FetchTransactionsResponse: Decodable {
    // The backend wraps Plaid's transaction list in this transactions field.
    let transactions: [PlaidTransaction]
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
        }
    }
}
