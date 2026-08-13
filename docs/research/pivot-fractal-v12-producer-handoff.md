# Pivot Fractal V12 Producer Handoff

This record freezes the accepted strict V12 producer resources for downstream
Django execution. The August 13 real-tick acceptance is recorded in
`docs/research/pivot-fractal-v12-producer-acceptance-2026-08-13.md`.

## Contract Identity

- Schema: `12`
- Engine: `PIVOT_FRACTAL_V2`
- Feature set: `schema_v12_pivot_signal_features`
- Storage root: `Common\Files\PivotFractalV12\runs\<run_id>\`
- Accepted producer source commit: `a4f6254c6610fc5a6d5600dd2a36be8b1ef02c30`
- Contract source commit: `187bfef815cf51bd7258b4d4398d69f59fe64eb6`
- Validator: `tools/deterministic_signal_ml/schema_contract.py`
- Validator SHA-256: `8ad8695bcbbc3aadda5bfefe146804d91f712ea55c1084b4cc39766e6471ef3b`
- Type-registry source: `tools/deterministic_signal_ml/build_dataset.py`
- Type-registry source SHA-256: `5de3480f206d08b4176e316be28057fb75d74c05f2ecb61ab95792c7c88473fc`
- Canonical registry SHA-256: `77237778f676bf087dcfd24749bc65b69ed602f9b078384fdaf40b695599bdad`
- Unique typed source columns: `464`
- Fixture tree SHA-256: `57606c858f66beff7d5822119e261933ada6221eea1242a29fad0a94784da673`

The canonical registry hash is SHA-256 of compact sorted JSON for
`build_dataset.COLUMN_TYPE_BY_NAME` using separators `(',', ':')`. The fixture
tree hash is built in filename order from `filename + NUL + file bytes` for all
eight files in the fixture directory.

## Vendoring Boundary

Django should vendor these resources only after final producer acceptance:

- `tools/deterministic_signal_ml/schema_contract.py` byte-for-byte;
- the explicit V12 type groups/registry from
  `tools/deterministic_signal_ml/build_dataset.py`;
- `tools/deterministic_signal_ml/tests/fixtures/schema_v12_pivot_signal_features/`;
- this handoff record plus the final V12 acceptance record.

The acceptance commit contains documentation and the Python derived-table
correction only. The accepted producer source commit above is the immutable
MQL5 runtime pin; Django should vendor the corrected builder bytes from the
acceptance commit.

V11 compatibility code, conversion logic, archived fixtures, raw private runs,
Parquet datasets, audit outputs, models, binaries, and compile logs are not part
of the vendorable contract.

## Feature Grain

`signal_origins.tsv` owns the immutable trigger-time Micro/Macro feature
vector. `%B`, Stochastic `MAIN_LINE`, and Stochastic `SIGNAL_LINE` export raw,
SMA 5, SMA slope, and state for shifts `0..5`; Bands `BASE_LINE` exports raw and
point slope for the same shifts; Micro/Macro width points are shift `0` only.
Virtual trials and retries join by origin and must not duplicate or recapture
indicator features.

## Accepted Evidence

- Strict fixture schema, formula, mutation, and V11-rejection tests pass.
- The explicit type registry is exhaustive and disjoint: `464/464` columns.
- The natural XAUUSD V12 run validates, builds, audits, and trains all six
  offline XGBoost ablations on `35,431` eligible rows.
- All `170` origin signal features are available for all `1,445` origins.
- The corrected `initial_matrix_wide.parquet` has `306` unique columns; each
  Micro/Macro width-points field occurs exactly once.
- No runtime model artifact or execution filter exists.

## Downstream State

The dependent Django plan may now consume V12 as authoritative. This handoff
does not authorize live MT5 rollout, runtime model loading, or deletion of
historical V11 evidence. Visual chart behavior remains an explicitly waived,
unverified residual risk; dataset acceptance is authoritative for this cutover.
