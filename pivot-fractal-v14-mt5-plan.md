# Plan: V14 MT5 Feature Capture And Producer Handoff

**Generated**: 2026-09-16
**Status**: Execution authorized; see `docs/README.md` for current progress.
**Complexity**: High. Four ordered sprints, M1-M4.
**Proposal**: [Accepted proposal](pivot-fractal-v14-feature-capture-proposal.md)
**Consumer plan**: [Django V14 plan](/home/admin/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v14-django-plan.md)

## Outcome And Boundaries

Replace the active V13 producer/offline contract with V14. Macro origins capture
Macro + Deep features; Deep events capture Deep + Micro features. Discover all
existing Deep pivot directions during eligible active Macro lifecycles and retain
ALIGNED/OPPOSED relationships per frozen parent link. Deliver a small, validated
initial-2015 XAUUSD dataset to Django. Do not implement standalone Deep capture,
change the structural Macro 1R execution policy, add live model inference, repair
GBPJPY conversion history, or run a full-history backtest.

The user's subsequent request to execute the MT5 sprints authorizes the scoped
implementation, native tester jobs and one commit per sprint. Django execution
and live rollout are outside this authorization.

## Decisions And Readiness

| Decision | Accepted scope and source |
| --- | --- |
| Timeframes | Explicit answer 1: QA H2/M15/M3. Keep public H1/M10/M3 defaults and strict supported-period ordering. |
| Deep coverage | Explicit answer 2: both directions only while eligible Macro parents are active. |
| Compatibility | Explicit answer 3: V14-only active code and tools; remove deprecated V13 runtime and related dead code in both projects. |
| Existing data | Original MT5 exports/recoveries remain intact. Explicit answer 4 authorizes only the Django plan's staging V13 dataset/research purge. |
| QA source | Latest clarification requires initial-2015 windows. Confirmed missing conversion history selects XAUUSD_Exness_2015; recent GBPJPY data is not a substitute. |
| Django limits | Staging and focused checks only; no broad QA or production deployment. |
| Work ownership | One writer per worktree, no delegated agents, no new MQL5 test harness/EA/script or CI. |

No required product question remains. Exact run IDs, source hashes, commit parents
and tester job IDs are execution receipts, not unanswered design choices. Recheck
branch/worktree ownership before execution; baseline HEAD is `8625222` on
`bot/pivot_points_fractal`. The proposal is a known untracked planning artifact.
The completed EURUSD plan is historical and must not be resumed.

## Shared V14 Contract

M1 owns the contract; Django consumes its final M4 pins without local reinterpretation.

| Surface | V14 rule |
| --- | --- |
| Version | Schema 14, feature set `schema_v14_hft_deep_pivot_features`, explicit `.h1` and `.deep_parent` model sets. Retain `PIVOT_FRACTAL_V2` as the unchanged pivot engine label. |
| Files | Retain the twelve TSV basenames and native grains. Root becomes `Common\\Files\\PivotFractalV14\\runs\\<run_id>`. New headers/policy IDs; reject V13 and earlier input. |
| Origin features | `origin_macro_*` and `origin_deep_*`; remove `origin_micro_*` from the active origin schema. |
| Event features | `deep_deep_*` and `deep_micro_*`, captured once per event. Add both block-completeness flags and `deep_feature_snapshot_complete`. |
| Parent links | Replace ambiguous link `direction` with `parent_direction`, `deep_direction`, and `direction_relationship` (`ALIGNED`/`OPPOSED`). |
| Deep outcomes | Keep outcome `direction` as the Deep execution direction; add `parent_direction` for unambiguous direct origin references. Validate against the frozen link. Do not copy features onto outcomes. |
| Identities | One consumed `(symbol, timeframe, active bar open, level)` identity; direction is an outcome. No second PP identity or retroactive parents. |
| Trials | Eight Macro lanes, one parity per accepted broker request, three shared Deep 1R/2R/3R trials and three outcomes per parent link. No Deep orders or 5R. |
| Capture | Each pair belongs to its own trigger time; shift-0 observations freeze as observed. Pivots use prior completed broker candles. Percent-B uses the touched pivot of the owning signal. |
| Indicators | Preserve Bands 21/0/2, SMA, PRICE_WEIGHTED; Stochastic 5/3/3, SMA, STO_CLOSECLOSE; existing raw/derived mathematics and shifts. No unrelated indicator-policy change. |
| Lifecycles | Same-tick parent terminal transitions precede discovery. Preserve own-lane entry times, exact durations/ages, actual broker close clocks, and non-binary censoring. |
| Capacity | Keep existing caps and atomic event admission. Record any rejection explicitly; do not silently truncate parents or raise limits without evidence. |
| Money | Preserve actual account-currency calculations, eligibility, 17-significant-digit serialization and strict finite-number validation. No pip-only substitute. |
| Ownership | Use `HFT_GRID_AI_PIVOT_FRACTAL_V14` for the new execution magic source; never adopt V13 positions. This changes ownership identity, not execution mathematics. |

