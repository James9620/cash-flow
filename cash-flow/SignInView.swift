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
            CashFlowTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cash Flow")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(CashFlowTheme.primaryText)

                    Text("Sign in securely, then set up your Discretionary Number widget.")
                        .font(.headline)
                        .foregroundStyle(CashFlowTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CashFlowMiniWidgetPreview(balance: 420, statusText: "Preview")
                    .frame(maxWidth: .infinity)

                CashFlowPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        CashFlowStatusPill("Apple + Cash Flow session", color: CashFlowTheme.accent, systemImage: "lock")

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
                                    .tint(CashFlowTheme.accent)

                                Text("Signing in...")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CashFlowTheme.secondaryText)
                            }
                        }

                        if let errorMessage = session.errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(CashFlowTheme.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
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

#Preview {
    SignInView(session: .previewSignedOut)
}
