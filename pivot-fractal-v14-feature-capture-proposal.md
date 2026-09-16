# Proposal: V14 Timeframe Features And Broader Deep Capture

> Historical accepted proposal, retained for the separate Django plan's references.
> MT5 implementation and optimization are complete; use the
> [current index](docs/README.md) for accepted builds, source selection and open gates.
> The [Django plan](/home/admin/python_projects/hft-grid-ai-orchestrator/pivot-fractal-v14-django-plan.md)
> owns subsequent consumer decisions. Planning-era wording below is historical and
> does not restart either workflow. Original bytes: `04b5c6a:pivot-fractal-v14-feature-capture-proposal.md`.

**Original planning status (2026-09-16)**: Ready for planning. All required decisions are recorded; execution has not
started. The staging purge below is an accepted future implementation scope.

Prepared 2026-09-16 from the MT5 checkout at `8625222` and the Django checkout at
`6263ce4`. This proposal coordinates the producer and consumer and records the
accepted scope for their subsequent implementation plans.

## Problem And Outcome

V13 captures Macro and Micro indicator features on each Macro origin, but only
Micro indicator features on each Deep event. Deep pivot geometry already exists;
its own timeframe's indicator context is missing. Admission also requires an
eligible active Macro parent with the same direction, excluding opposite-direction
Deep patterns during that parent's lifecycle.

The proposed result is a versioned research dataset with these feature owners:

| Signal | Feature timeframes | Capture clock |
| --- | --- | --- |
| Macro origin | Macro + Deep; exclude Micro | That Macro origin's trigger |
| Deep event | Deep + Micro | That Deep event's trigger |

Django should let researchers explore aligned and opposed Deep events with their
own captured features. Both checkouts become V14-only, with obsolete V13 runtime
code and related dead code removed. Existing V13 staging datasets and saved
research will be purged before the V14 rebuild; production remains untouched. Wider coverage
supplies additional observations, not a claim of profitable patterns.

## Scope

- MT5 producer, its offline Python contracts/tools, and coordinated Django intake
  and research behavior for the new schema and feature identities.
- Existing PP/S1-S3/R1-R3 triggers and first-consumption identities; expand direction
  coverage without inventing new pivot types, retries or repeated identities.
- Deep capture in both directions remains bound to eligible active Macro
  lifecycles. Collection without any Macro parent is excluded.
- GBPJPY diagnosis must address small windows at the start of the original 2015
  archive. Its confirmed missing conversion history selects `XAUUSD_Exness_2015`
  for the main QA dataset, also using initial-2015 windows. Full-history GBPJPY
  conversion support is a separate future task.
- Django changes and validation limited to the existing staging environment and
  isolated focused checks. No broad suite, full browser/performance/release QA,
  production deployment, or production data operations.
- Remove obsolete V13 runtime/schema tooling and related dead code in both
  repositories. Consolidate current documentation and instructions around V14 so
  deprecated material does not consume the active context window.
- Preserve original exports, production data and protected recovery material.
  Purge V13 datasets and saved research from staging only, then rebuild for V14.
  Preserve staging credentials and unrelated state. No live trading rollout.

## Recommended Approach

1. Introduce schema V14 with explicit feature and capture-policy identities.
   Keep V13 meanings frozen: a former Micro column cannot silently become Deep.
   Historical V14 coverage requires market-data replay; the missing captures and
   excluded events cannot be reconstructed from the twelve V13 TSVs alone.
2. Capture each pair at its own trigger, retaining broker-causal clocks and frozen
   current-bar observations. A later Deep snapshot cannot fill an earlier Macro
   row. Preserve pivot-relative percent-B: use the touched Macro pivot for Macro
   features and the touched Deep pivot for Deep features. Keep existing indicator
   parameters and Django's versioned Stochastic K/SMA(3) interpretations.
3. Store Deep features once per event, with shared 1R/2R/3R trials. Freeze eligible
   active parents without a direction filter; retain Macro and Deep directions
   separately and classify ALIGNED/OPPOSED per parent link. An event may have both
   relationships across different parents. Preserve parent-specific censoring and
   explicit invalid/capacity states.
4. Keep the real structural Macro 1R order boundary unchanged. Deep events and
   missing research features must not change order permission, size or lifecycle.
   Use cached Deep indicator handles with the existing bounded ownership pattern.
