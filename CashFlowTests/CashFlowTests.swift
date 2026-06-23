//
//  CashFlowTests.swift
//  CashFlowTests
//
//  Created by James Larkin on 6/18/26.
//

import Foundation
import Testing
@testable import cash_flow

struct CashFlowTests {
    @Test func plaidTransactionValuesUseCorrectImportFields() throws {
        let plaidTransaction = makePlaidTransaction(
            amount: 42.75,
            date: "2026-06-14",
            name: "RAW COFFEE SHOP",
            merchantName: " Coffee Shop ",
            category: ["Food and Drink", "Restaurants"]
        )

        let values = PlaidTransactionImportLogic.transactionValues(from: plaidTransaction)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: values.date)

        #expect(values.plaidID == "plaid-1")
        #expect(values.amount == 42.75)
        #expect(values.merchant == "Coffee Shop")
        #expect(values.category == "Restaurants")
        #expect(dateComponents.year == 2026)
        #expect(dateComponents.month == 6)
        #expect(dateComponents.day == 14)
    }

    @Test func modifiedPlaidTransactionValuesReflectCorrectedPayload() {
        let plaidTransaction = makePlaidTransaction(
            id: "same-id",
            amount: 19.95,
            date: "2026-06-20",
            name: "Corrected Merchant",
            merchantName: nil,
            category: ["Shops", "Sporting Goods"]
        )

        let values = PlaidTransactionImportLogic.transactionValues(from: plaidTransaction)

        #expect(values.plaidID == "same-id")
        #expect(values.amount == 19.95)
        #expect(values.merchant == "Corrected Merchant")
        #expect(values.category == "Sporting Goods")
    }

    @Test func removedIncomeSubtractsOnlyDiscretionaryAmount() {
        let delta = PlaidTransactionImportLogic.balanceDeltaForRemovedIncome(
            amount: 1000,
            savingsPercentage: 25
        )

        #expect(delta == -750)
    }

    @Test func directDepositDetectionRequiresIncomingMoneyAndIncomeText() {
        let payrollDeposit = makePlaidTransaction(
            amount: -2000,
            name: "Employer Payroll",
            category: ["Transfer", "Payroll"],
            personalFinanceCategory: PlaidPersonalFinanceCategory(primary: "INCOME", detailed: "INCOME_WAGES")
        )
        let positivePayrollLookingCharge = makePlaidTransaction(
            amount: 2000,
            name: "Payroll Services",
            category: ["Service"]
        )
        let ordinarySpending = makePlaidTransaction(
            amount: 48,
            name: "Cafe",
            category: ["Food and Drink", "Restaurants"]
        )

        #expect(PlaidTransactionImportLogic.isDirectDeposit(payrollDeposit))
        #expect(!PlaidTransactionImportLogic.isDirectDeposit(positivePayrollLookingCharge))
        #expect(!PlaidTransactionImportLogic.isDirectDeposit(ordinarySpending))
    }

    @Test func directDepositCreationAddsSpendableBalance() {
        let payrollDeposit = makePlaidTransaction(
            amount: -2000,
            name: "Direct Deposit",
            category: ["Income", "Payroll"]
        )

        let plan = PlaidTransactionImportLogic.incomeEventPlan(
            for: payrollDeposit,
            existingIncomeAmount: nil,
            savingsPercentage: 20
        )

        guard case let .upsert(values, balanceDelta) = plan else {
            Issue.record("Expected an upsert plan.")
            return
        }

        #expect(values.amount == 2000)
        #expect(balanceDelta == 1600)
    }

    @Test func correctedDirectDepositOnlyAddsTheDifference() {
        let correctedPayrollDeposit = makePlaidTransaction(
            amount: -2200,
            name: "Direct Deposit",
            category: ["Income", "Payroll"]
        )

        let plan = PlaidTransactionImportLogic.incomeEventPlan(
            for: correctedPayrollDeposit,
            existingIncomeAmount: 2000,
            savingsPercentage: 20
        )

        guard case let .upsert(values, balanceDelta) = plan else {
            Issue.record("Expected an upsert plan.")
            return
        }

        #expect(values.amount == 2200)
        #expect(balanceDelta == 160)
    }

    @Test func incomeCorrectedIntoSpendingRemovesExistingIncome() {
        let correctedSpending = makePlaidTransaction(
            amount: 120,
            name: "Grocery Store",
            category: ["Shops", "Groceries"]
        )

        let plan = PlaidTransactionImportLogic.incomeEventPlan(
            for: correctedSpending,
            existingIncomeAmount: 2000,
            savingsPercentage: 20
        )

        guard case let .removeExisting(balanceDelta) = plan else {
            Issue.record("Expected a remove-existing plan.")
            return
        }

        #expect(balanceDelta == -1600)
    }

    @Test func discretionaryAmountClampsSavingsPercentage() {
        #expect(PlaidTransactionImportLogic.discretionaryAmount(fromIncome: 1000, savingsPercentage: -10) == 1000)
        #expect(PlaidTransactionImportLogic.discretionaryAmount(fromIncome: 1000, savingsPercentage: 150) == 0)
        #expect(PlaidTransactionImportLogic.discretionaryAmount(fromIncome: 1000, savingsPercentage: 30) == 700)
    }

    @Test func widgetSnapshotCountsCurrentMatchingSpendingAndBalance() throws {
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let oldDate = try #require(Calendar.current.date(byAdding: .month, value: -1, to: now))
        let progressWidget = Widget(
            name: "Dining",
            type: .progressBar,
            budget: 100,
            period: .monthly,
            categories: ["Dining"]
        )
        let billWidget = Widget(
            name: "Bills",
            type: .billStack,
            budget: 900,
            period: .monthly,
            categories: ["Utilities"]
        )
        let settings = UserSettings(savingsPercentage: 20, discretionaryBalance: 321)
        let bankConnection = BankConnection(status: .connected, lastSyncedAt: now)
        let transactions = [
            Transaction(amount: 40, date: now, merchant: "Cafe", category: "dining", plaidID: "spend-1"),
            Transaction(amount: 25, date: oldDate, merchant: "Old Cafe", category: "Dining", plaidID: "old-1"),
            Transaction(amount: -2000, date: now, merchant: "Payroll", category: "Payroll", plaidID: "income-1")
        ]

        let snapshot = WidgetSnapshotExporter().makeSnapshot(
            widgets: [progressWidget, billWidget],
            transactions: transactions,
            settings: settings,
            bankConnection: bankConnection,
            now: now
        )
        let progressItem = try #require(snapshot.widgets.first { $0.type == .progressBar })

        #expect(snapshot.bankStatus == .connected)
        #expect(snapshot.lastSyncedAt == now)
        #expect(snapshot.discretionaryBalance == 321)
        #expect(snapshot.widgets.count == 2)
        #expect(progressItem.spent == 40)
        #expect(progressItem.remaining == 60)
        #expect(progressItem.progress == 0.4)
    }

    @Test func widgetSnapshotClampsProgressAtOneHundredPercent() throws {
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let widget = Widget(
            name: "Dining",
            type: .progressBar,
            budget: 50,
            period: .monthly,
            categories: ["Dining"]
        )
        let transaction = Transaction(
            amount: 80,
            date: now,
            merchant: "Dinner",
            category: "Dining",
            plaidID: "spend-1"
        )

        let snapshot = WidgetSnapshotExporter().makeSnapshot(
            widgets: [widget],
            transactions: [transaction],
            settings: nil,
            bankConnection: nil,
            now: now
        )
        let item = try #require(snapshot.widgets.first)

        #expect(snapshot.bankStatus == .notConnected)
        #expect(item.spent == 80)
        #expect(item.remaining == -30)
        #expect(item.progress == 1)
    }

    private func makePlaidTransaction(
        id: String = "plaid-1",
        amount: Double = 12.34,
        date: String = "2026-06-14",
        name: String = "Merchant",
        merchantName: String? = nil,
        category: [String]? = nil,
        personalFinanceCategory: PlaidPersonalFinanceCategory? = nil
    ) -> PlaidTransaction {
        PlaidTransaction(
            transactionID: id,
            name: name,
            merchantName: merchantName,
            amount: amount,
            date: date,
            category: category,
            personalFinanceCategory: personalFinanceCategory
        )
    }
}
