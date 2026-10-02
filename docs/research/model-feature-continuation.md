# Sealed Intake Continuation Candidate

This owner specifies the opt-in producer candidate for the growing-intake platform.
The [current index](../README.md) owns its validation status. Existing
[complete-run profiles](../architecture/model-feature-dataset.md) and dated
[2.10 handoff](entry-quality-lifecycle-backend-handoff.md) remain authoritative
for accepted ten/eleven-file exports. This candidate is not an operational intake
profile, a native acceptance receipt, or permission to activate an EA.

## Identity And Ownership

The exact new family is `MQL5_MODEL_CONTINUATION`, continuation version `1`,
with the generated descriptor SHA-256 and the exact embedded old tuple:
producer `2.10`, schema `1`, feature set `macro_micro_standard_v1`,
extension `1`, and the engine-specific outcome policy for
`PIVOT_MACRO_V2` or `CANDLE_PATTERN_ATR_V3`.
[continuation_contract.py](../../tools/model_dataset/continuation_contract.py)
enumerates every file, column, type, key, state field and source pin. There is
no schema inference or arbitrary table dispatch. The descriptor declares
`operational=false`; source/offline checks cannot change that status.

Shared capture receives adapter configuration and read-only state rows. It
imports no engine globals. Engine-owned generated serializers observe consumed
Pivot triggers/PP arms, pending origins, midpoint/parity/deferred closes and
broker ownership; Candle fills/closes/re-entry/cursors; and shared confirmed
structure/context. Broker strategy, request admission, execution and immutable
SL/TP remain under their existing owners.

Each physical run has an explicit source/session namespace and maps its
run-local first identifier cell to the canonical session. IDs, clocks or prices
cannot guess cross-run equivalence. A new physical tester run must bind an
accepted replay witness. Same-process demo rotations preserve actual engine
state. Demo restart/restoration and REAL capture are unsupported. Tester-to-demo
requires a separately evidenced source/origin/session transition and exclusive
entry cutover. Historical tester censors stay frozen; simulated pending positions
or re-entry never become demo fills. Unsupported temporal gaps reject acceptance.

## Inputs And Observed Proofs

`Enable_Intake_Continuation=false` by default; enabling it also requires
`Enable_Signal_Feature_Export=true`.
`Intake_Source_Id` and `Intake_Session_Id` select safe namespaces.
`Intake_Segment_Seconds` accepts exactly `3600`, `14400` or `86400`:
these are collection/synchronization intervals, not training durations.
`Signal_Feature_Run_Id` remains the fresh physical run ID.

Source proof is derived from actual pinned semantic MQL5/Python source bytes;
configuration proof is derived from the actual canonical core manifest.
Optional `Intake_Source_Proof` and `Intake_Configuration_Proof` are expected
pins that reject mismatches. They cannot replace observed proof. Generated
serializer bodies are checked against the source registry without circular hashes.

`Intake_History_Proof` is required. For TESTER it pins the immutable original
source/session history-anchor receipt, independently authenticated by the trusted
native owner. Each physical job also needs its own separately registered current
history receipt; changing its end date does not change the anchor. LIVE_DEMO keeps
its independently verified native history receipt policy. SHA-256 shape is not
certification. Code identity and market-source identity are different; unsupported
legacy provenance rejects. Actual consumed warmup, Macro/M1, pattern, indicator
and execution ATR values, including failures, are hashed into the checkpoint.
Those observations cannot certify unavailable history or missing callbacks.

### History Anchor And Physical Job Receipts

The explicit `history_binding_policy` is
`IMMUTABLE_ORIGINAL_ANCHOR_REGISTERED_PHYSICAL_JOB_HISTORY_V1` for TESTER and
`INDEPENDENT_VERIFIED_NATIVE_HISTORY_RECEIPT_V1` for LIVE_DEMO. The original anchor
remains fixed across same-source/session/configuration replay. The current job
receipt is `NATIVE_PHYSICAL_JOB_HISTORY_V1` with exactly these sixteen keys:

`kind`, `source_origin`, `native_run_id`, `physical_run_id`, `source_id`,
`session_id`, `engine`, `symbol`, `configuration_proof`, `history_anchor_sha256`,
`date_from`, `date_to`, `model`, `native_custom_symbol`,
`native_decision_spec_fields`, `bounded_observation_pins`.

The trusted native source owner issues the current receipt after the actual job,
binding its original loaded INI/SET, native run and report, source/EX5 and exact
current dates. Both current receipt and original anchor bytes are independently
registered out of band and rechecked. A caller cannot replace either pin. The
from-date stays fixed; the end date may grow but cannot shrink below the anchor.
Source/session/symbol/engine/configuration and the explicit sixteen decision-spec
fields stay equal. Current spec has those fields plus `symbol` and `custom_symbol`;
original dynamic timestamps/prices are excluded from source identity. Changed
old consumed quotes/history still fail full causal-prefix and semantic-state
equality before any suffix emission.

`bounded_observation_pins` are informational references inside the registry-pinned
whole current receipt. Their nonempty/hash shape does not authenticate independent
observations. The trusted owner must retain actual allowed bounded native source
observations; it cannot certify them by copying caller checksums. No unchanged
whole-cache, external broker-equivalence or all-physical-tick claim is added.

