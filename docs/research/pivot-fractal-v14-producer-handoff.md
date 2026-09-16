# Pivot Fractal V14 Producer Handoff

Frozen 2026-09-16 for offline research and the separately authorized Django
staging cutover. This is the producer contract and small-source receipt;
[the current index](../README.md) owns execution status and open gates.

## Contract And Ownership

- EA `1.40`, schema `14`, engine `PIVOT_FRACTAL_V2`, namespace
  `HFT_GRID_AI_PIVOT_FRACTAL_V14`; older positions are never adopted.
- Feature set `schema_v14_hft_deep_pivot_features`; explicit `.h1` and
  `.deep_parent` model sets contain 181 and 186 features respectively.
- Origins own `origin_macro_*` plus `origin_deep_*`. Events own `deep_deep_*`
  plus `deep_micro_*`. Each pair freezes at its own trigger against its own
  touched pivot. Shift-0 observations stay as observed; pivots use shift 1.
- Each block has a completeness flag; the snapshot flag is their conjunction.
  Missing features preserve raw rows and exclude the corresponding model cohort.
  Later Deep observations cannot fill an earlier Macro snapshot.
- Deep collection requires eligible entered Macro virtual or confirmed broker
  parents. Both Deep directions are captured; parent links carry
  `parent_direction`, `deep_direction` and `direction_relationship`
  (`ALIGNED`/`OPPOSED`). Deep outcome `direction` owns execution geometry;
  `parent_direction` resolves the origin. No standalone or retroactive links.
- One direction-independent consumed Deep identity owns three shared 1R/2R/3R
  trials and three outcomes per frozen link. Parent exit censors only that link;
  another active parent can continue. No Deep order or 5R trial exists.
- Eight Macro lanes remain STRUCTURAL/MIDPOINT_50 times 1R/2R/3R/5R. Only the
  structural Macro 1R lane may send; accepted requests own exact parity shadows.
- Broker time owns causality. Parent terminal transitions precede Deep discovery;
  actual broker close clocks cap existing links. Censors, invalid money/geometry,
  no-touch and atomic capacity rejection remain explicit without binary losses.
- Completed `h1_structural_lifecycle_seconds` is retrospective and excluded from
  causal features. `m10_parent_age_seconds` is exact trigger-time age. Inclusive
  minute selectors use `<= minutes * 60`, independently and together with AND.
- Defaults remain H1/M10/M3 with strict `Micro < Deep < Macro`. H1/M10 field names
  denote roles; the manifest owns actual periods. QA uses H2/M15/M3 as well.

Six cached handles preserve Bands 21/0/2, SMA, PRICE_WEIGHTED and Stochastic
5/3/3, SMA, STO_CLOSECLOSE. Export-off allocates no research indicators/state.
Finite numeric values retain 17-significant-digit serialization. The validator
accepts only V14; V13 and earlier are neither converted nor dual-loaded.
The [runtime guide](../architecture/market-data-broker-executor.md) and
[research guide](../../tools/deterministic_signal_ml/README.md) own procedures.

## Reproducible Pins

Producer commit: `d60bc2c0f030301d4962a38b9f218cf1e0b556aa`.
QA/Git reconstruction anchor: `879b39c41d54b4d1b8a8b1b0948e743a2a355497`.
M4 changes provenance tooling and documentation only; producer, validator,
builder and fixture bytes remain unchanged. Its commit/rollback receipt lives
in `.codex-artifacts/pivot-fractal-v14/m4/commit.json` after the commit gate.

