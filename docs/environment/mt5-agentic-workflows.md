# MT5 Environment And Validation

Use this runbook for environment setup, compiler operations and verification.
The [current index](../README.md) selects source/compile evidence and outstanding
gates. Runtime semantics belong to the [architecture](../architecture/market-data-broker-executor.md);
research and source procedures belong to the [V14](../../tools/deterministic_signal_ml/README.md)
and [Exness](../../tools/exness_tick_history/README.md) tool guides.

## Codex And Artifact Ownership

[AGENTS.md](../../AGENTS.md) routes tasks to installed skills. Standalone Planner
owns proposals/saved/phased/sprint plans, including direct requests; short chat
plans use native behavior. `codex-agentic-stack` supplies Token Saver, Web QA,
`on-demand-skills`, `understand-anything`, shared MCP routes and lifecycle hooks.
Web QA applies only to a task involving browser behavior; it cannot establish MT5
chart acceptance. Resolve helpers from installed discovery, without copying
skills/hooks or pinning cache versions.

Read the relevant source, tool guide and existing tests first. For a concrete
MQL5/MT5 or offline Python guidance gap, search bounded metadata with
`$codex-agentic-stack:on-demand-skills` and inspect one fitting pinned Agentic
Awesome Skills bundle plus needed support files. Reuse the selection; if coverage
is missing, use project contracts, official APIs and native tools. This repository
has no Django app. Retrieved guidance cannot override broker/research boundaries,
Planner, MCP policies or authorized scope, and reading it does not authorize setup
scripts, model calls, delegation or a full-catalog installation.

For substantial unfamiliar cross-module work, use
`$codex-agentic-stack:understand-anything` to build/refresh a scoped external graph
of the implicated services or Python tool. Reuse fresh results, bound queries and
confirm conclusions in source. Check language coverage: file-only/unsupported MQL5
results do not prove include reachability, callbacks or broker behavior. Use manual
include tracing and existing source/compile gates for those gaps. Exclude terminal
data, export runs, credentials, logs, binaries and runtime artifacts from the scope.
Small familiar/documentation edits can skip graphs and retrieval with a reason.

Planner proposals/plans or existing task evidence record skill ID/pinned revision/
reason/prerequisites, graph scope/freshness/coverage/artifact or skip reason,
affected files, MCP routes/fallbacks and validation. Keep graph/library caches
external; do not write tracked graphs or another planning/continuation system.
Planning can prepare derived context without editing source or initializing active
execution state. No LLM trials, embeddings or upstream multi-agent pipeline.