Replay uses safe `Intake_Replay_Witness_Id` and exact
`Intake_Replay_Witness_Proof`, under the fixed witness root. Operators never
supply arbitrary paths. An immutable source receipt remains external to the files
it authenticates. Digests establish equality; they do not authenticate a caller.

## Exact Segment Inventory

Under `Common/Files/MQL5ModelContinuationV1/runs/<physical_run_id>/segments/<ordinal>/`
a published segment contains exactly these six files:

| File | Contents |
| --- | --- |
| `segment_manifest.tsv` | Exact key/value manifest, old manifest keys prefixed `core_`, source/session/origin mapping, predecessor seal/state, configuration/history binding and observed weekly native sessions. |
| `input_events.tsv` | Ordered bounded canonical callback blocks, callback counts/bounds, causal chain, quote/transaction envelopes, acquisition/clock/history evidence and per-callback maximum gaps. |
| `fact_events.tsv` | Fact ordinal, causal input ordinal, CAPTURE/TERMINAL phase, explicitly enumerated old table, typed row key and exact typed payload. |
| `window_births.tsv` | Immutable typed Macro births, source/open clocks, OHLC, raw/trade ladders, validity and first quote observation. |
| `state_checkpoint.tsv` | Exact START/END component/object/field/type/value rows. |
| `segment_seal.tsv` | First-five-file row/byte/chain proofs, completion, input/fact/birth/record cursors, causal chain and END-state digest; terminal phases additionally retain exact core summary fields. |

The descriptor is the machine-readable header/key inventory. Old payload fields
use their registered headers/types. Native typed TEXT uses literal `\N` for
a deinitialized MQL5 string, `-` for explicit empty, and lowercase UTF-8 hex for
nonempty text. Private comments hash separate NULL/EMPTY/UTF8 domain tags.
Continuation-private FLOAT64 values use exactly 16 lowercase IEEE754 hexadecimal
bits; finite DBL_MAX/EMPTY_VALUE, signed zero and tiny values remain distinct.
NaN/Inf reject. Quotes, transactions, consumed-history and state share that
lossless encoding; legacy business Decimal output remains unchanged. State object
IDs use canonical decimal text. Maximum row is 1 MiB; decoded payload cap is 480 KiB.
Every file chain is SHA-256 of the previous 32 digest bytes followed by the exact
UTF-8 row including CRLF, with the header included. State equality hashes the
canonical row body excluding START/END. No date-based suppression occurs: a late
outcome referencing an old entry is a new fact ordinal.

At segment open the seal has private name `segment_seal.partial`. Publication
flushes/closes all five payloads, writes/flushes/closes the private seal, and
moves it to `segment_seal.tsv` last. Inbox discovery must skip directories
without the final seal. A partial or crash directory is never a failed intake
job or a complete segment. Actual native publication/crash behavior still needs
acceptance; source compilation is not an atomicity receipt.

## Callback And Coverage Policy

The generated descriptor pins a different acquisition policy for each origin:

| Origin | Acquisition | Observer clock | Source-quality claim | Startup state |
| --- | --- | --- | --- | --- |
| TESTER | `AUTHENTICATED_LOCAL_CUSTOM_TESTER_DELIVERY_V1` | `TESTER_SIMULATED_QUOTE_SECONDS` | `HISTORICAL_SOURCE_GAPS_UNKNOWN_V1` | `FIRST_DELIVERED_TICK_PRE_DISPATCH_FULL_STATE_V1` |
| LIVE_DEMO | `OBSERVED_CALLBACK_STREAM_FRESH_QUOTE_3S_V1` | `UTC_SECONDS` | `INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1` | `ONINIT_FULL_STATE_V1` |

MQL5 may coalesce callbacks. Neither origin promises all physical broker ticks or
complete TIMER/TRADE queue delivery. The source hashes every processed
TICK/TIMER/TRADE callback with its full acquired quote, engine sequence, broker
clock and typed transaction/request/result envelope. Request/result values are
defined only for TRADE_TRANSACTION_REQUEST. Dataset bounds remain actual source
quote/evidence clocks.

TESTER separates delivery from quote freshness. A quoted callback records
`capture_status=OBSERVED_CALLBACK_ONLY`, native quote status and nonnegative
fresh/stale/missing counts, including separate stale TICK/TRADE counts. Raw quote
age, simulated quote jumps and monotonic diagnostics remain exported. A stale
TIMER quote is an observation; it does not prove source completeness or a market
closure. Missing quotes, stale TICK/TRADE and unavailable observations reject
native admission. This policy does not relabel historical gaps as closures or
infer source quality from a timer total.

TESTER START is the complete initialized shared/engine state after the first
delivered TICK refreshes its quote, before the first input, ModelObserve or engine
dispatch. All OnInit strategy state, including Candle's initial Micro cursor,
remains serialized. TIMER/TRADE-first, a missing/invalid first quote, a fact/birth
before anchor, or finalization without that anchor rejects the whole run; the
producer never skips to a later tick. LIVE_DEMO retains its OnInit START.