| Resource | SHA-256 |
| --- | --- |
| `schema_contract.py` | `7157f520318218ac62fb5aa69bcd88d57c8f3d80db2f9016cf5e0a34963936fd` |
| `build_dataset.py` | `4fa1d8e5a628a26488dc3f3cfdff301d7af7215304396f082e714dc6c3ba9f8b` |
| Canonical 656-column type registry | `dedc9d4ebcf461fe68c63558db825011ac3734121f9f89437cf10e8bdb1550af` |
| Feature-set registry | `ee51077168dd6ef76ec082fa4e9bbab602d8d5f4de91c1a6f32d2adbf6f5c4d6` |
| Ordered canonical header bundle | `64f35a1f562d2e665507e8ff386c80a4b1331a383eb55933937bad767c7e69bf` |
| Fixture generator | `b3bcaf3d03dbfd908f77e1a3778684099cb3050a0360329f1079b9aa93ebe69d` |
| Fixture provenance | `67f2fad8f621ca06471467aab98c945d89c2d6647e021b44ccfb8d483ef51290` |
| Sorted twelve-TSV fixture bundle | `b0cdd5ea5af59ff7d2b1bb748412385faaf49567ba69101c3cd0f682762b6619` |
| Complete fixture file/hash mapping | `85ab125042ac0bc70f6fb116835a0c4a4a886d4d14449db926b5380e492e8b9d` |
| 38-source MQL5 file/hash mapping | `e2cec13d3a6ebd1c468bdc78faf08886ee5d45488adfd001a40db473fb113afd` |
| Accepted EX5 | `423433befab4ecfb97a9685bfefda479d0a5acfe7d5d08ffaf0b03399b92be1b` |

Registry/mapping hashes use ASCII compact sorted JSON (`sort_keys=True`,
`separators=(",", ":")`). Header hashes use tab-joined column names plus LF;
the bundle concatenates `filename + NUL + canonical header` in the table order
below. The fixture bundle uses `filename + NUL + file bytes` in lexicographic
filename order. Exact native headers, including their line endings, have
separate hashes in the source receipt; no input bytes are normalized in place.

| TSV (contract order) | Columns | Canonical header SHA-256 |
| --- | ---: | --- |
| `run_manifest.tsv` | 3 | `287cd6df5a48e8a373de6b9777f8e85aaf1a772051ce9344f5af8ab0d808f501` |
| `pivot_windows.tsv` | 51 | `000a0813806fdc60408874d1e98b17a63e9bf4041efa278616ddda78c66870f7` |
| `signal_origins.tsv` | 222 | `f13d02d467571179c4d84f3e87af337838b52aa580a46f76123243243f6c12ff` |
| `virtual_trials.tsv` | 55 | `205606c5eaae1516298f031fd7ebd08847ba348f0f10e26ec42343d1aafd2d12` |
| `virtual_outcomes.tsv` | 31 | `944ca5c52254854e1310169736051373d103e535bfbfb7e97014c6bc0e17b26a` |
| `deep_pivot_events.tsv` | 208 | `d5f0f3937a06a5b77d123f68d108ae7c6bbd10bc2f10e8c4565443b5703c8818` |
| `deep_pivot_parent_links.tsv` | 18 | `4fe82759e653489d308fb12d5b91bbc71bee63fbd9eaab1598cb5bc0cb75476c` |
| `deep_virtual_trials.tsv` | 33 | `4df88ba5d24f22b237bcfe16db941671d3abb2fe095f7a7cede0ea1707caf70f` |
| `deep_virtual_outcomes.tsv` | 30 | `bc73cb1e0115c6d1711fd93673824b33cb6ecf942f3998bda6e46526d33565dd` |
| `execution_checks.tsv` | 82 | `5bf2df73100249356302df7b3fb85f5a9d3b9d0859c91dc3a9d61d9c4bd673c9` |
| `broker_outcomes.tsv` | 61 | `3a196c628ef3bee7fa73a1979eb6b13c1cc41ea6765acfd0213f48742cd9977c` |
| `run_summary.tsv` | 52 | `4b8685319d8af6e055d2d9f540c7d26071ef896a1a4525a918c16928f1b8e9ec` |

The full pin file includes individual fixture files and Python/MQL5 source
hashes. Independent retained files live under
`/home/admin/Documents/Exness_Research_Runs/V14_MT5_Handoff_20260916/`:

- `contract-pins.json`: SHA-256
  `01fed99ba7dbfbdc3ee25b5261b6c023959dfc3cad8bba27fc14e35c7b7e41f9`.
- `source-receipt.json`: SHA-256
  `bfcddc769d106462140994d17d300c986a9a6ef6360e49c63e8212480169ee46`.
- `column-type-registry.json`, `feature-registry.json`, and `runs/<run_id>/`.
  Sidecars are outside the twelve-file folder. The run is a byte-preserving
  independent copy, not a symlink to shared terminal data.

## Selected Initial-2015 Source

