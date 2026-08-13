# Pivot Fractal V12 Producer Handoff

This record freezes the strict V12 contract resources for downstream Django
preparation. It does not declare runtime acceptance or authorize the Django
cutover. Final producer acceptance still requires the Sprint 6 MetaEditor
compile and human real-tick Strategy Tester/chart gate.

## Contract Identity

- Schema: `12`
- Engine: `PIVOT_FRACTAL_V2`
- Feature set: `schema_v12_pivot_signal_features`
- Storage root: `Common\Files\PivotFractalV12\runs\<run_id>\`
- Contract source commit: `187bfef815cf51bd7258b4d4398d69f59fe64eb6`
- Validator: `tools/deterministic_signal_ml/schema_contract.py`
- Validator SHA-256: `8ad8695bcbbc3aadda5bfefe146804d91f712ea55c1084b4cc39766e6471ef3b`
- Type-registry source: `tools/deterministic_signal_ml/build_dataset.py`
- Type-registry source SHA-256: `bf3a28208b2b2e9c30fdb0935d99f7e4b93b23d1bfe100d2d94fd358b6351e3c`
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

## Current Evidence

- Strict fixture schema, formula, mutation, and V11-rejection tests pass.
- The explicit type registry is exhaustive and disjoint: `464/464` columns.
- The fixture validate/build/audit pipeline emits eight raw plus five derived
  Parquet tables, `170` feature-availability records, and the expected offline
  XGBoost support guard (`16 < 500`).
- No runtime model artifact or execution filter exists.

## Pending Acceptance

The downstream Django plan remains blocked from implementation/cutover until a
later acceptance record names the final producer commit and proves:

- MetaEditor MCP compile with `0 errors, 0 warnings` and `.ex5` regeneration;
- a natural strict V12 real-tick run with `export_status=OK` and zero integrity
  errors;
- human reproduction of selected causal Bands/Stochastic features;
- export-on/off behavior parity and bounded performance evidence.