5. Update Django's V14-only importer, typed storage, feature catalog, condition
   admission, connected-Deep identities, membership queries and affected HTML/API
   behavior together. Macro conditions remain tied to their capture time; Deep
   refinements can use Deep + Micro. Reject V13 uploads and remove V13 runtime
   readers, aliases and compatibility branches. Do not reinterpret historical
   V13 conditions, snapshots or datasets as V14 evidence.
6. Keep event, origin, parent-link and outcome support distinct. Related observations
   must stay together across temporal validation boundaries. A filtered V14 aligned
   subset is not guaranteed to reproduce V13: earlier admission through an opposed
   parent can change which first touch consumes an identity.
7. Prove non-use before removing related legacy code, including callbacks,
   registries and fixture discovery. Retain only checks/history still required for
   V14 rejection rules and safe schema evolution; those are not dead code. Migrate
   unique current facts into the maintained guide owners, then retire superseded
   documents with Git recovery references and protected operational handoffs.
   Keep the unchanged production release identity distinct from V14 staging.

Primary owners are the MT5 feature capture, indicator loader, Deep lifecycle and
statistics exporter, `tools/deterministic_signal_ml/`, and Django's
`apps/datasets/`, `apps/research/` and associated HTML/GraphQL contracts.

## GBPJPY Feasibility And QA Choice

Read-only MetaTrader inspection confirms the conversion-history problem:

- `GBPJPY_Exness_2015` is a custom Forex symbol with profit currency JPY and margin
  currency GBP. The inspected tester journal uses a USD deposit currency.
- The 2026-09-16 journal reports USDJPY bar history from 2021-10-25 and tick history
  from 2026-01-01. During the 2015-start test it repeatedly reports
  `no prices for symbol USDJPY` with a zero quote/time.
- The actual inputs are H2/M15/M3, export enabled, run `Gbp_2015_H2M15M3`.
- MT5's `OrderCalcProfit` returns account-currency values. The EA uses it for
  reference-risk sizing and virtual money eligibility; real execution also checks
  margin. GBPJPY prices alone do not supply historical JPY-to-USD conversion.
  Margin conversion may require additional currency history as well.
- Pivot/indicator calculation itself does not need USDJPY. Failed money plans can
  make Macro trials ineligible and therefore leave no eligible parents for Deep
  admission. The inspected run-summary path had no file, so this diagnosis does
  not certify zero Macro-origin rows or a completed dataset's exact failure counts.

The custom GBPJPY symbol is not inherently unusable. Its own price history can
support pivots and indicators, but complete USD-valued trials and execution checks
also require correctly mapped historical currency-conversion prices. The current
tester environment lacks that dependency for the beginning of the archive.

The user requires GBPJPY QA to use small windows at the start of the original
2015 data, provisionally 2015-08-10 through 2015-08-14. The source begins on
2015-08-10; account explicitly for indicator warm-up and unavailable early features
without inventing earlier bars. A recent window is not an acceptable substitute
for this historical feasibility check.

Given the confirmed conversion gap, select `XAUUSD_Exness_2015` for the main V14
dataset audit, also using small initial-2015 windows with explicit warm-up.
Reuse the GBPJPY diagnostic evidence rather than repeating a test with the same
missing prerequisite. GBPJPY can become the primary QA symbol only if a bounded
check establishes valid conversion prices and money eligibility for those 2015
windows; there is no fallback to recent GBPJPY data.

Defer GBPJPY conversion-history acquisition/mapping and validation across the
whole available Exness archive to a separate task. Preserve its original history
and the reproduction evidence. Do not change currencies to fabricate USD results
or bypass money checks. Neither a small-window pass nor XAUUSD acceptance certifies
full-history GBPJPY support.

The existing custom-symbol alignment audit establishes historical GBPJPY source
coverage; it does not establish currency-conversion availability or complete broker
equivalence. No tester run, history repair or symbol-property change was performed
while preparing this proposal.

## Django Staging And Focused Validation

Use the retained `hft-refinement-staging` site and its documented
`bin/refinement-staging refresh` / `status` workflow during authorized execution.
The accepted transition is to inventory and quiesce the exact staging workload,
purge its V13 datasets and dependent saved research through the existing canonical
deletion path while V13-aware code is still available, and then migrate/rebuild
that environment for V14. Verify the deletion closure before removing V13 runtime
code. Preserve credentials, unrelated state, original exports and production;
do not substitute a global volume prune or whole-host reset. New V14 staging
evidence needs one small, complete, source-bound producer run, not an entire-history
import.

