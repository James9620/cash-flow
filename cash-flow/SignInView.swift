//
//  SignInView.swift
//  cash-flow
//
//  Created by Codex on 6/22/26.
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Bindable var session: BackendSession
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            CashFlowSignInColors.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cash Flow")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(CashFlowSignInColors.primaryText)

                    Text("Connect securely before syncing bank data and widget snapshots.")
                        .font(.headline)
                        .foregroundStyle(CashFlowSignInColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        configureAppleRequest(request)
                    } onCompletion: { result in
                        handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(session.isSigningIn)

                    if session.isSigningIn {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(CashFlowSignInColors.accent)

                            Text("Signing in...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CashFlowSignInColors.secondaryText)
                        }
                    }

                    if let errorMessage = session.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(CashFlowSignInColors.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CashFlowSignInColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInSession.makeNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInSession.sha256(nonce)
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                session.errorMessage = AppleSignInSessionError.unsupportedCredential.localizedDescription
                return
            }

            guard let rawNonce = currentNonce else {
                session.errorMessage = AppleSignInSessionError.missingNonce.localizedDescription
                return
            }

            do {
                let identityToken = try AppleSignInSession.identityTokenString(from: credential)
                let authorizationCode = AppleSignInSession.authorizationCodeString(from: credential)

                Task {
                    await session.signIn(
                        identityToken: identityToken,
                        rawNonce: rawNonce,
                        authorizationCode: authorizationCode
                    )
                }
            } catch {
                session.errorMessage = error.localizedDescription
            }

        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }

            session.errorMessage = error.localizedDescription
        }
    }
}

private enum CashFlowSignInColors {
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 15 / 255)
    static let surface = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255)
    static let accent = Color(red: 74 / 255, green: 158 / 255, blue: 255 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 176 / 255)
    static let error = Color(red: 255 / 255, green: 95 / 255, blue: 116 / 255)
}

#Preview {
    SignInView(session: .previewSignedOut)
}
