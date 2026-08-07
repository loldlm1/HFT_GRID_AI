# Plan: Strict V11 Dataset Column Type Registry Correction

**Generated**: 2026-08-07
**Status**: Active implementation; ordered sprint state is hook-managed
**Estimated complexity**: Medium
**Risk class**: Medium - changes offline TSV-to-DuckDB typing and research
artifacts only; broker execution, MQL5 runtime, schema headers, and raw evidence
must remain unchanged
**Execution baseline**: Branch `bot/pivot_points_fractal`, commit
`0e2f7291ffd5b1cecb5bac2a9b95f0bdf8a1c2dc`

## Goal

Replace heuristic V11 dataset column typing with an exhaustive frozen registry,
prove every strict schema column has exactly one declared type, and rerun the
official validate/build/audit/train pipeline against the accepted XAUUSD
January-July evidence.

The confirmed defect is narrow: `execution_checks.block_source` contains valid
text such as `broker_close`, but the official builder defaults unrecognized
columns to `DOUBLE`. A diagnostic text override already proves the raw run and
derived research logic are sound. This plan makes that correction official and
prevents future schema columns from silently inheriting a numeric type.

## Scope And Fixed Decisions

- Keep strict schema version 11, all eight TSV headers, manifest tokens, table
  grains, model features, and target semantics unchanged.
- Define explicit `STRING`, `TIMESTAMP`, `BOOLEAN`, `INTEGER`, and `FLOAT`
  membership for every unique column in `TABLE_COLUMNS`.
- Fail at import/test time when a schema column is missing from the registry,
  appears in multiple type groups, or an obsolete registry entry remains.
- Type `block_source` as string and add a populated `broker_close` regression,
  not merely a null-only fixture assertion.
- Preserve raw Common Files evidence, failed/diagnostic artifacts, V9/V10
  fixtures, and archived V11 history.
- Use the accepted run
  `2026.01.05_00_00_00_XAUUSD_pivot_v11` for the official full regression.
- Measure strict validation, build, audit, and training wall time and peak RSS.
- Do not change `.mq5`/`.mqh`, broker behavior, public inputs, the `.ex5`, or
  compile artifacts. No MetaEditor compile is required.
- Do not add MQL5 harnesses, test EAs/scripts, CI, or Strategy Tester automation.
- Live rollout and runtime model loading remain unauthorized.

## Sprint 1: Freeze Explicit V11 Column Types

**Goal**: Remove heuristic/fallback typing and make the V11 loader contract
complete, reviewable, and fail-closed.

**Tracked scope**:

- `tools/deterministic_signal_ml/build_dataset.py`
- `tools/deterministic_signal_ml/tests/test_pivot_fractal_research_contract.py`
- active plan/index documentation

**Commit**: `fix: freeze explicit v11 dataset column types`

### Tasks

1. Replace suffix-based string inference and default `DOUBLE` casting with
   five explicit frozen column sets and one derived name-to-type registry.
2. Validate registry disjointness and exact parity with all unique
   `TABLE_COLUMNS` names before dataset assembly can run.
3. Make `_typed_expression()` reject unknown columns rather than guessing.
4. Add tests for exact registry coverage, `block_source` string typing, and a
   complete fixture build containing `block_source=broker_close`.
5. Run Python compileall, the full existing contract suite, deterministic
   fixture validate/build/audit, expected training support guard, exact
   schema/header references, and `git diff --check`.

### Acceptance Gate

- [x] Every V11 schema column has exactly one explicit type.
- [x] `block_source` loads populated text without a DuckDB conversion error.
- [x] Unknown, duplicate, and stale registry entries fail closed.
- [x] All Python and fixture checks pass.
- [x] No MQL5/runtime/schema-header behavior changes.
- [x] Exactly one Sprint 1 commit is created; its SHA is recorded in Sprint 2.

**Sprint 1 evidence**:

- Registry coverage: 333 unique columns exactly once - 55 `VARCHAR`, 28
  `TIMESTAMP`, 39 `BOOLEAN`, 73 `BIGINT`, and 138 `DOUBLE`.
- Populated regression: a cloned strict fixture with
  `block_source=broker_close` validates and builds as DuckDB `VARCHAR`.
- Python compileall passes; all 28 contract tests pass in 9.176 seconds.
- Fixture validate/build/audit passes with the expected
  `INSUFFICIENT_SUPPORT`; training fails closed at `16 < 500` as designed.
- Exact raw query/eight-file hashes remain unchanged, no MQL5 or compile
  artifact is modified, and `git diff --check` passes.

**Sprint 1 commit**: `a5547c3adf99b1bae615309b67fc0884a75958e7`.

**Rollback point**: `0e2f729`.

## Sprint 2: Official Full-Run Regression And Performance Evidence

**Goal**: Prove the unmodified accepted raw run succeeds through the official
toolchain without the diagnostic override and record bounded offline cost.

**Tracked scope**:

- Git-ignored dataset, audit, model, and timing artifacts
- this plan and compact research documentation

**Commit**: `docs: record official v11 dataset registry acceptance`

### Tasks

1. Re-run strict validation against the accepted raw run and record wall time,
   peak RSS, and validated row counts.
2. Build the official dataset under a new artifact ID without monkeypatching or
   editing raw TSV files; verify all 13 Parquet table counts.
3. Run the official pivot audit and require 7,032 strict parity matches, zero
   mismatches, and the expected explicit exclusions.
4. Run offline training on the official dataset and record eligible rows,
   timing, memory, and offline-only approval state.
5. Compare official and prior diagnostic counts, inspect output sizes, and
   decide whether any safe optimization is justified without changing
   behavior.
6. Re-run the full Python/static validation gate and `git diff --check`.

### Acceptance Gate