Retain still-used H1/M10 role identifiers unless the new contract requires a change;
their actual periods come from the manifest. Do not turn this into an unrelated
rename. Old schema rejection fixtures, dated evidence and Git recovery references
are not runtime compatibility. Final contract counts/hashes must be computed,
never copied from the V13 181/99-feature or header pins.

## Named Resources

- Instructions and guides: `AGENTS.md`, `README.md`, `docs/README.md`,
  `docs/architecture/market-data-broker-executor.md`,
  `docs/environment/mt5-agentic-workflows.md`,
  `tools/deterministic_signal_ml/README.md`, `tools/exness_tick_history/README.md`.
- MQL5 entry/config: `HFT_Grid_AI.mq5`,
  `services/trading_management/indicator_definitions_loader.mqh`,
  `services/trading_management/pivot_fractal_engine_config.mqh`,
  `services/trading_management/ea_inputs.mqh`.
- Capture/runtime: `services/trading_signals/pivot_context_features.mqh`,
  `pivot_fractal_statistics_export.mqh`, `deep_pivot_signal_struct.mqh`,
  `deep_pivot_lifecycle.mqh`, `pivot_fractal_signal_detection.mqh`,
  `pivot_fractal_engine_state.mqh`, `pivot_trial_matrix_lifecycle.mqh` in that directory.
  Follow aggregator references through `services/trading_signals.mqh` and the other
  three entrypoint aggregators; versioned callback callers are in scope.
- Offline: `tools/deterministic_signal_ml/schema_contract.py`, `build_dataset.py`,
  `feature_encoder.py`, `validation_splits.py`, `model_config.py`, `train_model.py`,
  `pivot_fractal_audit.py`, `parent_chronology.py`, `report_writer.py`.
- Existing tests: `tools/deterministic_signal_ml/tests/test_pivot_fractal_schema.py`,
  `test_pivot_fractal_research_contract.py`, `test_pivot_fractal_audit.py`,
  `research_test_support.py`; move the active fixture generator into
  `tests/fixtures/schema_v14_hft_deep_pivot_features/` beneath that tooling directory.
- Execution artifacts: ignored `.codex-artifacts/pivot-fractal-v14/`; native tester
  configs/inputs under the terminal's `MQL5/Profiles/Tester/`, with retained copies
  in the ignored artifact directory. Preserve existing operator artifacts.
- Existing compiler fallback: `tools/mt5/compile_mt5.py`, only if discovered MCP
  cannot execute, with the failure reason recorded.
- Source evidence: `docs/research/exness-single-file-preparation-2026-09-09.md`,
  `docs/research/exness-custom-symbol-alignment-2026-09-09.md`; retained original
  XAUUSD and GBPJPY tick files/manifests are read-only inputs.
