"""Build local deterministic signal datasets from Phase 1 TSV exports."""

from __future__ import annotations

import argparse
from pathlib import Path

from validate_phase1_run import Phase1ValidationError, validate_phase1_runs


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs-root", required=True, help="Folder containing Phase 1 run folders.")
    parser.add_argument("--run-id", action="append", required=True, help="Run ID to include. Repeat for multiple runs.")
    parser.add_argument("--dataset-id", required=True, help="Dataset output ID.")
    parser.add_argument("--output-root", default="artifacts/datasets", help="Dataset output root.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing dataset folder.")
    parser.add_argument("--validate-only", action="store_true", help="Validate inputs without writing Parquet files.")
    parser.add_argument(
        "--allow-mixed-config",
        action="store_true",
        help="Allow multiple config_id values across selected runs.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        validations = validate_phase1_runs(
            Path(args.runs_root),
            args.run_id,
            allow_mixed_config=args.allow_mixed_config,
        )
    except Phase1ValidationError as exc:
        parser.exit(1, f"validation failed: {exc}\n")

    total_features = sum(validation.feature_rows for validation in validations)
    total_outcomes = sum(validation.outcome_rows for validation in validations)
    total_joined = sum(validation.joined_rows for validation in validations)
    print(
        "validation ok | "
        f"runs={len(validations)} | "
        f"features={total_features} | "
        f"outcomes={total_outcomes} | "
        f"joined={total_joined}"
    )
    for validation in validations:
        for warning in validation.warnings:
            print(f"warning [{validation.run_id}]: {warning}")

    if args.validate_only:
        return 0

    parser.error("Dataset build implementation starts in Sprint 3.")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