Run `V14_XAUUSD_20150817_H2M15M3_M3_20260916`, native job
`7686113583110594438`, config `cfg_7723362761121334487`.
Symbol `XAUUSD_Exness_2015`; requested August 17, 2015 00:00 through August 22
00:00 end exclusive; observed broker interval August 17 00:00 through August 21
19:05:21. Settings: H2/M15/M3, EXNESS_SESSION, real ticks, 50 ms delay,
simulated USD 1,000,000, 1:10000, fixed-reference 0.01 percent, source Shift=0,
`profit_in_pips=false`, optimization/visualization off. The run seals
`OK/NATURAL`; all 129 origin and 908 event feature pairs are complete.

The retained run is at `runs/V14_XAUUSD_20150817_H2M15M3_M3_20260916/`
under the independent root above; total twelve-file size is 30,841,071 bytes.

| File | Data rows | Exact native file SHA-256 |
| --- | ---: | --- |
| `run_manifest.tsv` | 64 | `51694727bc25876842c226206146e63fd323f929ed2f3762186f2220a2820ce8` |
| `pivot_windows.tsv` | 478 | `0dc0c58883725484ef2c7d7f7945ef2f957787641134b8ec1228e95281612e7e` |
| `signal_origins.tsv` | 129 | `dbd3321e68ef63ee17b9e56313e40a2c10a29d77dbf4c388db3a358d90b9f43c` |
| `virtual_trials.tsv` | 1,151 | `15bcc5fa3bc3c9becbd0caf125ab036c50113f3bcd3dd2052341fd475df7925b` |
| `virtual_outcomes.tsv` | 1,151 | `76b4158ecd6a2858556b03b41f332253c0c71934ddcaa33fa684d066949bcfb2` |
| `deep_pivot_events.tsv` | 908 | `fd6529bdf2da15c77b026196dd07a4f55fe630228a1cfe5fba369f0c18d452aa` |
| `deep_pivot_parent_links.tsv` | 15,732 | `2b5a69afa1d16acd253a57a5414fb92e3ca9b05d9999c6d5db7d070ca58c330b` |
| `deep_virtual_trials.tsv` | 2,724 | `f240c2256e0d4d487d51b8ed7daf26744c5231d24df51e99587e89e6f6936a54` |
| `deep_virtual_outcomes.tsv` | 47,196 | `70aada73a817d8797e2ee164ed49c86bb43e015a2bbc327023b79f6e7b25b213` |
| `execution_checks.tsv` | 499 | `f7fc01642e392a82e3247159bb73e64b8ee986622a08f229cf943be238fde46d` |
| `broker_outcomes.tsv` | 119 | `6fbc4c7c32c84edb057696d205a9864e6fb1be8632fe203f20e125030841ade4` |
| `run_summary.tsv` | 1 | `56a6b8cbdd1f7b75a5a7fc7665a7a603a50ef55e476be8292973d359a84e2bb5` |

Source binding is the retained `XAUUSD_ticks.tsv` preparation
`full-utc-20260908-v1`, inventory `inv-489d6d719c5119422305f285`, 333,083,223
ticks / 15,247,608,724 bytes, SHA-256
`bd443ff944f345a236932f5d68c2bd9c61cdfd47131b2740aa1e4e0bd5f7f8f4`.
The hash comes from retained preparation evidence; M4 rechecks its size and
manifest binding without rereading the entire archive. Its first tick is August
10, 2015. This source preparation does not certify formal Exness broker equality.

## Bounded Acceptance Evidence

MetaEditor 6184 optimized AVX2 compiles with 0 errors and 0 warnings; EX5 size
308,334 bytes. M3/M4 retain the exact M2 binary and all 38 source hashes.
The 51 focused V14 tests pass, including shared-event purging across validation
and holdout folds. The fixture regenerates byte-for-byte. M4's renamed Exness
provenance API passes the existing 91-test suite. No new MQL5 harness exists.

| Window, end exclusive | Periods | Origins / events | Aligned / opposed links | Matched broker evidence |
| --- | --- | ---: | ---: | --- |
| August 10-15, 2015 | H2/M15/M3 | 104 / 709 | 6,653 / 6,397 | On/off/V13: 768 messages, 43 report fields |
| August 10-15, 2015 | H1/M10/M3 | 196 / 1,049 | 9,971 / 9,431 | On/off/V13: 1,393 messages, 43 fields |
| August 17-22, 2015 | H2/M15/M3 | 129 / 908 | 7,248 / 8,484 | On/off: 955 messages, 43 fields |

