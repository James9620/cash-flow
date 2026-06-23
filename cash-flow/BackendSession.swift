//
//  BackendSession.swift
//  cash-flow
//
//  Created by Codex on 6/22/26.
//

import Foundation
import Observation
import Security

struct BackendSessionResponse: Decodable {
    let sessionToken: String
    let userID: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case userID = "user_id"
        case expiresAt = "expires_at"
    }
}

enum BackendSessionStore {
    private static let userIDDefaultsKey = "cashflow_session_user_id"
    private static let expirationDefaultsKey = "cashflow_session_expires_at"
    private static let sessionTokenAccount = "cashflow_session_token"

    static var sessionToken: String? {
        KeychainSessionStore.readString(account: sessionTokenAccount)
    }

    static var userID: String? {
        UserDefaults.standard.string(forKey: userIDDefaultsKey)
    }

    static var expiresAt: String? {
        UserDefaults.standard.string(forKey: expirationDefaultsKey)
    }

    static var isSignedIn: Bool {
        guard let token = sessionToken else {
            return false
        }

        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func save(response: BackendSessionResponse) throws {
        try KeychainSessionStore.saveString(response.sessionToken, account: sessionTokenAccount)
        UserDefaults.standard.set(response.userID, forKey: userIDDefaultsKey)
        UserDefaults.standard.set(response.expiresAt, forKey: expirationDefaultsKey)
    }

    static func clear() {
        KeychainSessionStore.deleteString(account: sessionTokenAccount)
        UserDefaults.standard.removeObject(forKey: userIDDefaultsKey)
        UserDefaults.standard.removeObject(forKey: expirationDefaultsKey)
    }
}

@MainActor
@Observable
final class BackendSession {
    @ObservationIgnored
    private let sessionClient: BackendSessionClient

    private(set) var isSignedIn: Bool
    private(set) var userID: String?
    var isSigningIn = false
    var errorMessage: String?

    init(
        sessionClient: BackendSessionClient = BackendSessionClient(),
        isSignedIn: Bool? = nil,
        userID: String? = nil
    ) {
        self.sessionClient = sessionClient
        self.isSignedIn = isSignedIn ?? BackendSessionStore.isSignedIn
        self.userID = userID ?? BackendSessionStore.userID
    }

    func signIn(identityToken: String, rawNonce: String, authorizationCode: String?) async {
        isSigningIn = true
        errorMessage = nil

        defer {
            isSigningIn = false
        }

        do {
            let response = try await sessionClient.exchangeAppleSession(
                identityToken: identityToken,
                rawNonce: rawNonce,
                authorizationCode: authorizationCode
            )

            try BackendSessionStore.save(response: response)
            userID = response.userID
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
            isSignedIn = BackendSessionStore.isSignedIn
            userID = BackendSessionStore.userID
        }
    }

    func signOut() {
        // Sign-out only clears the app session. Apple controls the user's Apple ID authorization state.
        BackendSessionStore.clear()
        userID = nil
        isSignedIn = false
        errorMessage = nil
    }

    static var previewSignedIn: BackendSession {
        BackendSession(isSignedIn: true, userID: "preview-user")
    }

    static var previewSignedOut: BackendSession {
        BackendSession(isSignedIn: false, userID: nil)
    }
}

struct BackendSessionClient {
    private let session: URLSession
    private let baseURL: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        session: URLSession = .shared,
        baseURL: String = "https://cash-flow-production-341d.up.railway.app"
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func exchangeAppleSession(
        identityToken: String,
        rawNonce: String,
        authorizationCode: String?
    ) async throws -> BackendSessionResponse {
        guard let url = URL(string: baseURL + "/auth/apple-session") else {
            throw BackendSessionClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(
            BackendAppleSessionRequest(
                identityToken: identityToken,
                rawNonce: rawNonce,
                authorizationCode: authorizationCode
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        return try decoder.decode(BackendSessionResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendSessionClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = try? decoder.decode(BackendSessionErrorResponse.self, from: data).error
            throw BackendSessionClientError.serverError(
                statusCode: httpResponse.statusCode,
                message: serverMessage
            )
        }
    }
}

private struct BackendAppleSessionRequest: Encodable {
    let identityToken: String
    let rawNonce: String
    let authorizationCode: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case rawNonce = "raw_nonce"
        case authorizationCode = "authorization_code"
    }
}

private struct BackendSessionErrorResponse: Decodable {
    let error: String?
}

private enum BackendSessionClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The login server URL is not valid."
        case .invalidResponse:
            return "The login server returned a response the app could not read."
        case .serverError(let statusCode, let message):
            return message ?? "The server returned status code \(statusCode)."
        }
    }
}

private enum KeychainSessionStore {
    private static let service = "com.jameslarkin.cashflow.session"

    static func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func saveString(_ value: String, account: String) throws {
        deleteString(account: account)

        guard let data = value.data(using: .utf8) else {
            throw KeychainSessionError.invalidString
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainSessionError.saveFailed(status)
        }
    }

    static func deleteString(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

private enum KeychainSessionError: LocalizedError {
    case invalidString
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidString:
            return "The session token could not be stored."
        case .saveFailed:
            return "The session token could not be saved to Keychain."
        }
    }
}
