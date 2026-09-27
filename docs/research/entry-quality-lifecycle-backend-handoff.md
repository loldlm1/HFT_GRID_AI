# Entry Quality, Lifecycle And Backend Selection Handoff

This is the incremental delivery from the five-sprint
[implementation plan](../../mql5-entry-quality-lifecycle-plan.md). The
[previous producer handoff](model-feature-producer-handoff.md) remains complete;
its historical pins, datasets and manual follow-ups retain their original scope.
This supplement adds two producer profiles and a downstream selection contract.
Backend implementation, intake performance acceptance and live rollout are not
included. The [current index](../README.md) owns execution and human-review status.

## Delivered Producer Profiles

Family `MQL5_MODEL_FEATURES`, core schema `1`, extension schema `1`, feature set
`macro_micro_standard_v1`, ordered headers and ten Pivot / eleven Candle files
are unchanged. Dispatch on the complete registered tuple, never schema alone.

| Engine | EA version | Outcome policy | Admission / expiry |
| --- | --- | --- | --- |
| Retained `PIVOT_MACRO_V1` | 2.00 | `PIVOT_MACRO_OUTCOME_V1` | Legacy / NONE |
| Retained `CANDLE_PATTERN_ATR_V2` | 2.00 | `CANDLE_ATR_OUTCOME_V1` | Legacy / ENTRY_PLUS_MACRO |
| New `PIVOT_MACRO_V2` | 2.10 | `PIVOT_MACRO_OUTCOME_V2` | SPREAD_3_STOPS_FREEZE_TICK_V1 / ENTRY_PLUS_MACRO |
| New `CANDLE_PATTERN_ATR_V3` | 2.10 | `CANDLE_ATR_OUTCOME_V2` | SPREAD_3_STOPS_FREEZE_TICK_V1 / ENTRY_PLUS_MACRO |

Keep historical reads and frozen research identities. Reject unknown/mixed
tuples; do not relabel an old run or reinterpret it with the new rules. New magic
namespaces/comments never adopt previous-engine positions. Public inputs remain
unchanged; there is no MQL5 offset/limit control or admission multiplier input.

### Fixed Entry Admission

Use one validated fresh quote/specification snapshot and existing normalized SL:

```text
spread_price = Ask - Bid
minimum_price = 3 * spread_price
              + max(stops_level_points, freeze_level_points) * point
              + trade_tick_size
risk_price = Ask - SL       for BUY
risk_price = SL - Bid       for SELL
admit if risk_price > 0 and risk_price + trade_tick_size * 0.000001 >= minimum_price
```

All prices must be finite, Ask >= Bid > 0, point/tick positive and broker levels
nonnegative. Equality admits. The tolerance addresses floating-point arithmetic;
it is not a configurable spread allowance. Tick size is not assumed equal to
point size. A zero spread still requires the broker distance plus one trade tick.
Existing geometry, volume, money, session, permission and OrderCheck rules also
apply. The EA neither widens SL nor changes the strategy to pass this gate.

The rule independently gates real entries and virtual entries, including the
midpoint's actual touch and Candle re-entries. Quotes captured at different times
can yield different admissions. Exact parity copies each accepted request; an
independent research result cannot suppress it. Later spread or fill deviation
does not retroactively reject an entry. Expiry closes never run this entry gate.

Rejected offers retain their audit evidence but have no actual entry clock,
completed return, binary target or offset/limit slot. A consumed Pivot origin
is not retried merely because the spread later improves.

### Deterministic Horizon And Observable Exit

The deadline is raw entry milliseconds plus `macro_seconds * 1000`. An H1 entry
at 04:13 expires at 05:13; H2 at 06:13; H4 at 08:13. It is not the next candle
boundary or a count of open-session minutes. Each structural, midpoint and parity
entry owns its deadline. A later midpoint can outlive its structural siblings.
Untouched midpoints become NOT_TRIGGERED when no structural lane survives.

Broker outcomes use the confirmed fill clock. Broker trial geometry and parity
retain the request clock and submitted reference deadline. Never move parity to
the broker fill or treat a submitted request as proof of a filled position.
Pivot supports native MN1 = 2,592,000 seconds in its new profile; Candle excludes
MN1. The descriptor lists supported durations and requires Micro < Macro.

