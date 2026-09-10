# Plan: Project Guidance, Documentation, And Dead-Code Cleanup

**Generated**: 2026-09-10
**Status**: In progress - Sprint 1
**Execution authorization**: User requested ordered execution of Sprints 1-3, validation and sprint commits on 2026-09-10. Accepted decisions remain in force.
**Proposal**: Not requested; direct Planner plan with questions.
**Estimated complexity**: Medium, with a high-consequence broker boundary that must remain unchanged.

## Overview

Reduce the project's checked-out documentation to a small, current V13 reference
set, align project instructions with the installed skill/plugin stack, and remove
code only where non-use or equivalent behavior can be demonstrated. Older detail
remains recoverable from Git. This is maintenance of the existing collector,
offline research tools, and structural broker lane, not a strategy upgrade.

Discovery baseline is commit `bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93` on
`bot/pivot_points_fractal`. The checkout was clean and five commits ahead of its
remote-tracking branch. Do not reset, rewrite, or publish that existing history.

| Discovery fact | Planning implication |
| --- | --- |
| 119 tracked Markdown files, totaling 2,186,770 bytes | Target 14 permanent documents plus this one plan during execution/closeout. |
| 69 archived plan files and 26 archived research files | Delete obsolete checkout copies through reviewed Git changes. |
| 24 documents outside archive directories | Consolidate overlapping guides and superseded status records. |
| `AGENTS.md` is 317 lines / 16,543 bytes | Target at most 160 lines / 8 KiB, preserving critical constraints. |
| `docs/addons/base.md` describes V10, six TSVs and two handles as active | Retire this guide; use the current V13 architecture contract. |
| Research index selects the older Exness handoff | Establish one maintained current-status index. |
| EA property version is `1.30`; export schema is `13` | Document these distinct identities accurately; cleanup does not bump either. |
| All 39 MQL5 source/include files are reachable | File inclusion does not establish that every helper is used. |
| Array helpers have no callers; other helpers have only definition references | Require individual deletion proofs, not a blanket legacy-name purge. |
| V12 fixture is used by rejection tests | Preserve it; V9/V10/V11 fixtures are separate unused candidates. |

These are discovery observations, not completed implementation gates. No tests,
compile, tester run, document deletion, or source cleanup was performed in planning.

## Scope And Decisions

| Decision | Resolution and source |
| --- | --- |
| D1: historical retention | Q1 option A, recommended and accepted by the user's reply, "use all recommended options": remove obsolete documents from the checkout, retain essential V13/Exness evidence and Git recovery references. |
| D2: project maintenance rules | User explicitly delegated local project/AGENTS rules. Define document ownership, replacement, retention, and validation in existing guidance. |
| D3: dead-code scope | User explicitly allowed removal where warranted. Choose proven unused helpers, unused fixtures, and pure redundant branches; preserve observable V13 behavior. |
| D4: execution boundary | The original request is a direct Planner plan plus questions. The subsequent user request explicitly authorizes ordered Sprint 1-3 implementation, validation and commits. |
| D5: organization | Use seven current guides/indexes and seven essential evidence records. Reuse existing paths where possible; create only `docs/README.md` as a permanent new document. |
| D6: work ownership | One agent and one writing session per worktree. No delegated agents, global configuration changes, or remote Git writes. |

**Pending required decisions**: None.

**In scope**: project guidance, current and historical tracked documentation,
related stale `.gitignore` entries, demonstrably unused MQL5 helpers and Python
fixtures, current evidence navigation, and scoped verification/rollback records.

**Non-goals**: schema or strategy changes, live deployment, broker/account/custom
symbol changes, new model behavior, downstream Django changes, dependency or
compiler upgrades, global Codex/plugin/skill edits, Git history rewriting, and
cleanup of private datasets, terminal folders, logs, binaries, retained handoffs,
or caches. No new MQL5 harnesses, test EAs/scripts, CI, or test infrastructure.

**Safe assumptions**: keep English and the repository's existing naming/style;
retain public tool/CLI entrypoints and the current Python environment; a candidate
that cannot be proved unused stays. No deletion quota overrides correctness.

The accepted retention choice supersedes the old blanket requirement to keep
all historical tracked documents in place. It does not authorize deleting private
raw evidence, changing historical results, or weakening schema rejection tests.

## Target Documentation And Disposition

### Seven Current Guides And Indexes

