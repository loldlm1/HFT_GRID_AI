# Pivot Fractal V13 Producer Acceptance

## Decision

**ACCEPTED FOR OFFLINE PRODUCER HANDOFF, WITH HUMAN VISUAL VERIFICATION
OUTSTANDING.** The final MetaEditor compile, bounded real-tick Strategy Tester
run, strict V13 validation/build/audit, and export-on/off broker-event parity
pass. The downstream Django plan may consume the frozen V13 contract and prepare
its research workflow, but its destructive V12 removal gate remains separate.

This acceptance does not authorize live rollout, runtime model loading, online
learning, execution filtering, or deletion of V12 data. A human visual/chart
pass remains required before any deployment claim.

## Provenance

- Branch: `bot/pivot_points_fractal`
- Sprint 8 rollback point: `dc41827b087cda707e7d9c4e31d882463871d20b`
- Sprint 8 acceptance commit:
  `8c57aaf28577b872ad9863367585c549012364a6`
- Schema/feature/root: `13`, `schema_v13_hft_deep_pivot_features`,
  `Common\\Files\\PivotFractalV13\\runs\\<run_id>\\`
- Accepted run: `v13_sprint8_acceptance_1d_fix9_20260831`
- Validator SHA-256:
  `65cdea96cf4018e5068dcd59d598c171ae83979130458fa3339a6f36b0edf5c9`
- Builder SHA-256:
  `f3de2ca4cabc80fa2144544f1efcc7f09fdf8ce85b2552fc8f655396194b9c32`
- Canonical 566-column registry SHA-256:
  `986c4868fb70b08e18296e8679a5ad2aeebe59849571ef2b7ee58fcab8cde3c1`
- Fixture provenance SHA-256:
  `cb079ab86f1e8123d62205fe355bb95fc10b68c3f8cc0d2ebe50fe088e68af12`
- Sorted twelve-TSV fixture bundle SHA-256:
  `ea36e31a685b80e0562a04400758bcf1b2dae3be596a3afa45a0f809be9b70f5`

## Final Compile

- MetaEditor MCP preflight: PASS; build `6140`, target `x64`, and
  `can_compile_file=true`.
- Final MCP `compile_file`: PASS, `0 errors, 0 warnings`, `25,376 ms`.
- Latest regenerated ignored `HFT_Grid_AI.ex5`: `293,838` bytes, modified
  `2026-08-31 13:31:06 -0400`, SHA-256
  `cfd0d5730947fcb7b78a73b1a7349382a77b30f2d0ec65d570fb9349135d98fd`.
- The accepted tester binary was captured separately from this documentation
  closeout compile; source anchors are identical and `.ex5` files remain
  ignored/generated artifacts.

Compiled source anchors:

- `HFT_Grid_AI.mq5`:
  `43cee11c41d5f59759c7c17773bd46837062b71456aa5d34ef6b51f85782e43c`
- `services/trading_signals/deep_pivot_lifecycle.mqh`:
  `cace91c7029e2b631503c801f010500f7e4c4da415bacf93ccbaef49cfdbb4ba`
- `services/trading_signals/pivot_trial_matrix_state.mqh`:
  `d622172e856e0a2ea5619a19373373f2b362cdbc6fea2b10585826b3fe611048`
- `services/trading_signals/pivot_trial_matrix_geometry.mqh`:
  `72804427d592d428898db80b052b206cdd93dd811525ae01cf2a892a766a5279`
- `services/trading_signals/pivot_trial_matrix_lifecycle.mqh`:
  `6ad4af881bc45f889c9978d4b7a373c159efffd3e17bc94d180560412b50a41e`

## Bounded Tester Evidence

The accepted export-on and matching export-off runs used XAUUSD, chart M3,
`PERIOD_M3 < PERIOD_M10 < PERIOD_H1`, real ticks, `EXNESS_SESSION`, USD
`1,000,000`, leverage `1:10000`, and `ExecutionMode=120` milliseconds over
`2026.06.29 00:00` through `2026.06.30 00:00`.

- Export on: `306,627` ticks, `460` bars, `2:52.304` test time,
  `2:57.379` total time, `158 MB`, final balance `1,000,102.64`.
