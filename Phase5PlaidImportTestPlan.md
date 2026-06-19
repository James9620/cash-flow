# Phase 5 Plaid Import Test Plan

There is not an XCTest target in the current Xcode project yet. The Plaid import rules now live in `PlaidTransactionImportLogic`, which is a small pure Swift seam that future XCTest files can call with `@testable import cash_flow`.

## Focused XCTest Cases To Add

1. Added transaction import values
   - Given a new Plaid transaction with `transaction_id`, amount, date, merchant name, and category path.
   - Assert `transactionValues(from:)` returns the Plaid ID, amount, parsed date, cleaned merchant name, and the most specific category.

2. Modified transaction import values
   - Given the same Plaid ID with corrected amount, date, merchant, or category.
   - Assert the returned values reflect the corrected Plaid payload so the existing SwiftData row can be updated in place.

3. Removed paycheck balance math
   - Given an existing income amount of `1000` and savings percentage `25`.
   - Assert `balanceDeltaForRemovedIncome` returns `-750`, so removing the paycheck subtracts only the discretionary portion.

4. Direct deposit detection
   - Assert negative payroll or `INCOME_WAGES` transactions are treated as direct deposits.
   - Assert positive payroll-looking transactions are not treated as income, because Plaid uses negative amounts for incoming money.
   - Assert ordinary spending transactions are not treated as income.

5. Direct deposit creation
   - Given a negative direct deposit of `-2000` and savings percentage `20`.
   - Assert `incomeEventPlan` returns an upsert plan with income amount `2000` and balance delta `1600`.

6. Direct deposit correction
   - Given an existing income event amount of `2000`, then a modified Plaid income transaction of `-2200` with savings percentage `20`.
   - Assert `incomeEventPlan` returns an upsert plan with balance delta `160`, not the full `1760`, so the app does not double-count corrected deposits.

7. Income corrected into non-income
   - Given an existing income event amount of `2000`, then a modified Plaid transaction with a spending category.
   - Assert `incomeEventPlan` returns a remove plan with balance delta `-1600` when savings percentage is `20`.

8. Discretionary percentage clamping
   - Assert savings below `0` behaves like `0`.
   - Assert savings above `100` behaves like `100`.
   - Assert a normal savings percentage returns the expected spendable amount.

## SwiftData Integration Cases After A Test Target Exists

Use an in-memory SwiftData `ModelContainer` with `Widget`, `Transaction`, `IncomeEvent`, and `UserSettings` registered.

1. Added transactions insert one `Transaction` row.
2. Modified transactions update the existing row for the same Plaid ID instead of inserting a duplicate.
3. Removed transactions delete the matching `Transaction` row.
4. Removed paycheck transactions also delete the matching `IncomeEvent` and subtract the discretionary amount.
5. Non-income transactions do not create a `UserSettings` row just to do nothing.