| Permanent path | Authoritative responsibility |
| --- | --- |
| `AGENTS.md` | Task routing, critical runtime/research boundaries, validation and document-maintenance rules. |
| `README.md` | Product purpose, version identities, minimal orientation, links to deeper guidance. |
| `docs/README.md` (new) | Current state, active plan pointer, outstanding gates, evidence selection and Git history recovery. |
| `docs/architecture/market-data-broker-executor.md` | Full current MQL5 input, lifecycle, time, resource, capacity, broker and export contract. |
| `docs/environment/mt5-agentic-workflows.md` | Environment setup, local artifact ownership, MCP discovery, compile/fallback procedure and verification commands. |
| `tools/deterministic_signal_ml/README.md` | Strict V13 intake, native grains, validation/build/audit/training workflow, research/leakage and recovery boundaries. |
| `tools/exness_tick_history/README.md` | Source preparation, profiles, native import/capture/round-trip operations, broker comparison and operational safeguards. |

The architecture document owns runtime semantics; tool READMEs link to those
semantics and own their operator procedures. `docs/README.md` alone owns changing
project status. A dated acceptance result is evidence for its identified inputs,
not a second copy of current operating instructions.

### Seven Essential Evidence Records

Keep these paths to preserve useful provenance and downstream references:

| Path under `docs/research/` | Retained purpose |
| --- | --- |
| `pivot-fractal-v13-producer-handoff.md` | Frozen V13 schema, registry/fixture pins and downstream vendoring boundary. |
| `pivot-fractal-v13-producer-acceptance-2026-08-31.md` | Original V13 bounded runtime, export and performance acceptance. |
| `parent-close-chronology-acceptance-2026-09-09.md` | Corrected producer, current pre-cleanup compile pin, focused parity and recovery limitations. |
| `exness-tick-history-acceptance.md` | Source-pipeline implementation evidence and rollback ledger. |
| `exness-single-file-preparation-2026-09-09.md` | Persistent tick files, counts, hashes and approved EURUSD representation policy. |
| `exness-custom-symbol-alignment-2026-09-09.md` | Native mapping/H1/sample checks and unresolved broker equivalence. |
| `exness-xauusd-run-verification-2026-09-09.md` | Original historical run diagnosis and verified session mapping. |

Preserve recorded results, dates, hashes, qualifications and attribution. Permit
only clearly identified navigation/status annotations and links to replacement
guides or Git snapshots. Do not replace historical source hashes with new hashes
or silently convert an old pending result to PASS. Mark the August V13 handoff as
a frozen snapshot; current source/compile selection belongs in `docs/README.md`.

### Retirement Map

All paths in this table are baseline source locations, not future live links.
For every file, record keep/merge/delete, the reason, the destination for unique
current content, and its recovery commit/path before deletion.

| Baseline path/cohort | Disposition |
| --- | --- |
| `docs/addons/README.md`, `docs/addons/base.md` | Delete after preserving any still-valid unique details in README/architecture; discard obsolete V10 instructions. |
| `docs/workflows/pivot-fractal-statistics-flow.md`, `docs/workflows/pivot-fractal-offline-research-boundaries.md` | Merge unique workflow, leakage, duration and acceptance requirements into the research tool README; delete originals. |
| `docs/workflows/exness-tick-history.md` | Merge unique native UI, clock/specification, import replacement, seasonal comparison and recovery procedures into the Exness tool README; delete original. |
| `docs/plans/README.md`, `docs/research/README.md` | Replace current navigation/status with `docs/README.md`; delete originals. |
| `docs/research/exness-research-handoff-2026-09-09.md` | Migrate current completion, retained-artifact locations and outstanding gates into `docs/README.md`; delete the superseded status copy. |
| `docs/research/exness-tick-history-handoff-2026-09-07.md` | Preserve unique seasonal intervals/report references needed by current procedures or evidence navigation, then delete. |
| `docs/research/pivot-fractal-v12-producer-handoff.md`, `docs/research/pivot-fractal-v12-producer-acceptance-2026-08-13.md` | Delete checkout copies; retain commit/path recovery and strict V12 rejection behavior. |
| All 69 tracked files under `docs/plans/archive/` | Delete after resolving retained evidence links, commit/rollback references and still-relevant rationale. |
| All 26 tracked files under `docs/research/archive/` | Delete after extracting any unique current constraint or provenance needed by the retained set. |

Expected net result: retain 13 existing Markdown documents, add `docs/README.md`,
and retire 106 existing documents. This plan is the fifteenth document while it
is current or the most recent closeout. Measure bytes as well as file count;
do not meet the count target by pasting all historical material into larger guides.
If a unique current contract cannot safely fit its designated owner, retain it
and explain the exception rather than losing necessary information.

## Protected Contracts

Use a requirement-to-document crosswalk before shortening guidance. Keep the
following critical boundaries directly in `AGENTS.md`, with full detail in the
appropriate owner document:

- Strict V13, engine `PIVOT_FRACTAL_V2`, twelve files, public input surface and
  `Micro < Deep < Macro`; no restored compatibility/runtime-model controls.
- Broker-native completed candles and causal identities; H1 terminal processing
  before deep discovery; analysis time never controls execution.
- Only structural H1 1R can send, with fresh broker checks, FOK, V13 ownership,
  fixed-reference lot sizing and immutable SL/TP. Research cannot affect it.
