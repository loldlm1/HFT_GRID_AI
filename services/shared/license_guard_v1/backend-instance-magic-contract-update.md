# Backend Contract Update: Instance-Scoped Trade Magic

**Status**: Proposed additive contract
**Scope**: License backend, shared license guard, Pandora Box EA, and future EAs that need per-chart trade ownership.

## Purpose
Current production EAs receive one `magic_number` for the shared license lane. That causes overlap when multiple charts or multiple EAs in the same MT5 account use the same numeric magic. MT5 does not namespace magic numbers by EA, so trade ownership must be unique at the numeric magic level.

This update keeps the existing license lane for entitlement, online seat, heartbeat, and request de-duplication, but introduces a stable EA chart `instance_id` that receives its own backend-issued trade `magic_number`.

## Design Summary
- License lane remains:
  - `source + email + ea_id + company + account_number + account_type`
- Trade identity becomes:
  - `broker_account + ea_id + instance_id -> magic_number`
- Backend must enforce:
  - One stable magic per instance key.
  - No duplicate numeric magic values across active EA instances on the same broker account, even when `ea_id` differs.
  - Magic remains signed-32-bit safe: `1..2147483647`.
- The EA must not generate live random trade magic locally.
- Missing or invalid instance magic remains fail-closed.

## New EA Field
Add an opaque chart-instance identifier:

```json
{
  "instance_id": "pandora_box_7W8S2K5NQ4H9"
}
```

Rules:
- Required for instance-scoped magic allocation.
- Opaque string from EA to backend.
- Recommended max length: 64 ASCII characters.
- Recommended charset: `A-Z`, `a-z`, `0-9`, `_`, `-`.
- Must not contain account numbers, license tokens, API keys, broker credentials, emails, or proprietary strategy settings.
- Must be stable for the same EA chart instance across restart/recompile.
- Must be unique enough that two charts do not intentionally share the same `instance_id`.

## Recommended Endpoint
Prefer a lightweight endpoint separate from lane heartbeat:

```text
POST /api/v1/licenses/instance_magic
```

Purpose:
- Validate the caller's license identity and broker account context.
- Allocate or return a stable instance-scoped trade magic.
- Do not allocate a new online seat.
- Do not replace the lane leader/follower heartbeat model.

Required request fields:
- All shared request fields from `backend-entitlements-contract.md`:
  - `source`
  - `email`
  - `ea_id`
  - `license_key`
  - `broker_account`
- `instance_id` string

Example request:

```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "pandora_box",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  },
  "instance_id": "pandora_box_7W8S2K5NQ4H9"
}
```

Success (`200 OK`) response:

```json
{
  "ok": true,
  "instance_id": "pandora_box_7W8S2K5NQ4H9",
  "magic_number": 490123456,
  "trade_identity_scope": "instance"
}
```

Response rules:
- `magic_number` is required on success.
- `magic_number` must be a supported signed-32-bit positive integer.
- Same request identity and `instance_id` must return the same magic on later calls.
- A different active `instance_id` on the same broker account must receive a different numeric magic.

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`, `broker_account_not_found`
- `422`: `invalid_payload`, `missing_instance_id`, `invalid_instance_id`, `missing_magic_number`, `invalid_magic_number`
- `429`: `rate_limited`
- `500`: `internal_error`

## Alternative Endpoint Shape
If adding a new endpoint is not practical, `/licenses/verify` may accept optional `instance_id` and return an instance-scoped `magic_number` only for clients that declare support for instance magic.

If this approach is used, it must not break the leader/follower lane model:
- Legacy EAs without `instance_id` keep receiving lane magic.
- New EAs with `instance_id` receive instance magic.
- Followers still need a way to get their own instance magic without becoming heartbeat leaders.

For this reason, the separate `instance_magic` endpoint is preferred.

## Backend Persistence
Add or extend storage for EA instances.

Suggested fields:
- `id`
- `broker_account_id`
- `source`
- `email` or user/license foreign key
- `ea_id`
- `instance_id`
- `magic_number`
- `status` (`active`, `archived`, etc.)
- `first_seen_at`
- `last_seen_at`
- `created_at`
- `updated_at`

Required uniqueness:
- Unique active instance key:
  - `broker_account_id + ea_id + instance_id`
- Unique active numeric trade magic:
  - `broker_account_id + magic_number`

Magic allocation:
- Generate within `1..2147483647`.
- Avoid sequential values if possible, but uniqueness and stability matter more than randomness.
- Never reassign an active instance's magic after it has been returned.
- Do not recycle a magic while positions or daily-results history may still reference it.

## Daily Results
Use the simplest production model: each EA chart instance reports its own daily result for its own runtime trade magic.

Rules:
- `daily_results.magic_number` is the instance-scoped runtime trade magic used by `CTrade`.
- Deal filtering in the EA remains by `DEAL_MAGIC == magic_number`.
- Existing dedupe remains valid:
  - `broker_account + ea_id + magic_number + UTC day`
- The lane leader should not aggregate all chart instances unless a separate, tested aggregation feature is built later.
- Instance daily-results calls must not allocate online seats.

## EA Behavior Expectations
At startup:
1. Run existing license guard verification/authorization.
2. Resolve or generate the local chart `instance_id`.
3. Request instance magic from backend.
4. Fail closed if the response is missing or invalid.
5. Set `g_magic_number` and `CTrade.SetExpertMagicNumber()` to the instance-scoped magic.

The compact chart panel should show only the instance-scoped trade magic. Logs may include lane and `instance_id` for support.

## Production Rollout
Use an additive rollout. Backend goes first.

1. Deploy backend support while preserving legacy `/licenses/verify` behavior.
2. Validate backend behavior with test payloads:
   - Same `instance_id` returns the same magic.
   - Different `instance_id` values on the same broker account return different magic values.
   - Different EA IDs on the same broker account do not collide numerically.
   - Daily-results accepts the instance-scoped magic.
3. Release EA changes to staging/demo accounts.
4. Roll out to production charts only when flat, or implement a separate legacy migration mode.
5. After adoption, keep license lane identity for heartbeat/entitlement, but stop treating lane magic as the live trade identity for new EA versions.

## Production Migration Risk
Do not switch a chart to instance-scoped magic while it still has open positions under the legacy lane magic unless explicit migration behavior exists.

Safe default:
- If legacy lane-magic positions exist for the chart symbol, the new EA should refuse to initialize and show a clear migration-blocked status.
- Upgrade the chart only after positions are flat, or keep the previous EA version managing those positions until they close.

## Acceptance Checklist
- Backend is backwards compatible with legacy EAs.
- Instance magic allocation does not consume extra online seats.
- Numeric magic uniqueness is enforced per broker account.
- Magic is stable for a given `instance_id`.
- Missing or invalid magic is a hard failure.
- Daily-results dedupe still works per scoped magic.
- EA panel shows scoped trade magic.
- Support logs can correlate lane, `instance_id`, and magic without exposing secrets.
