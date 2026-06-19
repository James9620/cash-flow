# Known Issues

Last updated: 2026-06-19

## Build and Verification

- Full `xcodebuild build` could not be completed inside the Codex sandbox because Xcode/SwiftPM tried to use cache and sandbox features that are blocked in this environment. The touched Swift files were parse-checked successfully, but a full local Xcode build should still be run on the developer machine.
- The iOS simulator could not be inspected directly from Codex because the XcodeBuildMCP simulator tools were not available in this session.

## Authentication and Secrets

- The server now supports JWT bearer-token authentication with `AUTH_MODE=user-token`, but the iOS app is still using the development shared-secret request path. Before production, the app needs a real sign-in flow and must send user JWTs to the backend.
- Simulator bank testing still requires development auth configuration: Railway should use `AUTH_MODE=development-shared-secret`, and the local simulator run environment must provide `CASH_FLOW_API_SECRET_KEY`.
- Secrets are intentionally not committed. The local `server/.env` file is ignored and must be configured separately on each machine or deployment environment.

## Server Hardening

- Postgres token storage is implemented, but JSON token storage still exists as a development fallback. Production should explicitly use Postgres through `TOKEN_STORE_BACKEND=postgres` and a Railway database URL.
- Plaid webhook signature verification exists, but it only runs when `PLAID_WEBHOOK_VERIFICATION` is enabled. Production should enable it before trusting webhook payloads.

## Widgets

- Widgets do not appear automatically after bank sign-in. They must be manually added from the iOS Home Screen widget picker.
- The Discretionary widget can show the shared balance snapshot, but Progress Bar and Bill Stack widgets need matching local `Widget` records before they can show useful budget data.
- The widget extension now has the main Cash Flow widget, but the generated Control Widget and Live Activity files still contain template/demo behavior and are not production-ready.

## App Experience

- The Home tab is still a placeholder screen. The main app is currently focused on bank connection and debug tooling.
- The Reset Local Bank Data action is still intended for development/debug use only.

## Tests

- The XCTest/Swift Testing target exists, but it still needs real focused tests for Plaid import behavior, modified transactions, removed transactions, direct deposit detection, and discretionary balance math.