TP/SL can resolve before the deadline. An unresolved virtual lane at/after it
uses the first valid observed exit-side quote and records TIME_EXIT. A broker
close at/after it has the same horizon classification while retaining the native
broker reason separately. No price is invented for a quote gap. The exact
deadline is deterministic; the observable close may occur later.

Execution reconciles first, then requests an opposing FOK deal for the exact
owned ticket and remaining volume. SL/TP remain immutable. Pending requests,
refusals and uncertain results retain ownership and bounded retry/diagnostics.
A timer only processes lifecycle work. A bounded research queue handles Pivot
deal facts that arrive ahead of the latest observed quote; it cannot delay or
authorize execution. Unresolved run end remains censored.

### Consumer Field Map

The [canonical schema](../architecture/model-feature-dataset.md) owns every
column, clock companion, type and nullable token. New profiles make some
previously optional proof fields conditionally mandatory; no header changed.

| Evidence | Fields / consumer rule |
| --- | --- |
| Frozen policy | Manifest `engine`, `producer_version`, `outcome_policy`, `expiry`, `macro_seconds`, `config_id`; generated profile admission metadata. No new manifest keys. |
| Entry quote/specification | Trial `entry_bid`, `entry_ask`, `point_size`, `trade_tick_size`, `spread_points`, `stops_level_points`, `freeze_level_points`. |
| Entry proof | Trial `normalized_risk_distance_price`, `normalized_risk_distance_points`, `minimum_risk_distance_points`, `distance_eligible`, existing `sl` and entry direction. Multiply point distances by `point_size` before comparing prices. |
| Conditional requirement | All eleven proof fields above are required for admitted trials and computed distance rejections. Unavailable geometry/specification stays explicitly unavailable; it cannot claim eligibility. |
| Request audit | `execution_checks.tsv` quote, point/tick, stop/freeze, risk, volume, check/send results and ownership fields. Candle ENTRY rows must agree with submitted trial proof. Preserve later reconciliation facts separately. |
| Actual membership clock | Outcome `entry_time_msc` reconciled with execution facts, plus its analysis-clock companions. Trial/request timestamps alone do not establish a broker fill. Preserve an earlier proven fill known-at clock when available. |
| Lifecycle | Trial and outcome `deadline_time_msc`; outcome `exit_time_msc`, `observed_time_msc`, `duration_ms`. Raw milliseconds own ordering, causality and exact durations. |
| Time exit | `status=TIME_EXIT`, observed price / `gross_r`, null `binary_label`, `binary_eligible=0`; virtual observed Bid/Ask with null threshold/gap/nominal R. Native broker reason remains separate. |
| No completed result | Rejected, unentered and censored outcomes do not acquire fabricated exit, duration, return or loss labels. Parity is always excluded from targets. |
| Costs | Actual broker costs/net remain execution facts; unknown virtual costs/net stay null. Price R is not a net-profit claim. |

The original Decimal tokens, all-or-none clock companions and source hashes must
survive intake. Feature gaps remain predicate-specific availability, not an
automatic veto of a real order or a reason to invent a missing causal feature.

## Backend Changes To Plan

Read-only inspection on 2026-09-27 used backend HEAD
`ba435d85c4872c8d78511fbea9dab0682f1a7042` in
`/home/admin/python_projects/hft-grid-ai-orchestrator`. Concurrent optimization
edits were observed and preserved. Re-read the current owners before editing;
this inspection neither freezes that checkout nor certifies deployed support.

| Concern | Current backend owner and required change |
| --- | --- |
| Exact profiles / provenance | `backend/apps/datasets/contracts/model_features_v1/{schema_contract,metadata,semantics,engines}.py`, `provenance.json`, `docs/contracts/model-feature-intake-v1.md`: register new tuples, per-profile producer version/expiry, required proof, new-Pivot durations and exact engine-kind dispatch. Current metadata still lists only old profiles. |
| Intake / storage / projection | `backend/apps/datasets/services/model_feature_{intake,validation,projection,execution,storage,stream}.py`: adapt typed policy checks and actual-entry/deadline projection, preserving bounded PostgreSQL processing, source attestations and the READY gate. |
| Daily membership | `backend/apps/research/analysis_window_contracts.py`, `services/analysis_window_contexts.py`, `persistence/model_contexts.py`: version offset/limit configuration, preselection membership, selected ordinals, partition identity and audit disposition. |
| Discovery / descendants | `backend/apps/research/services/model_discovery_evidence.py`, `model_discovery.py`: apply every candidate's full causal predicates before its own offset/limit selection. Preserve root support and correct pruning proofs. |
| WFO / ranking | `backend/apps/research/services/model_forward.py`, `model_pattern_ranking.py`, engine contracts and categorical/forward contract owners: freeze selection policy across TRAIN/TEST, update profile dispatch and bind all memberships/caches to the new identity. |
| Product / adapters | Existing domain commands, generated GraphQL/tools and research UI: expose nonnegative integer settings, defaults 0/0, selection audits and immutable identity consistently. Backend owns the rule. |

