#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/run_mql5_tests.sh [--mt5-root PATH] [--symbol SYMBOL] [--period PERIOD] [--report-dir PATH]

Description:
  Compiles and runs all tests matching tests/*_test.mq5.
  Compile gate is strict: any warning or error fails the test.
  Runtime gate is strict: script must load, emit PASS, and avoid FAIL.

Options:
  --mt5-root PATH   MetaTrader root (contains terminal64.exe and MQL5/)
  --symbol SYMBOL   Symbol used when launching script tests (default: EURUSD)
  --period PERIOD   Period used when launching script tests (default: M1)
  --report-dir DIR  Report output root (default: logs/test-runner)
  -h, --help        Show this help
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

sanitize_line() {
  printf '%s' "$1" | tr '\r\n\t' '   '
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

is_windows() {
  local kernel
  kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
  [[ "$kernel" == *mingw* || "$kernel" == *msys* || "$kernel" == *cygwin* ]]
}

to_native_path() {
  local path="$1"
  if is_windows; then
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w "$path"
    else
      printf '%s' "$path"
    fi
  else
    winepath -w "$path" 2>/dev/null
  fi
}

run_windows_binary() {
  local exe="$1"
  shift
  if is_windows; then
    "$exe" "$@"
  else
    require_command wine
    wine "$exe" "$@"
  fi
}

decode_log_to_utf8() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    : >"$dst"
    return
  fi

  if command -v iconv >/dev/null 2>&1; then
    if iconv -f utf-16le -t utf-8 "$src" >"$dst" 2>/dev/null; then
      :
    elif iconv -f utf-8 -t utf-8 "$src" >"$dst" 2>/dev/null; then
      :
    else
      cp "$src" "$dst"
    fi
  else
    cp "$src" "$dst"
  fi
}

decoded_line_count() {
  local file="$1"
  local tmp

  if [[ ! -f "$file" ]]; then
    printf '0'
    return
  fi

  tmp="$(mktemp)"
  decode_log_to_utf8 "$file" "$tmp"
  wc -l <"$tmp" | tr -d ' '
  rm -f "$tmp"
}

latest_log_file() {
  local dir="$1"
  local latest=""
  if compgen -G "$dir/*.log" >/dev/null 2>&1; then
    latest="$(ls -1t "$dir"/*.log | head -n 1)"
  fi
  printf '%s' "$latest"
}

extract_new_segment() {
  local before_file="$1"
  local before_lines="$2"
  local after_file="$3"
  local output_file="$4"
  local decoded

  : >"$output_file"
  [[ -n "$after_file" && -f "$after_file" ]] || return

  decoded="$(mktemp)"
  decode_log_to_utf8 "$after_file" "$decoded"

  if [[ -n "$before_file" && "$before_file" == "$after_file" ]]; then
    local start_line
    start_line=$((before_lines + 1))
    if [[ "$start_line" -le 1 ]]; then
      cat "$decoded" >"$output_file"
    else
      tail -n +"$start_line" "$decoded" >"$output_file" || true
    fi
  else
    cat "$decoded" >"$output_file"
  fi

  rm -f "$decoded"
}

contains_script_token() {
  local file="$1"
  local script_name="$2"
  local token="$3"

  [[ -f "$file" ]] || return 1

  awk -v script_name="$script_name" -v token="$token" '
    BEGIN {
      found = 0;
      script_name = tolower(script_name);
      token = tolower(token);
    }
    {
      line = tolower($0);
      if(index(line, script_name) > 0 && index(line, token) > 0) {
        found = 1;
        exit 0;
      }
    }
    END {
      if(found == 1) {
        exit 0;
      }
      exit 1;
    }
  ' "$file"
}

extract_first_matching_line() {
  local file="$1"
  local script_name="$2"
  local token="$3"
  local line=""

  if [[ -f "$file" ]]; then
    line="$(awk -v script_name="$script_name" -v token="$token" '
      BEGIN {
        script_name = tolower(script_name);
        token = tolower(token);
      }
      {
        low = tolower($0);
        if(index(low, script_name) > 0 && index(low, token) > 0) {
          print $0;
          exit 0;
        }
      }
    ' "$file")"
  fi

  printf '%s' "$line"
}

parse_compile_result() {
  local utf8_log="$1"
  local result_line
  local errors
  local warnings

  result_line="$(grep -Eio 'result:?[[:space:]]*[0-9]+[[:space:]]+errors?,[[:space:]]*[0-9]+[[:space:]]+warnings?' "$utf8_log" | tail -n 1 || true)"
  [[ -n "$result_line" ]] || return 1

  errors="$(printf '%s\n' "$result_line" | sed -E 's/.*result:?[[:space:]]*([0-9]+)[[:space:]]+errors?.*/\1/I')"
  warnings="$(printf '%s\n' "$result_line" | sed -E 's/.*errors?,[[:space:]]*([0-9]+)[[:space:]]+warnings?.*/\1/I')"

  printf '%s\t%s\t%s\n' "$errors" "$warnings" "$result_line"
}

