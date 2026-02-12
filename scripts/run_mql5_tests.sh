#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/run_mql5_tests.sh [--mt5-root PATH] [--symbol SYMBOL] [--symbols CSV] [--matrix-smoke] [--optional-symbol SYMBOL] [--period PERIOD] [--report-dir PATH] [--fast] [--compile-only]

Description:
  Compiles tests matching tests/*_test.mq5, then runs one harness script across one or more symbols.
  Compile gate is strict: any warning or error fails the test.
  Runtime gate is strict: harness must load/unload and emit TEST_PASS/TEST_FAIL markers.

Options:
  --mt5-root PATH      MetaTrader root (contains terminal64.exe and MQL5/)
  --symbol SYMBOL      Single runtime symbol (default: EURUSD)
  --symbols CSV        Runtime symbol list, comma-separated (overrides --symbol)
  --matrix-smoke       Use matrix symbols: EURUSD,XAUUSD,US30
  --optional-symbol S  Append one extra optional symbol (e.g. USDJPY or BTCUSD)
  --period PERIOD      Period used for runtime startup context (default: M1)
  --report-dir DIR     Report output root; runner writes only DIR/latest (default: logs/test-runner)
  --fast               Skip per-test wrapper compile; compile harness only (faster, less strict)
  --compile-only       Compile gates only; skip runtime (does not launch terminal64.exe)
  -h, --help           Show this help
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
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

is_terminal_already_running() {
  if is_windows; then
    if command -v tasklist >/dev/null 2>&1; then
      tasklist /NH /FI "IMAGENAME eq terminal64.exe" 2>/dev/null | grep -Eqi 'terminal64\.exe'
      return $?
    fi
    return 1
  fi

  ps -eo args | grep -i '[t]erminal64\.exe' >/dev/null 2>&1
}

list_terminal_processes() {
  if is_windows; then
    if command -v tasklist >/dev/null 2>&1; then
      tasklist /NH /FI "IMAGENAME eq terminal64.exe" 2>/dev/null || true
    fi
    return 0
  fi

  ps -eo pid,ppid,etime,args | grep -i '[t]erminal64\.exe' || true
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

latest_log_file() {
  local dir="$1"
  local pattern="$2"
  if compgen -G "$dir/$pattern" >/dev/null 2>&1; then
    ls -1t "$dir"/$pattern | head -n 1
  fi
}

decoded_line_count() {
  local file="$1"
  local tmp

  if [[ -z "$file" || ! -f "$file" ]]; then
    printf '0'
    return
  fi

  tmp="$(mktemp)"
  decode_log_to_utf8 "$file" "$tmp"
  wc -l <"$tmp" | tr -d ' '
  rm -f "$tmp"
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
        exit;
      }
    }
    END { exit (found ? 0 : 1); }
  ' "$file"
}

contains_text_token() {
  local file="$1"
  local token="$2"

  [[ -f "$file" ]] || return 1

  awk -v token="$token" '
    BEGIN {
      found = 0;
      token = tolower(token);
    }
    {
      line = tolower($0);
      if(index(line, token) > 0) {
        found = 1;
        exit;
      }
    }
    END { exit (found ? 0 : 1); }
  ' "$file"
}

contains_harness_test_marker() {
  local file="$1"
  local marker="$2"
  local test_name="$3"

  [[ -f "$file" ]] || return 1

  awk -v marker="$marker" -v test_name="$test_name" '
    BEGIN {
      found = 0;
      marker = tolower(marker);
      test_name = tolower(test_name);
    }
    {
      line = tolower($0);
      if(index(line, marker) > 0 && index(line, test_name) > 0) {
        found = 1;
        exit;
      }
    }
    END { exit (found ? 0 : 1); }
  ' "$file"
}

extract_harness_line() {
  local file="$1"
  local marker="$2"
  local test_name="$3"

  [[ -f "$file" ]] || return 1

  awk -v marker="$marker" -v test_name="$test_name" '
    BEGIN {
      found = 0;
      marker = tolower(marker);
      test_name = tolower(test_name);
    }
    {
      line = tolower($0);
      if(index(line, marker) > 0 && (test_name == "" || index(line, test_name) > 0)) {
        found = 1;
        print $0;
        exit;
      }
    }
    END { exit (found ? 0 : 1); }
  ' "$file"
}

trim_spaces() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

sanitize_token() {
  local value="$1"
  value="${value//[^a-zA-Z0-9._-]/_}"
  printf '%s' "$value"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MT5_ROOT_ARG=""
TEST_SYMBOL="${TEST_SYMBOL:-EURUSD}"
TEST_SYMBOLS_CSV="${TEST_SYMBOLS:-}"
MATRIX_SMOKE=0
OPTIONAL_SYMBOL=""
TEST_PERIOD="${TEST_PERIOD:-M1}"
FAST_MODE=0
COMPILE_ONLY=0
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
    --symbols)
      [[ $# -ge 2 ]] || die "--symbols requires a value"
      TEST_SYMBOLS_CSV="$2"
      shift 2
      ;;
    --matrix-smoke)
      MATRIX_SMOKE=1
      shift
      ;;
    --optional-symbol)
      [[ $# -ge 2 ]] || die "--optional-symbol requires a value"
      OPTIONAL_SYMBOL="$2"
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
    --fast)
      FAST_MODE=1
      shift
      ;;
    --compile-only)
      COMPILE_ONLY=1
      shift
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

declare -a RUN_SYMBOLS=()
if [[ -n "$TEST_SYMBOLS_CSV" ]]; then
  IFS=',' read -r -a raw_symbols <<< "$TEST_SYMBOLS_CSV"
  for raw_symbol in "${raw_symbols[@]}"; do
    symbol="$(trim_spaces "$raw_symbol")"
    [[ -n "$symbol" ]] && RUN_SYMBOLS+=("$symbol")
  done
elif [[ "$MATRIX_SMOKE" -eq 1 ]]; then
  RUN_SYMBOLS=("EURUSD" "XAUUSD" "US30")
else
  RUN_SYMBOLS=("$TEST_SYMBOL")
fi

if [[ -n "$OPTIONAL_SYMBOL" ]]; then
  optional_trimmed="$(trim_spaces "$OPTIONAL_SYMBOL")"
  [[ -n "$optional_trimmed" ]] && RUN_SYMBOLS+=("$optional_trimmed")
fi

declare -a UNIQUE_SYMBOLS=()
for symbol in "${RUN_SYMBOLS[@]}"; do
  symbol="$(trim_spaces "$symbol")"
  [[ -n "$symbol" ]] || continue
  found=0
  for existing_symbol in "${UNIQUE_SYMBOLS[@]}"; do
    if [[ "${existing_symbol^^}" == "${symbol^^}" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    UNIQUE_SYMBOLS+=("$symbol")
  fi
done

RUN_SYMBOLS=("${UNIQUE_SYMBOLS[@]}")
[[ "${#RUN_SYMBOLS[@]}" -gt 0 ]] || die "No runtime symbols resolved. Use --symbol or --symbols."

require_command find
require_command awk
require_command grep
require_command sed
require_command sort
require_command date
require_command mktemp
require_command ps

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

if [[ "$COMPILE_ONLY" -ne 1 ]] && is_terminal_already_running; then
  running_terminals="$(list_terminal_processes)"
  die "Detected running terminal64.exe. Close MT5 first. Processes: ${running_terminals:-unavailable}"
fi

mapfile -t TEST_FILES < <(find "$PROJECT_ROOT/tests" -maxdepth 1 -type f -name '*_test.mq5' | sort)
[[ "${#TEST_FILES[@]}" -gt 0 ]] || die "No test files found in tests/*_test.mq5"

RUN_STAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_DIR="$REPORT_ROOT/latest"
COMPILE_DIR="$RUN_DIR/compile"
RUNTIME_DIR="$RUN_DIR/runtime"
CONFIG_DIR="$RUN_DIR/config"
SUMMARY_LOG="$RUN_DIR/summary.log"
STAGE_DIR="$MT5_ROOT/MQL5/Scripts/HFT_Grid_AI_Tests"
HARNESS_NAME="hft_grid_ai_tests_harness"
HARNESS_SOURCE="$PROJECT_ROOT/tests/${HARNESS_NAME}.mq5"

mkdir -p "$REPORT_ROOT"
[[ -e "$RUN_DIR" || -L "$RUN_DIR" ]] && rm -rf "$RUN_DIR"
mkdir -p "$COMPILE_DIR" "$RUNTIME_DIR" "$CONFIG_DIR" "$STAGE_DIR"
: >"$SUMMARY_LOG"

summary() {
  printf '%s\n' "$*" | tee -a "$SUMMARY_LOG" >/dev/null
}

SYMBOLS_LIST="$(IFS=,; printf '%s' "${RUN_SYMBOLS[*]}")"

summary "RUN_STAMP=$RUN_STAMP"
summary "PROJECT_ROOT=$PROJECT_ROOT"
summary "MT5_ROOT=$MT5_ROOT"
summary "SYMBOLS=$SYMBOLS_LIST"
summary "PERIOD=$TEST_PERIOD"
summary "FAST_MODE=$FAST_MODE"
summary "COMPILE_ONLY=$COMPILE_ONLY"
summary "TEST_COUNT_DISCOVERED=${#TEST_FILES[@]}"
summary ""

log "MT5 root: $MT5_ROOT"
log "MetaEditor: $METAEDITOR_EXE"
log "Terminal: $TERMINAL_EXE"
log "Tests discovered: ${#TEST_FILES[@]}"
log "Runtime symbols: $SYMBOLS_LIST"
log "Fast mode: $FAST_MODE"
log "Compile only: $COMPILE_ONLY"
log "Summary log: $SUMMARY_LOG"

compile_failures=0
runtime_failures=0
harness_ready=0
runtime_cmd_exit=0
harness_reason=""
harness_hint=""

# shellcheck disable=SC2034
declare -A TEST_STATUS=()
declare -A TEST_REASON=()
declare -A TEST_COMPILE_LOG=()
declare -a COMPILE_OK_TESTS=()

declare -a TEST_NAMES=()
for source_file in "${TEST_FILES[@]}"; do
  TEST_NAMES+=("$(basename "$source_file" .mq5)")
done

summary "[COMPILE]"
if [[ "$FAST_MODE" -eq 1 ]]; then
  for source_file in "${TEST_FILES[@]}"; do
    test_name="$(basename "$source_file" .mq5)"
    TEST_STATUS["$test_name"]="PASS"
    TEST_REASON["$test_name"]="compile: skipped in fast mode; harness compile gate enabled"
    COMPILE_OK_TESTS+=("$test_name")
    summary "PASS $test_name compile fast_mode_harness_only"
  done
else
  for source_file in "${TEST_FILES[@]}"; do
    test_name="$(basename "$source_file" .mq5)"
    source_ex5="${source_file%.mq5}.ex5"

    compile_raw_log="$COMPILE_DIR/${test_name}.metaeditor.raw.log"
    compile_utf8_log="$COMPILE_DIR/${test_name}.metaeditor.log"

    rm -f "$source_ex5" "$compile_raw_log" "$compile_utf8_log"

    source_native="$(to_native_path "$source_file")"
    compile_log_native="$(to_native_path "$compile_raw_log")"

    set +e
    run_windows_binary "$METAEDITOR_EXE" "/compile:$source_native" "/log:$compile_log_native" "/portable" >/dev/null 2>&1
    compile_exit=$?
    set -e

    decode_log_to_utf8 "$compile_raw_log" "$compile_utf8_log"
    TEST_COMPILE_LOG["$test_name"]="$compile_utf8_log"

    parse_output="$(parse_compile_result "$compile_utf8_log" || true)"
    if [[ -z "$parse_output" ]]; then
      TEST_STATUS["$test_name"]="FAIL"
      TEST_REASON["$test_name"]="compile: no parseable result line"
      compile_failures=$((compile_failures + 1))
      summary "FAIL $test_name compile no_parseable_result exit_code=$compile_exit log=$compile_utf8_log"
      continue
    fi

    compile_errors="$(printf '%s' "$parse_output" | awk -F '\t' '{print $1}')"
    compile_warnings="$(printf '%s' "$parse_output" | awk -F '\t' '{print $2}')"
    compile_result_line="$(printf '%s' "$parse_output" | awk -F '\t' '{print $3}')"

    if [[ "$compile_errors" != "0" || "$compile_warnings" != "0" ]]; then
      TEST_STATUS["$test_name"]="FAIL"
      TEST_REASON["$test_name"]="compile: strict gate failed (${compile_result_line})"
      compile_failures=$((compile_failures + 1))
      summary "FAIL $test_name compile strict_gate result=\"$compile_result_line\" log=$compile_utf8_log"
      continue
    fi

    if [[ ! -f "$source_ex5" ]]; then
      TEST_STATUS["$test_name"]="FAIL"
      TEST_REASON["$test_name"]="compile: missing ex5 artifact"
      compile_failures=$((compile_failures + 1))
      summary "FAIL $test_name compile missing_ex5 log=$compile_utf8_log"
      continue
    fi

    cp -f "$source_ex5" "$STAGE_DIR/${test_name}.ex5"
    COMPILE_OK_TESTS+=("$test_name")
    summary "PASS $test_name compile result=\"$compile_result_line\" log=$compile_utf8_log"
  done
fi

summary ""
summary "[HARNESS_COMPILE]"

harness_compile_raw_log="$COMPILE_DIR/${HARNESS_NAME}.metaeditor.raw.log"
harness_compile_utf8_log="$COMPILE_DIR/${HARNESS_NAME}.metaeditor.log"
harness_source_ex5="${HARNESS_SOURCE%.mq5}.ex5"

rm -f "$harness_source_ex5" "$harness_compile_raw_log" "$harness_compile_utf8_log"

if [[ ! -f "$HARNESS_SOURCE" ]]; then
  harness_reason="harness source not found"
  harness_hint="$HARNESS_SOURCE"
  compile_failures=$((compile_failures + 1))
  summary "FAIL harness compile source_missing path=$HARNESS_SOURCE"
else
  harness_source_native="$(to_native_path "$HARNESS_SOURCE")"
  harness_log_native="$(to_native_path "$harness_compile_raw_log")"

  set +e
  run_windows_binary "$METAEDITOR_EXE" "/compile:$harness_source_native" "/log:$harness_log_native" "/portable" >/dev/null 2>&1
  harness_compile_exit=$?
  set -e

  decode_log_to_utf8 "$harness_compile_raw_log" "$harness_compile_utf8_log"

  harness_parse_output="$(parse_compile_result "$harness_compile_utf8_log" || true)"
  if [[ -z "$harness_parse_output" ]]; then
    harness_reason="harness compile has no parseable result"
    harness_hint="$harness_compile_utf8_log"
    compile_failures=$((compile_failures + 1))
    summary "FAIL harness compile no_parseable_result exit_code=$harness_compile_exit log=$harness_compile_utf8_log"
  else
    harness_errors="$(printf '%s' "$harness_parse_output" | awk -F '\t' '{print $1}')"
    harness_warnings="$(printf '%s' "$harness_parse_output" | awk -F '\t' '{print $2}')"
    harness_result_line="$(printf '%s' "$harness_parse_output" | awk -F '\t' '{print $3}')"

    if [[ "$harness_errors" != "0" || "$harness_warnings" != "0" ]]; then
      harness_reason="harness strict compile gate failed"
      harness_hint="$harness_result_line"
      compile_failures=$((compile_failures + 1))
      summary "FAIL harness compile strict_gate result=\"$harness_result_line\" log=$harness_compile_utf8_log"
    elif [[ ! -f "$harness_source_ex5" ]]; then
      harness_reason="harness missing ex5 artifact"
      harness_hint="$HARNESS_SOURCE"
      compile_failures=$((compile_failures + 1))
      summary "FAIL harness compile missing_ex5 log=$harness_compile_utf8_log"
    else
      cp -f "$harness_source_ex5" "$STAGE_DIR/${HARNESS_NAME}.ex5"
      summary "PASS harness compile result=\"$harness_result_line\" log=$harness_compile_utf8_log"
      harness_ready=1
    fi
  fi
fi

summary ""
summary "[RUNTIME]"
passed_tests=0
failed_tests=0

if [[ "$COMPILE_ONLY" -eq 1 ]]; then
  summary "SKIP runtime compile_only=1"
  summary ""
else
  summary "[TEST_RESULTS]"

  for runtime_symbol in "${RUN_SYMBOLS[@]}"; do
    symbol_token="$(sanitize_token "$runtime_symbol")"
    harness_runtime_terminal_log="$RUNTIME_DIR/${HARNESS_NAME}.${symbol_token}.terminal.log"
    harness_runtime_mql_log="$RUNTIME_DIR/${HARNESS_NAME}.${symbol_token}.mql.log"
    harness_runtime_config="$CONFIG_DIR/${HARNESS_NAME}.${symbol_token}.ini"

    symbol_harness_ready=0
    symbol_harness_reason=""
    symbol_harness_hint="none"
    runtime_cmd_exit=0

    summary "SYMBOL_BEGIN=$runtime_symbol"

    if [[ "$harness_ready" -eq 1 && "${#COMPILE_OK_TESTS[@]}" -gt 0 ]]; then
      terminal_before="$(latest_log_file "$MT5_ROOT/logs" '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].log')"
      mql_before="$(latest_log_file "$MT5_ROOT/MQL5/Logs" '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].log')"

      terminal_before_lines="$(decoded_line_count "$terminal_before")"
      mql_before_lines="$(decoded_line_count "$mql_before")"

      {
        echo "[StartUp]"
        printf 'Script=HFT_Grid_AI_Tests\\%s\n' "$HARNESS_NAME"
        printf 'Symbol=%s\n' "$runtime_symbol"
        printf 'Period=%s\n' "$TEST_PERIOD"
        echo "ShutdownTerminal=1"
      } >"$harness_runtime_config"

      harness_runtime_config_native="$(to_native_path "$harness_runtime_config")"

      set +e
      run_windows_binary "$TERMINAL_EXE" "/portable" "/config:$harness_runtime_config_native" >/dev/null 2>&1
      runtime_cmd_exit=$?
      set -e

      sleep 1

      terminal_after="$(latest_log_file "$MT5_ROOT/logs" '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].log')"
      mql_after="$(latest_log_file "$MT5_ROOT/MQL5/Logs" '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].log')"

      extract_new_segment "$terminal_before" "$terminal_before_lines" "$terminal_after" "$harness_runtime_terminal_log"
      extract_new_segment "$mql_before" "$mql_before_lines" "$mql_after" "$harness_runtime_mql_log"

      has_loaded=0
      has_removed=0
      has_summary=0
      has_harness_fail=0

      if contains_script_token "$harness_runtime_terminal_log" "script ${HARNESS_NAME} (" "loaded successfully"; then
        has_loaded=1
      fi
      if contains_script_token "$harness_runtime_terminal_log" "script ${HARNESS_NAME} (" "removed"; then
        has_removed=1
      fi
      if contains_text_token "$harness_runtime_mql_log" "HARNESS_SUMMARY:"; then
        has_summary=1
      fi
      if contains_text_token "$harness_runtime_mql_log" "HARNESS_FAIL"; then
        has_harness_fail=1
      fi

      if [[ "$has_loaded" -ne 1 ]]; then
        symbol_harness_reason="runtime: harness did not load"
        symbol_harness_hint="$harness_runtime_terminal_log"
      elif [[ "$has_removed" -ne 1 ]]; then
        symbol_harness_reason="runtime: harness did not unload"
        symbol_harness_hint="$harness_runtime_terminal_log"
      elif [[ "$has_summary" -ne 1 ]]; then
        symbol_harness_reason="runtime: missing HARNESS_SUMMARY marker"
        symbol_harness_hint="$harness_runtime_mql_log"
      else
        symbol_harness_ready=1
      fi

      if [[ "$symbol_harness_ready" -eq 1 ]]; then
        summary_line="$(extract_harness_line "$harness_runtime_mql_log" 'HARNESS_SUMMARY:' '' || true)"
        if [[ "$has_harness_fail" -eq 1 ]]; then
          summary "FAIL harness runtime symbol=$runtime_symbol marker=HARNESS_FAIL exit_code=$runtime_cmd_exit summary=\"${summary_line:-missing}\" mql_log=$harness_runtime_mql_log"
        else
          summary "PASS harness runtime symbol=$runtime_symbol marker=HARNESS_PASS exit_code=$runtime_cmd_exit summary=\"${summary_line:-missing}\" mql_log=$harness_runtime_mql_log"
        fi
      else
        summary "FAIL harness runtime symbol=$runtime_symbol reason=\"$symbol_harness_reason\" hint=$symbol_harness_hint exit_code=$runtime_cmd_exit"
      fi
    else
      if [[ "${#COMPILE_OK_TESTS[@]}" -eq 0 ]]; then
        symbol_harness_reason="runtime skipped: no compile-pass tests"
      else
        symbol_harness_reason="${harness_reason:-runtime not started}"
      fi
      summary "FAIL harness runtime symbol=$runtime_symbol reason=\"$symbol_harness_reason\" hint=$symbol_harness_hint"
    fi

    symbol_passed_tests=0
    symbol_failed_tests=0

    for test_name in "${TEST_NAMES[@]}"; do
      if [[ "${TEST_STATUS[$test_name]+set}" == "set" && "${TEST_STATUS[$test_name]}" == "FAIL" ]]; then
        symbol_failed_tests=$((symbol_failed_tests + 1))
        failed_tests=$((failed_tests + 1))
        summary "FAIL $runtime_symbol $test_name ${TEST_REASON[$test_name]}"
        continue
      fi

      if [[ "$symbol_harness_ready" -ne 1 ]]; then
        symbol_failed_tests=$((symbol_failed_tests + 1))
        failed_tests=$((failed_tests + 1))
        runtime_failures=$((runtime_failures + 1))
        summary "FAIL $runtime_symbol $test_name runtime ${symbol_harness_reason}"
        continue
      fi

      has_pass=0
      has_fail=0

      if contains_harness_test_marker "$harness_runtime_mql_log" "TEST_PASS:" "$test_name"; then
        has_pass=1
      fi
      if contains_harness_test_marker "$harness_runtime_mql_log" "TEST_FAIL:" "$test_name"; then
        has_fail=1
      fi

      if [[ "$has_fail" -eq 1 ]]; then
        fail_line="$(extract_harness_line "$harness_runtime_mql_log" 'TEST_FAIL_DETAILS:' "$test_name" || true)"
        [[ -n "$fail_line" ]] || fail_line="$(extract_harness_line "$harness_runtime_mql_log" 'TEST_FAIL:' "$test_name" || true)"
        symbol_failed_tests=$((symbol_failed_tests + 1))
        failed_tests=$((failed_tests + 1))
        runtime_failures=$((runtime_failures + 1))
        summary "FAIL $runtime_symbol $test_name runtime ${fail_line:-TEST_FAIL marker}"
      elif [[ "$has_pass" -ne 1 ]]; then
        symbol_failed_tests=$((symbol_failed_tests + 1))
        failed_tests=$((failed_tests + 1))
        runtime_failures=$((runtime_failures + 1))
        summary "FAIL $runtime_symbol $test_name runtime missing_TEST_MARKER"
      else
        symbol_passed_tests=$((symbol_passed_tests + 1))
        passed_tests=$((passed_tests + 1))
        summary "PASS $runtime_symbol $test_name runtime"
      fi
    done

    summary "SYMBOL_TOTAL symbol=$runtime_symbol passed=$symbol_passed_tests failed=$symbol_failed_tests"
    summary ""
  done
fi

compile_tests_passed=0
compile_tests_failed=0
for test_name in "${TEST_NAMES[@]}"; do
  if [[ "${TEST_STATUS[$test_name]+set}" == "set" && "${TEST_STATUS[$test_name]}" == "FAIL" ]]; then
    compile_tests_failed=$((compile_tests_failed + 1))
  else
    compile_tests_passed=$((compile_tests_passed + 1))
  fi
done

executed_symbol_count=0
total_test_executions=0
if [[ "$COMPILE_ONLY" -ne 1 ]]; then
  executed_symbol_count=${#RUN_SYMBOLS[@]}
  total_test_executions=$(( ${#RUN_SYMBOLS[@]} * ${#TEST_NAMES[@]} ))
fi

summary "[TOTAL]"
summary "SYMBOL_COUNT=$executed_symbol_count"
summary "TOTAL_TEST_EXECUTIONS=$total_test_executions"
summary "COMPILE_TESTS_PASSED=$compile_tests_passed"
summary "COMPILE_TESTS_FAILED=$compile_tests_failed"
summary "PASSED=$passed_tests"
summary "FAILED=$failed_tests"
summary "COMPILE_FAILURES=$compile_failures"
summary "RUNTIME_FAILURES=$runtime_failures"
summary "COMPILE_LOG_DIR=$COMPILE_DIR"
summary "RUNTIME_LOG_DIR=$RUNTIME_DIR"

if [[ "$COMPILE_ONLY" -eq 1 ]]; then
  if [[ "$compile_failures" -gt 0 ]]; then
    summary "SUITE=FAIL"
    log "Suite result: FAIL (compile-only, failures=$compile_failures)"
    exit 1
  fi

  summary "SUITE=PASS"
  log "Suite result: PASS (compile-only, tests=${#TEST_NAMES[@]} harness_compile=strict)"
  exit 0
fi

if [[ "$failed_tests" -gt 0 ]]; then
  summary "SUITE=FAIL"
  log "Suite result: FAIL ($failed_tests/$(( ${#RUN_SYMBOLS[@]} * ${#TEST_NAMES[@]} )) failed)"
  exit 1
fi

summary "SUITE=PASS"
log "Suite result: PASS ($passed_tests/$(( ${#RUN_SYMBOLS[@]} * ${#TEST_NAMES[@]} )) passed)"