The present `advance_model_context` restricts children to the parent's MEMBER
rows, and the scorer starts from materialized node members. That remains useful
for causal predicate ancestry, but cannot use the parent's capped selection as
the child's full candidate stream. Keep preselection and selected membership
separate. This is a required behavioral change, not just two new form fields.

### Trades_Offset And Trades_Limits

Both settings are nonnegative integers, default 0. `Trades_Limits=0` is unlimited.
They belong to backend research/WFO configuration; producer datasets retain all
offers and admitted entries so nodes can apply different causal filters.

For each declared node/setup, symbol/direction category and daily analysis window:

1. Resolve the full inherited plus local entry-time predicates and entry category
   against the complete eligible entered stream. Preserve feature availability
   rules and causal known-at constraints. Do not start from a capped parent result.
2. Count independent entered decisions. Collapse ratio rows at the
   dataset-qualified attempt plus entry-policy/touch grain before numbering.
   Structural and midpoint entries have distinct times. Keep broker/virtual
   cohorts explicit; parity and unentered offers consume no slot. Independent
   signal-root support is not multiplied by ratios or re-entries.
3. Use the existing analysis-clock policy for half-open window membership and
   its start-date label. Overnight entries belong to the window's starting day.
   Sort by raw entry milliseconds, producer sequence, then stable qualified
   identity; analysis clocks alone cannot resolve ties or DST folds.
4. Assign ordinals 1, 2, ... and keep `n > offset` and
   `(limit == 0 or n <= offset + limit)`. Reset per node/setup/day. Inherit the
   same offset/limit values down the path; depth changes the matching stream.
5. Score the retained entries using only outcomes available by the score cutoff.
   Losses, time exits, unknown outcomes and censors never refund or replace a
   selected slot. Eventual binary eligibility never decides entry membership.

Original/re-entry parentage and direction remain explicit. Preserve any existing
selected-parent strategy constraint as a causal entry qualification before
numbering. Selecting observed re-entry fills is not a counterfactual replay of
broker trading after the backend skips a parent. The daily window selects entries;
it does not close trades at the window end or replace their Macro deadlines.

| Acceptance case | Required selection / behavior |
| --- | --- |
| Matches `[1,2,3,4,5]`, 0/0 | All five. |
| Same stream, 3/0 | `[4,5]`; offset only. |
| Same stream, 0/1 | `[1]`; limit only. |
| Same stream, 3/2 | `[4,5]`. Three matches select none; four select only the fourth. |
| Parent `[1,2,3,4,5,6,7,8]`; child `[2,4,6,7,8]`; 3/2 | Parent selects `[4,5]`; child selects `[7,8]`. Child preselection is a parent preselection subset; selected sets need not be subsets. |
| Next day, same setup | Start again at ordinal 1; no carryover. Other setups have independent counters. |
| `[00:00,08:00)` | Entry exactly 08:00 is excluded. Discovery 07:59 with midpoint/fill 08:01 is excluded. A selected 07:59 entry can close after 08:00. |
| `[22:00,02:00)` | 01:00 belongs to the prior start date; 02:00 is excluded. |
| Equal raw entry milliseconds | Producer sequence breaks the tie, then stable identity. Repeated analysis-clock values never duplicate or reorder raw entries. |
| Four ratio rows plus parity | One entered decision for the declared entry/setup; parity adds no slot or independent support. |
| Selected entries 4 and 5 time out / remain unresolved | Keep slots 4 and 5. Do not replace them with entries 6 and 7. Report their distinct outcomes. |
| Training cutoff precedes a selected close/observation | The slot remains selected; exclude its unavailable outcome from that score. Do not recompute sequence from only completed outcomes. |

