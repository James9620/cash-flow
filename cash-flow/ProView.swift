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
                CashFlowHomeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerPanel
                        planPanel
                        actionPanel
                        messagePanel
                    }
                    .padding()
                }
            }
            .navigationTitle("Cash Flow Pro")
            .toolbarBackground(CashFlowHomeColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await subscriptionManager.refresh()
        }
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subscriptionManager.isPro ? "Pro Active" : "Upgrade")
                .font(.caption.weight(.bold))
                .foregroundStyle(CashFlowHomeColors.secondaryText)

            Text("Advanced Income Split")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(CashFlowHomeColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Route each paycheck to savings, bills/reserve, and discretionary spending.")
                .font(.subheadline)
                .foregroundStyle(CashFlowHomeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var planPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionManager.packageTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CashFlowHomeColors.primaryText)

                    Text(subscriptionManager.isPro ? "Unlocked on this account." : "Monthly subscription")
                        .font(.caption)
                        .foregroundStyle(CashFlowHomeColors.secondaryText)
                }

                Spacer()

                Text(subscriptionManager.packagePriceText)
                    .font(.headline.weight(.black))
                    .foregroundStyle(CashFlowHomeColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actionPanel: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isPro {
                Label("Cash Flow Pro is active", systemImage: "checkmark.seal")
                    .font(.headline)
                    .foregroundStyle(CashFlowHomeColors.success)
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
                .tint(CashFlowHomeColors.accent)
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
            .tint(CashFlowHomeColors.accent)
            .disabled(subscriptionManager.isLoading || subscriptionManager.isPurchasing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CashFlowHomeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var messagePanel: some View {
        if subscriptionManager.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading subscription status.")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CashFlowHomeColors.secondaryText)
        }

        if let setupMessage = subscriptionManager.setupMessage {
            Text(setupMessage)
                .font(.subheadline)
                .foregroundStyle(CashFlowHomeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let noticeMessage = subscriptionManager.noticeMessage {
            Text(noticeMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CashFlowHomeColors.success)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let errorMessage = subscriptionManager.errorMessage {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(CashFlowHomeColors.error)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ProView(subscriptionManager: SubscriptionManager())
}
