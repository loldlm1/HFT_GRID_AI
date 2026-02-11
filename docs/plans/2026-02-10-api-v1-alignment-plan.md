# API v1 Alignment Plan (MQL5 EAs)

## Goal
Align all MQL5 EAs with backend API v1 contracts for:

- `POST /api/v1/licenses/verify`
- `POST /api/v1/broker_accounts/daily_results`

This document captures the agreed production behavior so future EAs can reuse the same integration pattern.

## Contract Summary

### 1) `licenses/verify`

Request payload:

- `source`
- `email`
- `ea_id`
- `license_key`
- `broker_account`:
  - `name`
  - `company`
  - `account_number`
  - `account_type` (`real|demo`)
- `addons` (optional, send only when non-empty)

Response handling:

- `200 ok` + `ok=true`: accept license, update local runtime context (`expires_at`, `trial`, `plan_interval`, `broker_account`).
- Non-2xx or `ok=false`: log backend `error` and fail validation.
- Timer refresh failure: remove EA immediately and log HTTP/error details.

### 2) `broker_accounts/daily_results`

Request payload:

- `source`
- `email`
- `ea_id`
- `license_key`
- `broker_account`:
  - `company`
  - `account_number`
  - `account_type`
- `result_timestamp`: unix epoch for `00:00:00 UTC` of reported day
- `result_value`: string with 2 decimals

Response handling:

- `201 created`: success.
- `409 already_recorded`: treat as success (idempotent).
- `404 broker_account_not_found`: force one license re-verify, retry once.
- `422 invalid_payload`: block retries for that day and log.
- `429`/`5xx`/network failure: retry with backoff.

## Business Rules (agreed)

1. Daily result metric:
`realized net closed P/L = profit + swap + commission + fee`.

2. Scope:
all symbols/account activity (not chart symbol only).

3. Timestamp policy:
report the most recent completed UTC day, with day start timestamp (`00:00:00 UTC`).

4. No-trade days:
send `0.00` to preserve continuity.

5. Offline recovery:
no historical backfill; report only the most recent completed UTC day.

## Implementation Pattern for Other EAs

1. Keep license and daily-results modules separated (single responsibility).
2. Reuse verified license runtime context (`email`, `ea_id`, `license_key`, broker account info).
3. Run reporting from timer with low-frequency gate (not every tick).
4. Persist per-account reported day using terminal global variables or shared state to reduce duplicates.
5. Treat backend duplicate responses as successful sync.
6. Log every failed request with HTTP + backend error string.

## Validation Checklist

- Compile EA cleanly.
- Confirm `licenses/verify` payload includes broker account and optional addons.
- Confirm license refresh logs detailed error and removes EA on failure.
- Confirm daily result sends once per completed UTC day.
- Confirm duplicate day returns `409` and is marked synced locally.
- Confirm missing broker path performs one re-verify and one retry.
- Confirm no-trade days send `result_value="0.00"`.