scan_mock_dependency_usage() {
  local source_file="$1"
  local pattern
  pattern='CopyRates|CopyTicks|CopyTicksRange|CopyBuffer|iOpen|iHigh|iLow|iClose|iVolume|SeriesInfoInteger|iBars|Bars\('
  grep -nE "$pattern" "$source_file" || true
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MT5_ROOT_ARG=""
TEST_SYMBOL="${TEST_SYMBOL:-EURUSD}"
TEST_PERIOD="${TEST_PERIOD:-M1}"
REPORT_ROOT="${PROJECT_ROOT}/logs/test-runner"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mt5-root)
      [[ $# -ge 2 ]] || die "--mt5-root requires a value"
      MT5_ROOT_ARG="$2"
      shift 2
      ;;
    --symbol)
      [[ $# -ge 2 ]] || die "--symbol requires a value"
      TEST_SYMBOL="$2"
      shift 2
      ;;
    --period)
      [[ $# -ge 2 ]] || die "--period requires a value"
      TEST_PERIOD="$2"
      shift 2
      ;;
    --report-dir)
      [[ $# -ge 2 ]] || die "--report-dir requires a value"
      REPORT_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

require_command find
require_command awk
require_command grep
require_command sed
require_command sort
require_command date
require_command mktemp

if ! is_windows; then
  require_command wine
  require_command winepath
  if [[ -z "${WINEDEBUG:-}" ]]; then
    export WINEDEBUG="${MQL5_WINEDEBUG:--all}"
  fi
fi

find_mt5_root() {
  local project_parent
  local -a candidates=()
  local candidate
  project_parent="$(cd "$PROJECT_ROOT/../../.." && pwd)"

  [[ -n "$MT5_ROOT_ARG" ]] && candidates+=("$MT5_ROOT_ARG")
  [[ -n "${MT5_ROOT:-}" ]] && candidates+=("${MT5_ROOT}")
  candidates+=("$PROJECT_ROOT" "$project_parent")

  for candidate in "${candidates[@]}"; do
    [[ -z "$candidate" ]] && continue
    if [[ -f "$candidate/terminal64.exe" && -d "$candidate/MQL5" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

MT5_ROOT_DETECTED="$(find_mt5_root || true)"
[[ -n "$MT5_ROOT_DETECTED" ]] || die "Unable to locate MT5 root. Provide --mt5-root PATH."

MT5_ROOT="$MT5_ROOT_DETECTED"
TERMINAL_EXE="$MT5_ROOT/terminal64.exe"

if [[ -f "$MT5_ROOT/MetaEditor64.exe" ]]; then
  METAEDITOR_EXE="$MT5_ROOT/MetaEditor64.exe"
elif [[ -f "$PROJECT_ROOT/MetaEditor64.exe" ]]; then
  METAEDITOR_EXE="$PROJECT_ROOT/MetaEditor64.exe"
else
  die "MetaEditor64.exe not found in MT5 root or project root."
fi

[[ -f "$TERMINAL_EXE" ]] || die "terminal64.exe not found at $TERMINAL_EXE"
[[ -d "$MT5_ROOT/MQL5/Scripts" ]] || die "Scripts directory not found at $MT5_ROOT/MQL5/Scripts"

mapfile -t TEST_FILES < <(find "$PROJECT_ROOT/tests" -maxdepth 1 -type f -name '*_test.mq5' | sort)
[[ "${#TEST_FILES[@]}" -gt 0 ]] || die "No test files found in tests/*_test.mq5"
discovered_tests="${#TEST_FILES[@]}"

RUN_STAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_DIR="$REPORT_ROOT/$RUN_STAMP"
COMPILE_DIR="$RUN_DIR/compile"
RUNTIME_DIR="$RUN_DIR/runtime"
CONFIG_DIR="$RUN_DIR/config"
STAGE_DIR="$MT5_ROOT/MQL5/Scripts/HFT_Grid_AI_Tests"
RESULTS_TSV="$RUN_DIR/results.tsv"
MOCK_WARNINGS_TXT="$RUN_DIR/mock_dependency_warnings.txt"
REPORT_MD="$RUN_DIR/report.md"
REPORT_JSON="$RUN_DIR/report.json"

mkdir -p "$COMPILE_DIR" "$RUNTIME_DIR" "$CONFIG_DIR" "$REPORT_ROOT" "$STAGE_DIR"
: >"$RESULTS_TSV"
: >"$MOCK_WARNINGS_TXT"

log "MT5 root: $MT5_ROOT"
log "MetaEditor: $METAEDITOR_EXE"
log "Terminal: $TERMINAL_EXE"
log "Tests found: $discovered_tests"
log "Report dir: $RUN_DIR"

total_tests=0
passed_tests=0
failed_tests=0
compile_failures=0
runtime_failures=0
report_generated=0
interrupted=0
reports_ready=1

write_reports() {
  local processed_tests
  ((reports_ready == 1)) || return 0
  ((report_generated == 0)) || return 0
  processed_tests="$(wc -l <"$RESULTS_TSV" | tr -d ' ')"

  {
    echo "# MQL5 Test Runner Report"
    echo
    echo "- Generated at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- Project root: $PROJECT_ROOT"
    echo "- MT5 root: $MT5_ROOT"
    echo "- Test pattern: tests/*_test.mq5"
    echo "- Runtime symbol/period: ${TEST_SYMBOL}/${TEST_PERIOD}"
    echo "- Tests discovered: $discovered_tests"
    echo "- Tests processed: $processed_tests"
    echo "- Passed: $passed_tests"
    echo "- Failed: $failed_tests"
    echo "- Compile failures: $compile_failures"
    echo "- Runtime failures: $runtime_failures"
    echo
    echo "## Results"
    echo
    echo "| Test | Status | Phase | Reason |"
    echo "|---|---|---|---|"
    while IFS=$'\t' read -r t_name t_status t_phase t_reason t_hint t_compile t_term t_mql t_exit; do
      printf '| `%s` | **%s** | `%s` | %s |\n' "$t_name" "$t_status" "$t_phase" "$t_reason"
    done <"$RESULTS_TSV"
    echo
    echo "## Failure Hints"
    echo
    while IFS=$'\t' read -r t_name t_status t_phase t_reason t_hint t_compile t_term t_mql t_exit; do
      if [[ "$t_status" == "FAIL" ]]; then
        echo "- $t_name ($t_phase): $t_hint"
        echo "  Compile log: $t_compile"
        echo "  Terminal segment: $t_term"
        echo "  MQL segment: $t_mql"
      fi
    done <"$RESULTS_TSV"
    echo
    if [[ -s "$MOCK_WARNINGS_TXT" ]]; then
      echo "## Mock-Dependency Warnings"
      echo
      echo "The following tests reference data-coupled APIs. They are not auto-failed, but should be reviewed:"
      echo
      sed 's/^/- /' "$MOCK_WARNINGS_TXT"
      echo
    fi
    echo "## Agent Fix Workflow"
    echo
    echo "1. Open the failing compile/runtime log files listed above."
    echo "2. Fix compile warnings/errors first; runtime is only valid after clean compile."
    echo "3. For runtime FAIL, inspect first FAIL line in MQL segment and corresponding terminal segment."
    echo "4. Re-run this script until all tests report PASS."
  } >"$REPORT_MD"

  {
    echo "{"
    echo "  \"generated_at\": \"$(json_escape "$(date '+%Y-%m-%d %H:%M:%S')")\","
    echo "  \"project_root\": \"$(json_escape "$PROJECT_ROOT")\","
    echo "  \"mt5_root\": \"$(json_escape "$MT5_ROOT")\","
    echo "  \"symbol\": \"$(json_escape "$TEST_SYMBOL")\","
    echo "  \"period\": \"$(json_escape "$TEST_PERIOD")\","
    echo "  \"total\": $discovered_tests,"
    echo "  \"processed\": $processed_tests,"
    echo "  \"passed\": $passed_tests,"
    echo "  \"failed\": $failed_tests,"
    echo "  \"compile_failures\": $compile_failures,"
    echo "  \"runtime_failures\": $runtime_failures,"
    echo "  \"results\": ["
    first_record=1
    while IFS=$'\t' read -r t_name t_status t_phase t_reason t_hint t_compile t_term t_mql t_exit; do
      if [[ "$first_record" -eq 0 ]]; then
        echo "    ,"
      fi
      first_record=0
      if [[ "$t_exit" =~ ^-?[0-9]+$ ]]; then
        t_exit_value="$t_exit"
      else
        t_exit_value="0"
      fi
      echo "    {"
      echo "      \"test\": \"$(json_escape "$t_name")\","
      echo "      \"status\": \"$(json_escape "$t_status")\","
      echo "      \"phase\": \"$(json_escape "$t_phase")\","
      echo "      \"reason\": \"$(json_escape "$t_reason")\","
      echo "      \"hint\": \"$(json_escape "$t_hint")\","
      echo "      \"compile_log\": \"$(json_escape "$t_compile")\","
      echo "      \"terminal_segment\": \"$(json_escape "$t_term")\","
      echo "      \"mql_segment\": \"$(json_escape "$t_mql")\","
      echo "      \"runner_exit_code\": $t_exit_value"
      echo -n "    }"
    done <"$RESULTS_TSV"
    echo
    echo "  ]"
    echo "}"
  } >"$REPORT_JSON"

  ln -sfn "$RUN_DIR" "$REPORT_ROOT/latest" 2>/dev/null || true
  report_generated=1
}

on_interrupt() {
  interrupted=1
  warn "Interrupt received. Stopping run and writing partial report."
  exit 130
}

on_exit() {
  local exit_code=$?
  if ((reports_ready == 1)) && ((report_generated == 0)); then
    write_reports || true
  fi
  if ((interrupted == 1)); then
    warn "Partial report available: $RUN_DIR"
  fi
  return "$exit_code"
}

trap on_interrupt INT TERM
trap on_exit EXIT

for source_file in "${TEST_FILES[@]}"; do
  total_tests=$((total_tests + 1))
  test_name="$(basename "$source_file" .mq5)"
  source_ex5="${source_file%.mq5}.ex5"

  compile_raw_log="$COMPILE_DIR/${test_name}.log"
  compile_utf8_log="$COMPILE_DIR/${test_name}.utf8.log"
  compile_stdout_log="$COMPILE_DIR/${test_name}.stdout.log"

  runtime_stdout_log="$RUNTIME_DIR/${test_name}.stdout.log"
  runtime_terminal_segment="$RUNTIME_DIR/${test_name}.terminal.segment.log"
  runtime_mql_segment="$RUNTIME_DIR/${test_name}.mql.segment.log"
  runtime_config="$CONFIG_DIR/${test_name}.ini"

  phase="compile"
  status="FAIL"
  reason=""
  hint=""
  compile_result_line=""

  mock_hits="$(scan_mock_dependency_usage "$source_file")"
  if [[ -n "$mock_hits" ]]; then
    {
      printf '%s\n' "[$test_name]"
      printf '%s\n\n' "$mock_hits"
    } >>"$MOCK_WARNINGS_TXT"
  fi

  rm -f "$source_ex5" "$compile_raw_log" "$compile_utf8_log" "$compile_stdout_log"

  source_native="$(to_native_path "$source_file")"
  compile_log_native="$(to_native_path "$compile_raw_log")"

  set +e
  run_windows_binary "$METAEDITOR_EXE" "/compile:$source_native" "/log:$compile_log_native" "/portable" >"$compile_stdout_log" 2>&1
  compile_cmd_exit=$?
  set -e

  decode_log_to_utf8 "$compile_raw_log" "$compile_utf8_log"

  parse_output="$(parse_compile_result "$compile_utf8_log" || true)"
  if [[ -z "$parse_output" ]]; then
    reason="compile log has no parseable result line"
    hint="Check $compile_utf8_log for MetaEditor startup or path issues."
    compile_failures=$((compile_failures + 1))
    failed_tests=$((failed_tests + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$test_name" "$status" "$phase" \
      "$(sanitize_line "$reason")" "$(sanitize_line "$hint")" \
      "$compile_utf8_log" "$runtime_terminal_segment" "$runtime_mql_segment" "$compile_cmd_exit" >>"$RESULTS_TSV"
    log "FAIL [compile] $test_name - $reason"
    continue
  fi

  compile_errors="$(printf '%s' "$parse_output" | awk -F '\t' '{print $1}')"
  compile_warnings="$(printf '%s' "$parse_output" | awk -F '\t' '{print $2}')"
  compile_result_line="$(printf '%s' "$parse_output" | awk -F '\t' '{print $3}')"

  if [[ "$compile_errors" != "0" || "$compile_warnings" != "0" ]]; then
    reason="strict compile gate failed: ${compile_result_line}"
    hint="Fix compiler errors and warnings in $source_file and re-run."
    compile_failures=$((compile_failures + 1))
    failed_tests=$((failed_tests + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$test_name" "$status" "$phase" \
      "$(sanitize_line "$reason")" "$(sanitize_line "$hint")" \
      "$compile_utf8_log" "$runtime_terminal_segment" "$runtime_mql_segment" "$compile_cmd_exit" >>"$RESULTS_TSV"
    log "FAIL [compile] $test_name - $compile_result_line"
    continue
  fi

  if [[ ! -f "$source_ex5" ]]; then
    reason="compile reported success but .ex5 artifact was not generated"
    hint="Verify MetaEditor output path and permissions for $source_file."
    compile_failures=$((compile_failures + 1))
    failed_tests=$((failed_tests + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$test_name" "$status" "$phase" \
      "$(sanitize_line "$reason")" "$(sanitize_line "$hint")" \
      "$compile_utf8_log" "$runtime_terminal_segment" "$runtime_mql_segment" "$compile_cmd_exit" >>"$RESULTS_TSV"
    log "FAIL [compile] $test_name - missing .ex5 artifact"
    continue
  fi

  cp -f "$source_ex5" "$STAGE_DIR/${test_name}.ex5"

  phase="runtime"
  status="FAIL"
  reason=""
  hint=""

  terminal_before="$(latest_log_file "$MT5_ROOT/logs")"
  mql_before="$(latest_log_file "$MT5_ROOT/MQL5/Logs")"
  terminal_before_lines=0
  mql_before_lines=0

  if [[ -n "$terminal_before" ]]; then
    terminal_before_lines="$(decoded_line_count "$terminal_before")"
  fi
  if [[ -n "$mql_before" ]]; then
    mql_before_lines="$(decoded_line_count "$mql_before")"
  fi

  {
    echo "[StartUp]"
    printf 'Script=HFT_Grid_AI_Tests\\%s\n' "$test_name"
    printf 'Symbol=%s\n' "$TEST_SYMBOL"
    printf 'Period=%s\n' "$TEST_PERIOD"
    echo "ShutdownTerminal=1"
  } >"$runtime_config"

  runtime_config_native="$(to_native_path "$runtime_config")"

  set +e
  run_windows_binary "$TERMINAL_EXE" "/portable" "/config:$runtime_config_native" >"$runtime_stdout_log" 2>&1
  runtime_cmd_exit=$?
  set -e

  sleep 1

  terminal_after="$(latest_log_file "$MT5_ROOT/logs")"
  mql_after="$(latest_log_file "$MT5_ROOT/MQL5/Logs")"

  extract_new_segment "$terminal_before" "$terminal_before_lines" "$terminal_after" "$runtime_terminal_segment"
  extract_new_segment "$mql_before" "$mql_before_lines" "$mql_after" "$runtime_mql_segment"

  has_wrong_type=0
  has_loaded=0
  has_removed=0
  has_pass=0
  has_fail=0

  if contains_script_token "$runtime_terminal_segment" "$test_name (" "wrong program type"; then
    has_wrong_type=1
  fi
  if contains_script_token "$runtime_terminal_segment" "script ${test_name} (" "loaded successfully"; then
    has_loaded=1
  fi
  if contains_script_token "$runtime_terminal_segment" "script ${test_name} (" "removed"; then
    has_removed=1
  fi
  if contains_script_token "$runtime_mql_segment" "$test_name (" "pass"; then
    has_pass=1
  fi
  if contains_script_token "$runtime_mql_segment" "$test_name (" "fail"; then
    has_fail=1
  fi

  if [[ "$has_wrong_type" -eq 1 ]]; then
    reason="terminal reported wrong program type while loading script"
    hint="Ensure test artifact is staged under MQL5/Scripts and startup Script path is relative to Scripts."
  elif [[ "$has_loaded" -ne 1 ]]; then
    reason="script did not load successfully"
    hint="Check $runtime_terminal_segment and $runtime_stdout_log for startup/config issues."
  elif [[ "$has_removed" -ne 1 ]]; then
    reason="script did not unload cleanly"
    hint="Test may be blocked in runtime loop; inspect $runtime_terminal_segment."
  elif [[ "$has_fail" -eq 1 ]]; then
    fail_line="$(extract_first_matching_line "$runtime_mql_segment" "$test_name (" "fail")"
    reason="test emitted FAIL"
    hint="$(sanitize_line "$fail_line")"
  elif [[ "$has_pass" -ne 1 ]]; then
    reason="test completed without PASS marker"
    hint="Ensure test script prints PASS on success and no early return path skips it."
  else
    status="PASS"
    reason="PASS"
    hint="runtime_cmd_exit=$runtime_cmd_exit"
  fi

  if [[ "$status" == "FAIL" ]]; then
    if grep -Eqi 'no history data|history.*not found|symbol.*not found|cannot select symbol|market closed|invalid symbol' "$runtime_terminal_segment" "$runtime_mql_segment" 2>/dev/null; then
      hint="${hint} | Mock-only test appears context-sensitive. Validate chart symbol/period or remove market-data dependency."
    fi
    runtime_failures=$((runtime_failures + 1))
    failed_tests=$((failed_tests + 1))
    log "FAIL [runtime] $test_name - $reason"
  else
    passed_tests=$((passed_tests + 1))
    log "PASS [runtime] $test_name"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$test_name" "$status" "$phase" \
    "$(sanitize_line "$reason")" "$(sanitize_line "$hint")" \
    "$compile_utf8_log" "$runtime_terminal_segment" "$runtime_mql_segment" "$runtime_cmd_exit" >>"$RESULTS_TSV"
done

write_reports

log "Markdown report: $REPORT_MD"
log "JSON report: $REPORT_JSON"

if [[ "$failed_tests" -gt 0 ]]; then
  log "Suite result: FAIL ($failed_tests/$total_tests failed)"
  exit 1
fi

log "Suite result: PASS ($passed_tests/$total_tests passed)"
