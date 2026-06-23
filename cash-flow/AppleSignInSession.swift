//
//  AppleSignInSession.swift
//  cash-flow
//
//  Created by Codex on 6/22/26.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Security

enum AppleSignInSession {
    static func makeNonce(length: Int = 32) throws -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard status == errSecSuccess else {
            throw AppleSignInSessionError.nonceGenerationFailed
        }

        // Apple only receives the hash of this value. The raw value goes to our backend for verification.
        return String(randomBytes.map { characters[Int($0) % characters.count] })
    }

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func identityTokenString(from credential: ASAuthorizationAppleIDCredential) throws -> String {
        guard let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleSignInSessionError.missingIdentityToken
        }

        return token
    }

    static func authorizationCodeString(from credential: ASAuthorizationAppleIDCredential) -> String? {
        guard let data = credential.authorizationCode else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

enum AppleSignInSessionError: LocalizedError {
    case missingIdentityToken
    case missingNonce
    case nonceGenerationFailed
    case unsupportedCredential

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple did not return an identity token."
        case .missingNonce:
            return "The sign-in request could not be verified."
        case .nonceGenerationFailed:
            return "The app could not create a secure sign-in nonce."
        case .unsupportedCredential:
            return "Apple returned an unsupported sign-in credential."
        }
    }
}