LIVE_DEMO requires native broker-estimate quote age between -1 and 3 seconds.
Connected/synchronized flags or cached SymbolInfoTick success alone do not prove
availability. Unsupported active observer or monotonic gaps over 3 seconds,
unavailable observations and clock regressions reject. Weekly quote/trade sessions
are observed metadata, never proof of holidays, outages or quiet-market closure.
Only independently authenticated, revision-pinned calendar/feed evidence bound
to the same history receipt and clock basis may cover a closed interval.
`VerifiedClosure` checks binding; a trusted owner must authenticate the receipt.
No native demo closure/crash/collector acceptance is claimed.

Blocks flush after 60 observer seconds, 65,536 callbacks, trades, acquisition
transitions, large callback gaps or rotation. Reader bounds are 63 seconds and
65,536 callbacks. Each block retains callback counts, first/last clocks and raw
maximum gaps. The exact input header has 36 columns: the generated original 29
plus capture/quote status and five quote partitions. Replay preserves causal
simulated quote clocks, quotes, transactions and consumed-history values; it
excludes physical monotonic zero-based fields 8, 9 and 28 from TESTER equality. Exported raw
physical values remain available for review.

### Authenticated Native Tester Admission

[Native evidence](../../tools/model_dataset/native_evidence.py) requires an
injected trusted source-owner `NativeJobRegistry`, never a caller's JSON, checksum,
boolean or registry. Its exact registration binds the authorised scope and
original native job, natural completion within the wall deadline, independent
generated-tick report/journal counters, loaded INI/SET/report values, source/EX5,
local-custom original history anchor and current physical-job history receipt,
original six-file segment hashes and any verified cold-prefix counters. Exactly
seven original artifact roles are required: `prelaunch`, `owned_job`,
`native_result`, `report_json`, `report_xlsx`, `history`, `history_anchor`.
The helper is not hardcoded to QA dates. Q05 A authorised the bounded two-day
extension lane, and the user's scoped delegation covered the necessary successor
proof choices. The executed source was LOCAL_CUSTOM_TESTER; it does not certify
external broker equivalence or a live feed.

Artifact parsing uses the same bounded, nofollow, regular-file FD snapshot that
is hashed, with before/after identity fences, strict JSON and nonblocking special
file refusal. Factory-issued proofs have immutable defensive snapshots and
identity tracking; direct construction, `__new__`, subclasses, mutation and missing
registry cannot authorize admission. A submitted archive cannot become its own
trust anchor by recomputing checksums.

All delivered TICK ordinals must equal the independently observed native generated
total, with exact callback/quote partitions, ordered chains, native natural
completion and source call-site proof. Count equality alone does not certify
external feed quality, TIMER/TRADE completeness or missing physical ticks.
Registered COLD delivery is provisional. Whole-old comparison, an authenticated
ordinary fence and paired cold/replay evidence remain separate gates. A generic
safe checkpoint may have no pending broker or virtual objects; its exact actual
nonnegative counts, healthy full state and native terminal-effect fence still
must match. Positive broker-and-virtual pending continuity is a separate mechanism
gate and was demonstrated at ordinary16 for both engines. The fence audit is
pinned by the same trusted native owner. Consumer database reconciliation remains
independent of these source checks.

## Replay, Bootstrap And Terminal Branch

An ordinary rotation snapshots engine/shared END, seals ROTATED, then opens the
next segment with the same actual START state. It never calls ModelSeal,
CandleFinish or engine finalization/reset. Typed window births allow pending
reference closure before the old parent row appears on window close.

Historical continuation replays the original history anchor with exactly pinned
settings/source/history. Native source code verifies the complete canonical INPUT
block chain, every old FACT/BIRTH prefix and actual START/END semantic state.
Only after equality at the predecessor cursor does it suppress the proven
prefix and export a suffix. It still pays all replay CPU; savings are export,
transfer and import only. The one-day bytes below are measured; long-history CPU
and maximum-state costs remain unmeasured. New wall-clock timings
need not equal old acquisition timings. Causal inputs are never silently dropped.

The old READY archive lacks a pre-finalization checkpoint. Bootstrap requires a
new complete paired replay and whole-original-source comparison. The actual
TERMINAL branch is retained separately. Only an earlier ordinary ROTATED prefix
before every native tester-end effect is extendable; overlap after that boundary
must be replayed/exported again. A TerminalBegin PRE_FINALIZATION snapshot alone
is insufficient: native forced closes can arrive before OnTester/ModelSeal.

The trusted source owner must audit native broker/journal effects and issue
`VerifiedNativeFence`, binding the actual paired terminal seal, code/config/feed
pins, first terminal-effect ordinal and last safe input ordinal. The reader requires the factory-issued delivery proof to bind the original
trusted native-owner fence audit; caller fence fields alone cannot authenticate it. Unsupported/absent provenance or an end-effect
inside the selected cursor rejects. Empty/no-signal states cannot establish the positive pending broker/virtual
mechanism. They may form a generic safe resume checkpoint only after the same
actual state, whole-source and authenticated terminal-effect fence checks.