- Eight H1 lanes, shared deep 1R/2R/3R trials, frozen parent links, atomic capacity,
  explicit invalid/censored states, and actual broker parent-close chronology.
- Exact durations and zero-second completed broker lifecycles; retrospective H1
  duration stays outside causal model features; no censored-to-loss relabeling.
- Four cached feature handles, native-grain feature ownership, include order,
  bounded state/hot paths and read-only chart work with the 16-position bound.
- Required compile preflight, existing Python contracts, artifact privacy,
  no new MQL5 test infrastructure, and no live rollout authorization.

Current operational limits must remain visible: human chart/rendering verification
is outstanding; formal Exness broker equivalence is INCONCLUSIVE; full semantic
validation of the large recovered run is NOT RUN. Preparation and chronology
checks must not be presented as closing these gates.

## Named Resources And Prerequisites

- Applicable project guidance: `AGENTS.md`; current environment and seven retained
  evidence records named above. Recheck branch, status and instructions at execution.
- Installed skills: `planner`, `production-engineering-stack:mql5-production-engineering`,
  `production-engineering-stack:python-django-production-engineering`,
  `codex-agentic-stack:token-saver-orchestrator`, and `openai-docs` when current
  Codex behavior needs verification. Resolve helper paths from the installed skill;
  do not pin native cache versions into project guidance.
- Codex CLI observed during discovery: `0.153.4`. No settings/model/provider
  changes are required. Installed plugin caches and user-level skill sources are
  read-only references for this task.
