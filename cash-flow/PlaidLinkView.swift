//
//  PlaidLinkView.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import LinkKit
import SwiftUI
import UIKit

struct PlaidLinkView: UIViewControllerRepresentable {
    // This temporary token comes from your backend's /create-link-token route.
    let linkToken: String

    // The parent SwiftUI view uses this callback to send Plaid's public_token back to the backend.
    let onSuccess: (String) -> Void

    // This callback lets the parent sheet close if the user exits Plaid Link before finishing.
    let onExit: () -> Void

    init(
        linkToken: String,
        onSuccess: @escaping (String) -> Void,
        onExit: @escaping () -> Void = {}
    ) {
        // Store the token and callbacks so the UIKit wrapper can use them during Plaid Link presentation.
        self.linkToken = linkToken
        self.onSuccess = onSuccess
        self.onExit = onExit
    }

    func makeCoordinator() -> Coordinator {
        // The coordinator keeps the Plaid session alive while Link is on screen.
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        // Plaid needs a UIKit view controller to present its Link interface.
        let controller = UIViewController()

        // The LinkTokenConfiguration wires Plaid's success callback to this SwiftUI wrapper.
        let configuration = LinkTokenConfiguration(
            token: linkToken,
            onSuccess: { result in
                // Plaid returns a publicToken that the app must exchange on the backend.
                DispatchQueue.main.async {
                    onSuccess(result.publicToken)
                }
            },
            onExit: { _ in
                // Close the SwiftUI sheet when the user cancels or exits Link.
                DispatchQueue.main.async {
                    onExit()
                }
            },
            onEvent: nil,
            onLoad: nil
        )

        do {
            // LinkKit 7 creates a PlaidLinkSession from the link token configuration.
            let handler = try Plaid.createPlaidLinkSession(configuration: configuration)

            // Retain the handler so it is not released while the sheet is presenting Plaid Link.
            context.coordinator.handler = handler

            // Open Link after SwiftUI has had a chance to attach the controller to the sheet.
            DispatchQueue.main.async {
                handler.open(using: .viewController(controller))
            }
        } catch {
            // A configuration failure usually means the link token is missing, expired, or malformed.
            assertionFailure("Failed to create Plaid Link handler: \(error)")
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Plaid Link does not need SwiftUI-driven updates after it has been opened.
    }

    final class Coordinator {
        // Keeping this reference alive keeps the Plaid Link session alive.
        var handler: PlaidLinkSession?
    }
}
