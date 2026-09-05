"""Small, explicit commands for the currently implemented service increment."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .archive import ArchiveKey, SourceError, inspect_archive, inventory, probe_archive
from .config import ConfigError, load_profile
from .download import download_inventory
from .storage import Store, StorageError, atomic_json

DEFAULT_PROFILE = Path(__file__).parent / "profiles/xauusd_pro.example.toml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare and verify offline Exness tick history.")
    parser.add_argument("--config", type=Path, default=DEFAULT_PROFILE, help="Strict TOML profile")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("inspect-config", help="Validate and summarize configuration without writes or network")
    command = commands.add_parser("inventory", help="Freeze bounded archive discovery and interval ownership")
    command.add_argument("--start")
    command.add_argument("--end")
    command.add_argument("--granularity", choices=("auto", "year", "month", "day"))
    command = commands.add_parser("download", help="Download verified candidates with immutable source versions")
    command.add_argument("--inventory", required=True)
    command.add_argument("--resume", action="store_true", help="Reuse a validated owned partial object")
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
        elif args.command == "inventory":
            with Store(profile.data_root) as store:
                result = inventory(profile, start=args.start, end=args.end, granularity=args.granularity)
                atomic_json(store.path("runs", result["inventory_id"], "inventory.json"), result, immutable=True)
            result = {key: value for key, value in result.items() if key not in ("candidates", "owners", "feed")}
        elif args.command == "download":
            report = download_inventory(profile, args.inventory, resume=args.resume)
            result = {key: value for key, value in report.items() if key != "objects"}
            result["verified_archives"] = sum(item["state"] == "VERIFIED" for item in report["objects"])
            result["unresolved_archives"] = sum(item["state"] != "VERIFIED" for item in report["objects"])
        else:
            key = ArchiveKey(profile.instrument.archive_symbol, args.year, args.month, args.day)
            if args.command == "probe-archive":
                result = probe_archive(key, profile.network).summary()
            else:
                result = inspect_archive(args.path, key, profile.limits)
        print(json.dumps(result, indent=2, sort_keys=True))
        if result.get("status") == "DOWNLOAD_INCOMPLETE":
            return 3
        return 0 if result.get("state", "AVAILABLE_CANDIDATE") == "AVAILABLE_CANDIDATE" else 3
    except ConfigError as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        return 2
    except (SourceError, StorageError) as exc:
        print(f"Source contract error: {exc}", file=sys.stderr)
        return 3
    except OSError:
        print("Local I/O failed; check owned paths and available storage.", file=sys.stderr)
        return 3
    except KeyboardInterrupt:
        print("Interrupted; no completed dataset was published.", file=sys.stderr)
        return 130