[continuation_reader.py](../../tools/model_dataset/continuation_reader.py)
provides `compare_legacy_whole`, `build_witness` and `bootstrap_witness`.
The bootstrap helper derives the legacy binding from the actual whole old
archive; callers cannot inject a certification string. It compares every typed
old fact and semantic summary under explicit run mapping. Only individually
named physical writer metric `buffer_peak` is classified separately, with both
actual values pinned; semantic counts/bounds/censors/statuses/availability/history
stay exact. The extendable witness contains six fixed files:
`witness_manifest.tsv`, `input_prefix.tsv`, `fact_prefix.tsv`,
`window_prefix.tsv`, `state_checkpoint.tsv`, `witness_seal.tsv`.
Frozen legacy contexts retain terminal facts. Active continuation views use
explicit phase/source mapping and never append capture after terminal cursors.

State registry exclusions are physical export handles/buffers/row counters/seal
flags, reconstructed indicator handles, and non-decision logging/audit/visual
counters. The generated registry observes all semantic engine fields, including
healthy capture and pre-finalization lifecycle flags. Candle and Pivot each
observe actual OnTester completion; natural and interrupted terminal status must
agree with it. Human/source review must
confirm each exclusion remains observational.

## Candidate Validation And Cost

Final12 freezes 53 MQL5 and 10 Python files, with 59 semantic source files excluding
four generated headers. Source SHA-256 is
`eff52334565416511d540fd4dbd739d6aa349ba709c2118452faf8c7f502ac30`;
descriptor SHA-256 is
`d29647a3f1f44fb72fde615d1ec0d358dafe0d6eef6ff150a0568cf90a1f22e4`.
The only final11-to12 changes are the native generic fence's exact zero-count
validation and the generated source/descriptor literals. Strategy, causal
capture/replay and legacy writers are unchanged.

All 64 focused continuation/native-evidence tests pass in 22.870 seconds, including
changed-end history authentication, original-anchor tamper recheck, zero-state
fence acceptance and negative counts/ordinals. The unchanged 95-test legacy-reader
gate is reused. Existing Python tests and both real EA compiler owners are used;
no MQL5 test EA/script/harness, framework or CI was added. The offline reader uses
a bounded 8 MiB temporary SQLite cache; Django retains authoritative typed bounded
PostgreSQL COPY/derive/reconciliation.

Both actual native working targets compile with MetaEditor6230 optimized
AVX2/FMA3, zero errors/warnings: Pivot 7.893 seconds and Candle 2.821 seconds.
Their EX5 pins differ from the earlier hidden12 compilation because they were
compiled at the actual catalogued QA paths. Both receipts remain immutable:

| Actual native working binary | Bytes | SHA-256 |
| --- | ---: | --- |
| Pivot | 518,530 | `8bcbe939f1ee189ca2588959b222d469dfad6cf85494ae24c44e4aac2d1efe7a` |
| Candle | 274,330 | `ec0a2a48ebe7511589b84ce0f740caa8b74b046ae2619403c67c9c30abd78db8` |

Pins and logs are retained separately in ignored
`build-final-candidate-12/` and `build-final-candidate-12-native/`.
Original c04 binaries and every earlier candidate remain unchanged.

## Final11/12 Date-Step Native Evidence

Q05 A authorised original-anchor 2016-03-14 to 2016-03-15 and extended
2016-03-14 to 2016-03-16, exact XAUUSD_Exness_2015 LOCAL_CUSTOM_TESTER, native
real ticks Model4, M3/H4 and the reviewed explicit inputs. Eight final11 jobs
passed: base COLD and extended MODE_OFF/COLD/REPLAY for each engine. These prove
changed-end authentication and that prefix16 plus the extended replay suffix
equals the extended COLD source, including first-day overlap and second-day
callbacks. The original history anchor stays fixed; each physical dated job has
its own authenticated receipt.

Four accepted final12 jobs then proved a fresh latest-safe ordinary46 checkpoint:
extended COLD and REPLAY for each engine, without additional dates. A failed
Pivot prelaunch case carried a stale optional expected source pin; source rejected
OnInit, and a stale report was refused. The preserved failure is not an admitted
job. The corrected case used the automatic source pin with mandatory independent
registered source/EX5/config/job binding. Each actual job launched once under the
same exclusive native owner, 300-second wall deadline and waits <=45 seconds.
All jobs completed or stopped; no live-hour wait or full-history run occurred.

| Final12 proof | Pivot | Candle |
| --- | ---: | ---: |
| Native delivered TICK count | 210,367 | 210,367 |
| Whole callbacks | 383,340 | 383,583 |
| Canonical input blocks | 9,959 | 10,189 |
| Immutable facts / births | 824 / 12 | 5,290 / 12 |
| Full ordered START+END state rows | 111,128 | 18,848 |
| Ordinary16 pending BROKER / VIRTUAL / PARITY | 1 / 13 / 1 | 8 / 26 / not applicable |
| Latest46 pending BROKER / VIRTUAL / PARITY | 0 / 8 / 0 | 0 / 0 / not applicable |
| New CAPTURE outcomes for pre16 entries | 7 | 34 |
| Cold / replay native wall, ms | 3,918 / 3,711 | 3,841 / 4,350 |