Bind values, ordering/reset/grain policy version, full path, engine/outcome tuple,
window/category and knowledge cutoff into immutable research/WFO identities,
membership digests, replay and caches. Each candidate needs its own full eligible
stream. TRAIN and TEST use the same policy; freeze parameters from TRAIN and
do not tune them against TEST. Preserve root-overlap and close/observation
knowledge boundaries. Reject negative, fractional, Boolean and malformed values.

Report offered, rejected, entered, offset-skipped, limit-excluded and selected
counts separately, followed by TP/SL/time-exit/censored counts. Binary TP/SL rates
need an explicit eligible denominator; time exits can contribute observed returns
without being recoded as binary losses. Preserve both preselection support and
selected support in parent/child explanations and pruning.

### Intake Efficiency Boundary

Producer transition checks catch contradictions early and export complete proof.
They do not authenticate uploaded files or establish backend relational storage.
Keep whole-source identity/hash checks, strict tuple/scalar/clock/reference/semantic
validation, source-versus-stored reconciliation and the short atomic READY gate.
Only correctly bound checkpoints may be reused; a changed policy or file digest
invalidates the relevant evidence. Never trust a producer success flag alone.

Coordinate with the ongoing backend optimization: measure upload, parsing/hashing,
COPY, semantic checks, projections and publication separately; reuse its bounded
batch/index/cache work. Do not port this repository's diagnostic SQLite reader
into backend runtime or add a second ingestion service. The measured local reader
times below are neither backend benchmarks nor a promise of upload speed.

## Pins, Examples And Validation

Final MQL source commit: `eb816df65bee051e8ae906cc90d89b7eb6ee386f`.
S4 evidence commit: `afda9d45cec92c38c9664c689267feffe65c259a`.
MetaEditor 6230 AVX2/FMA3 compiled both EAs with zero errors and zero warnings.
S5 adds consumer JSON proof/duration metadata; generated MQL and both EX5s remain
byte-identical to the accepted S3/S4 builds.

| Binary | Bytes | SHA-256 |
| --- | ---: | --- |
| `Pivot_Macro.ex5` | 274942 | `246cb9a54b3ab9ef766c1c54d1f6aa8d1b4601b7d8298d60e6810b46920a3185` |
| `Candle_Pattern_Discovery.ex5` | 158692 | `34e18fea0dd7e2b9c30d4073ae605f63bdec0f6d00feae5811f44ed7d24ca98e` |

Private delivery directory: `.codex-artifacts/entry-quality-lifecycle/s5/`.
`consumer-contract.json` SHA-256:
`7f4a5f1c12fef2cafaff1c9b2905c53ec958d398d4e7ce546294cecec2cd5f0e`.
`handoff.zip` SHA-256:
`9008662bffa607a65ed0380579c961745149908884925755407d917b3436e71a`.
The archive contains the descriptor, `release-pins.json`, native year receipts,
examples, validation results and `SHA256SUMS`. Source/build/job/TSV hashes remain
outside sealed source folders. Raw native datasets are retained locally, not
embedded in the archive or tracked fixtures.

The descriptor comes from `tools/model_dataset/schema_contract.py`; it includes
profile coefficients, conditional proof fields and supported durations. Regenerate
with the [existing tool commands](../../tools/model_dataset/README.md).
Examples use the existing `tools/model_dataset/tests/fixtures.py`; synthetic
compiler/symbol facts identify fixtures, not native-run provenance.

| Example names | Expected result |
| --- | --- |
| `SYN_OLD_PIVOT`, `SYN_OLD_CANDLE` | Historical profiles pass unchanged. |
| `SYN_NEW_PIVOT`, `SYN_NEW_CANDLE` | New profiles and complete entry proof pass. |
| `SYN_EQUALITY_CANDLE` | Risk equals the independently calculated fixed minimum; pass. |
| `SYN_REJECTED_CANDLE` | Distance rejection, no parity/entry/binary target; pass. |
| `SYN_EXPIRY_PIVOT` | Fill/request clock separation and later observed quote at expiry; pass. |
| `BAD_FALSE_ELIGIBILITY`, `BAD_MISSING_PROOF` | Reject false admission or incomplete proof. |
| `BAD_MIDPOINT_DEADLINE`, `BAD_MIXED_PROFILE` | Reject a borrowed deadline or mixed profile tuple. |