- [x] Official validate/build/audit/train completes without an override.
- [x] Dataset and audit counts exactly match the accepted diagnostic evidence.
- [x] Raw query and eight TSV hashes remain unchanged.
- [x] Offline time/memory/file growth are measured and bounded.
- [x] Any optimization recommendation preserves strict deterministic behavior.
- [x] Exactly one Sprint 2 commit is created; its SHA is recorded in Sprint 3.

**Sprint 2 evidence**:

- Strict validate: 7,178 origins, 186,036 trials, 185,788 outcomes;
  119.08 seconds and 1,935,292 KB peak RSS.
- Official build: dataset
  `v11_type_registry_xauusd_20260105_20260731`; 181.15 seconds and
  1,935,524 KB peak RSS. The build includes its own strict validation.
- Official table counts exactly match the diagnostic build: 3,412 windows,
  7,178 origins, 186,036 trials, 185,788 outcomes, 178,982 matrix-long rows,
  7,178 initial-wide rows, 114,848 chains, 7,054 calibration rows, and 178,701
  eligible ML rows.
- `block_source` is DuckDB `VARCHAR` for all 28,466 checks: 21,166 null,
  7,054 `broker_close`, 134 `market_session`, 104 `sl_tp_geometry`, six
  `volume`, and two `order_send` rows.
- Official audit
  `v11_type_registry_xauusd_20260105_20260731_audit` completes in 2.36 seconds
  at 158,948 KB peak RSS with 7,032 strict pairs, 7,032 matches, and zero
  mismatches.
- Official model
  `v11_type_registry_xauusd_20260105_20260731_model` trains 178,701 rows in
  746.65 seconds at 2,024,896 KB peak RSS. All four ablation metrics exactly
  match the diagnostic run; approval remains `OFFLINE_RESEARCH_ONLY` and no
  runtime artifact is emitted.
- Official artifact sizes are 84,614,794 dataset bytes, 3,302,417 audit bytes,
  and 147,935,571 model bytes. All 13 Parquet tables are semantically identical
  to the diagnostic build; 12 are byte-identical and `virtual_outcomes` has
  equal schema plus zero rows in either `EXCEPT ALL` direction.
- Python compileall and all 28 tests pass again; raw hashes remain exact and no
  MQL5, `.ex5`, compile log, query, or TSV content changes.

**Performance decision**: no source optimization is justified. The explicit
registry adds no meaningful cost, audit is cheap, and training dominates the
offline workflow. For routine builds, skip a separate `--validate-only` pass
because the build command validates internally. For Strategy Tester speed,
keep file logging disabled outside evidence runs. The accepted approximately
3m55s export-enabled, file-logged seven-month run and 83/2,048 peak EA state do
not justify changing the bounded MQL5 hot path.

**Rollback point**: `a5547c3` (Sprint 1).

## Sprint 3: Closeout, Archive, And Hook Cleanup

**Goal**: Record the correction ledger, archive this focused plan, return active
planning state to none, and leave the workspace ready for the user's renewed
human real-tick evidence.

**Tracked scope**:

- this plan
- `AGENTS.md`
- `docs/plans/README.md`
- `docs/research/README.md`
- dated plan/research archive README files
- active plan-hook state

**Commit**: `docs: close out v11 dataset type registry correction`

### Tasks

1. Record Sprint 1-2 SHAs, validations, artifact IDs, timings, memory, hashes,
   rollback points, and residual restrictions.
2. Mark this plan completed, move it to a dated archive, and update active
   indexes without editing prior archives.
3. Validate the archive links and workspace diff, create the single Sprint 3
   commit, mark hook state complete, and remove disposable hook JSON files.
4. State the next human gate: a renewed real-tick run may confirm operational
   behavior, but this Python-only correction does not require `.ex5`
   regeneration.

### Acceptance Gate

- [ ] The official offline pipeline is accepted and documented.
- [ ] No MQL5 source or binary changed.
- [ ] The plan and compact evidence are archived with correct links.
- [ ] Exactly one Sprint 3 commit is created and recorded.
- [ ] Active hook state is completed and cleaned.

**Rollback point**: Sprint 2 commit.

## Validation Strategy

- Python: compileall and all existing `unittest` contract modules.
- Fixture: strict validate, official build, audit, and expected insufficient
  support training guard.
- Real evidence: strict validate, official build, audit, and offline training
  using the preserved eight-file run.
- Contract sweeps: exact registry coverage, eight-file headers, manifest
  tokens, V11-only acceptance, V9/V10 rejection, and future-feature leakage.
- Safety: verify no `.mq5`, `.mqh`, `.ex5`, compile log, raw query, or raw TSV
  diff/hash change.
- Performance: `/usr/bin/time` wall time and peak RSS plus artifact byte size;
  prefer no optimization unless evidence shows material avoidable overhead.

## Execution Order

1. Initialize hook state at Sprint 1.
2. Implement, validate, and commit Sprint 1 only.
3. Advance exactly one sprint and run the complete official pipeline.
4. Document and commit Sprint 2 only after every regression gate passes.
5. Advance to Sprint 3, archive, validate, commit, complete hook state, and
   remove disposable hook files.
6. Do not invoke MetaEditor or Strategy Tester during this plan.

## Completion Checklist

- [ ] Explicit type registry exactly covers strict V11.
- [ ] Populated `block_source` text is regression-tested.
- [ ] Official accepted-run dataset, audit, and model artifacts succeed.
- [ ] Diagnostic and official counts match.
- [ ] Performance evidence is recorded without speculative runtime changes.
- [ ] Raw evidence and MQL5 behavior remain unchanged.
- [ ] Three ordered sprint commits and rollback points are recorded.
- [ ] Plan archive and hook cleanup are complete.
