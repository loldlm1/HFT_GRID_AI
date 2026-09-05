# Exness Tick History

An offline Python CLI for immutable Exness archives and MT5 research input.
Python 3.11+ is required (`tomllib`); the validated environment is Python 3.12
with DuckDB 1.5.4. Run from the repository root:

```bash
.venv/bin/python -m pip install -r tools/exness_tick_history/requirements.txt
.venv/bin/python -m tools.exness_tick_history --help
.venv/bin/python -m tools.exness_tick_history inspect-config
.venv/bin/python -m tools.exness_tick_history probe-archive --year 2026 --month 9 --day 1
.venv/bin/python -m tools.exness_tick_history inspect-archive <local.zip> --year 2026 --month 9 --day 1
.venv/bin/python -m tools.exness_tick_history inventory --start 2026-08-01 --end 2026-09-02 --granularity auto
.venv/bin/python -m tools.exness_tick_history download --inventory <inventory_id> --resume
.venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
```

Copy `profiles/xauusd_pro.example.toml` to the ignored data root for private
configuration. Pass `--config <path>` before the command. Explicit dates mean
`[start, end)` in UTC; `latest-published` is resolved during inventory. Archive
symbol, broker suffix/override, account type and live/demo mode are independent.
Use a different profile ID for each account/feed. The source CSV does not prove
that the selected archive matches a Pro account.

`inspect-config` performs no writes, network calls or terminal actions. Exit 2
means configuration error; exit 3 means unavailable source or failed integrity;
exit 130 means interruption. Reports distinguish incomplete evidence from a
demonstrated mismatch. Secrets are not accepted in configuration; urllib honors
the operator's existing proxy environment without printing its values.

The archive host may work when the Exness selection page returns 403. A denied
request does not establish missing history or a market holiday. This tool does
not control a VPN. Never change raw timestamps or quotes to obtain a match.

Inventory freezes a UTC cutoff, HEAD evidence, estimated bytes and disjoint
source intervals in `runs/<inventory_id>/inventory.json`. Auto mode prefers
whole completed years, then months, then days. Explicit year/month modes may
fetch extra container days for a subrange; inspect `extra_container_days` and
the byte estimate before downloading. Missing larger containers fall back to
smaller ones only after 404. Access failures remain distinct from unavailable
URLs. A latest-publication HEAD is a candidate until body/coverage validation.

Downloads stream through `partial/`, verify size, ZIP limits and CRC, then
publish under `archives/<sha256>/`. The SQLite ledger records verified objects.
Repeat the same command to verify and reuse completed bytes. Ctrl-C retains
owned partials; `--resume` uses them only when validator, size and byte range
agree. Without `--resume`, only disposable partials restart. A changed source
requires a fresh inventory; previous archive versions remain intact. Run one
writer per data root. A stale lock file is harmless once its OS lock is released;
never delete another process's active lock. Incomplete downloads exit 3 and
write details to `runs/<inventory_id>/download-status.json`.

See the [workflow](../../docs/workflows/exness-tick-history.md) for the source,
terminal and acceptance contract. Native MT5 checks are pending until the
operator completes the guided steps after the implementation batch.