All seven valid and four intentionally invalid examples behave as expected;
all 95 shared tests pass. The schema header check proves no MQL regeneration
change. S4 accepted 48 native datasets, exact repeated exports/broker facts,
feature prefixes, H2/H4, seasonal clocks, FX and independent feature audits.

| Final one-year run ID | Native generation | Local strict reader | Real / virtual time exits |
| --- | ---: | ---: | ---: |
| `EQL_S4_CANDLE_FINAL_YEAR` | 25.855 s | 136.766 s | 104 / 999 |
| `EQL_S4_PIVOT_FINAL_YEAR` | 32.846 s | 69.331 s | 1543 / 9479 |

Each naturally sealed year has 31,438,575 real ticks and effective raw coverage
2015-08-11 00:00:01 through 2016-08-09 23:59:56. The requested first day supplies
startup history. Baseline generation was 51.531 / 71.754 seconds; fewer entries,
different re-entry counts and shorter Pivot lifecycles change workload. Pivot
adds audit rows and takes longer to read, with similar cost per row. These results
do not isolate an algorithmic gain or certify ten-year speed. No automatic
second/third year was justified by the measured state/resource evidence.

The user's subsequent cross-symbol verification reuses the exact accepted S4
H1/M3 week runs, with every source/EX5/TSV hash unchanged. Independent point-unit
arithmetic checks 14,166 trial proofs and 3,935 entry audit rows with zero unit or
admission mismatches. Both BUY/SELL admissions and distance rejections are covered
on both engines. Native accepted-request/parity/outcome/trade counts agree:

| Tested symbol | Point / trade tick | Candle broker trades | Pivot broker trades |
| --- | --- | ---: | ---: |
| `XAUUSD_Exness_2015` | 0.001 / 0.001 | 15 | 71 |
| `EURUSD_Exness_2015` | 0.00001 / 0.00001 | 1415 | 212 |

Receipts: `closeout/cross-symbol-audit.json` in the same private evidence root.
The rule uses each symbol's quote and specification in price units. The tested
native symbols have zero stops/freeze levels and equal point/tick sizes; existing
synthetic boundary tests additionally cover nonzero levels, unequal point/tick,
zero spread and exact admission equality. No broker-wide or live certification
is implied. Earlier native receipts and the published handoff archive are retained.

### Human Acceptance And Rollback

The user explicitly selected Q06 option B after automated validation and the
cross-symbol audit: close this implementation delivery with human acceptance
deferred. This is separate from the earlier Candle visual-polish deferral and
does not claim human or live acceptance. Plan D12 records the decision. The
original archive retains its pre-deferral receipt; this closeout annotation owns
the later decision. Concrete cases remain available for the deferred review:

| Case | Private report and review focus |
| --- | --- |
| Pivot M6/M3, 2015-08-24..26, 100 ms delay | `s3/pivot-final-delay-report.xml`: 43 real expiry closes, one exact owned close per position, later observed deal facts and separate parity clock. |
| Candle M6/M3, same dates, zero delay | `s2/candle-expiry-dense-report.xml`: 55 real expiry closes, fixed entry rejection and existing Candle lifecycle. Later Candle regression remains exact. |
| Pivot H4/M3, 2016-03-11..15 | `s4/pivot-h4-spring-report.xml`: own four-hour entry deadlines across the seasonal/weekend interval. |

Paths above are relative to `.codex-artifacts/entry-quality-lifecycle/`; MCP's
`.xml` reports contain XLSX workbooks. Adjacent `-job.json` files locate the exact
tester INI/SET, source/binary pins and native job identity. A visual replay uses
the same actual EA/settings and a fresh run ID; never overwrite the retained run.
Review declined tight entries, unchanged SL/TP, per-entry deadlines, delayed
observable closes and no duplicate close/entry. Native forced refusal, missing
quote/specification and exact-equality injection remain unrun; deterministic
fixtures and source review cover their stated invariants, not live equivalence.

Rollback uses normal reverse-order revert commits with each sprint's recorded
parent and matching private binaries. Keep new-profile datasets and receipts
immutable. Any later live rollout needs older positions flat, hedging, one EA
instance per account/symbol and the existing human/broker/feed gates. This handoff
authorizes no account operation, backend deployment or rewrite of historical data.
