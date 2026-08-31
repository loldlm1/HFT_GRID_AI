# Pivot Fractal V13 Producer Handoff

**Status**: Sprint 8 compile and bounded real-tick tester acceptance complete;
human visual/chart verification remains outstanding. Django may prepare against
this frozen V13 handoff, but its destructive V12 removal gate remains separate.

This document freezes the strict producer resources and evidence grains so the
downstream application does not need to infer columns, ratios, lifecycles, or
censoring behavior.

## Contract Identity

- Schema: `13`
- Engine: `PIVOT_FRACTAL_V2`
- Feature set: `schema_v13_hft_deep_pivot_features`
- H1 feature set: `schema_v13_hft_deep_pivot_features.h1`
- Deep feature set: `schema_v13_hft_deep_pivot_features.deep_parent`
- Storage root: `Common\Files\PivotFractalV13\runs\<run_id>\`
- Magic namespace: `HFT_GRID_AI_PIVOT_FRACTAL_V13`
- Default timeframe order: `PERIOD_M3 < PERIOD_M10 < PERIOD_H1`
- Pre-compile producer/tooling pin: `a684db53fe9988425005933c57f4e9bd32b9eb5c`
- Sprint 7 documentation commit: `dc41827b087cda707e7d9c4e31d882463871d20b`
- Final accepted producer commit: the Sprint 8 commit containing this handoff
  (resolve with `git log -1 -- docs/research/pivot-fractal-v13-producer-handoff.md`)
- Final compile source anchors:
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
- Validator: `tools/deterministic_signal_ml/schema_contract.py`
- Validator SHA-256:
  `65cdea96cf4018e5068dcd59d598c171ae83979130458fa3339a6f36b0edf5c9`
- Builder/type-registry source: `tools/deterministic_signal_ml/build_dataset.py`
- Builder SHA-256:
  `f3de2ca4cabc80fa2144544f1efcc7f09fdf8ce85b2552fc8f655396194b9c32`
- Canonical 566-column registry SHA-256:
  `986c4868fb70b08e18296e8679a5ad2aeebe59849571ef2b7ee58fcab8cde3c1`
- H1 model feature count: `181`
- Deep model feature count: `99`
- Fixture provenance SHA-256:
  `cb079ab86f1e8123d62205fe355bb95fc10b68c3f8cc0d2ebe50fe088e68af12`
- Sorted twelve-TSV fixture bundle SHA-256:
  `ea36e31a685b80e0562a04400758bcf1b2dae3be596a3afa45a0f809be9b70f5`
- Ordered header bundle SHA-256:
  `0be0e6265b3d736119aa1195d7f98e948ad932d876e8f5f06635d6f3de17ee6b`

The registry hash is SHA-256 of compact sorted JSON for
`schema_contract.COLUMN_TYPE_BY_NAME`. The fixture bundle hashes files in
lexicographic filename order as `filename + NUL + file bytes`. The header
bundle uses the contract file order and the same framing with only each first
line, including its newline.

## Exact File Contract

| File | Columns | Header SHA-256 | Fixture file SHA-256 |
| --- | ---: | --- | --- |
| `run_manifest.tsv` | 3 | `287cd6df5a48e8a373de6b9777f8e85aaf1a772051ce9344f5af8ab0d808f501` | `89877a13edd8b5f45e4d5b394e23a3a867924766303bd69c9d77fc478959af8f` |
| `pivot_windows.tsv` | 51 | `000a0813806fdc60408874d1e98b17a63e9bf4041efa278616ddda78c66870f7` | `6c5f5fe7e0a4ae0d61ec3a043f3e0aa267986fc3965abfe61abf48f4854b03d9` |
| `signal_origins.tsv` | 222 | `21e2d9f6447161de9ccbb55e71e902bf772802622bc690198b642d0d23b2831a` | `4020a47c4595b8d2572bb2c9138b50ee4cc38721c8be92d312b6ce7e8b6be80a` |
| `virtual_trials.tsv` | 55 | `205606c5eaae1516298f031fd7ebd08847ba348f0f10e26ec42343d1aafd2d12` | `1d762ed006a0ba961fd8a387c00edc0e63b396ddac07d58c23f25040ebb35f07` |
| `virtual_outcomes.tsv` | 31 | `944ca5c52254854e1310169736051373d103e535bfbfb7e97014c6bc0e17b26a` | `4b5aff4fdd6fcc1c2f1214bfc430ad1f094570d699a93129549d04d68c1e1076` |
| `deep_pivot_events.tsv` | 121 | `c155444f20bb9c90317a4067197c414c0b369c8a635da6540b3ba4e78d5126c7` | `457ab49c5fd1c75cb27146cd0266347774f7e049dbf32d8f32202ffaa7c56845` |
| `deep_pivot_parent_links.tsv` | 16 | `da31b3bcd7913598f239d933fe6db05658b464419f257137b85572493ccd822e` | `bea205eabf53981cb0abf2a10a45dfabd22513a2604e61a445a7e6b803bfe8e8` |
| `deep_virtual_trials.tsv` | 33 | `4df88ba5d24f22b237bcfe16db941671d3abb2fe095f7a7cede0ea1707caf70f` | `47e46341c300954d48ce4007b785c81145199a6736e9f8473b5f73fa87444e42` |
| `deep_virtual_outcomes.tsv` | 29 | `1b6299175318b8d999ae0b3a9846b2fbfd49d7941b16a4dd288bde1bcafd4700` | `a9d3d4a8a79ce59483f50b30fbf8ab1ff09d47ff5537e74db1bcf68e4bd6a249` |
| `execution_checks.tsv` | 82 | `5bf2df73100249356302df7b3fb85f5a9d3b9d0859c91dc3a9d61d9c4bd673c9` | `5bf2df73100249356302df7b3fb85f5a9d3b9d0859c91dc3a9d61d9c4bd673c9` |
| `broker_outcomes.tsv` | 61 | `3a196c628ef3bee7fa73a1979eb6b13c1cc41ea6765acfd0213f48742cd9977c` | `3a196c628ef3bee7fa73a1979eb6b13c1cc41ea6765acfd0213f48742cd9977c` |
| `run_summary.tsv` | 52 | `4b8685319d8af6e055d2d9f540c7d26071ef896a1a4525a918c16928f1b8e9ec` | `160c0bbfcf58d16b09216ccd93581b070a50ddc075b4bd5660e0e1b24fbe4035` |

## Evidence And Lifecycle Rules

- Each H1 origin declares `STRUCTURAL` and `MIDPOINT_50` at `1R`, `2R`,
  `3R`, and `5R`. There are no Bands-width policies or re-entry generations.
- Midpoint entry occurs only at the first executable touch of the exact halfway
  price toward the next outward pivot. Untouched rows become `NOT_TRIGGERED`
  when the last structural lane exits.
- Only structural H1 `1R` may reach the broker. An accepted request creates one
  exact parity shadow for calibration only.
- One direction-independent M10 pivot identity owns one configured-Micro event
  snapshot and shared deep `1R/2R/3R` geometry.
- Parent links fan the event out to every active same-direction H1 virtual or
  confirmed broker parent without duplicating the feature vector.
- A parent exit censors unresolved child outcomes as `CENSORED_PARENT_EXIT`.
  Censored, capacity-rejected, ineligible, and not-triggered rows have no binary
  target and are never relabeled as losses.
- `h1_structural_lifecycle_seconds` is exact completed parent duration and is
  retrospective. `m10_parent_age_seconds` is exact age at the M10 trigger.
  Neither is rounded or capped.
- Public minute selectors are separate inclusive predicates using
  `seconds <= minutes * 60`. Applying both uses AND semantics.

## Downstream Vendoring Boundary

After Sprint 8 acceptance, Django may vendor:

- `tools/deterministic_signal_ml/schema_contract.py` byte-for-byte;
- the explicit type registry and native-grain builder contract from
  `tools/deterministic_signal_ml/build_dataset.py`;
- `tools/deterministic_signal_ml/tests/fixtures/schema_v13_hft_deep_pivot_features/`;
- this handoff and the dated final acceptance record.

Django must not vendor V12 compatibility code, conversion logic, private raw
runs, generated Parquet data, audit/model output, binaries, compile logs, or
account/terminal metadata. Its V12 code/data deletion gate remains explicit and
separate; this handoff does not authorize it.

## Completed Static/Offline Evidence

- Python `compileall`: PASS.
- Complete contract suite: `38` tests, PASS.
- Strict V13 fixture validate/build: PASS.
- V13 fixture audit: PASS, `AUDIT_COMPLETE`.
- H1 and deep training loaders: PASS (`8` H1 rows, `5` deep rows).
- Fixture minimum-support gate: expected rejection (`8 < 500`, `5 < 500`).
- Fixture provenance SHA-256 verification: PASS.
- Sprint 6 `git diff --check`: PASS.
- Sprint 8 static identifier/include/broker-boundary review: PASS.
- Sprint 8 Python `compileall` and all `38` contract tests: PASS.
- Accepted-run strict validation and typed dataset build: PASS.
- Accepted-run structural audit: PASS; research status is the expected
  `INSUFFICIENT_SUPPORT` for a one-day, `51`-origin sample.
- Accepted-run dataset manifest SHA-256:
  `159afc6fd0caf7290d42828bcc697520b043b02a078e7f4bacadae6e7476c8c1`.
- Accepted-run quality report SHA-256:
  `bc4c706dc28d5b0f6da63b68cf64e4e66cc99a992de304b2f9466529027a0b0a`.
- Accepted-run audit SHA-256:
  `08bdbfb2a7aecfaf153d0636673cd2334de7747b94a66bb92456416c329a8917`.

## Final Compile Evidence

- MetaEditor MCP preflight: PASS; compiler build `6140`, target `x64`,
  `can_compile_file=true`.
- Final MCP `compile_file`: PASS, `0 errors, 0 warnings`, `25,376 ms`.
- Latest regenerated ignored `HFT_Grid_AI.ex5`: `293,838` bytes, modified
  `2026-08-31 13:31:06 -0400`, SHA-256
  `cfd0d5730947fcb7b78a73b1a7349382a77b30f2d0ec65d570fb9349135d98fd`.
- The accepted tester binary was captured separately from this documentation
  closeout compile; source anchors are identical and `.ex5` files remain
  ignored/generated artifacts.

## Bounded Strategy Tester Evidence

The accepted run is `v13_sprint8_acceptance_1d_fix9_20260831`. Its export-on
and matching export-off cases used XAUUSD, chart M3,
`PERIOD_M3 < PERIOD_M10 < PERIOD_H1`, real ticks, `EXNESS_SESSION`, USD
`1,000,000`, leverage `1:10000`, and `ExecutionMode=120` milliseconds over
`2026.06.29 00:00` through `2026.06.30 00:00`.

- Export on: `306,627` ticks, `460` bars, `2:52.304` test time,
  `2:57.379` total time, `158 MB`, final balance `1,000,102.64`.
- Export off: the same ticks, bars, broker events, and final balance;
  `3.501` seconds test time, `8.672` seconds total time, `140 MB`.
- Normalized `Trade`/`Trades` streams contain `408` lines per side and share
  SHA-256
  `9b88dc7181b21684373110b96d0182d45b8abc01f12b49a61af6980858ebd1be`.
- Export off created no V13 run directory.
- Tester-loaded binary: `293,474` bytes, SHA-256
  `0dfda46d0b1de75423978af431e1c1c011f8463a3c29a94880392a491c964896`.
- The natural export-on seal contains all twelve TSV files with
  `export_status=OK` and `completion_status=NATURAL`.
- It contains `51` origins, `204` structural plus `204` midpoint H1 lanes,
  `51` broker-parity trials/outcomes, `277` M10 events, `2,449` parent links,
  `831` shared deep trials, `7,347` deep parent outcomes, `204` execution
  checks, and `51` broker outcomes.
- H1 matrix outcomes are `108` TP, `244` SL, `40` not-triggered, and `16`
  run-censored; the run-summary aggregate also includes `26` TP and `25` SL
  broker-parity outcomes.
- Duplicate-identity, referential-integrity, row-integrity, and parity-terminal
  mismatch counts are all zero. Parent-exit and run-end censors remain outside
  binary losses.

## Timing Interpretation

The tester's configured `120 ms` execution delay prevents this run from proving
sub-120 ms latency, perfect intra-second fill ordering, or exact exchange-level
tick sequencing. V13 timestamps are broker-time seconds; same-second facts are
accepted only through the EA's causal processing order, immutable entry/SL/TP
geometry, terminal reconciliation, and consistent cross-file identities. No
handoff claim depends on sub-second precision.

## Acceptance Boundary

The V13 producer is accepted for offline handoff and Django contract alignment.
Human chart-object/rendering inspection remains outstanding and is required
before any deployment-oriented claim. This handoff does not authorize live
rollout, execution filtering, runtime model loading, online learning, V12 data
deletion, or bypassing the downstream destructive-cutover gate.
