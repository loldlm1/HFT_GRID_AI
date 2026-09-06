"""Small, explicit commands for the currently implemented service increment."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .archive import ArchiveKey, SourceError, inspect_archive, inventory, probe_archive
from .config import ConfigError, load_profile
from .download import download_inventory
from .storage import Store, StorageError, atomic_json, feed_identity, object_hash, read_json
from .sanitize import build_dataset
from .report import audit_dataset, save_comparison, seasonal_report, seasonal_schedule
from .mt5_export import export_mt5
from .compare import compare_broker, compare_roundtrip, comparison_profile_hash

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
    command = commands.add_parser("build", help="Build exact ordered UTC-date Parquet partitions")
    command.add_argument("--inventory", required=True)
    command.add_argument("--dataset-id", required=True)
    command = commands.add_parser("audit", help="Verify partition bytes, logical hashes and row conservation")
    command.add_argument("--dataset-id", required=True)
    command = commands.add_parser("export-mt5", help="Prepare exact native tick chunks under verified spec/clock inputs")
    command.add_argument("--dataset-id", required=True)
    command.add_argument("--export-id", required=True)
    command.add_argument("--specification", type=Path, required=True)
    command.add_argument("--clock", type=Path, required=True)
    command.add_argument("--custom-symbol")
    command.add_argument("--chunk-rows", type=int, default=1_000_000)
    command = commands.add_parser("compare-roundtrip", help="Compare complete native re-export in exact tick order")
    command.add_argument("--export-id", required=True)
    command.add_argument("--native-export", type=Path, required=True)
    command.add_argument("--encoding", choices=("utf-8-sig", "utf-16", "ascii"), default="utf-8-sig")
    command.add_argument("--evidence", type=Path)
    command.add_argument("--comparison-id")
    command = commands.add_parser("compare-broker", help="Score one frozen broker day with complete native reference captures")
    command.add_argument("--dataset-id", required=True)
    command.add_argument("--reference", type=Path, required=True)
    command.add_argument("--roundtrip-report", type=Path)
    command.add_argument("--comparison-id")
    command = commands.add_parser("seasonal-schedule", help="Show deterministic winter/summer and US/UK transition candidates")
    command.add_argument("--year", type=int, required=True)
    command = commands.add_parser("seasonal-report", help="Require independent frozen winter/summer and transition results")
    command.add_argument("--year", type=int, required=True)
    command.add_argument("--comparisons", nargs="*", default=[])
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
            result["feed_sha256"] = object_hash(feed_identity(profile))
            result["comparison_profile_sha256"] = comparison_profile_hash(profile)
        elif args.command == "seasonal-schedule":
            result = seasonal_schedule(args.year)
        elif args.command == "seasonal-report":
            result = seasonal_report(profile, args.year, args.comparisons)
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
        elif args.command == "build":
            report = build_dataset(profile, args.inventory, args.dataset_id)
            result = {key: report[key] for key in ("dataset_id", "rows", "logical_sha256", "data_integrity")}
        elif args.command == "audit":
            result = audit_dataset(profile, args.dataset_id)
        elif args.command == "export-mt5":
            report = export_mt5(profile, args.dataset_id, args.export_id, read_json(args.specification), read_json(args.clock),
                                custom_symbol=args.custom_symbol, chunk_rows=args.chunk_rows)
            result = {key: report[key] for key in ("export_id", "custom_symbol", "rows", "ordered_quote_sha256", "data_integrity", "mt5_round_trip")}
            result["chunk_count"] = len(report["chunks"])
        elif args.command == "compare-roundtrip":
            result = compare_roundtrip(profile, args.export_id, args.native_export, encoding=args.encoding,
                                       evidence=read_json(args.evidence) if args.evidence else None,
                                       evidence_root=args.evidence.parent if args.evidence else None)
            result = save_comparison(profile, result, args.comparison_id)
        elif args.command == "compare-broker":
            result = compare_broker(profile, args.dataset_id, args.reference,
                                    roundtrip=read_json(args.roundtrip_report) if args.roundtrip_report else None)
            result = save_comparison(profile, result, args.comparison_id)
        else:
            key = ArchiveKey(profile.instrument.archive_symbol, args.year, args.month, args.day)
            if args.command == "probe-archive":
                result = probe_archive(key, profile.network).summary()
            else:
                result = inspect_archive(args.path, key, profile.limits)
        if args.command == "compare-broker":
            summary = {key: result[key] for key in ("comparison_id", "broker_comparison", "gates", "unresolved")}
            print(json.dumps(summary, indent=2, sort_keys=True))
        else:
            print(json.dumps(result, indent=2, sort_keys=True))
        if args.command == "compare-roundtrip":
            return {"PASS": 0, "FAIL": 3, "INCONCLUSIVE": 4}[result["mt5_round_trip"]]
        if args.command == "compare-broker":
            return {"PASS": 0, "FAIL": 3, "INCONCLUSIVE": 4}[result["broker_comparison"]]
        if args.command == "seasonal-report":
            return {"PASS": 0, "FAIL": 3, "INCONCLUSIVE": 4}[result["seasonal_acceptance"]]
        if result.get("data_integrity") in ("FAIL", "INCONCLUSIVE"):
            return 3 if result["data_integrity"] == "FAIL" else 4
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
    except ImportError:
        print("A required package is unavailable; install the service requirements.", file=sys.stderr)
        return 2
    except Exception as exc:
        if type(exc).__module__ in ("duckdb", "_duckdb"):
            print(f"Dataset engine failed ({type(exc).__name__}); check memory/spill limits and artifact integrity.", file=sys.stderr)
            return 3
        raise
    except KeyboardInterrupt:
        print("Interrupted; no completed dataset was published.", file=sys.stderr)
        return 130
