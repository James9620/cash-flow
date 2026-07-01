# Cash Flow Roadmap

Last updated: 2026-07-01

## Final Version Scope

- The first production-ready version will ship with the Discretionary Number widget only.
- Progress Bar and Bill Stack are deferred to future updates after the core login, bank sync, and discretionary balance flow are stable.

## Current Phase

Step 7 is focused on onboarding, design polish, and Discretionary widget readiness:

- Sign in with Apple gates the app.
- First-run onboarding appears after sign-in and before the main tabs.
- Onboarding saves the user's income split before any optional Plaid import.
- Plaid sandbox bank connection and transaction import continue to work.
- Direct deposits update discretionary balance.
- The Discretionary widget reads the shared App Group snapshot.
- Cash Flow Pro subscription plumbing exists through RevenueCat and is reused for feature gating.
- Server auth, token storage, and webhook settings are production-ready, with backend entitlement enforcement still deferred.

## Future Updates

- Run the app target, widget extension, and `CashFlowTests` locally in Xcode after Step 7 changes.
- Deploy/update Railway production environment values before production use.
- Add the Progress Bar widget after the Discretionary widget is stable.
- Add the Bill Stack widget after Progress Bar is stable.
- Expand Home settings when those widgets return to the active product scope.