Whole cold48 equals its proven prefix46 plus two emitted replay segments for every
ordered fact, birth, full state boundary and causal input/history digest. Native
report/journal and source state independently place the resume cursor before all
terminal effects. Every legacy row/semantic summary and all 43 native statistics,
Results, Orders and Deals cells match the retained same-date final11 MODE_OFF.
No final12 MODE_OFF run is claimed: that unchanged-input evidence is reused under
the exact source-difference proof and new final12 COLD/REPLAY whole-source parity.
The final11 actual changed-date proof is likewise retained as unaffected evidence.

After an accepted full capture, mint the next witness at the latest independently
proven safe ordinary ROTATED checkpoint. This advances the resume/export cursor;
it does not change the already published historical knowledge cursor. Latest46
has zero broker state, while the separate ordinary16 positive pending proof
establishes the requested mechanism. Whole terminal/censor branches remain frozen.
New late observations are immutable CAPTURE facts with explicit phase/source
mapping; no terminal outcome is overwritten or adopted into the resume prefix.

Actual-original offline mutations reject 29 cases per engine, covering unissued
authority, changed source/EX5/config/history/anchor, wrong replay cursors/witness,
missing or corrupted input/state/seal and caller-recomputed submitted checksums.
These are copy mutations, not native crash/feed fault injections.

### Measured Cost And Limits

| Two-day actual final12 cost | Pivot | Candle |
| --- | ---: | ---: |
| Full sealed export, bytes | 14,468,391 | 15,180,389 |
| Latest46 two-segment suffix, bytes | 346,237 | 378,104 |
| Sealed suffix export reduction | 97.607% | 97.509% |
| Local replay witness, bytes | 6,667,745 | 13,472,981 |
| Full input-block file bytes | 5,657,599 | 5,885,560 |
| Full state-checkpoint file bytes | 7,437,535 | 1,108,046 |
| START rows / body bytes | 55,564 / 3,772,891 | 9,424 / 562,046 |
| END rows / body bytes | 55,564 / 3,662,100 | 9,424 / 543,456 |

Fact payload hex is exactly twice the native UTF-8 body: 1,033,770/516,885 bytes
for Pivot and 7,112,654/3,556,327 for Candle; envelope metadata adds more.
Canonical blocks average 38.49/37.65 callbacks, so they avoid a raw per-tick tape
but remain a material source-local witness. State snapshots can dominate sparse
Pivot output. The witness is not a free transfer and must remain local to the
producer for replay. Cold wall ratios against retained tiny MODE_OFF are
1.554/1.442; these cached owner timings do not isolate serialization/SHA CPU.

Every update still replays CPU from the original anchor. Only the verified
suffix is exported/transferred/imported. An old five-year READY source requires
a one-time actual whole-source comparison and newly observed safe pre-terminal
witness; unsupported provenance rejects. It does not support arbitrary next-date
state restoration. Five-year/full-history CPU, maximum semantic state, long live
hourly capture, all physical ticks and external feed quality remain unmeasured.
Stale TIMER observations remain raw evidence; missing/stale TICK/TRADE and
unsupported LIVE_DEMO gaps still fail closed.

The ignored `native-20160314-02/` owner retains original job archives and
`extended12-replay-{pivot,candle}-paired-continuation-validation.json`,
`{pivot,candle}-native-broker-parity-12.json`,
`extended12-cold-*-{bootstrap-witness,native-latest46-fence,positive-pending16}.json`,
`{pivot,candle}-actual-adversarial-checks-12.json`,
`native-export-costs-12.json` and original-pin consumer bundles.

### Operational Trust Handoff

The tested route is the exclusive source/native owner issuing protected original
job/INI/SET/report/journal/source/EX5/history and six-file pins, then a private
read-only handoff to the independent consumer. An operational manual tester update
needs that trusted owner to deliver the evidence through an authenticated,
source-scoped server inbox whose protected registry supplies admission pins.
Staff uploads, caller JSON, file checksums and a submitted seal cannot populate
that authority themselves. That authenticated server-inbox issuer/service is
not implemented or activated by this producer QA; collector/demo/production
activation and database publication belong to the platform's separate gates.

The user explicitly delegated necessary technical acceptance choices. The source
owner reports the scoped technical proof and root reviews it; no human-observed
chart/tester verdict is recorded. Operational family status remains false.
Independent wire/core interoperability is separate from imported database integrity
or a live deployment claim. The current index owns final review and commit status.

## Historical Same-Day Native Evidence

Q02 A authorises the one-day LOCAL_CUSTOM_TESTER lane; Q03 supplied Navigator
refresh/MetaEditor availability. D17/Q04 A requires the MQL-side delivery/freshness
classification repair and explicit unknown historical source quality, without
waiving exporter defects. Candidate10 is retained same-day evidence. Review found
that its dated history-receipt identity prevented a later end date; final11 fixed
that defect and the dated native proof above covers extension. The following
candidate10 measurements retain their original one-day scope.

