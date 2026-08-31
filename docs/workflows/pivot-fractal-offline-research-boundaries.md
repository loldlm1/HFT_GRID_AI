# Pivot Fractal V13 Offline Research Boundaries

This workflow starts from strict Pivot Fractal V13 producer exports and ends
in local typed DuckDB/Parquet datasets, deterministic audits, reports, and
offline model candidates. It never loads a model into MT5, authorizes an order,
or turns a retrospective selector into a runtime filter.

Use `docs/workflows/pivot-fractal-statistics-flow.md` for the operator sequence
and `docs/research/pivot-fractal-v13-producer-handoff.md` for the pinned
producer contract. V12 documents, fixtures, and runs are historical evidence;
they are not converted, dual-written, or accepted by active tooling.

## Runtime Separation

```text
causal H1 pivot trigger
-> one structural H1 1R broker decision inside MQL5
-> H1 structural/midpoint virtual lanes and shared M10 evidence
-> strict V13 export seal
-> typed validation and native-grain derived artifacts
-> leakage-safe audit and explicit H1/deep offline training
```

- Export, virtual lanes, deep events, and offline artifacts cannot authorize,
  deny, delay, resize, duplicate, close, or modify the broker lane.
- MT5 owns broker session, permissions, Bid/Ask, pivot geometry, stops/freeze,
  volume, margin, `OrderCheck`, send retcodes, magic, tickets, and reconciliation.
- Missing or malformed feature data makes research evidence incomplete while an
  independently valid broker decision remains unchanged.
- No runtime model loader, score, pattern matcher, online learner, or execution
  filter exists in this boundary.

## Strict V13 Intake

The validator accepts schema `13`, engine `PIVOT_FRACTAL_V2`, feature set
`schema_v13_hft_deep_pivot_features`, and exactly these twelve files under
`Common\\Files\\PivotFractalV13\\runs\\<run_id>\\`:

1. `run_manifest.tsv`
2. `pivot_windows.tsv`
3. `signal_origins.tsv`
4. `virtual_trials.tsv`
5. `virtual_outcomes.tsv`
6. `deep_pivot_events.tsv`
7. `deep_pivot_parent_links.tsv`
8. `deep_virtual_trials.tsv`
9. `deep_virtual_outcomes.tsv`
10. `execution_checks.tsv`
11. `broker_outcomes.tsv`
12. `run_summary.tsv`

Every header and column type is frozen. The validator rejects unknown files,
unknown columns, V12 roots/headers, mixed configurations, partial fan-out,
orphan links, and incompatible timeframe, quote, geometry, capacity, money, or
feature policies. It never migrates an older run in place.

## Native Evidence Boundary

- `signal_origins.tsv` owns one immutable H1 Micro/Macro feature vector per
  consumed H1 identity.
- `virtual_trials.tsv` and `virtual_outcomes.tsv` own the eight H1 lanes:
  `STRUCTURAL` and `MIDPOINT_50`, each at `1R`, `2R`, `3R`, and `5R`.
- `deep_pivot_events.tsv` owns one configured-Micro vector per shared causal
  M10 event. The default source is M3, but the manifest's actual timeframe is
  authoritative.
- `deep_pivot_parent_links.tsv` owns the active H1 parent association and its
  exact `m10_parent_age_seconds`.
- `deep_virtual_trials.tsv` owns shared M10 `1R/2R/3R` geometry; deep outcomes
  resolve each `(parent_link_id, deep_trial_id)` pair independently.
- `broker_outcomes.tsv` owns actual fills, closes, costs, and realized R. A
  parity shadow is calibration-only and never enters an H1 or deep target cohort.

Features remain at their native grain. Joining an M10 event feature onto a
parent/ratio row is allowed only inside the explicit deep trainer and must not
be persisted as duplicated source evidence.

## Causal And Retrospective Time

The producer stores exact non-negative broker-time seconds without rounding or
an upper bound:

```text
h1_structural_lifecycle_seconds = completed parent close - parent entry
m10_parent_age_seconds = M10 trigger - parent entry
```

The H1 duration is known only after a virtual or broker parent has closed. It is
therefore a retrospective segmentation field, not a causal feature or a
deployable execution condition. `NOT_TRIGGERED`, `INELIGIBLE`, and
`CENSORED_RUN_END` rows keep it null. The M10 age is known at event time and is
valid only for the linked parent.

The downstream application exposes two independent, inclusive selectors:

```text
h1_structural_lifecycle_seconds <= h1_minutes * 60
m10_parent_age_seconds <= m10_minutes * 60
```

Applying both selectors is an explicit AND at research time. A value such as
`h1_minutes=30` excludes M10 links whose parent age is outside the selected
parent lifecycle cohort, but it does not delete later raw events, cap producer
capture, or relabel censored evidence. There is no implicit 30/60/120-minute
maximum.

## Target And Leakage Boundary

The primary binary cohorts contain only feature-complete, eligible
`TP_FIRST`/`SL_FIRST` rows. Censored, ineligible, not-triggered, capacity,
parity, denied, failed-send, and incomplete rows remain auditable facts with no
binary target. Broker P&L, terminal status, close time, lifecycle duration,
parent age after selection, and any other future-only value are prohibited from
model features.

H1 and deep training are separate selections:

- H1 reads `eligible_h1_trials.parquet` and balances support by `origin_id`.
- Deep reads `eligible_deep_trials.parquet`, joins event features explicitly,
  and reports parent/event/origin support separately.

Chronological partitions keep all rows for one H1 active bar together across
duplicate runs. A training row must terminate strictly before the validation
boundary. Analysis time is presentation/grouping metadata only and never
reorders causal events.

## Artifact And Promotion Rules

Generated datasets, audits, reports, and models stay under ignored `artifacts/`
directories. Model manifests must state the evidence grain, cutoff, weighting,
warnings, `approval_state=OFFLINE_RESEARCH_ONLY`, and
`runtime_artifact_emitted=false`.

The V13 producer handoff is not a deployment approval. Downstream Django may
prepare from the accepted contract after the final compile and bounded
real-tick tester evidence are recorded; the human chart-object/rendering check
remains a separate outstanding gate. Its explicit V12 removal/deletion work
also remains a separately authorized change. No live rollout is authorized by
this workflow.

## Historical Boundary

V12 and earlier plans, acceptance records, fixtures, datasets, and raw runs stay
under their existing archive paths as immutable historical material. They may be
consulted for provenance, but active V13 validation never rewrites, relabels,
or combines them.
