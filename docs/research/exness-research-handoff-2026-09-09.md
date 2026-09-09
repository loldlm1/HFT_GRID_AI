# Exness Research - Current Thread Handoff

Current as of 2026-09-09. No implementation plan or sprint remains active.
Start new work from this record and [AGENTS.md](../../AGENTS.md); completed
plans and older task checkpoints are historical context.

## Completed Work

| Area | Accepted result | Evidence |
| --- | --- | --- |
| Persistent tick preparation | One reusable TSV per requested symbol; 1,018,476,599 ticks through September 7, 2026 | [Preparation](exness-single-file-preparation-2026-09-09.md) |
| Native custom symbols | Intended broker mappings, 24 exposed core properties, all 265,592 H1 rows and 12 sampled tick intervals checked | [Alignment](exness-custom-symbol-alignment-2026-09-09.md) |
| Historical XAUUSD run | Real-tick completion verified; original run retains its diagnosed censor-time defect | [Original verification](exness-xauusd-run-verification-2026-09-09.md) |
| Parent-close correction | EA close-clock handoff fixed; Python chronology/recovery added; focused Exness tester passes | [Acceptance](parent-close-chronology-acceptance-2026-09-09.md) |
| Historical recovery | Separate derivative corrects 1,109 censor timestamps and passes all 53 chronology checks | Same acceptance record |

The source files retain UTC with Shift=0. EURUSD uses the user-approved,
manifested representation-artifact policy, bounded by `1e-16`; every source tick
is retained. Other symbols keep strict source quotes. Broker feed equality and
full specification/P&L parity are not established by the import checks.

Use `EXNESS_SESSION` for the four custom symbols in this workflow, with
H1/M10/M3 unless a new task explicitly changes the configuration. It controls
export analysis-time normalization; it does not shift source ticks, broker
candles or execution clocks. The [original verification](exness-xauusd-run-verification-2026-09-09.md#session-setting-for-all-four-symbols)
records the implemented symbol/calendar mapping.

## Retained Files

Visible reusable imports:

```text
/home/admin/Documents/Exness_Tick_Data/XAUUSD_ticks.tsv
/home/admin/Documents/Exness_Tick_Data/EURUSD_ticks.tsv
/home/admin/Documents/Exness_Tick_Data/GBPJPY_ticks.tsv
/home/admin/Documents/Exness_Tick_Data/BTCUSD_ticks.tsv
```

Keep each adjacent `<SYMBOL>_manifest.json`, plus `README.md` and `SHA256SUMS`.
The four TSVs total 45,742,234,721 bytes. Task-owned archive/extraction payloads
were already removed after verification; unrelated retained archives remain.

The original run remains at:

```text
/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files/PivotFractalV13/runs/XAUUSD_Exness_Run_2015/
```

The recovered copy remains at:

```text
/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered/
```

Keep its adjacent `.corrections.jsonl`, `.provenance.json` and `.README.md`.
The derivative is not a new tester run. All 1,109 affected outcomes remain
`CENSORED_PARENT_EXIT`, excluded from binary statistics with null targets.
Byte verification proves that reversing only documented run-label/clock changes
reproduces every original TSV hash. No full tester rerun was needed for this
confirmed defect.

## Validation And Remaining Gates

- Exness service: 91 tests pass at closeout, including 17 preparation tests.
  The maintained Python/C++ preparation sources match all four final manifests.
- V13 correction: 45 contract tests pass; MetaEditor build 6184 reports zero
  errors/warnings. Reuse the unchanged binary/source evidence in the acceptance
  record instead of recompiling for a new thread.
- Focused Exness tester: strict V13 and 53 chronology checks pass. Export-on/off
  runs match all 43 report fields and 694 ordered broker messages at 50 ms
  execution delay. Exact tester IDs and settings are in the acceptance record.
- Full semantic validation of the large recovered dataset remains **NOT RUN**.
  The chronology audit does not certify all geometry, feature or money rules.
- Formal broker equivalence remains **INCONCLUSIVE**. Positive native broker
  trade tick/value, complete specification/session/P&L evidence, historical
  clock/feed mapping and registered round-trip/comparison gates remain open.
- Human chart-object/rendering verification remains outstanding before any
  deployment claim. No live rollout is authorized.

Use the [operator workflow](../workflows/exness-tick-history.md) for a newly
requested symbol/run or remaining acceptance work. Reuse existing captures and
reports while their inputs remain valid. Older preparation/diagnosis records
retain their original pending states; this record and the parent-close
acceptance supersede those workflow instructions without rewriting the evidence.

## Commits And Thread Cleanup

Parent-close sprints are `65090dc`, `10aa194` and `4185054`. Preparation service
and previously retained operational reports are saved in `33eb5a6`, whose
rollback parent is `4185054`. The documentation closeout is the commit containing
this handoff, with rollback parent `33eb5a6`.

Ignored `.codex-artifacts/thread-closeout-20260909/` contains byte-preserved
snapshots of the four completed task checkpoints and a cleanup receipt with
the final commit, source/data-preservation checks and removed cache inventory.
Original checkpoints and acceptance evidence remain at their existing paths;
their old session IDs and then-uncommitted status do not represent active work.
Generated Python bytecode and the empty pre-archive plan directory are removed.
The maintained `.venv`, native helper cache, datasets and compiled EA are retained.

There is no project-local `.codex/` hook override or active `.codex-hook-state/`
to reset. Installed plugin hooks and global Codex configuration/session history
are preserved. The next thread should use this handoff, not restore completed
plan state. Official [hook discovery](https://learn.chatgpt.com/docs/hooks#where-codex-looks-for-hooks)
defines the user, project and plugin configuration boundaries.