| Candidate10 pin | SHA-256 |
| --- | --- |
| Semantic source (53 MQL5 and 10 Python owners) | e338b7d46400a5438dbf97953743cb4972af6ad891204d2100f5a1f233bb22d9 |
| Exact generated descriptor | cfee0bfd1986ef1fb40e164809f6e81eab9b6ffbf0256d6aaf4990ea1a1a60f2 |
| Pivot EX5, 518,596 bytes | d3d554bd02768bfe6d90c6bcf37e4c720203c9753aa4442d5c17178eb64c1b49 |
| Candle EX5, 274,312 bytes | 4e298bb307fcfebed4d70a7a6d83b3d6baeedfc4b35cc8ac19caa1c597ac218a |

Optimized MetaEditor6230 AVX2/FMA3 compiles both with zero errors/warnings:
8,099/3,026 ms. Fresh binaries and all frozen source bytes match; root original
EX5 files and retained earlier candidates remain unchanged. The final 41 continuation
and 13 native authority tests pass in 15.690 seconds; 95 unchanged old-reader tests
reuse their valid 14.866-second baseline gate. Generated contract and diff checks pass.

All six candidate10 native jobs complete naturally, once each, within 300 seconds.
Mode-off10 matches retained c04b3d6 ten/eleven TSVs under only explicit run-ID
mapping. Cold and replay match all 43 native non-job report statistics and every
Results/Orders/Deals cell: 137,217 generated ticks, 461 bars and 13/35 trades.
Natural tester report quality is 100% real ticks; that label does not certify an
external broker or full physical-tick cache.

Cold captures produce 25 sealed segments each. The whole legacy typed facts and
semantic terminal summary match, with only named physical buffer_peak recorded
separately. Ordinary segment16 has actual pending Pivot 1 broker/13 virtual/1 broker
parity and Candle 8 broker/26 virtual objects. Original native report deals show
all 13/35 broker closes strictly before the final quote; no end-of-test close is
adopted. The original TERMINAL branches stay retained. Source states independently
prove no outstanding broker fill at finalization.

Each source-created witness selects only those 16 ordinary segments. The producer
replays the same original anchor, verifies every old INPUT/FACT/BIRTH and full
START/END checkpoint, suppresses proven ordinals, and exports 9 suffix segments.
Cold16 plus replay9 exactly matches cold25:

| Paired evidence | Pivot | Candle |
| --- | ---: | ---: |
| Actual callbacks | 223,706 | 223,824 |
| Canonical input blocks | 3,744 | 3,856 |
| Immutable facts | 437 | 2,920 |
| Typed window births | 6 | 6 |
| Full ordered START/END state rows | 55,908 | 9,540 |
| Later CAPTURE outcomes for entries in the proven prefix | 7 | 34 |

Every causal chain boundary matches. Late observations retain their own ordinal;
no date filter removes them. No terminal key is reused as an active mutable fact.
The native quiet-capture audit records 3,684/3,688 blocks without facts, with
129,737/124,073 TICK and 84,144/80,330 TIMER callbacks. Four/one segments contain
callbacks and zero facts. Quote freshness and clock diagnostics stay separate:
10,018 stale TIMER observations each, zero missing/stale TICK/stale TRADE/unavailable.
Between-block simulated quote jumps reach 3,595 seconds; no market-closure or external
source-quality claim follows.

Twenty-four actual-original negative checks per engine reject missing/fake proof,
changed source/binary/config/history/origin, changed prefix cursors/witness, omitted,
duplicated or corrupt input, missing state/seal and substituted native artifacts.
Original receipts/files remain pinned. These are offline copy mutations; native
crash, feed fault injection, demo capture and collector activation were not run.

| Actual10 bytes / cost | Pivot | Candle |
| --- | ---: | ---: |
| Cold25 total segment bytes | 6,606,267 | 7,301,609 |
| Cold input blocks | 2,139,349 | 2,247,248 |
| Cold fact envelopes | 586,038 | 4,363,216 |
| Cold START/END state bytes | 3,747,792 | 557,356 |
| Corresponding legacy archive bytes | 286,338 | 1,971,950 |
| Replay9 suffix bytes | 1,873,950 | 2,141,179 |
| Cold case wall including native owner/report work | 3.246 s | 3.171 s |
| Replay case wall including native owner/report work | 3.154 s | 2.983 s |

Fact hex doubles decoded payload bytes exactly; full envelopes are 2.156x/2.229x.
Maximum actual row is 6,306/6,623 bytes. Pivot snapshots dominate sparse capture;
this wire is larger than its legacy archive. Suffix-only export/transfer savings
do not remove same-anchor CPU. Timings are single mechanism observations,
not an isolated overhead benchmark, peak-memory result or five-year cost claim.
Hourly rotations use simulated time; no real-hour wait occurs.

Final pins/logs are in ignored
`.codex-artifacts/intake-continuation/build-final-candidate-10/`.
Native originals and small derived receipts are in
`native-20160314-02/`: `mode-off-exact-equivalence-10-bound.json`,
`replay10-{pivot,candle}-paired-continuation-validation.json`,
`{pivot,candle}-native-broker-parity-10.json`,
`capture10-{pivot,candle}-bootstrap-witness.json`,
`{pivot,candle}-actual-adversarial-checks-10.json`,
`native-byte-cost-measurements-10.json` and
`native-independent-quiet-capture-10-bound.json`. The superseded initial derived
mode-off/quiet receipts retain their incorrect metadata for audit; only the
explicit bound replacements represent final10. Raw native rows/paths/accounts
remain private.