The official [instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
and [skills/plugins](https://learn.chatgpt.com/docs/skills-and-plugins) pages were
searched and fetched on 2026-09-10; the observed CLI was `0.153.4`. Project AGENTS
owns product-specific rules. User/global configuration and installed plugins own
provider/authentication settings and shared lifecycle hooks. Restart a session to
load revised instructions; do not reinstall unchanged plugins or duplicate their
Stop/PreCompact/PostCompact/SessionStart hooks. No project config override is needed.

Use one writer per worktree. Planner execution state belongs in ignored
`.codex-hook-state/`; detailed receipts belong in ignored `.codex-artifacts/`.
Retain accepted operator handoffs and original/derived evidence. Do not clean
shared terminal folders, global session/authentication state or plugin caches.

Use the retained plugin's `references/project-mcp-routing.md` for shared routes.
Preserve server IDs `metaeditor` and `metatrader5`, endpoints, credential references,
approval policy and project overrides; optional missing tools need no new global
defaults. Context7 supplies package/API guidance, OpenAI Docs handles Codex/OpenAI,
and GitHub MCP is for authorized remote state; local Git owns checkout/history.
MetaEditor and terminal MCP capabilities are discovered at runtime. MetaEditor
must run for compiler tools; MT5 must run for terminal/tester tools. Call the
respective `get_workspace_info` before that server's operations. Missing tools
leave dependent gates unrun, while source inspection can continue. Tool approval
never authorizes account changes or live orders. Keep
`METATRADER_METAEDITOR_MCP_API_KEY` and `METATRADER_TERMINAL_MCP_API_KEY` values,
account/community identifiers and private terminal data out of logs and commits.

## Path Contract

### Windows

```powershell
$MT5_ROOT = "C:\MetaTrader 5-1"
$METAEDITOR = Join-Path $MT5_ROOT "MetaEditor64.exe"
$EA_ENTRYPOINT = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\HFT_Grid_AI.mq5"
$COMPILE_LOG = Join-Path $MT5_ROOT "MQL5\Experts\HFT_Grid_AI\logs\compile\agentic-build.log"
$MT5_COMMON_FILES = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$PIVOT_RUNS_ROOT = Join-Path $MT5_COMMON_FILES "PivotFractalV14\runs"
```

### Ubuntu/Wine

```bash
export MT5_ROOT="/home/admin/.wine/drive_c/MetaTrader 5-1"
export METAEDITOR="$MT5_ROOT/MetaEditor64.exe"
export EA_ENTRYPOINT="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/HFT_Grid_AI.mq5"
export COMPILE_LOG="$MT5_ROOT/MQL5/Experts/HFT_Grid_AI/logs/compile/agentic-build.log"
export MT5_COMMON_FILES="$HOME/.wine/drive_c/users/admin/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
export PIVOT_RUNS_ROOT="$MT5_COMMON_FILES/PivotFractalV14/runs"
```

If the Wine prefix changes, locate only the Common Files directory:

```bash
find "$HOME/.wine" "$HOME/.mt5" "$HOME/.config" -maxdepth 8 \
  -type d -path '*/MetaQuotes/Terminal/Common/Files' 2>/dev/null
```

## Compile Policy

Recompile after MQL5 source/include or toolchain changes, or an explicit gate.
Reuse an unchanged compile pin selected by the current index. Before source edits,
retain the matching ignored binary and source hashes when available for rollback.

1. Discover the current MetaEditor schema and call `get_workspace_info` first.
   Verify allowed roots and `can_compile_file` before compiler/file operations.
2. Call `compile_file` with the actual absolute EA path and supported target.
3. Require `0 errors, 0 warnings`; verify a regenerated `HFT_Grid_AI.ex5` using
   timestamp, size and SHA-256, and retain matching source/include hashes.
4. If MCP cannot execute, record the precise reason and use the fallback below.
   A syntax-only `/s` check or stale binary is not acceptance. If no runner works,
   the compile gate remains unrun and source sprint completion is blocked.

Keep optimization and instruction target explicit: use `no_optimization=false`
and `target="AVX2"` for the selected local build. The current index records the
same-source Regular/AVX2/AVX512 comparison and exact tested binary. Linux CPU
flags alone do not establish tester support or speed. Test loading and compare
exact native facts before measuring another target; use warm-ups, alternating
repetitions and observed variability. Retain AVX2 when a target's gain is within
noise or below the recorded promotion threshold. Per-build target experiments
must not change the global compiler preference. Binary pins are local-host
acceptance, not portability or deployment certification.

### Project-Native Fallback

Ubuntu/Wine:

```bash
python3 tools/mt5/compile_mt5.py \
  --wine \
  --mt5-root "$MT5_ROOT" \
  --entrypoint "$EA_ENTRYPOINT" \
  --log "$COMPILE_LOG" \
  --mode compile
```

Windows PowerShell:

```powershell
py -3.12 tools\mt5\compile_mt5.py `
  --mt5-root $MT5_ROOT `
  --entrypoint $EA_ENTRYPOINT `
  --log $COMPILE_LOG `
  --mode compile
```

Record parsed compiler status and `.ex5` metadata, not the full log.

## Python Environment And Checks

### Independent Candle Acceptance

Compile `Candle_Pattern_Discovery.mq5` through the same MetaEditor preflight and
AVX2 gate, preserving the Pivot binary. Candle defaults are H1/M3 and export off;
use a fresh `Signal_Feature_Run_Id` for every export run under
`Common\Files\CandlePatternV1\runs\`. Write tester `.set` files without a UTF-8
BOM, with a comment first and native `value||start||step||stop||N` values.
Validate the actual manifest periods after execution; settings-file intent alone
does not establish which inputs MT5 loaded.

Use the [Candle reader and selection commands](../../tools/candle_pattern_ml/README.md)
for its exact eight-file contract. Preserve separate run IDs, ratio grains and
family/direction categories. Native tester reports requested as XML may be XLSX
ZIP containers: detect the signature and compare actual order/deal worksheet
cells, not only aggregate profit. Fault injection targets only a new owned run;
retain any moved source file outside its strict directory and verify failed seal
and reader refusal. Existing operator runs are never fault fixtures.

The [current index](../README.md) records acceptance and limits. Consumer checks
use its disposable PostgreSQL/Redis and native Chromium runners; no production
or staging intake/deployment is implied. Human MT5 visual work remains deferred.

### Existing Python Environment

The Exness tool requires Python 3.11+ (`tomllib`). The accepted local environment
uses Python 3.12 and the pinned dependencies in each requirements file. Reuse the
maintained `.venv`; setup commands are for an absent environment, not routine upgrades:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/deterministic_signal_ml/requirements.txt
.venv/bin/python -m pip install -r tools/exness_tick_history/requirements.txt
```

Run affected existing contracts and syntax checks after Python/fixture changes:

```bash
rtk test .venv/bin/python -m unittest discover -s tools/deterministic_signal_ml/tests -p 'test_*.py'
rtk test .venv/bin/python -m unittest discover -s tools/exness_tick_history/tests -p 'test_*.py'
.venv/bin/python -m compileall -q tools/deterministic_signal_ml tools/exness_tick_history
```

If RTK is unavailable, run the underlying command and keep bounded output.
The Exness preparation tests exercise its maintained C++17 helper; `g++`/`c++`
with 128-bit integers is required for that path. Do not add MQL5 test infrastructure.
Use the V14 tool guide for validate/build/audit/train commands; keep generated
artifacts under the existing ignored dataset/audit/model paths. Never place
provenance sidecars inside a strict twelve-file source run.

### Selected Staging Source

The current index identifies the user-selected MT5 source folder; the frozen M4
handoff continues to own schema/fixture pins and historical acceptance. A selected
operator folder is not import-ready while its TSVs are still growing. Do not stop
the operator run, replace its binary, truncate tables or synthesize a successful
summary to prepare a handoff.

Before Django's staging purge/intake, require `OK/NATURAL`, exactly twelve regular
files, stable sizes/mtimes, and strict validation plus the separate parent chronology
check. Record all twelve SHA-256 hashes and native-grain counts in a new source
receipt outside the run directory. Independently copy the sealed source into the
consumer's owned staging inbox during its authorized execution and verify the copy
against that receipt. Preserve the original terminal files and old receipts.

Measure the selected folder's actual byte/row counts before intake; a short list
of TSV names does not establish a tiny workload. Keep synthetic tests tiny and
staging workflows bounded to the selected cases. Source validation/intake does not
authorize broad suites, historical model searches or production deployment.

## Documentation And Static Gate

```bash
git diff --check
git diff --name-only
git diff --cached --check
git diff --cached --name-status
git check-ignore .codex-hook-state/probe.json .codex-artifacts/probe.txt HFT_Grid_AI.ex5 .venv/probe logs/probe.log artifacts/exness_tick_history/probe.json
```

Review exact identifiers, all relative links/anchors, current version/status
claims and each contract's document owner. Keep AGENTS at most 160 lines / 8 KiB.
For retirements, verify Git commit/path recovery and migrate unique current facts
before deleting explicit reviewed files. A historical Git path, external operator
path or command placeholder is distinct from a live local documentation link.

Every sprint also traces include order/reachability/cycles and reviews the broker
and research boundaries. Documentation-only gates confirm source/include/schema
hashes unchanged; no new compile is needed. Source cleanup needs exact non-use or
equivalence proof, existing affected tests and the compile gate. Stage only reviewed
paths, commit each sprint separately and record its rollback parent. Restore a
matching binary or recompile if source is reverted.

## Strategy Tester And Chart Acceptance

Use the current index to select accepted prior evidence and the remaining human
visual gate. A new full runtime acceptance uses **Every tick based on real ticks**,
matched export-disabled/enabled intervals and file logs off. Check H1 midpoint
touch/no-touch and all ratios, paired Macro/Deep and Deep/Micro capture, both
parent relationships, parent-specific censoring,
R5 continuation without a special controller, structural 1R broker ownership,
export-off parity and DST. Validate/build/audit the strict V14 output, preserving
the configured support floor even when the run has insufficient support.

Record elapsed time, peak state/capacity, twelve-file row counts, folder growth,
source/binary hashes, tester settings and meaningful diagnostics. Human inspection
checks owned lines/labels, cleanup and the 16-position rendering bound. Fixtures
and compilation cannot replace that visual check. It is required before a
deployment-oriented claim and does not block separately authorized offline
contract preparation.

For behavior-preserving optimization, compare all twelve files in original row
order with exact values, normalizing only verified run IDs (including the manifest
run-ID value). Keep feature, timestamp, price, outcome and membership facts exact.
Pair this with ordered broker messages and non-job report fields, strict validation,
chronology and disposable failed-export cases. Sidecars own build/performance pins.
Use warm-ups and alternating baseline/final repetitions, report medians and ranges,
and treat gains below 5% as inconclusive for performance promotion. A bounded process
sample cannot establish absence of leaks over every multi-year run. Reuse valid
same-binary gates and never replace an active operator's EX5 for benchmarking.

For a fatal research failure, retain the first `PIVOT_V14_EXPORT_FAILED` journal
entry, its external `PivotFractalV14/diagnostics/<run_id>.failure.txt` sidecar when
available, tester job ID, settings and source/binary pin. The EA stops only the
tester at an event boundary; a `FAILED` / `CENSORED` or unsealed export is invalid.
Use fresh run IDs after correction. Fault checks may invalidate a header or
remove an export file only in a new disposable run, with the original file
retained outside its strict directory.

Native tester tool timeouts limit waiting, not execution. Retain each returned
job ID, use waits no longer than 60 seconds, and stop only that matching active
job if its planned guard expires. Retain owned settings and raw receipts outside
tracked source; never start a duplicate job after a waiting timeout.

### Full-History EURUSD Operator Gate

The completed reliability work leaves full-history acceptance separate. Its
historical V13 `.ini` and `.set` are named
`eurusd-reliability-full-history-avx2-operator` under the existing
`C:\MetaTrader 5-1\MQL5\Profiles\Tester\` directory. Exact copies and the
operator handoff are in ignored `.codex-artifacts/eurusd-tester-reliability/sprint-4/`.
These settings and their original ID remain retained historical artifacts.

For a separately authorized V14 launch, create new owned settings and a new V14
run ID after verifying the selected binary and that no tester job is active.
Do not reuse the historical `EURUSD_Reliability_FULL_AVX2_OPERATOR_20260910`
identity or apply its V13 acceptance to V14. Keep the existing
`EURUSD_Exness_2015` ticks/specifications, requested interval 2015-08-10 to
2026-09-08 (end exclusive), real ticks, M3 chart, H1/M10/M3, EXNESS_SESSION,
50 ms delay, reference-balance size 0.001, simulated USD 1,000,000 / 1:10000,
export on and debug/visualization/optimization/forward off. Preflight the terminal
MCP, then call `tester_run_backtest` with the absolute configuration/input paths
and `wait=false`; retain the returned job ID.

Set the full-history monitoring/stop budget at launch. Focused-run guards are not
a full-history acceptance budget. Monitor export growth and first-failure
diagnostics; retain any failed output and restart only with a new ID. Acceptance
requires natural successful sealing, reconciled warm-up/tick counts, capacity
evidence and applicable strict semantic plus chronology validation. A bounded
chronology audit alone is insufficient. Preserve the original failed EURUSD run,
its pre-stop backup and the XAUUSD original/recovered artifacts. Human chart,
formal Exness broker-equivalence and recovered-run semantic gates remain separate.

Record the actual execution delay. A run configured with `ExecutionMode=120`
ms can establish causal processing, geometry, reconciliation and parity, but not
sub-120 ms latency, perfect intra-second ordering or exchange tick sequencing.
Any other configured delay retains its corresponding limitation. A recovered
historical export is not a fresh test of the corrected binary.

Retain private reports/journals outside tracked source, using compact status,
hashes, paths, counts and first useful failures in documentation. Reuse passing
evidence while its inputs remain valid. Keep failed original runs intact and use
new run IDs for corrections. No validation result authorizes live rollout or
another repository's destructive data/schema cutover.
