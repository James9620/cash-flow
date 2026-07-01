# Known Issues

Last updated: 2026-06-24

## Build and Verification

- Full `xcodebuild` validation still needs to be run locally in Xcode. The Codex sandbox cannot complete SwiftPM/Xcode work because SwiftPM cache writes and CoreSimulator services are blocked.
- Run the app target, `CashFlowWidgetsExtension`, and `CashFlowTests` on the developer machine before moving to Phase 6.

## Production Configuration

- Railway must be updated before production use:
  - `NODE_ENV=production`
  - `AUTH_MODE=user-session`
  - `SESSION_JWT_SECRET`
  - `TOKEN_STORE_BACKEND=postgres`
  - `DATABASE_URL` or `POSTGRES_URL`
  - `PLAID_WEBHOOK_VERIFICATION=true`
  - `APPLE_BUNDLE_ID=com.jameslarkin.cashflow`
- Existing simulator Plaid connections that used install UUIDs may need to reconnect after switching to Apple-backed user IDs.

## Widgets

- Widgets do not appear automatically after bank sign-in. They must be manually added from the iOS Home Screen widget picker.
- The first production-ready version only includes the Discretionary Number widget.
- Progress Bar and Bill Stack are intentionally deferred to future updates. Any current Progress Bar or Bill Stack code should be treated as non-final until those widgets are brought back into scope.

## Development Tools

- The SwiftData Debug tab remains development-only and should not be treated as production user experience.