- Official pages searched and fetched on 2026-09-10:
  [AGENTS.md discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
  and [Skills and Plugins](https://learn.chatgpt.com/docs/skills-and-plugins).
  They support scoped instruction layering and loading reusable capabilities
  without copying their contents into project guidance.
- Existing `.venv/bin/python`, both tool `requirements.txt` files, existing Python
  suites/fixtures, `tools/exness_tick_history/native_stream.cpp`, and
  `tools/mt5/compile_mt5.py`. Do not upgrade dependencies for this cleanup.
- Disposable implementation receipts: ignored
  `.codex-artifacts/project-guidance-cleanup/`; active execution checkpoint:
  ignored `.codex-hook-state/`, using the installed Planner handoff contract.
  Planning does not create either execution artifact.
- Before source changes, preserve the current ignored `.ex5` plus metadata in the
  task's ignored evidence directory if available. Verify Git can read the baseline
  documents before deleting their checkout copies. Retain all external data and
  provenance sidecars at their existing locations.

## Sprint 1: Align Guidance And Establish Current Document Owners

**Goal**: A new session can identify the current contract, correct skill and next
validation step from a compact, consistent documentation entrypoint.

**Dependencies**: Accepted D1-D6; execution authorization; unchanged or reconciled
baseline; execution state initialized through the installed Planner contract.

**Tracked scope**: this plan, the seven current guide/index paths, navigation-only
edits in the seven evidence records, and the seven retired addon/workflow/index
files listed in the first four rows of the retirement map.

**Commit**: `docs: align V13 guidance and consolidate current workflows`

**Rollback point**: Record the actual pre-sprint HEAD as `S1_PARENT`; reverse only
this sprint's reviewed changes or revert its completed commit.

### Task 1.1: Freeze The Inventory And Ownership Crosswalk

- **Location**: tracked Markdown inventory; `AGENTS.md`; this plan; ignored task receipts.
- **Work**: inventory every document, outbound local references and unique current
  requirements. Distinguish live guidance, dated evidence and obsolete history.
  Record the baseline SHA and a complete disposition manifest; inspect historical
  sections as needed to avoid losing still-current rationale.
- **Acceptance**: every baseline Markdown file has a disposition and recovery
  location; every protected contract has a current owner. No implementation
  artifact, external file or private checkpoint is in the deletion manifest.
- **Validation**: reconcile manifest count/bytes against `git ls-files`; compare
  each protected contract with source and current acceptance, not old plans.
- **Rollback**: discard only task-owned draft receipts; no source changes here.

### Task 1.2: Upgrade AGENTS And Document Maintenance Rules

- **Location**: `AGENTS.md`, `README.md`, `docs/README.md`, environment runbook.
- **Dependencies**: Task 1.1 crosswalk.
- **Work**: replace duplicated generic skill prose with task-specific routing and
  links. Correct the old "Planner only when explicitly invoked" instruction:
  saved/phased/sprint plans use Planner, short chat plans use create-plan, and
  native collaboration mode remains separate. Preserve scoped execution authority
  and pending decisions across interruptions. Keep one-agent defaults and plugin
  ownership; omit unrelated framework catalogs and changing cache paths.
- **Work**: define one maintained owner per topic, one current status index, and
  update-in-place rules. Future docs must extend an owner or justify a distinct
  concern. Superseded plans/status notes leave the checkout once their useful
  facts and recovery SHA are retained; keep at most one current/latest plan.
  Retain unique acceptance evidence only while it substantiates current behavior,
  unresolved gates or downstream contracts. Historical results remain dated.
- **Acceptance**: root AGENTS is at most 160 lines / 8 KiB with the protected
  boundaries intact; README is orientation rather than a second specification;
  `docs/README.md` identifies current work, evidence and all three open gates.
- **Validation**: G1-G3 below; source/include files remain byte-identical.
- **Rollback**: restore these documents from `S1_PARENT` as a reviewed change.

### Task 1.3: Consolidate Current Procedures And Remove Duplicate Guides

- **Location**: architecture/environment docs, both tool READMEs, addon/workflow
  docs, old plan/research indexes, retained evidence navigation.
- **Dependencies**: Tasks 1.1-1.2 establish the owners and preservation rules.
- **Work**: move unique current content to the owners, then delete the seven
  duplicate/stale guide/index files. Transfer Exness clock/specification checks,
  import replacement cautions, native UI instructions, fixed seasonal scoring
  constraints and reader limitations; preserve the separate source preparation
  and registered broker-acceptance procedures. Transfer research duration,
  leakage, grain, provenance/recovery and acceptance rules without weakening them.
- **Acceptance**: no V10/V12 description is presented as current; no competing
  current handoff or duplicated full runtime/CLI procedure is selected by the
  entrypoints; all retained local file and anchor links resolve.
- **Validation**: G1-G3 and documentation command review against existing CLI
  parsers. Run only safe `--help` commands if needed; do not import symbols,
  download histories, train models or re-run large datasets to check documentation.
- **Rollback**: restore deleted guides and their incoming links together.

### Sprint 1 Gate

- [x] Tasks complete; G1-G3 pass and source/include baseline is unchanged.
- [x] Evidence navigation and all preserved safety/research requirements reviewed.
- [x] Record actual evidence and residual risks; stage only reviewed paths.
- [ ] Create exactly one Sprint 1 commit; record commit SHA and `S1_PARENT`.
- [ ] Start Sprint 2 only after this gate completes. No compile is needed here.

Sprint 1 validation (2026-09-10): G1-G3 PASS; 55 retained local links/anchors,
119 recovery objects and six privacy probes checked; all 39 source/include files
and Python/schema/fixture inputs remain unchanged. AGENTS is 128 lines / 8,174
bytes. Five CLI help entrypoints pass. Seven obsolete current guides/indexes are
removed. Compiler/tester and Python suites were not rerun for documentation-only
changes. Detailed receipts: `.codex-artifacts/project-guidance-cleanup/`.

## Sprint 2: Remove Obsolete History And Superseded Status Copies

**Goal**: Reach the compact retained document set with recoverable history and
no stale current-status pointers or dangling retained evidence references.

**Dependencies**: Sprint 1 committed; complete disposition manifest; baseline
history readable; current status and relevant unique content already migrated.

**Tracked scope**: this plan; the remaining 99 retirements (95 archived documents,
two old Exness handoffs, two V12 records); `.gitignore`; current index and necessary
navigation/status annotations in retained documents.

**Commit**: `docs: remove obsolete archives and superseded handoffs`

**Rollback point**: Sprint 1 commit, recorded as `S2_PARENT`; revert the complete
Sprint 2 commit to restore retired paths and their matching navigation.

### Task 2.1: Preserve Recovery References And Resolve Historical Dependencies

- **Location**: `docs/README.md`, seven evidence records, retirement manifest.
- **Work**: select current evidence explicitly and label older pins as snapshots.
  Replace links into soon-deleted archives with a compact baseline commit/path
  reference, keeping sprint rollback facts. Preserve unique seasonal capture
  provenance from the older Exness handoff at its designated current owner.
- **Acceptance**: history is discoverable without restoring whole archives;
  evidence remains accurately dated and current source pins are unambiguous.
- **Validation**: `git cat-file -e <retained-sha>:<retired-path>` for every retired
  path, plus a `git show <retained-sha>:<retired-path>` recovery sample from each
  cohort. Check navigation-only evidence diffs against the baseline.
- **Rollback**: restore the paired reference/document changes from `S2_PARENT`.

### Task 2.2: Delete Reviewed Obsolete Documents And Simplify Ignore Rules

- **Location**: remaining retirement paths; `.gitignore`; current index.
- **Dependencies**: Task 2.1 and manifest cross-check.
- **Work**: delete only the explicit tracked manifest paths. Do not run directory
  purges or `git clean`. Remove obsolete archive allowlist exceptions and dead
  lead-magnet output patterns only after checking actual ownership; preserve
  ignores for binaries, logs, private configuration, `.venv`, task state and data.
  Existing retained files outside tracked documentation are out of scope even
  when their directories resemble retired paths.
- **Acceptance**: target 14 permanent Markdown documents plus this plan; no
  duplicated archive, placeholder tombstone per retired file, or external backup
  is introduced. Git retains all historical contents and commit ancestry.
- **Validation**: G1-G3; exact planned-versus-actual deletion set; `git check-ignore`
  privacy probes; source/include/schema/fixture hashes unchanged from Sprint 1.
- **Rollback**: revert this sprint as a unit; never reconstruct archives from memory.

### Sprint 2 Gate

- [ ] All retirements have a recoverable commit/path and resolved live references.
- [ ] Document count/bytes, ignore policy, G1-G3 and unchanged source checks pass.
- [ ] Preserve private artifacts; record any justified retention exception.
- [ ] Create exactly one Sprint 2 commit; record commit SHA and `S2_PARENT`.
- [ ] Start Sprint 3 only after this gate completes. No compile is needed here.

## Sprint 3: Remove Proven Dead Code And Validate Integration

**Goal**: Remove unused maintenance surface while preserving broker execution,
V13 exports, CLI behavior, active tests and evidence interpretation.

**Dependencies**: Sprint 2 committed; individual deletion proofs; binary/source
rollback metadata; working MetaEditor MCP or the documented compile fallback.

**Tracked scope**: proven candidates below, their owning include declarations,
unused V9/V10/V11 fixtures, this plan and the current index's cleanup evidence.
Existing Python implementation, public contracts and tests change only if a
specific non-use proof requires a narrowly related reference update.

**Commit**: `refactor: remove unused helpers and obsolete fixtures`

**Rollback point**: Sprint 2 commit, recorded as `S3_PARENT`; source reversal must
be paired with the preserved ignored binary or a recompile of restored source.

### Task 3.1: Establish A Candidate-By-Candidate Deletion Proof

- **Location**: `HFT_Grid_AI.mq5`, all `services/` includes, Python entrypoints,
  fixtures, imports, tests and compile runner.
- **Work**: use exact identifier references, aggregate include tracing, platform
  event knowledge, conditional compilation, imports, CLI dispatch and fixture
  discovery. Record each candidate as remove/retain with evidence. One textual
  occurrence is a lead, not proof. Preserve event handlers, registered/dynamic
  entrypoints and helpers with uncertain external use or side effects.
- **Acceptance**: every deletion has an explicit owner, proof and affected gate;
  no live feature removal, guard change, broad rename or speculative refactor.
- **Validation**: G1 and G4. Review references in the complete tracked source,
  tests and current docs, including code that reaches fixtures dynamically.
- **Rollback**: no mutation in this task; preserve the decision receipt.

Initial candidates found during discovery (not a mandatory deletion list):

| File or location | Candidate scope |
| --- | --- |
| `services/utils/array_functions.mqh`, `services/trading_tools.mqh` | `AddElementToArray`, `RemoveElementFromArray` and the otherwise unnecessary include. |
| `services/trading_management/indicator_definitions_loader.mqh` | `PivotBandsHandleReady`, `PivotStochasticHandleReady`; retain handle initialization/release paths. |
| `services/trading_management/market_conditions_functions.mqh` | `IsMarketOpen`; retain broker session evaluation used by the execution kernel. |
| `services/trading_management/pivot_fractal_engine_config.mqh` | `PivotFractalEngineEnabled`, `PivotLevelIdAt`, `PivotTrialFirstTouchLabel`; retain public/fixed contract constants. |
| `services/trading_signals/deep_pivot_lifecycle.mqh` | `DeepPivotEventCapacityRejectedCount`, `DeepPivotFrozenParentPeak`, `DeepPivotFrozenParentCountForEvent`, `FindDeepPivotOutcome`. |
| `services/trading_signals/execution_logging.mqh` | `ExecutionTimeToken`, `ExecutionAppendQueryDebugChangedLog`, `ExecutionAppendQueryDebugThrottledLog`. |
| `services/trading_signals/market_status_controller.mqh` | `MarketStatusLastChangeTime`, `MarketStatusReason`, `MarketStatusAllowsSignalAttempts`, `MarketStatusAllowsBrokerActions`; retain live status/logging behavior. |
| `services/trading_signals/pivot_fractal_engine_state.mqh` | `PivotFractalWindow`. |
| `services/trading_signals/pivot_fractal_signal_detection.mqh` | `ProcessPivotFractalTick`; retain the live prepared-tick path. |
| `services/trading_signals/pivot_signal_state.mqh` | `PivotSignalHasBrokerExposure`, `PivotSignalHasConfirmedOutcome`, `PivotSignalExecutionComplete`. |
| `services/trading_signals/pivot_trial_matrix_geometry.mqh` | `PivotTrialPriceDistancePoints`, `PivotTrialGeometryEquivalent`. |
| `services/trading_signals/pivot_trial_matrix_state.mqh` | `PivotTrialStateCapacityFailed`, `PivotTrialStateAllocationFailed`, `FindPivotTrialActiveStateByOriginId`, `CountPivotTrialActiveStatesForOrigin`, `RemovePivotTrialActiveStateByTrialId`. |
| `services/utils/broker_constraints_helper.mqh` | `EnforceBrokerDistance`, `ValidateDistanceAgainstBrokerLimits`; retain all live distance checks. |
| `services/utils/market_data_time.mqh` | `MarketDataUsesUnitedStatesDst`, `MarketDataDstActive`; retain current symbol/calendar mapping. |
| `HFT_Grid_AI.mq5`, `services/trading_signals/pivot_signal_lifecycle.mqh` | `PivotRunCompletionStatus` has an identical `CENSORED` result on both remaining paths; simplify only after proving the removed predicates are pure. Then review the orphaned `PivotSignalLifecycleHasOutstandingAttempts`. |
| `tools/deterministic_signal_ml/tests/fixtures/schema_v9_pivot_fractal/`, `schema_v10_macro_micro_pivot/`, `schema_v11_pivot_trial_matrix/` | 23 tracked TSVs with no discovered active fixture references. Confirm discovery behavior before removal. |

The final two abbreviated fixture names are sibling directories under
`tools/deterministic_signal_ml/tests/fixtures/`. Keep
`schema_v12_pivot_signal_features/` for `test_v12_and_legacy_shapes_are_rejected`
and all V13 fixture/provenance files. `PivotTrialLanesHaveOutstandingState` has
another live caller and must remain even if its completion-status use is removed.
`native_stream.cpp` is built by `prepare.py`; its Python/C++ boundary is active.

### Task 3.2: Apply Only Proven Removals

- **Location**: approved candidate owners and aggregate include declarations.
- **Dependencies**: Task 3.1 proof for each individual change.
- **Work**: delete unused definitions and orphaned includes/fixtures. A private
  constant/type may be removed only if it becomes unused through an approved
  deletion and is neither serialized nor part of a public contract. Preserve
  broker ordering, logging, export fields, fixed caps and public names/defaults.
- **Acceptance**: no remaining references to removed identifiers; retained
  callers/entrypoints remain intact; no new broker mutation or schema conversion
  path; the empty `OnTrade` callback is not misclassified by a caller-count scan.
- **Validation**: G1, G4, G5 and G6. Run the existing Python contract suite after
  fixture deletion; keep all assertions and V12 rejection coverage.
- **Rollback**: restore the affected definitions/includes/fixtures together;
  restore/recompile the matching binary, never an unrelated terminal artifact.

### Task 3.3: Record Current Integration Evidence And Close Out

- **Location**: `docs/README.md`, this plan, ignored task receipts/execution state.
- **Dependencies**: Tasks 3.1-3.2 and all required gates.
- **Work**: record actual removals/retentions, document counts/bytes, test results,
  compiler build and binary/source hashes, recovery anchor and residual risks.
  Current compile metadata is a new dated result; do not overwrite the August or
  September historical acceptance. Clear active-plan status only at completion.
- **Acceptance**: concise current evidence distinguishes verified preservation
  from unrun tester checks and the three pre-existing operational gates. No
  fresh tester, latency, broker-equivalence or deployment claim is inferred.
- **Validation**: final G1-G6 reconciliation, reusing unchanged passing evidence;
  inspect the staged diff and verify only intended paths are included.
- **Rollback**: reverse current-status/plan annotations with the corresponding
  source changes so metadata never selects an incompatible binary.

### Sprint 3 Gate

- [ ] Every removal has proof; G1-G6 pass for their affected inputs.
- [ ] Final MQL5 compile reports `0 errors, 0 warnings` and regenerated binary metadata.
- [ ] Source/fixture contracts and pre-existing operational limits remain intact.
- [ ] Create exactly one Sprint 3 commit; record commit SHA and `S3_PARENT`.
- [ ] Record completion in ignored execution state; retain only this latest plan.

## Validation Contract

All checks below are implementation work to run and record, not planning PASS
claims. Record actual exit status, scope, input SHA and concise evidence. Use
installed read-only inspectors and ad hoc bounded Python/shell checks; do not
introduce permanent validation infrastructure for this cleanup.

### G1: Git, Identifier, Include And Safety Review (Every Sprint)

```bash
rtk git status --short --branch
rtk git diff --stat
git diff --check
git diff --name-only
git diff --cached --check
git diff --cached --name-status
rg -n --glob '*.mq5' --glob '*.mqh' '^\s*#include' HFT_Grid_AI.mq5 services
rg -n --glob '*.mq5' --glob '*.mqh' '\bOrderSend\s*\(' HFT_Grid_AI.mq5 services
rg -n --glob '*.mq5' --glob '*.mqh' 'TRADE_ACTION_SLTP|OrderSendAsync|PositionClose|PositionModify' HFT_Grid_AI.mq5 services
```

Trace include paths relative to their owner, checking missing targets, cycles,
reachability and the four-aggregator order. Expect one `OrderSend` owner in
`execution_controller.mqh` and no new trade-mutation paths. An expected no-match
`rg` exit 1 is not a failure. Compare actual source hashes for documentation-only
sprints. Review all four public input groups, magic namespace, fixed caps,
feature handles, parent chronology and broker/research isolation.

### G2: Document Ownership, Versions And Links

- Inventory tracked Markdown files using `git ls-files -z` and filesystem
  existence, including planned additions before staging. Reconcile actual
  deletions against the disposition manifest; record file/byte totals.
- Validate every retained relative Markdown file/directory link and heading
  fragment, including reference-style links; inspect code-formatted paths in
  current guides too. Distinguish future paths, placeholders, external operator
  paths and explicit `<commit>:<historical-path>` recovery references. Do not
  count these documented exceptions as ordinary live checkout links.
- Check the seven current guides for obsolete schema/feature/skill identifiers,
  old handoff selection and conflicting status. Rejection examples and dated
  evidence may mention V9-V12; they must not become accepted/current contracts.
- Confirm each protected requirement has a current owner and remains reachable
  from AGENTS/README. Verify AGENTS line/byte targets and avoid duplicated full
  contracts. No need to start another Codex agent to test instruction discovery.

### G3: Artifact Privacy And Recovery

```bash
git check-ignore .codex-hook-state/probe.json .codex-artifacts/probe.txt HFT_Grid_AI.ex5 .venv/probe logs/probe.log artifacts/exness_tick_history/probe.json
git cat-file -e bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:AGENTS.md
```

Check every retired path's retained Git object, plus sampled `git show` recovery.
Review `.gitignore` changes against existing ignored ownership. Do not traverse
or rehash tens of gigabytes of unchanged private data to validate doc cleanup;
confirm that no command or staged change targets those resources.

### G4: Dead-Code And Behavior Preservation

For each approved identifier, run an exact word-boundary reference sweep across
tracked source, tests and current docs before and after deletion, such as:

```bash
rg -n '\b(AddElementToArray|RemoveElementFromArray)\b' HFT_Grid_AI.mq5 services tools
rg -n 'schema_v9_pivot_fractal|schema_v10_macro_micro_pivot|schema_v11_pivot_trial_matrix' tools
rg -n 'schema_v12_pivot_signal_features|test_v12_and_legacy_shapes_are_rejected' tools/deterministic_signal_ml/tests
```

Inspect declarations, overloads, macros, conditionals, built-in callbacks,
import/CLI dispatch and filesystem-based fixture discovery. Compare the public
input declarations and V13 schema/header/fixture hashes before and after. A
reachable expression can be simplified only with a return-value and side-effect
proof. Unproven candidates remain and are listed with the reason.

### G5: Existing Python Contracts

Run after fixture or Python changes, or when needed to verify consolidated
documented entrypoints. Do not repeat passing suites without changed inputs.

```bash
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python tools/deterministic_signal_ml/build_dataset.py --runs-root tools/deterministic_signal_ml/tests/fixtures --run-id schema_v13_hft_deep_pivot_features --validate-only
```

The suite must still cover strict headers/registry, native H1/deep grain, leakage,
parent chronology, same-second broker lifecycle and rejection of V12/legacy
shapes. Record actual counts; historical counts of 45 and 91 are not a new PASS.

If Python implementation or Exness dependencies/references actually change, run
the affected suite and syntax checks as appropriate:

```bash
rtk test .venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
.venv/bin/python -m compileall -q tools/deterministic_signal_ml tools/exness_tick_history
```

No Exness source change is currently planned. No full-history backfill, model
training, production-data rewrite or external network gate is required here.

### G6: Final MQL5 Compile And Operational Interpretation

1. Discover current MetaEditor MCP tools/schemas at runtime. Its first operation
   must be `get_workspace_info`; verify the workspace root and compile capability
   before any other compiler operation.
2. Compile the actual `HFT_Grid_AI.mq5` with `compile_file`. Require exactly
   `0 errors, 0 warnings`; confirm the ignored `.ex5` was regenerated and record
   timestamp, size, SHA-256, compiler build and matching source/include hashes.
3. If MCP cannot execute, record the precise reason and use the environment
   runbook's existing `tools/mt5/compile_mt5.py --wine --mt5-root ... --entrypoint ...
   --log ... --mode compile` procedure. A syntax check or stale binary cannot
   substitute. If both paths fail, this source sprint remains incomplete.
4. Proven unreachable removals and pure equivalent simplification introduce no
   new MQL5 behavior. Preserve applicable historic runtime evidence while stating
   that it tested the earlier binary. If any candidate would alter live lifecycle,
   order, feature, logging or chart behavior, retain/defer it; do not smuggle a
   behavior change through this cleanup. Such a change needs its own scoped
   acceptance, including proportional human Strategy Tester/chart checks.
5. Leave existing chart-rendering, broker-equivalence and recovered-run semantic
   gates outstanding. Compilation does not close any of them or authorize rollout.

## Testing Strategy And Risks

Unit/integration coverage comes from the maintained Python suites, strict V13
fixture validation, include/reference analysis and MQL5 compilation. Documentation
acceptance covers ownership, links, executable command names, version/status
accuracy, recovery, and instruction size. Relevant operational checks are scoped
as G6; UI/accessibility and deployment acceptance are not changed by this work.

| Risk | Mitigation and validation signal |
| --- | --- |
| Important rationale disappears with archives | Per-file disposition and requirement crosswalk, retained Git objects, sampled recovery and seven selected evidence records. |
| Shorter AGENTS hides a trading constraint | Keep critical kernel rules inline; compare every protected contract with its authoritative owner and source. |
| Historical pins look like current acceptance | Dated snapshots retain original results; one current index selects current source/compile evidence and open gates. |
| Dead-code scan misses implicit callers | Per-candidate proof including callbacks/macros/imports/fixture discovery; retain uncertainty; compile and existing tests. |
| Removal of old fixtures weakens rejection coverage | Preserve V12/V13 fixtures and all existing rejection assertions; verify suite and registry/hash checks. |
| Ignore cleanup affects private artifacts | Explicit ignore probes and reviewed deletion manifest; no directory purges or terminal/data cleanup. |
| New source is paired with an old binary | Require regenerated `.ex5` metadata and source hashes; preserve binary rollback before source edits. |
| Independent writer or stale baseline appears | Stop on unexpected changes; reconcile ownership before further mutations; preserve existing commits and work. |
| Cleanup records recreate document sprawl | One current status index, one current/latest plan, compact tracked evidence and ignored detailed receipts. |

## Rollback And Execution Order

Preserve the baseline commit and all retired Git objects in normal ancestry.
Recovery inspection uses `git show <commit>:<path>`; do not rewrite history or
push branch changes as part of this plan. For committed rollback, revert sprint
commits in reverse order (3, 2, 1) as needed, preserving unrelated subsequent work.
Before a commit, reverse only reviewed task-owned changes. Never use a hard reset,
blanket checkout, archive-directory purge or `git clean`.

Source rollback must also select the matching retained ignored binary or compile
the restored source. It does not modify terminal attachment/account state or
original/recovered datasets and sidecars. Navigation and status updates roll back
with their corresponding source/document changes.

Execution was authorized on 2026-09-10. At the execution handoff, read
`references/execution-state.md` relative to the installed Planner skill, initialize
active-plan state, and retain the accepted decisions and authorization across
interruptions. Do not restart completed archived plans. New material questions
remain pending and block only dependent work through that handoff contract.

For each sprint: implement only that sprint; run and record its gates; review and
stage exact paths; create exactly one sprint-specific commit; record its parent
rollback SHA and completion SHA; then advance. Independent read-only tool checks
may be batched, but sprint dependencies and mutations remain ordered.

Update this plan and current status before the relevant sprint commit. Record the
resulting commit SHA in ignored execution state afterward; the final tracked row
may identify "the commit containing this closeout" with its known parent, avoiding
a fourth metadata-only commit or amending a completed commit. This plan remains
the most recent closeout until a later task replaces it and retains its Git anchor.

| Sprint | Proposed commit | Rollback parent | Execution evidence |
| --- | --- | --- | --- |
| 1 | `docs: align V13 guidance and consolidate current workflows` | `bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93` | G1-G3 and CLI help PASS; commit pending |
| 2 | `docs: remove obsolete archives and superseded handoffs` | Sprint 1 commit (`S2_PARENT`) | Not run |
| 3 | `refactor: remove unused helpers and obsolete fixtures` | Sprint 2 commit (`S3_PARENT`) | Not run |

## Completion Checklist

- [x] Required retention decision resolved; no material planning question remains.
- [x] Three ordered sprints name scope, validation, commits and rollback points.
- [x] Execution authorized and active-plan checkpoint initialized.
- [x] Current documentation consolidated and critical instructions preserved.
- [ ] Reviewed obsolete documents removed with recoverable Git references.
- [ ] Proven dead code/fixtures removed; uncertain candidates retained explicitly.
- [ ] Affected checks pass, final binary/source metadata is recorded, and all
  unrun operational gates remain accurately labeled.
- [ ] Exactly three sprint commits and their rollback parents are recorded.
- [ ] Current status and completed execution state agree; private artifacts and
  unrelated history remain preserved.