Earlier02/03 NULL encoding,04 lossy state/freshness classification,06 bounded
prefix reader and07/09 startup/lookahead failures remain immutable. Candidate05
failed the prelaunch FD safety review;06 repaired it. Candidate10 repairs TESTER
START timing while preserving every field and strategy operation. The source
rollback parent is c04b3d6a0859a2d38f303286fa0fed6e6a90fe54. The technical native
mechanism passes; human source verdict, exact consumer admission/reconciliation,
operational P01 and the atomic producer feature commit remain pending. No release,
live origin or full-history certification is implied.

### Historical Candidate 04 Evidence (Rejected)

The user selected Q02 A for the exact one-day tester lane below and performed
Q03 Navigator refresh. MetaEditor MCP build 6230 became callable. Historical candidate
04 compiles both optimized AVX2/FMA3 EAs with zero errors/warnings and freezes
53 matching MQL5 files; all 131 shared tests pass in 26.056 seconds. Native NULL
and fixed-decimal checkpoint defects are repaired. Candidate 02 and diagnostic
03 failure receipts remain immutable; original root EX5 files are unchanged.

Retained c04b3d6 baseline and final04 mode-off exports both strictly validate.
All ten/eleven files match under only explicit run-ID mapping. Continuation-off
and enabled native runs both match all 43 non-job report statistics and every
Results/Orders/Deals cell, with 137,217 generated ticks under native Model 4 and 13/35 broker trades.
Enabled cases each produce 25 sealed six-file segments. An independent structural
audit matches all 437/2,920 legacy fact rows and semantic terminal summaries;
only the individually named physical writer metric buffer_peak differs. File
byte chains and linked START/END state digests match. Actual typed state contains
55,858/9,490 rows, including native NULL and two EMPTY_VALUE bit patterns each.

| Observed one-day output | Pivot | Candle |
| --- | ---: | ---: |
| Total segment bytes | 6,371,190 | 7,059,997 |
| Input block bytes | 1,914,727 | 2,016,090 |
| Fact envelope bytes | 586,038 | 4,363,216 |
| START/END state bytes | 3,745,192 | 554,756 |
| Corresponding legacy archive bytes | 286,338 | 1,971,950 |
| Enabled case wall including owner/report work | 3.132 s | 2.923 s |

Fact payload hex is exactly twice its decoded body. These single-case timings are
mechanism observations, not an isolated overhead benchmark or a long-history
performance claim. Hourly rotations use simulated tester time; no real-hour wait,
demo collector or account activation occurred.