- Export off: the same ticks, bars, broker events, and final balance;
  `3.501` seconds test time, `8.672` seconds total time, `140 MB`.
- Normalized `Trade`/`Trades` event streams: `408` lines on each side with
  shared SHA-256
  `9b88dc7181b21684373110b96d0182d45b8abc01f12b49a61af6980858ebd1be`.
- Export off created no V13 run directory.
- Tester-loaded binary: `293,474` bytes, SHA-256
  `0dfda46d0b1de75423978af431e1c1c011f8463a3c29a94880392a491c964896`.

The natural export-on seal contains all twelve TSV files and reports:

- `51` origins; `408` H1 matrix lanes plus `51` broker-parity trials.
- `204` structural and `204` midpoint lanes across `1R/2R/3R/5R`.
- H1 matrix outcomes: `108` TP, `244` SL, `40` not-triggered, and `16`
  run-censored. The run summary's aggregate `134` TP and `269` SL also includes
  the `26` TP and `25` SL broker-parity outcomes.
- `277` admitted M10 events, `2,449` parent links, `831` shared deep
  trials, and `7,347` parent-scoped deep outcomes.
- Deep outcomes: `2,040` TP, `4,293` SL, `929` parent-exit censors,
  `70` run-end censors, and `15` ineligible rows.
- `204` execution-check rows, `51` broker outcomes, `51` parity pairs,
  and zero parity terminal mismatches.
- Zero duplicate identities, referential-integrity errors, or row-integrity
  errors; `export_status=OK`, `completion_status=NATURAL`.

## Timing Interpretation

The tester's configured `120 ms` execution delay means this run cannot prove
sub-120 ms latency, perfect intra-second fill ordering, or exact exchange-level
tick sequencing. V13 stores broker timestamps to whole seconds, so same-second
facts are accepted only when the EA's causal processing order, immutable
geometry, terminal reconciliation, and cross-file identities remain consistent.
No performance or causal claim in this record depends on sub-second precision.

## Offline Evidence

- Python `compileall`: PASS.
- Complete contract suite: `38` tests, PASS.
- Strict validation of the accepted run: PASS.
- Typed dataset build: PASS at ignored dataset ID
  `sprint8-v13-fix9-1d-20260831`.
- Structural audit: PASS; research status is the expected
  `INSUFFICIENT_SUPPORT` for a one-day, `51`-origin sample.
- Dataset manifest SHA-256:
  `159afc6fd0caf7290d42828bcc697520b043b02a078e7f4bacadae6e7476c8c1`.
- Quality report SHA-256:
  `bc4c706dc28d5b0f6da63b68cf64e4e66cc99a992de304b2f9466529027a0b0a`.
- Audit SHA-256:
  `08bdbfb2a7aecfaf153d0636673cd2334de7747b94a66bb92456416c329a8917`.

## Acceptance Matrix

| Gate | Evidence | Status |
| --- | --- | --- |
| MetaEditor | build `6140`, `0 errors, 0 warnings`, regenerated binary | PASS |
| H1 lanes | structural/midpoint `1R/2R/3R/5R`, touch/no-touch, exits | PASS |
| Deep events | shared M10 identity, one configured-Micro snapshot, `1R/2R/3R` | PASS |
| Parent timing | exact uncapped seconds and same-second censor handling | PASS |
| Censoring | parent/run-end/ineligible facts remain outside binary losses | PASS |
| Broker safety | sole structural H1 `1R` send path, immutable SL/TP, no deep order | PASS |
| Export parity | identical normalized broker event stream with export on/off | PASS |
| V13 run | twelve files, natural seal, strict validate/build/audit | PASS |
| Operations | real ticks, state caps, cleanup, bounded memory | PASS |
| Visual chart | human chart-object and rendering inspection | OUTSTANDING |

## Residual Gates

- The human visual/chart pass remains outstanding and is required before any
  live or deployment-oriented acceptance.
- The one-day sample is not statistical support for a deployable model,
  profitability claim, or causal strategy selection.
- Django may align to the V13 contract, but V12 active-code/data deletion still
  requires its separately authorized gate.
- Older-engine positions must be flat, the account must support hedging, and
  only one EA instance may run per account/symbol before any future rollout.
