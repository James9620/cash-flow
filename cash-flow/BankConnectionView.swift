//
//  BankConnectionView.swift
//  cash-flow
//
//  Created by James Larkin on 6/14/26.
//

import SwiftData
import SwiftUI

struct BankConnectionView: View {
    // SwiftData provides this context through the app's modelContainer environment.
    @Environment(\.modelContext) private var modelContext

    // This query lets the view know whether any transactions already exist in SwiftData.
    @Query private var transactions: [Transaction]

    // @State keeps this observable view model alive for the life of the view.
    @State private var viewModel = BankConnectionViewModel()

    // The Link token is saved after the backend creates it, then passed into PlaidLinkView.
    @State private var linkToken: String? = nil

    // This state controls the SwiftUI sheet that presents Plaid Link.
    @State private var showingPlaidLink = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if transactions.isEmpty {
                    Button {
                        // The button starts an async task because fetching a link token is a network call.
                        Task {
                            if let token = await viewModel.connectBank() {
                                // Store the link token so the sheet can create Plaid Link.
                                linkToken = token

                                // Present Plaid Link only after a valid token is available.
                                showingPlaidLink = true
                            }
                        }
                    } label: {
                        Text("Connect Bank Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                } else {
                    VStack(spacing: 12) {
                        // Any existing transaction means the app has already imported bank data.
                        Text("Bank connected!")
                            .foregroundStyle(.green)

                        Button {
                            // Let the user manually run Plaid transaction sync without reconnecting their bank.
                            Task {
                                await viewModel.loadTransactions(context: modelContext)
                            }
                        } label: {
                            Text("Refresh Transactions")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)
                    }
                }

                if viewModel.isLoading {
                    // This spinner appears while the view model is waiting on the backend or SwiftData.
                    ProgressView()
                }

                if let errorMessage = viewModel.errorMessage {
                    // Backend and import errors are shown plainly so setup problems are visible.
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Bank")
        }
        .task(id: transactions.count) {
            guard !transactions.isEmpty else {
                return
            }

            // When this screen appears, quietly refresh only if Plaid has sent the server a webhook.
            await viewModel.loadTransactionsIfRefreshNeeded(context: modelContext)
        }
        .sheet(isPresented: $showingPlaidLink) {
            if let linkToken {
                // PlaidLinkView opens the LinkKit UI and returns a public_token after a successful connection.
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        // Close the sheet once Plaid reports success.
                        showingPlaidLink = false

                        // Exchange the public token, then fetch and save the user's transactions.
                        Task {
                            await viewModel.handlePublicToken(publicToken, context: modelContext)
                        }
                    },
                    onExit: {
                        // Close the sheet if the user leaves Plaid Link without connecting a bank.
                        showingPlaidLink = false
                    }
                )
            } else {
                // This is a defensive fallback in case the sheet is shown without a token.
                Text("Missing Plaid link token.")
                    .padding()
            }
        }
    }
}

#Preview {
    BankConnectionView()
        .modelContainer(for: [
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
