# Pivot Fractal V12 Producer Acceptance

## Decision

The strict V12 producer is accepted as the authoritative source for the
dependent Django research-app cutover. This acceptance covers dataset and
nonvisual Strategy Tester behavior. The user waived visual-window verification;
chart rendering remains an unverified residual risk and does not block dataset
consumption.

This acceptance does not authorize live rollout, runtime model loading, online
learning, or execution filtering.

## Provenance

- Accepted producer source: `a4f6254c6610fc5a6d5600dd2a36be8b1ef02c30`
- Producer rollback point: `a4f6254c6610fc5a6d5600dd2a36be8b1ef02c30`
- Compiler/terminal build: MetaTrader `6090`, X64
- Pre-run workspace EA: `245,940` bytes, SHA-256
  `83e55b498c81728776b41ad93fb95f6f3c56dd5332ed0b627e862c7a4be43388`
- Strategy Tester loaded one identical transferred package for both matched
  sessions, reported as `245,979` bytes.
- Post-audit MetaEditor MCP compile: `0 errors, 0 warnings`, `11,814` ms.
- Refreshed workspace EA: `245,208` bytes, SHA-256
  `553af41908b3061978bba8b5643110b92765953ef3429654ce1d03aa0db2ab84`.
  The refreshed artifact was not substituted into the already completed paired
  tester evidence; it proves the accepted source still compiles cleanly.
- Validator SHA-256:
  `8ad8695bcbbc3aadda5bfefe146804d91f712ea55c1084b4cc39766e6471ef3b`
- Builder/type-registry source SHA-256:
  `5de3480f206d08b4176e316be28057fb75d74c05f2ecb61ab95792c7c88473fc`
- Canonical 464-column registry SHA-256:
  `77237778f676bf087dcfd24749bc65b69ed602f9b078384fdaf40b695599bdad`
- V12 fixture tree SHA-256:
  `57606c858f66beff7d5822119e261933ada6221eea1242a29fad0a94784da673`

## Matched Tester Evidence

Both nonvisual sessions used XAUUSD M3, Macro H1, `EXNESS_SESSION`, real ticks,
2026-06-29 through 2026-08-09, initial deposit USD 1,000,000, leverage 1:10000,
120 ms execution delay, reference-balance-percent sizing at `0.01`, and both
debug log switches disabled. Only `Enable_Signal_Feature_Export` changed.

| Measurement | Export off | Export on |
| --- | ---: | ---: |
| Ticks | 8,826,608 | 8,826,608 |
| Bars | 13,680 | 13,680 |
| Tester elapsed | 29.782 s | 130.870 s |
| Peak tester memory | 342 MB | 355 MB |
| Dataset folder | 0 bytes | 52,738,715 bytes |

The normalized Trade/Trades event streams contain `11,450` lines each and have
the same SHA-256,
`79e1e65f0a7452764c2207ea626b2e2e668a46c2a37a3c3d7cfdff74a9a8d580`.
Therefore feature export did not change observed broker orders, fills, or
terminal outcomes in the matched run.

## Raw V12 Result

The immutable run `test_run_1` contains exactly the eight strict TSV files and
ends `export_status=OK`, `completion_status=NATURAL`:

- `684` pivot windows and `1,445` signal origins;
- `36,966` virtual trials: `35,535` matrix, `12,415` retries, and `1,431`
  broker-parity shadows;
- exactly `16` index-0 matrix cells for every origin;
- `36,914` virtual outcomes, with `52` explicit run-end censors;
- active-state peak `76/2,048`, with no capacity failure;
- zero duplicate identities, referential errors, or row-integrity errors;
- `1,431` broker outcomes: `702` TP, `726` SL, and `3` manual tester-end closes;
- `1,431` successful sends, `2` explicit `Invalid stops` failures, and `12`
  structural pre-send geometry denials;
- `1,418` strict parity pairs with `1,418` terminal matches and zero mismatches.

All `170` signal features are present on every origin. Shift-0 values remain
unclipped: Micro `%B` ranges from `-75.1383` to `181.9662`, and Macro `%B` from
`-32.1415` to `140.2661`. All four Stochastic shift-0 lines remain within
`0..100`.

Independent recomputation covered `34,680` formula observations across all
origins: Micro/Macro shift-0 `%B`, SMA5 and slope for `%B`, Stochastic
`MAIN_LINE` and `SIGNAL_LINE`, plus Band `BASE_LINE` slopes. No value exceeded
the frozen tolerance; maximum observed reconstruction error was below `1e-7`.

## Offline Pipeline And Correction

Strict validation, typed Parquet build, audit, and the full six-ablation XGBoost
training path pass on `35,431` eligible rows. The artifacts remain ignored,
offline-only, and emit no runtime-compatible model:

- dataset: `21,657,268` bytes;
- audit: `689,175` bytes, `AUDIT_COMPLETE`;
- models/reports: `41,664,714` bytes;
- chronological partitions: `28,241` training rows and `7,132` holdout rows;
- approval state: `OFFLINE_RESEARCH_ONLY`;
- `runtime_artifact_emitted=false`.

The audit found one derived-artifact defect while the raw TSVs remained valid:
`initial_matrix_wide.parquet` selected the two width-points fields twice and
DuckDB silently added `_1` aliases. The builder now selects those fields only
through the frozen origin feature list. Regression coverage requires each field
exactly once and forbids the suffixed aliases. The rebuilt wide table has `306`
columns, all unique. The raw schema, 464-column type registry, targets, and
broker behavior are unchanged.

## Validation Gate

- strict produced-run validation: PASS;
- complete Python suite: `29` tests PASS;
- Python `compileall`: PASS;
- `git diff --check`: PASS;
- raw-to-derived build and audit: PASS;
- six offline XGBoost ablations: PASS;
- matched export-off/export-on broker event parity: PASS;
- visual chart/window verification: NOT RUN, explicitly waived by the user.

The dependent Django plan may consume the pinned V12 contract and acceptance
record. Historical V11 datasets and archives remain preserved and must not be
converted or relabeled as V12.