Broker comparisons preserve ordered requests, fills, closes and failed requests;
only namespace/run-ID remapping is permitted. Baseline alternate filenames did
not launch, so the retained binary temporarily occupied the actual EA filename
with no chart instance attached; the exact V14 EX5 was restored and verified.
No V13 positions were adopted. This is bounded behavioral parity, not formal
broker-feed equivalence.

All three native exports pass full strict validation and separate chronology.
The independent selected copy also passes strict validation. Its audit is
`AUDIT_COMPLETE` at floor 30: 803 eligible H1 rows, 27,380 eligible Deep outcomes,
119 broker/calibration rows and 2,339 parent-exit censors. Narrow Django filters
may still lack support; keep their floors unchanged and test workflow boundaries
with the focused fixture. No expensive model search was run.

First-window execution begins August 11 after August 10 history initialization;
44 H2 and 15 default Macro snapshots remain explicitly incomplete. All Deep
pairs are complete. There are 9,492 independent raw/SMA arithmetic checks on the
main H2 run and 625 events with both link relationships. Every pivot level and PP
return is observed. Native/fixture evidence covers all lane ratios, no-touch,
invalid money, parent/run censors, shared outcomes and direction-independent
first consumption. The fixture checks atomic capacity rejection; native caps
are unsaturated. Same-second chronology tests plus source order establish causal
guards, while second-resolution data cannot prove subsecond sequencing.

Header/missing-file faults use jobs `7686114978818728391` and
`7686115247455143138`. Each preserves original bytes, latches one first error,
releases research once while retaining two open broker states, requests one
tester-only stop, scores zero and seals `FAILED/CENSORED`. Strict intake rejects
both. Logs are off; first-error diagnostics remain unconditional.

| Single-pass resource evidence | H2 V14 / V13 | Default V14 / V13 | Adjacent V14 |
| --- | ---: | ---: | ---: |
| Export-on seconds | 10.774 / 9.735 | 10.330 / 9.129 | 13.980 |
| Twelve-file bytes | 25,651,343 / 13,862,585 | 37,443,852 / 21,674,426 | 30,841,071 |
| V14 peak events / links / outcomes | 13 / 339 / 1,017 | 15 / 445 / 1,335 | 16 / 426 / 1,278 |

Links roughly double with both directions; observed elapsed increases are 10.7%
and 13.2%, with main/default tester memory 88-97 MB. These are single passes,
not repeated benchmarks or full-history estimates. Peak links/outcomes remain
below caps 4,096/18,432; no native capacity or integrity error occurs. Raw
reports, streams, counts, settings, faults and audits are retained under
`.codex-artifacts/pivot-fractal-v14/` and bound by the M4 receipts.

## Django Boundary And Recovery

Django may vendor `tools/deterministic_signal_ml/schema_contract.py` exactly,
the native-grain builder/type contract, and
`tools/deterministic_signal_ml/tests/fixtures/schema_v14_hft_deep_pivot_features/`.
Use the pinned feature owners and parent/outcome directions without translating
them back to V13. Keep terminal data, binaries, logs, generated models/Parquet,
credentials and source archives out of either Git checkout.

Upload only the twelve pinned TSVs after Django's V14 intake is implemented;
use a fresh source binding/intake ID and require its atomic READY transition.
Staging V13 purge/rebuild belongs to the separate Django plan. This MT5 execution
does not perform that purge, application changes or deployment. Production stays
outside scope. The native run is small workflow evidence, not training readiness.

Human chart acceptance, full-history replay, GBPJPY historical currency conversion,
formal Exness equivalence and full recovered-run semantic acceptance remain open.
GBPJPY custom prices are usable, but initial-2015 account-currency calculations
need correctly mapped conversion history; recent GBPJPY data is not a substitute.
XAUUSD is the accepted bounded fallback. No live rollout is authorized.

Rollback uses reviewed sprint reverts in reverse order and matching retained EX5
bytes or recompilation. Original/recovered MT5 data and this independent copy
remain intact; consumers cannot relabel V14 as an older schema. Retired V13
handoff and completed reliability-plan paths are recoverable from Git anchor
`879b39c` using the commands in the current index.
