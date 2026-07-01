//
//  SubscriptionManager.swift
//  cash-flow
//
//  Created by Codex on 6/24/26.
//

import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var subscriptionStatus: SubscriptionStatus = .free
    private(set) var isConfigured = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var setupMessage: String?
    private(set) var errorMessage: String?
    private(set) var noticeMessage: String?

    @ObservationIgnored
    private var currentPackage: RevenueCat.Package?

    @ObservationIgnored
    private var customerInfoListener: Task<Void, Never>?

    var packageTitle: String {
        currentPackage?.storeProduct.localizedTitle ?? "Cash Flow Pro"
    }

    var packagePriceText: String {
        currentPackage?.localizedPriceString ?? "Unavailable"
    }

    var canPurchase: Bool {
        isConfigured && currentPackage != nil && !isPurchasing
    }

    var isPro: Bool {
        subscriptionStatus == .pro
    }

    func configureIfPossible(userID: String?) async {
        clearMessages()

        guard let userID = userID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userID.isEmpty else {
            subscriptionStatus = .free
            setupMessage = "Sign in before loading subscription status."
            return
        }

        let apiKey = RevenueCatConfig.appleAPIKey
        guard !apiKey.isEmpty else {
            // Missing setup should not break the app; it just means purchases cannot load on this build.
            subscriptionStatus = .free
            setupMessage = "Add REVENUECAT_APPLE_API_KEY to enable purchases. Free mode is still available."
            return
        }

        do {
            if Purchases.isConfigured {
                if Purchases.shared.appUserID != userID {
                    let loginResult = try await Purchases.shared.logIn(userID)
                    apply(customerInfo: loginResult.customerInfo)
                }
            } else {
                #if DEBUG
                Purchases.logLevel = .debug
                #endif

                // RevenueCat needs the same stable user ID that our backend created after Sign in with Apple.
                Purchases.configure(withAPIKey: apiKey, appUserID: userID)
            }

            isConfigured = true
            startCustomerInfoListener()
            await refresh()
        } catch {
            subscriptionStatus = .free
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard isConfigured else {
            return
        }

        isLoading = true
        clearMessages(keepingSetupMessage: true)

        defer {
            isLoading = false
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)

            let offerings = try await Purchases.shared.offerings()
            currentPackage = offerings.current?.monthly ?? offerings.current?.availablePackages.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseCurrentPackage() async {
        guard isConfigured else {
            setupMessage = "Add REVENUECAT_APPLE_API_KEY to enable purchases."
            return
        }

        guard let currentPackage else {
            errorMessage = "No Cash Flow Pro product is available yet."
            return
        }

        isPurchasing = true
        clearMessages(keepingSetupMessage: true)

        defer {
            isPurchasing = false
        }

        do {
            let result = try await Purchases.shared.purchase(package: currentPackage)
            apply(customerInfo: result.customerInfo)

            if result.userCancelled {
                noticeMessage = "Purchase canceled."
            } else if subscriptionStatus == .pro {
                noticeMessage = "Cash Flow Pro is active."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isConfigured else {
            setupMessage = "Add REVENUECAT_APPLE_API_KEY to restore purchases."
            return
        }

        isLoading = true
        clearMessages(keepingSetupMessage: true)

        defer {
            isLoading = false
        }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
            noticeMessage = subscriptionStatus == .pro ? "Purchases restored." : "No active Pro purchase found."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearForSignOut() {
        customerInfoListener?.cancel()
        customerInfoListener = nil
        subscriptionStatus = .free
        isConfigured = Purchases.isConfigured
        currentPackage = nil
        clearMessages()
        // Do not call RevenueCat logOut here. The next signed-in user is attached with logIn(userID),
        // which avoids creating an anonymous customer in between app sessions.
    }

    private func startCustomerInfoListener() {
        guard customerInfoListener == nil else {
            return
        }

        customerInfoListener = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                await self?.apply(customerInfo: customerInfo)
            }
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        let isProActive = customerInfo.entitlements[SubscriptionEntitlements.proIdentifier]?.isActive == true
        subscriptionStatus = SubscriptionEntitlements.status(isProActive: isProActive)
    }

    private func clearMessages(keepingSetupMessage: Bool = false) {
        if !keepingSetupMessage {
            setupMessage = nil
        }

        errorMessage = nil
        noticeMessage = nil
    }
}