**Both strict continuation archives fail coverage acceptance.** Each records
1,756 quote-clock gaps over three seconds and 10,018 unavailable TIMER-only
observations; no unavailable TICK or TRADE observation occurs. TimeCurrent is
the last quote clock in OnTimer, and tester TimeTradeServer equals TimeCurrent
([native time documentation](https://www.mql5.com/en/docs/dateandtime/timecurrent),
[tester server-clock documentation](https://www.mql5.com/en/docs/dateandtime/timetradeserver)).
Neither timer totals nor weekly sessions certify active gaps or market closure.
No independent closure receipt is fabricated, and no witness/replay is admitted.
At this archived revision the origin-specific delivery proof was still under
review. D17 subsequently authorised the explicit TESTER policy above; candidate10
passes that scoped policy. The original04 failed verdict and artifacts remain unchanged.

Artifacts are retained under ignored
`.codex-artifacts/intake-continuation/build-final-candidate-04/` and
`native-20160314-02/`. Source/binary pins live in `source-binary-pins.json`;
`mode-off-exact-equivalence-04.json`, `capture-enabled-broker-parity-04.json`,
`native-structural-row-audit-04.json`, `native-unavailable-observations-04.json`
and both `capture04-*-continuation-validation.json` distinguish passing
independent checks from rejected continuity. At04, P01, native interruption/closure, bootstrap/replay, human acceptance and the
feature commit were open. Candidate10 now proves the scoped bootstrap/replay
mechanism above; native demo interruption/closure, human/consumer acceptance and
the atomic source commit remain outside this evidence. The family is nonoperational.

## Bounded Native Acceptance Recipe

Q02 A authorizes only this exact LOCAL_CUSTOM_TESTER lane. Its source binding is
the positively custom native symbol, retained authenticated local import/H1
provenance, bounded native day observations and actual tester warmup. It does not
claim external Exness/broker equivalence, complete physical-tick reexport or
unchanged full cache. No demo/REAL account orders, chart attachment, terminal
expert-setting changes, history imports/downloads or full-history jobs are included.

| Setting | Explicit candidate target |
| --- | --- |
| Engines | Both actual frozen final10 Pivot_Macro and Candle_Pattern_Discovery candidates; retained c04b3d6 baseline for broker comparison. |
| Symbol / chart / model | Existing `XAUUSD_Exness_2015`; M3; real ticks Model 4. |
| Interval | 2016-03-14 through 2016-03-15, one native tester calendar day. |
| Inputs | Broker_Session=1; Macro_Timeframe=16388 (H4); Micro_Timeframe=3 (M3); Lot_Type=1; Lot_Strategy_Size=0.001; Enable_Logs=false for both; Enable_File_Logs=false for Pivot only. Every engine-specific public input written explicitly. |
| Tester | USD deposit 10,000,000; leverage 500; no delay 0; optimization/forward/profit-in-pips all 0; nonvisual. |
| Capture | New source/session/physical IDs per reviewed lane; verified native history/feed receipt; derived code/config pins; 3600-second rotation. |
| Isolation | Existing native tester owner, one owned job at a time, fresh disposable INI/SET/report roots and already-frozen binary copies under ignored nonhidden logs. Original EX5 and operator exports remain pinned. |

Actual10 ordinary segment16 proves pending broker and virtual roles for both
engines under this exact day/settings. That proof does not generalise to an
arbitrary date or an empty-state run. Any longer interval remains outside the authorised Q02
lane until an exact new target is approved. Never invent pending objects or retrospective checkpoints.

Before launch, verify the native tester is idle under the actual current owner,
available disk >=10 GiB and memory >=1.5 GiB, exact existing tick/history receipt,
compiler/binary/settings pins and empty owned output IDs. Prepare INI/SET through
the discovered native owner only after lane approval. Capture journal offsets,
native reports and actual loaded manifests; configured intent is insufficient.
Use a 300-second overall wall deadline and native tester_wait timeouts <=45
seconds, with one launch per job. tester_wait accepts only run ID and timeout;
a wait timeout does not stop the job or establish a stall verdict. The same
native owner waits on the same job. The overall wall deadline uses tester_stop
only for that exact owned run ID. Wait expiry never launches a duplicate job.
No automated stall watchdog is certified by this recipe.

For each engine: compare retained baseline and candidate complete-run broker
facts with continuation disabled; run candidate continuation with unchanged
settings; strictly validate its continuation archive and compare whole typed
old facts/terminal effects; only after coverage admission audit an earlier
ordinary pending-state fence, generate a witness, replay the same anchor and
prove prefix equality, suppression and suffix closure. Compare every broker
order/deal/report cell under explicit physical ID mapping, not aggregate profit
alone. Record native wall time and input/state/fact/hex/total bytes; distinguish
unmeasured peak memory and isolated CPU overhead.

Copy only new owned output/witnesses for negative mutations. Prove changed
input/history/state/cursor rejection, missing final seal skip, partial writer
rejection, and independently evidenced closure versus unsupported active gap.
Offline negatives do not certify native crash or acquisition fault injection.
Actual LOCAL_CUSTOM_TESTER cold/paired capture is proved above. Native crash/feed
fault injection, LIVE_DEMO closure/capture, human tester/chart review and consumer
intake remain separate; demo collector activation stays outside this lane.

### Executed Final11 Date-Extension Lane

The reviewed recipe is saved in ignored
`.codex-artifacts/intake-continuation/history-anchor-split-11/native-extension-recipe.json`.
Q05 A authorised this exact two-day target and bounded current-history observations.
All eight planned final11 jobs completed and passed, four per engine. Their original
recipe is retained without retagging. No long live hour, full-history benchmark,
alternate date, history import or activation was included:

1. Base COLD, 2016-03-14 to 2016-03-15: strict whole legacy/broker comparison with
   retained c04/10; authenticate a new ordinary16 broker-and-virtual pending fence
   and a new11 ROTATED witness. Retain the paired whole TERMINAL branch.
2. Extended MODE_OFF, 2016-03-14 to 2016-03-16: new11 optimized/off reference and
   strict ten/eleven-file export with actual warmup/status checks.
3. Extended COLD over those same two days: authenticated current dated receipt
   with the original fixed anchor; prove the old prefix against the base witness.
4. Extended REPLAY over those same two days: replay the original anchor, compare
   every causal input/history/fact/birth and full START/END state through16, then
   emit the verified suffix. It includes the post16 first-day overlap and actual
   second-day callbacks, rather than filtering by date. Compare complete cold
   logical source with base prefix plus replay suffix, all late references and
   same-date MODE_OFF/COLD/REPLAY broker/report/order/deal cells.

Complete Pivot before starting Candle. Recheck current idle owner/capacity,
positive custom source, fresh source/binary/catalog/config/input fences and actual
bounded native source observations. Each job gets its own 300-second wall deadline,
one launch, same-owner waits <=45 seconds and exact-owned stop at deadline.
Generated ticks/segments for two days are measured from original native results,
not extrapolated from 137,217 one-day ticks. The recipe's replay witness digest is
a preparation placeholder, replaced only by the newly validated owner-issued
witness. A current receipt missing genuine source binding, failed warmup, incomplete
native job or changed old prefix fails the lane. The later scoped user delegation
permits technical acceptance choices; human-observed chart/tester verdict stays
unrecorded. Final12's latest-checkpoint proof and operational limits are above.