Use the separate `hft-refinement-feedback` environment for synthetic database and
migration tests. Select the smallest owning tests through the existing
`local_feedback.py --select-only` and registered `research_feedback.py` workflow;
do not use the retained staging database as a pytest database.

Focused coverage should address V14 intake and V13 rejection, the exact staging
purge and V14 rebuild,
new feature ownership and capture times, both link directions, parent censoring,
event deduplication, native-grain counts, and affected research/HTML/API flows.
Include targeted migration and small intake integration checks where needed.
Review only the changed staging workflows. The user's scope explicitly excludes
the otherwise standard broad and production release gates; record those as unrun,
not waived for a future production release or represented as passing.

## Decisions

Established from the discussion and latest request:

- Create the proposal first; implementation and sprint execution are not requested.
- Pair Macro + Deep and Deep + Micro; expand Deep pivot-direction coverage.
- GBPJPY QA must address the start of the original 2015 archive. The user rejects
  recent-window substitution and authorizes XAUUSD fallback, with full-history
  GBPJPY support addressed separately. The confirmed conversion gap selects
  `XAUUSD_Exness_2015` for the main QA dataset using initial-2015 windows.
- Django scope is staging and focused tests only, with no production deployment.
- No request changes the public H1/M10/M3 defaults. The non-default tuple below is
  a QA configuration, not a defaults change.
- Decision 1 answered: **H2/M15/M3 for QA**. The user's explicit answer selects A
  and agrees with the inspected tester inputs.
- Decision 2 answered: **active Macro lifecycles only**. The user's explicit
  answer selects A; independent no-parent Deep collection is excluded.
- Decision 3 answered with a stricter custom choice: **V14-only imports and removal
  of all deprecated V13 runtime code and related dead code in both projects**.
  The user also requests concise current context/documentation. Ongoing V13 runtime
  compatibility and historical in-app readers are therefore not proposed.
- Decision 4 answered: **purge V13 datasets and saved research from staging and
  rebuild it for V14**. The user explicitly selected B, including its destructive
  effect on staging history. This authorization does not extend to production,
  original exports, credentials or unrelated resources.

No required decision remains pending for the proposal. Implementation plans must
retain these answers and the staging-only deletion boundary.

## Success And Risks

Success means correctly timed feature pairs, both requested Deep relationships,
explicit censors and invalid states, a small complete V14 dataset accepted through
the V14-only Django intake policy, completed staging purge/rebuild, and a reviewable staging
workflow with focused evidence. MT5 source changes require a clean compile,
targeted native tester cases, broker export-on/off equivalence and bounded state
checks using the existing tooling; no new MQL5 test EA or harness is proposed.

Main risks are future-data leakage, altered first-consumption populations,
duplicated statistical support, larger parent-link fan-out, incompatible stored
research, and missing cross-currency history. Validate feature-pair and admission
effects separately. Preserve source/binary rollback points and version-compatible
Django readers. Code rollback alone cannot restore deleted staging records;
recovery requires an independently retained backup, if one exists. Do not claim
that the accepted purge is reversible or relabel historical data as V14.
Staging/focused evidence will not certify full-history coverage, broad application
regression safety, broker-feed equivalence or production readiness.

## References

- [Current MT5 state](docs/README.md)
- [Runtime contract](docs/architecture/market-data-broker-executor.md)
- [Custom-symbol source alignment](docs/research/exness-custom-symbol-alignment-2026-09-09.md)
- [Django intake](/home/admin/python_projects/hft-grid-ai-orchestrator/docs/contracts/v13-intake.md)
- [Django linked Deep research](/home/admin/python_projects/hft-grid-ai-orchestrator/docs/contracts/linked-deep-research-v1.md)
- [Django staging and feedback](/home/admin/python_projects/hft-grid-ai-orchestrator/docs/operations/local-development.md)
- [Django validation scope](/home/admin/python_projects/hft-grid-ai-orchestrator/docs/operations/validation-gate-reuse.md)
- [Official OrderCalcProfit contract](https://www.mql5.com/en/docs/trading/ordercalcprofit)
- [Official tester cross-rate history behavior](https://www.metatrader5.com/en/terminal/help/algotrading/testing_features)

## Next Requested Stage

Use this proposal as the shared contract for coordinated MT5 and Django implementation plans,
with the Django staging/focused-only restriction carried into every relevant gate.
Do not create execution state, run implementation sprints, refresh staging or
start tester jobs solely because this proposal was requested.
