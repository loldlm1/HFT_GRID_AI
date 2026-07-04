"""Run MetaEditor compile/syntax checks and parse compact status.

This helper is intentionally small and stdlib-only. It does not run Strategy
Tester and does not replace human-in-the-loop tester/chart validation.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Sequence


STATUS_RE = re.compile(r"(?P<errors>\d+)\s+errors?,\s+(?P<warnings>\d+)\s+warnings?", re.IGNORECASE)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mt5-root", default=os.environ.get("MT5_ROOT"), help="MetaTrader 5 root folder.")
    parser.add_argument("--entrypoint", help="EA entrypoint .mq5 path.")
    parser.add_argument("--log", help="MetaEditor log output path.")
    parser.add_argument("--mode", choices=("compile", "syntax"), default="compile")
    parser.add_argument("--wine", action="store_true", help="Run MetaEditor through Wine.")
    parser.add_argument("--timeout", type=int, default=180, help="MetaEditor timeout in seconds.")
    parser.add_argument("--no-portable", action="store_true", help="Do not pass /portable.")
    return parser


def require_path(value: str | None, label: str) -> Path:
    if not value:
        raise SystemExit(f"Missing required {label}. Pass --{label.replace('_', '-')} or set MT5_ROOT.")
    return Path(value).expanduser()


def default_entrypoint(mt5_root: Path) -> Path:
    return mt5_root / "MQL5" / "Experts" / "HFT_Grid_AI" / "HFT_Grid_AI.mq5"


def default_log(entrypoint: Path, mode: str) -> Path:
    return entrypoint.parent / "logs" / "compile" / f"agentic-{mode}.log"


def winepath(path: Path) -> str:
    result = subprocess.run(
        ["winepath", "-w", str(path)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def read_text_best_effort(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-16", "utf-8-sig", "utf-8", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def final_status_line(text: str) -> tuple[str | None, int | None, int | None]:
    last_line = None
    last_errors = None
    last_warnings = None
    for line in text.splitlines():
        match = STATUS_RE.search(line)
        if not match:
            continue
        last_line = line.strip()
        last_errors = int(match.group("errors"))
        last_warnings = int(match.group("warnings"))
    return last_line, last_errors, last_warnings


def compact_failure_lines(text: str) -> list[str]:
    lines = []
    for line in text.splitlines():
        lowered = line.lower()
        if (" error" in lowered or " warning" in lowered) and not STATUS_RE.search(line):
            lines.append(line.strip())
    return lines[-8:]


def command_for(args: argparse.Namespace, mt5_root: Path, entrypoint: Path, log_path: Path) -> list[str]:
    metaeditor = mt5_root / "MetaEditor64.exe"
    if args.wine:
        command = ["wine", str(metaeditor)]
        entry_arg = winepath(entrypoint)
        log_arg = winepath(log_path)
    else:
        command = [str(metaeditor)]
        entry_arg = str(entrypoint)
        log_arg = str(log_path)

    if not args.no_portable:
        command.append("/portable")
    if args.mode == "syntax":
        command.append("/s")
    command.append(f"/compile:{entry_arg}")
    command.append(f"/log:{log_arg}")
    return command


def run_command(command: Sequence[str], timeout: int) -> int:
    try:
        result = subprocess.run(command, timeout=timeout)
        return int(result.returncode)
    except subprocess.TimeoutExpired:
        return 124


def main() -> int:
    args = build_parser().parse_args()
    mt5_root = require_path(args.mt5_root, "mt5_root")
    entrypoint = Path(args.entrypoint).expanduser() if args.entrypoint else default_entrypoint(mt5_root)
    log_path = Path(args.log).expanduser() if args.log else default_log(entrypoint, args.mode)

    if not entrypoint.exists():
        print(f"entrypoint_missing={entrypoint}")
        return 2

    log_path.parent.mkdir(parents=True, exist_ok=True)
    command = command_for(args, mt5_root, entrypoint, log_path)
    process_code = run_command(command, args.timeout)

    if not log_path.exists():
        print(f"mode={args.mode}")
        print(f"process_returncode={process_code}")
        print(f"log_missing={log_path}")
        return 1

    log_text = read_text_best_effort(log_path)
    status_line, errors, warnings = final_status_line(log_text)
    success = errors == 0 and warnings == 0

    print(f"mode={args.mode}")
    print(f"process_returncode={process_code}")
    print(f"log={log_path}")
    if status_line:
        print(f"status={status_line}")
    else:
        print("status=missing")

    if not success:
        for line in compact_failure_lines(log_text):
            print(f"diagnostic={line}")
        print("result=FAIL")
        return 1

    print("result=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
