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

    // This query reads the explicit bank status row instead of inferring connection from transactions.
    @Query private var bankConnections: [BankConnection]

    // Transactions are shown as supporting sync detail only; they no longer decide whether the bank is connected.
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    // @State keeps this observable view model alive for the life of the view.
    @State private var viewModel = BankConnectionViewModel()

    // The Link token is saved after the backend creates it, then passed into PlaidLinkView.
    @State private var linkToken: String? = nil

    // This state controls the SwiftUI sheet that presents Plaid Link.
    @State private var showingPlaidLink = false

    private var bankConnection: BankConnection? {
        bankConnections.first
    }

    private var status: BankConnectionStatus {
        bankConnection?.status ?? .notConnected
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CashFlowBankColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        BankStatusPanel(
                            status: status,
                            lastSyncedAt: bankConnection?.lastSyncedAt,
                            transactionCount: transactions.count
                        )

                        VStack(spacing: 12) {
                            actionButtons
                        }

                        if viewModel.isLoading {
                            // This spinner appears while the view model is waiting on the backend or SwiftData.
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(CashFlowBankColors.accent)

                                Text("Working with your bank connection...")
                                    .font(.subheadline)
                                    .foregroundStyle(CashFlowBankColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let recoveryMessage = viewModel.errorMessage ?? bankConnection?.lastErrorMessage {
                            BankRecoveryMessage(message: recoveryMessage)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Bank")
            .toolbarBackground(CashFlowBankColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task(id: status.rawValue) {
            guard status == .connected else {
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

    @ViewBuilder
    private var actionButtons: some View {
        switch status {
        case .notConnected:
            primaryBankButton(title: "Connect Bank Account", action: startPlaidLink)

        case .connected:
            primaryBankButton(title: "Refresh Transactions") {
                Task {
                    // Let the user manually run Plaid transaction sync without reconnecting their bank.
                    await viewModel.loadTransactions(context: modelContext)
                }
            }

            secondaryBankButton(title: "Reconnect Bank", action: startPlaidLink)

        case .needsReconnect:
            primaryBankButton(title: "Reconnect Bank", action: startPlaidLink)

            secondaryBankButton(title: "Try Refresh Again") {
                Task {
                    await viewModel.loadTransactions(context: modelContext)
                }
            }

        case .error:
            primaryBankButton(title: "Try Refresh Again") {
                Task {
                    await viewModel.loadTransactions(context: modelContext)
                }
            }

            secondaryBankButton(title: "Reconnect Bank", action: startPlaidLink)
        }
    }

    private func startPlaidLink() {
        // The button starts an async task because fetching a link token is a network call.
        Task {
            if let token = await viewModel.connectBank(context: modelContext) {
                // Store the link token so the sheet can create Plaid Link.
                linkToken = token

                // Present Plaid Link only after a valid token is available.
                showingPlaidLink = true
            }
        }
    }

    private func primaryBankButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(CashFlowBankColors.accent)
        .disabled(viewModel.isLoading)
    }

    private func secondaryBankButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(CashFlowBankColors.accent)
        .disabled(viewModel.isLoading)
    }
}

private struct BankStatusPanel: View {
    let status: BankConnectionStatus
    let lastSyncedAt: Date?
    let transactionCount: Int

    var body: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    CashFlowStatusPill(statusPillTitle, color: statusColor)

                    Spacer()
                }

                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(CashFlowBankColors.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(CashFlowBankColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    BankStatusDetailRow(label: "Imported transactions", value: "\(transactionCount)")

                    if let lastSyncedAt {
                        BankStatusDetailRow(
                            label: "Last sync",
                            value: lastSyncedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    } else {
                        BankStatusDetailRow(label: "Last sync", value: "Not synced yet")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var title: String {
        switch status {
        case .notConnected:
            return "No Bank Connected"
        case .connected:
            return "Bank Connected"
        case .needsReconnect:
            return "Reconnect Needed"
        case .error:
            return "Bank Needs Attention"
        }
    }

    private var message: String {
        switch status {
        case .notConnected:
            return "Connect a bank account to import spending and income for your widgets."
        case .connected:
            return "Transactions can refresh from your Railway backend and update local widget data."
        case .needsReconnect:
            return "Plaid needs you to sign in again before the app can keep syncing."
        case .error:
            return "The last bank action did not finish. Try a refresh, or reconnect if the problem continues."
        }
    }

    private var statusColor: Color {
        switch status {
        case .notConnected:
            return CashFlowBankColors.secondaryText
        case .connected:
            return CashFlowBankColors.success
        case .needsReconnect:
            return CashFlowBankColors.warning
        case .error:
            return CashFlowBankColors.error
        }
    }

    private var statusPillTitle: String {
        switch status {
        case .notConnected:
            return "Optional"
        case .connected:
            return "Ready"
        case .needsReconnect:
            return "Reconnect"
        case .error:
            return "Retry"
        }
    }
}

private struct BankStatusDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(CashFlowBankColors.secondaryText)

            Spacer()

            Text(value)
                .foregroundStyle(CashFlowBankColors.primaryText)
        }
        .font(.caption)
    }
}

private struct BankRecoveryMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(CashFlowBankColors.error)
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CashFlowBankColors.error.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

typealias CashFlowBankColors = CashFlowTheme

#Preview {
    BankConnectionView()
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
