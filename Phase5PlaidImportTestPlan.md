# Phase 5 Plaid Import Test Plan

The focused Phase 5 tests now live in `CashFlowTests/CashFlowTests.swift`.

## Covered

- Plaid transaction import values for added and modified payloads.
- Removed income balance math.
- Direct deposit detection.
- Direct deposit creation and correction.
- Income corrected into spending.
- Savings percentage clamping.
- Widget snapshot category matching, current-period spending, bank status, discretionary balance, remaining amount, and progress clamping.

## Still Required Locally

- Run `CashFlowTests` in Xcode on the developer machine.
- Run the main app target with Sign in with Apple enabled.
- Run or install the widget extension and confirm all three widget configurations read the shared snapshot.
- Reconnect Plaid sandbox after sign-in if the previous access token was saved under the old install UUID.
