//
//  Models.swift
//  cash-flow
//
//  Created by James Larkin on 6/12/26.
//

import Foundation
import SwiftData

enum WidgetType: String, Codable, CaseIterable {
    // Shows spending as a stack of upcoming or category-based bills.
    case billStack

    // Shows spending progress toward the widget's budget.
    case progressBar

    // Shows one clear discretionary amount the user can still spend.
    case discretionaryNumber
}

enum BudgetPeriod: String, Codable, CaseIterable {
    // Resets and measures this budget every week.
    case weekly

    // Resets and measures this budget every month.
    case monthly
}

enum SubscriptionStatus: String, Codable, CaseIterable {
    // The default plan with free features only.
    case free

    // The paid plan with pro features enabled.
    case pro
}

@Model
final class Widget {
    // A stable unique value for this widget, useful when matching SwiftData objects to UI state or external references.
    var id: UUID

    // The user-facing name shown for this widget, such as "Rent" or "Groceries".
    var name: String

    // The kind of widget the app should show for this budget area.
    var type: WidgetType

    // The spending limit or target amount for this widget's selected period.
    var budget: Double

    // Whether this widget's budget should be measured by week or by month.
    var period: BudgetPeriod

    // The transaction category names that should be counted toward this widget's spending.
    var categories: [String]

    // The transactions SwiftData has linked back to this widget. This is a relationship, meaning SwiftData stores a connection between model objects instead of copying the transaction data into the widget.
    // The inverse points to Transaction.widget, so when a transaction is assigned to this widget, SwiftData can also show that transaction inside this list.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.widget)
    var transactions: [Transaction]

    init(
        id: UUID = UUID(),
        name: String,
        type: WidgetType,
        budget: Double,
        period: BudgetPeriod,
        categories: [String] = [],
        transactions: [Transaction] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.budget = budget
        self.period = period
        self.categories = categories
        self.transactions = transactions
    }
}

@Model
final class Transaction {
    // A stable unique value for this transaction inside the app.
    var id: UUID

    // The transaction amount, with spending typically stored as a positive app-level value.
    var amount: Double

    // The date when the transaction happened.
    var date: Date

    // The merchant or payee name attached to the transaction.
    var merchant: String

    // The spending category assigned to the transaction, such as "Dining" or "Utilities".
    var category: String

    // The identifier supplied by Plaid, used to match local records to imported bank transactions.
    var plaidID: String

    // The widget this transaction counts toward. This is an optional relationship because a transaction might be imported before the app knows which widget should count it.
    // SwiftData stores this object link so the app can ask which budget area owns the transaction without manually storing another widget ID.
    var widget: Widget?

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        merchant: String,
        category: String,
        plaidID: String,
        widget: Widget? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.category = category
        self.plaidID = plaidID
        self.widget = widget
    }
}

@Model
final class IncomeEvent {
    // A stable unique value for this income event inside the app.
    var id: UUID

    // The amount of income received.
    var amount: Double

    // The date the income was expected, earned, or recorded.
    var date: Date

    // The date the money actually arrived in the user's account.
    var depositedAt: Date

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        depositedAt: Date
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.depositedAt = depositedAt
    }
}

@Model
final class UserSettings {
    // The percentage of income the user wants to route to savings.
    var savingsPercentage: Double

    // Whether the user has finished the first-run setup flow.
    var onboardingComplete: Bool

    // Whether the user is on the free plan or the pro plan.
    var subscriptionStatus: SubscriptionStatus

    init(
        savingsPercentage: Double = 0,
        onboardingComplete: Bool = false,
        subscriptionStatus: SubscriptionStatus = .free
    ) {
        self.savingsPercentage = savingsPercentage
        self.onboardingComplete = onboardingComplete
        self.subscriptionStatus = subscriptionStatus
    }
}
