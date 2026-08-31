# Pivot Fractal V13 Producer Handoff

**Status**: Sprint 7 contract draft. The downstream Django V13 cutover remains
closed until the final MetaEditor compile and human Strategy Tester/chart gate
are accepted in Sprint 8.

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
- Sprint 7 documentation commit: the commit containing this handoff (resolve
  with `git log -1 -- docs/research/pivot-fractal-v13-producer-handoff.md`)
- Final accepted producer commit: pending Sprint 8
- Validator: `tools/deterministic_signal_ml/schema_contract.py`
- Validator SHA-256:
  `774c737ddce861cefe960c382acd865a9f4fbf7488edd734b5b58f24fda2ea1d`
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
separate; this draft does not authorize it.

## Completed Static/Offline Evidence

- Python `compileall`: PASS.
- Complete contract suite: `35` tests, PASS.
- Strict V13 fixture validate/build: PASS.
- V13 fixture audit: PASS, `AUDIT_COMPLETE`.
- H1 and deep training loaders: PASS (`8` H1 rows, `5` deep rows).
- Fixture minimum-support gate: expected rejection (`8 < 500`, `5 < 500`).
- Fixture provenance SHA-256 verification: PASS.
- Sprint 6 `git diff --check`: PASS.

## Pending Sprint 8 Evidence

- MetaEditor MCP workspace/compiler metadata: pending.
- Final `compile_file` result (`0 errors, 0 warnings`): pending.
- Regenerated V13 `.ex5` timestamp/size/SHA-256: pending.
- Human real-tick Strategy Tester/chart matrix: pending.
- Produced V13 run validation/build/audit and export-on/off parity: pending.
- Final accepted producer and Sprint 8 commit: pending.

Until every pending item is complete, this handoff is contract-ready but not an
accepted producer release. It does not authorize live rollout.
