//
//  ProView.swift
//  cash-flow
//
//  Created by Codex on 6/24/26.
//

import SwiftUI

struct ProView: View {
    let subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationStack {
            ZStack {
                CashFlowTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerPanel
                        planPanel
                        benefitsPanel
                        actionPanel
                        messagePanel
                    }
                    .padding()
                }
            }
            .navigationTitle("Cash Flow Pro")
            .toolbarBackground(CashFlowTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await subscriptionManager.refresh()
        }
    }

    private var headerPanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 12) {
                CashFlowStatusPill(subscriptionManager.isPro ? "Pro Active" : "Upgrade", color: subscriptionManager.isPro ? CashFlowTheme.success : CashFlowTheme.accent)

                Text("Advanced Income Split")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(CashFlowTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Route each paycheck to savings, bills/reserve, and discretionary spending.")
                    .font(.subheadline)
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var planPanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.packageTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(CashFlowTheme.primaryText)

                        Text(subscriptionManager.isPro ? "Unlocked on this account." : "Monthly subscription")
                            .font(.caption)
                            .foregroundStyle(CashFlowTheme.secondaryText)
                    }

                    Spacer()

                    Text(subscriptionManager.packagePriceText)
                        .font(.headline.weight(.black))
                        .foregroundStyle(CashFlowTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                CashFlowAllocationBar(
                    savingsPercentage: 20,
                    billsReservePercentage: 25,
                    isPro: true
                )
            }
        }
    }

    private var benefitsPanel: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("What Pro unlocks")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CashFlowTheme.primaryText)

                ProFeatureRow(
                    title: "Second income bucket",
                    message: "Keep bills and reserves out of the discretionary number automatically.",
                    systemImage: "slider.horizontal.3"
                )

                ProFeatureRow(
                    title: "Correction-safe history",
                    message: "Imported paycheck corrections undo the exact amount originally applied.",
                    systemImage: "clock.arrow.circlepath"
                )

                ProFeatureRow(
                    title: "Widget-ready math",
                    message: "The Discretionary Number snapshot stays aligned with your saved split.",
                    systemImage: "number.square"
                )
            }
        }
    }

    private var actionPanel: some View {
        CashFlowPanel {
            VStack(spacing: 12) {
                if subscriptionManager.isPro {
                    Label("Cash Flow Pro is active", systemImage: "checkmark.seal")
                        .font(.headline)
                        .foregroundStyle(CashFlowTheme.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Button {
                        Task {
                            await subscriptionManager.purchaseCurrentPackage()
                        }
                    } label: {
                        HStack {
                            if subscriptionManager.isPurchasing {
                                ProgressView()
                            } else {
                                Image(systemName: "creditcard")
                                Text("Start Pro")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CashFlowTheme.accent)
                    .disabled(!subscriptionManager.canPurchase)
                }

                Button {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(CashFlowTheme.accent)
                .disabled(subscriptionManager.isLoading || subscriptionManager.isPurchasing)
            }
        }
    }

    @ViewBuilder
    private var messagePanel: some View {
        if subscriptionManager.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading subscription status.")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CashFlowTheme.secondaryText)
        }

        if let setupMessage = subscriptionManager.setupMessage {
            Text(setupMessage)
                .font(.subheadline)
                .foregroundStyle(CashFlowTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let noticeMessage = subscriptionManager.noticeMessage {
            Text(noticeMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CashFlowTheme.success)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let errorMessage = subscriptionManager.errorMessage {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(CashFlowTheme.error)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProFeatureRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(CashFlowTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CashFlowTheme.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ProView(subscriptionManager: SubscriptionManager())
}
