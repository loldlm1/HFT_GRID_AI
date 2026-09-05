"""Small, explicit commands for the currently implemented service increment."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .archive import ArchiveKey, SourceError, inspect_archive, probe_archive
from .config import ConfigError, load_profile

DEFAULT_PROFILE = Path(__file__).parent / "profiles/xauusd_pro.example.toml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare and verify offline Exness tick history.")
    parser.add_argument("--config", type=Path, default=DEFAULT_PROFILE, help="Strict TOML profile")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("inspect-config", help="Validate and summarize configuration without writes or network")
    for name, help_text in (("probe-archive", "Probe one annual/monthly/daily ZIP URL without downloading its body"),
                            ("inspect-archive", "Verify one local source ZIP/CSV without changing it")):
        command = commands.add_parser(name, help=help_text)
        if name == "inspect-archive":
            command.add_argument("path", type=Path)
        command.add_argument("--year", type=int, required=True)
        command.add_argument("--month", type=int)
        command.add_argument("--day", type=int)
    args = parser.parse_args(argv)
    try:
        profile = load_profile(args.config)
        if args.command == "inspect-config":
            result = profile.summary()
        else:
            key = ArchiveKey(profile.instrument.archive_symbol, args.year, args.month, args.day)
            if args.command == "probe-archive":
                result = probe_archive(key, profile.network).summary()
            else:
                result = inspect_archive(args.path, key, profile.limits)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result.get("state", "AVAILABLE_CANDIDATE") == "AVAILABLE_CANDIDATE" else 3
    except ConfigError as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        return 2
    except SourceError as exc:
        print(f"Source contract error: {exc}", file=sys.stderr)
        return 3
    except KeyboardInterrupt:
        print("Interrupted; no completed dataset was published.", file=sys.stderr)
        return 130
