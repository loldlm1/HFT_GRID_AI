# Parent-Close Chronology Acceptance

All three authorized sprints are complete. The original sprint ledger is
recoverable at Git location
`bb97e9e29ad4cc61a07b7e4b9f4b92c56c64de93:docs/plans/archive/parent-close-chronology-2026-09-09/README.md`
through [history recovery](../README.md#guides-and-history-recovery).
The EA close-clock handoff, Python chronology checks, focused
Exness tester acceptance and separate historical recovery pass. Full semantic
validation of the large recovered run remains unrun.

## Defect And Correction

The original run contains 1,109 broker-parent child outcomes censored 1-3 seconds
after the parent's confirmed close. For the M10 event at `2015.08.13 05:40:58`,
the broker parent closed at `05:55:04`, but three child rows used the later
observation time `05:55:06`. All affected rows were already excluded from binary
statistics; no late completed child outcomes or late admissions were found.

The EA now retains confirmed close time on existing bounded deep links before
broker signal cleanup. Parent-exit censoring uses that time, including during
run termination. The broker close and later reconciliation remain separate
facts in broker outcomes and terminal execution checks. Censor quotes remain
observations, with no completed duration, return or binary target assigned.
Missing or inconsistent closure evidence fails research integrity without
changing the broker execution path.

Python strict validation indexes parent outcomes/fill evidence and rejects
children completed after parent closure or run-end censors on completed parents.
The separate DuckDB audit bounds working memory and scans the relevant columns
from eight tables, checking all twelve headers and the producer seal. Recovery
permits only late broker-parent censor clocks in a naturally completed run;
ambiguous identities, missing evidence and other audit failures refuse recovery.

Operational auditing also found 506 confirmed broker trades whose entry and
close serialize to the same second with duration zero. The producer and frozen
manifest permit nonnegative duration. Both Python checks now accept this valid
case, while strict validation rejects reversed clocks and inconsistent duration.
Equal serialized timestamps do not establish zero actual broker latency.

## Compile And Source Gates

- PASS: 45 Python contract tests, including delay, parent completion, run-end,
  recovery rejection/provenance and zero-second broker duration cases.
- PASS: MetaEditor build 6184, `0 errors, 0 warnings`. Runtime MCP discovery and
  `get_workspace_info` preceded `compile_file`. Compiler tools were absent from
  the CLI catalog; the local HTTP MCP succeeded after the documented Wine
  fallback produced no compile log.
- PASS: regenerated `HFT_Grid_AI.ex5`, 295,370 bytes, modified
  `2026-09-09T13:12:01.443617+00:00`, SHA-256
  `ac5ae06f4d7a2c788d4470e2b849a9bb76cd6b97d1d0c646c2e9ffd719b79237`.
- PASS: all 39 project source/include files match compiled-source hashes;
  include tracing reports zero cycles or missing files. Public inputs and the
  sole `OrderSend` owner are unchanged. No history scan, broker control, indicator
  handle, per-close allocation or additional export column was introduced.
- PASS: identifier/reference, broker/research boundary, documentation-link and
  whitespace reviews. Raw logs, data and compiled binaries remain local.

Python environment: project `.venv`, Python 3.12.14, DuckDB 1.5.4. Validation:

```bash
rtk test .venv/bin/python -m unittest discover \
  -s tools/deterministic_signal_ml/tests -p 'test_*.py'
.venv/bin/python -m compileall -q tools/deterministic_signal_ml
git diff --check
```

## Focused Exness Tester Acceptance

Both completed tests use `XAUUSD_Exness_2015`, verified `EXNESS_SESSION`,
H1/M10/M3 with chart M3, reference-balance lot mode, lot size `0.001`, real ticks
and 50 ms execution delay. The simulated account uses USD 1,000,000 and leverage
1:10000. Requested dates are August 11 through August 15, 2015, with the end
exclusive; the final exported tick is `2015.08.14 17:05:38`.

| Evidence | Result |
| --- | --- |
| Export-on tester ID | `7683526400313714503` |
| Export-off tester ID | `7683526814229975635` |
| Export-on run ID | `XAUUSD_ParentClock_Fix_Exness_20150811_14` |
| Producer completion | `NATURAL`, export `OK`, zero integrity errors |
| Strict `build_dataset.py --validate-only` | PASS on the export-on run |
| Focused chronology audit | PASS, all 53 checks |
| On/off broker parity | All 43 report fields and 694 ordered broker messages match |
| Ticks / bars / trades / deals | 328,861 / 1,685 / 174 / 348 |
| Export inventory | 196 origins, 1,742 H1/parity trials, 1,000 deep events, 30,162 deep outcomes |
| Deep censor counts | 2,243 parent-exit and 80 run-end |

The export-off run creates no directory for its configured ID,
`XAUUSD_ParentClock_Exness_Off_20150811_14`. The broker-message stream SHA-256 is
`d0b0363b245e8b337c6a5df279db7678ba2b6cf2f0129971e33c3c4356fac6ff`.
All three broker children matching the original example now censor exactly at
`2015.08.13 05:55:04`.

Parity compares export enabled/disabled using the corrected binary. A separate
historical-binary tester run was not executed. This bounded acceptance does not
establish custom-symbol broker equivalence or subsecond execution accuracy.

## Retained Historical Recovery

The original twelve files remain unchanged at:

```text
/home/admin/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files/PivotFractalV13/runs/XAUUSD_Exness_Run_2015
```

The visible derivative and required adjacent sidecars are:

```text
/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered/
/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered.corrections.jsonl
/home/admin/Documents/Exness_Research_Runs/XAUUSD_Exness_Run_2015_ParentClock_Recovered.provenance.json
```

Exactly 1,109 rows receive the linked broker close's terminal broker/analysis/
offset triplet. Their statuses remain `CENSORED_PARENT_EXIT`, binary eligibility
remains `0`, and targets remain null. Quotes, features, prices, durations, row
identities and counts are preserved. The other change is the derivative run ID
throughout the twelve files. Their total size is 15,516,573,445 bytes; the longer
run ID accounts for the increase from the original export.

The final chronology audit passes all 53 checks across 21,025,887 deep outcomes
and their parent evidence, with zero late admissions, completed children after
parent close or inappropriate run-end censors. Independent byte verification
checks both hash sets; reversing only documented run-label/clock changes
reproduces the original SHA-256 for every one of the twelve files. The formerly
failing event also passes strict `_validate_deep` with its complete 19 links,
three trials and 57 outcomes.

Recovery is a deterministic derivative of the historical export. It is not a
new tester run or an export of the corrected binary. The sidecars preserve each
original clock/observed quote, the authoritative replacement clock, both file
hash sets and the transformation. The exact executed recovery source is retained
as `recovery-tool-executed.py`, matching provenance SHA-256
`3eaa11d888b29146e4eea3287be0c6373a268310632edf74484c840e4d95e507`.
Recovery preceded the final identity guards; the final auditor independently
passes the resulting unchanged artifact.

No full historical Strategy Tester rerun was needed for this confirmed defect.
Full semantic validation of the large derivative is **NOT RUN**: chronology,
byte preservation and one strict event sample do not certify every geometry,
feature or money rule. Full statistical acceptance and broker equivalence are
separate gates. Human chart/rendering acceptance remains outstanding before
any deployment claim; this work does not authorize live rollout.

## Evidence And Rollback

Retained raw evidence is under ignored
`.codex-artifacts/parent-close-chronology-20260909/`:

- `metaeditor-preflight.json`, `metaeditor-compile.json`, `compiled-binary.json`
  and `sprint1-source-review.json`/`sprint3-source-review.json`: compiler and
  source provenance.
- `tester-exness-on-report.json`, `tester-exness-off-report.json`, their
  corresponding journals, `tester-exness-parity.json`,
  `tester-exness-on-validation.log`, `tester-exness-on-audit.json` and
  `tester-original-case.json`: accepted Exness tester evidence.
- `original-parent-audit.json`, `original-additional-chronology.json` and
  `same-second-broker-lifecycles.json`: original chronology diagnosis.
- `recovery-report.json`, `recovered-accepted-audit.json`,
  `recovery-byte-verification.json` and `recovered-strict-sample.json`:
  accepted recovery evidence.

Earlier `tester-on-*`/`tester-off-*` diagnostic runs used FIXED sessions and are
superseded by the verified `tester-exness-*` results. Intermediate
`recovered-final-audit.json`/`original-final-audit.json` failures used the obsolete
positive-duration check; `recovered-accepted-audit.json` is the final gate.

| Sprint | Commit | Rollback parent |
| --- | --- | --- |
| Producer handoff / strict chronology | `65090dc` | `3478c97` |
| Bounded audit / recovery | `10aa194` | `65090dc` |
| Operational acceptance / duration boundary | Commit containing this record | `10aa194` |

The ignored `checkpoint.json` records the final acceptance commit SHA. Rollback
references identify source boundaries; retained original/recovered data and
sidecars are preserved independently of source rollback.