- Official references: [timeframes](https://www.mql5.com/en/docs/constants/chartconstants/enum_timeframes),
  [OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit),
  [tester cross-rate history](https://www.metatrader5.com/en/terminal/help/algotrading/testing_features).
  These were inspected during discovery; refresh only if platform behavior changes.

## Common Execution Gates

Every sprint must complete its tasks, pass its own checks, record residual risks,
create exactly one reviewed sprint-specific commit, and record its actual parent
as the rollback point before the next sprint starts. No amend/history rewrite,
blanket staging, binary/log commits or execution-state initialization during planning.

- Reconcile branch/status; trace includes/callback reachability and exact removed
  references. Review the broker/research boundary and `git diff --check` each sprint.
- Python gate when affected:
  `rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'`.
  Run the Exness tooling suite only if that tooling or its fixtures change.
- For source/include changes: discover MetaEditor tools, call its
  `get_workspace_info`, then `compile_file` with the absolute EA path,
  `no_optimization=false`, `target="AVX2"`. Require 0 errors, 0 warnings and a
  regenerated EX5 with size, mtime, SHA-256 and source/include hash mapping.
  First verify compilation cannot auto-reload an attached trading instance; use
  the existing tester isolation or an isolated copy of this actual EA when needed.
  Never attach it to a live chart as part of this plan.
- Native tester: discover MT5 tools and preflight its workspace. Prepare owned
  `.ini`/`.set`, use `tester_run_backtest(config_path=..., inputs_path=..., wait=false)`,
  retain the returned ID and use status/waits no longer than 60 seconds. A timeout
  does not stop the job; never duplicate it or stop an unrelated operator job.
- Reuse unchanged passing evidence. If cleanup changes source, recompile and rerun
  affected native checks; do not apply an earlier binary's acceptance to new bytes.

## Sprint M1: Freeze The V14 Offline Contract

**Goal**: A runnable V14-only validator/builder and meaningful fixture establish the
producer/consumer interface before MQL5 implementation.
**Dependencies**: Accepted proposal and clean ownership; no Django mutation.
**Commit**: `feat(research): define the V14 paired-timeframe dataset contract`
**Tracked scope**: Offline files/tests above, this plan/proposal and current research
guide sections needed to explain the new development contract.

### M1.1 - Define headers, directions and provenance

- Implement the shared contract in `schema_contract.py`: exact headers/types,
  completeness flags, manifest policies, direction relationship and outcome parent
  direction. Audit config compatibility keys and source identity validation.
- Update the existing fixture generator and move its active output to the named V14
  directory. Include one Deep event linked to opposed parents, both relationships,
  PP return, missing features, parent/run censors, invalid money and atomic rejection.
- Acceptance: every feature has one owner; link/event/parent directions reconcile;
  outcomes cannot reference an origin using the Deep direction accidentally.
- Validation: existing schema tests adapted to V14 plus focused malformed-direction,
  wrong-prefix, wrong-completeness and V13-rejection cases. Preserve a minimal
  rejection input without an old loader or a second active full fixture suite.
- Rollback: revert reviewed contract/fixture changes; original exports are untouched.

### M1.2 - Adapt builders, audits and offline model boundaries

- Update the named builder/encoder/audit/training files for the four feature prefixes
  and causal relationship fields. Retain native grains, actual ages, balanced support,
  purged chronology and exclusion of future outcomes/durations from model inputs.
- Explicitly separate Macro and Deep feature sets and ablations. Never join a later
  Deep event into a Macro trigger snapshot or compare V14/V13 as identical populations.
- Verify that one Deep event linked to parents from different Macro bars cannot
  appear in both training and validation. Extend the existing purging/split helper
  as needed to exclude shared training events; test all linked ratios/outcomes,
  without building a separate training framework.
- Acceptance: builds and audits reconcile the V14 fixture; old schemas reject;
  feature-count/type registries derive from the new contract without stale pins.
- Validation: full existing focused Python tooling suite; build and audit the fixture
  through the real CLI. Insufficient support remains explicit; do not weaken floors
  or start an expensive model search to obtain a passing result.
- Rollback: revert the builder/registry changes together with their matching fixture.

**M1 gate**: Python/fixture gates and static review pass; record contract/header/type/
fixture hashes as provisional producer pins; exactly one commit and rollback parent.
The still-V13 EA is not advertised as producing this new contract yet.

## Sprint M2: Implement The Complete V14 Producer

**Goal**: A compilable EA emits the full V14 semantics on a small native replay.
**Dependencies**: M1 contract/fixture commit.
**Commit**: `feat(mt5): capture paired features and both Deep directions in V14`
**Tracked scope**: Named MQL5 entrypoint, indicator/capture, Deep structures/lifecycle,
exporter and all required callers; focused contract tests if implementation exposes
a contract defect. Any header correction invalidates/recomputes M1 pins explicitly.

### M2.1 - Own and freeze the four feature blocks

- Extend existing indicator/capture helpers with cached Deep Bands/Stochastic handles:
  six handles total across Macro/Deep/Micro, none for export-off. Check partial init,
  deinit, fatal teardown and data retries; never create handles per tick.
- Capture Macro/Deep at the origin and Deep/Micro at the event. Derive percent-B
  separately against each owning pivot even when raw buffers are shared for a tick.
- Export incomplete blocks and their reasons without changing the broker lane.
- Acceptance: own/lower values, timestamps, shifts and completeness match independent
  formula checks; Macro exports contain no Micro feature block.
- Validation: reference/include sweep, compile gate, a short XAUUSD initial-2015
  replay and strict V14 validation; retain explicit early warm-up incompleteness.
- Rollback: restore the pre-sprint source and matching saved EX5; retain all run folders.

### M2.2 - Freeze both-direction parents and preserve exact lifecycles

- Replace the buy/sell admission restriction with all eligible active parents frozen
  before discovery. Export both directions and the per-link relationship; retain
  first consumption, PP arming, all existing pivot/quote/stop rules and no retro-links.
- Size/reserve the entire fan-out atomically, update outcomes in the Deep direction,
  and resolve each origin reference in the parent direction. Preserve actual confirmed
  broker close time and per-link censoring when another parent continues.
- Update all twelve-file headers/writers/seals and failure diagnostics to V14,
  fresh export roots, feature IDs and ownership magic. Set EA version 1.40; keep
  the unchanged pivot engine label and public defaults. Remove superseded V13
  function/constant names by updating callers, not by compatibility aliases.
- Acceptance: one event can have both relationships without duplicate trials;
  closed/unentered parents cannot enter the frozen set; no Deep send is reachable.
- Validation: compile and strict fixture/native checks for both relationships,
  shared outcomes, first PP consumption, same-tick exit and all failure/censor states.
- Rollback: revert this sprint as one source/EX5 unit. No adoption of old positions.

**M2 gate**: 0 errors/warnings, regenerated EX5, Python regression suite, a naturally
completed strict native sample, and broker/research review pass; one commit/parent.

## Sprint M3: Audit Initial-2015 Data And Broker Equivalence

**Goal**: Establish bounded native evidence for the new behavior and the Django source.
**Dependencies**: M2 source and EX5 pins.
**Commit**: `test(mt5): verify V14 capture on initial-2015 XAUUSD windows`
**Tracked scope**: Existing focused tests/contract owners and current evidence; only
scoped fixes if checks expose a defect. Raw runs/settings/reports remain ignored.

### M3.1 - Freeze the small historical replay matrix

- Main symbol: `XAUUSD_Exness_2015`, EXNESS_SESSION, source ticks unchanged/Shift=0.
  First window: 2015-08-10 00:00 through 2015-08-15 00:00, end exclusive. Use H2/M15/M3;
  run H1/M10/M3 as a default-ordering regression on the same short interval.
- Preserve normal money mode/size: fixed reference 1,000,000, 0.01 percent; simulated
  USD 1,000,000 and 1:10000, real ticks, no optimization, 50 ms recorded delay and
  `profit_in_pips=false`. Use identical settings for all compared on/off pairs.
- Treat early unavailable indicators as missing evidence, not fabricated prehistory.
  If particular lifecycle cases or positive Django workflow support are absent,
  add the adjacent 2015-08-17 through 2015-08-22 window; do not switch to recent data,
  launch the entire archive or silently reduce support thresholds.
- Assign unique run IDs such as `V14_XAUUSD_20150810_H2M15M3_<receipt>` and freeze
  broker clocks/settings/source bindings. Reuse the known GBPJPY missing-conversion
  evidence; its repair and full-archive acceptance remain outside this plan.
- Acceptance: native events include both link relationships and complete feature
  pairs after warm-up. If a required case is absent, record the gap and resolve it
  with the existing fixture/native workflow before claiming that case passed.
- Rollback: revert any scoped fixes; original runs and retained evidence remain intact.

### M3.2 - Run semantic, chronology and broker checks

Run in the repository, with the actual discovered run root and fresh artifact IDs:

```bash
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <V14-runs-root> --run-id <run-id> --validate-only
.venv/bin/python tools/deterministic_signal_ml/parent_chronology.py --runs-root <V14-runs-root> --run-id <run-id> --memory-limit-mb 4096 --report <ignored-report.json>
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root <V14-runs-root> --run-id <run-id> --dataset-id <fresh-dataset-id>
.venv/bin/python tools/deterministic_signal_ml/pivot_fractal_audit.py --dataset-id <fresh-dataset-id> --audit-id <fresh-audit-id> --minimum-group-support 30
```

- Compare V14 export-on/off ordered broker requests, fills, closes and report fields.
  Compare against a retained V13 baseline on the same small window where possible;
  permit only documented namespace/run-ID remapping, never price/time/volume/SL/TP
  differences. Keep numerical serialization and executed geometry unchanged.
- Check same-tick exits, midpoint/no-touch, all ratios, opposed parents, failed money,
  capacity accounting and sealed fatal-error teardown using existing fixtures and
  tester techniques. No new test EA or permanent injection switch.
- Record elapsed time, counts, peak states and export size against the matched small
  baseline. Investigate material regressions; retain existing caps and no silent loss.
- Acceptance: successful exports seal OK/NATURAL; failed/censored test cases reject
  exactly as intended. Chronology alone is not semantic acceptance.
- Rollback: use the M2 pin if a fix fails; never edit original exports to make tests pass.

**M3 gate**: Required native/fixture cases, semantic/chronology checks, on/off parity
and bounded resource evidence pass; one commit/parent. Record human chart/rendering
acceptance as observed or still open. An open chart gate forbids deployment claims
but does not block the separately scoped offline/Django handoff.

## Sprint M4: Remove Legacy Code And Freeze The Consumer Handoff

**Goal**: A clean V14-only checkout with exact, reproducible downstream artifacts.
**Dependencies**: M3 behavior/QA evidence.
**Commit**: `refactor(mt5): retire V13 paths and publish the V14 producer handoff`
**Tracked scope**: Proven-unused related source/tooling, seven guide/index owners,
fixture references, and a new `docs/research/pivot-fractal-v14-producer-handoff.md`.

### M4.1 - Finish removal and shorten current guidance

- Inventory V13/legacy runtime names, loader modes, full fixtures and old feature
  aliases. Prove non-use through exact references, dynamic discovery and include
  reachability, then delete obsolete paths; migrate still-used behavior to V14.
- Retire the superseded V13 handoff and completed EURUSD plan only after unique
  current facts and Git commit/path recovery move to their owning current guides.
  Preserve dated acceptance that still supports open gates, original data and private
  handoffs. The new plan is the sole current implementation plan.
- Update the seven existing guide/index owners in place; keep changing status solely
  in `docs/README.md` and AGENTS within 160 lines/8 KiB. Do not enlarge discovery limits.
- Validation: exact legacy-reference inventory with a reviewed allowance for negative
  tests/history; all live links/anchors, ignores, include order and diff whitespace.
  Recompile/retest changed behavior if source removal affects prior pins.
- Rollback: restore retired paths from their recorded Git parent, not a history reset.

### M4.2 - Publish final pins and the small native source

- Freeze final headers, canonical type/feature registry, validator, builder, fixture
  generator/tree and source/EX5 hashes. Handoff must state exact versions, feature
  owners, parent/outcome direction rules, missing-data semantics and test limits.
- Select one complete small initial-2015 native run for Django staging. Bind all
  twelve file hashes, row counts, source/config IDs, periods, interval, account
  currency, export/completion seal and validation evidence. Keep sidecars outside
  the strict twelve-file folder and the independent copy outside shared mutable runs.
- Provide immutable contract/source pins and selected dataset receipt to Django D1.
  Copy no credentials, large source archive or binary into either Git checkout.
- Validation: rerun hash/link/registry reconciliation against the exact final source;
  reuse native evidence only if its inputs remain unchanged. Any changed contract
  invalidates the downstream pin before Django development begins.
- Rollback: restore the last compatible source/EX5 and retain V14 artifacts under
  their original identities; consumers cannot silently downgrade or relabel them.

**M4 gate**: All removal/document checks and applicable final runtime gates pass;
handoff plus exact native source receipt exists; one commit/parent. Django D1 may
begin only after this gate and authorization to execute the Django plan.

## Risks, Rollback And Completion

| Risk | Mitigation and acceptance signal |
| --- | --- |
| Future leakage | Distinct trigger snapshots, previous completed pivot candles, blocked future columns and chronological group tests. |
| Opposed-parent geometry/reference error | Event direction owns Deep prices; parent direction owns origin references; fixture and native joins agree. |
| Larger fan-out | Atomic reservation, fixed caps, measured peaks and explicit rejections, never truncated parent sets. |
| Changed population | V14 version boundary; no claim that filtering recreates V13 first-consumption events. |
| Missing conversion history | Initial-2015 XAUUSD fallback; full-history GBPJPY stays an explicit separate task. |
| Cleanup regressions | Non-use proof, regenerated EX5 when applicable, focused tests and exact consumer pins. |

At execution handoff, read the installed Planner's `references/execution-state.md`
and initialize state for this plan only. Update it after each validation, commit,
blocker and sprint transition. Preserve all accepted decisions across interruptions.
Commit rollback is a reviewed reverse-order revert; source rollback needs its
matching EX5 or recompile. No original/recovered dataset is overwritten or deleted.

Completion requires four sprint commits with recorded parents; V14-only active
producer/offline tools; native-grain feature/direction/chronology acceptance;
broker on/off equivalence; concise current docs; and the M4 handoff. Record any
human chart or formal broker-equivalence gates as open. Neither these small windows
nor Django staging certify full-history, live trading or production readiness.
