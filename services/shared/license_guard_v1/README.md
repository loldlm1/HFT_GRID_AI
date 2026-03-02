# Shared License Guard Service (v1)

Canonical reusable license service for MT5 EAs in this repository.

## Purpose
- Keep one implementation for verify/heartbeat lane guard, backend magic-number caching, and optional daily results reporting.
- Avoid duplicated web requests across charts for the same lane identity.
- Provide a deterministic migration target for old and new EAs.

## Canonical Files
- `services/shared/license_guard_v1/license_guard_profile.mqh`
- `services/shared/license_guard_v1/license_service.mqh`
- `services/shared/license_guard_v1/license_guard_online.mqh`
- `services/shared/license_guard_v1/daily_results_online.mqh`
- `services/shared/license_guard_v1/backend-entitlements-contract.md`
- `services/shared/license_guard_v1/license-shared-service-migration-plan.md`

## V1 Refactor Policy
- Legacy wrapper files were deprecated and removed in this repo refactor:
  - `services/SecurityLicense.mqh`
  - `services/SecurityLicenseOnline.mqh`
  - `services/BrokerAccountDailyResultsOnline.mqh`
- New and old EAs must integrate directly against `license_service.mqh` with profile macros.

## Integration Contract (EA side)
1. Include `services/shared/license_guard_v1/license_service.mqh` after defining profile macros.
2. Call `LicenseServiceInit()` in `OnInit` before trading initialization.
3. Wire `OnTimer` to `LicenseServiceOnTimer()`.
4. Wire `OnDeinit` to `LicenseServiceOnDeinit()`.
5. Use `LicenseGetCachedMagicNumber()` as the runtime trading magic in live mode.
6. If `LicenseGetCachedMagicNumber() <= 0` after startup verify, fail closed and remove EA.

## Profile Macros
Set per-EA values before including `license_service.mqh`.

- `LICENSE_SHARED_PROFILE_NAME` (chart/user message branding)
- `LICENSE_SHARED_SOURCE_KEY`
- `LICENSE_SHARED_BASE_EA_ID`
- `LICENSE_SHARED_API_BASE_URL`
- `LICENSE_SHARED_PRIMARY_CI_KEY`
- `LICENSE_SHARED_BASE_SECRET_KEY`
- `LICENSE_SHARED_ENFORCEMENT_ENABLED` (`1` or `0`)
- `LICENSE_SHARED_DAILY_RESULTS_ENABLED` (`1` or `0`)
- `LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS` (`1` or `0`)
- `LICENSE_SHARED_REQUIRED_ADDONS_CSV` (optional; empty string if no add-ons are required)

## Optional Add-on Entitlements
- Add-ons are optional by profile.
- EAs that do not require add-ons should keep `LICENSE_SHARED_REQUIRED_ADDONS_CSV` empty.
- EAs that require add-ons should define the CSV list or call `LicenseSetRequestedAddonsCsv()` at startup.

## Lane Identity and Request Sharing
The leader/follower lane key is derived from:
- `source + email + ea_id + company + account_number + account_type`

Runtime rules:
- One leader sends `verify/heartbeat` for a lane.
- Followers consume shared lane state and avoid duplicate requests.
- Followers can request leader reverify (`LicenseOnline_RequestLeaderReverify`).

## Daily Results Rules
- Daily results use backend `magic_number` from verify cache only.
- Local dedupe key includes `account + ea_id + magic_number`.
- Closed PnL aggregation filters by `DEAL_MAGIC == magic_number`.

## Migration Requirement
When adopting this module in an EA, remove or bypass legacy local license logic to prevent dual-auth flows.

Reference migration plan:
- `services/shared/license_guard_v1/license-shared-service-migration-plan.md`
