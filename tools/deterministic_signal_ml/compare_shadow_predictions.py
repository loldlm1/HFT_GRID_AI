"""Compare MQL5 shadow/filter predictions against the Python artifact scorer."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np

from model_artifact_contract import DEFAULT_EXPORT_ROOT
from model_artifact_validator import (
    ModelArtifactValidationError,
    encode_rows,
    read_feature_map,
    score_classifier,
    score_regressor,
    validate_export_artifact,
)
from schema_contract import MODEL_FEATURE_COLUMNS, NULL_TOKEN


DEFAULT_CLASSIFIER_TOLERANCE = 1e-6
DEFAULT_REGRESSOR_TOLERANCE = 1e-6


class ShadowPredictionComparisonError(RuntimeError):
    """Raised when shadow prediction parity cannot be established."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    export_group = parser.add_mutually_exclusive_group(required=True)
    export_group.add_argument("--export-id", help="Export ID under --export-root.")
    export_group.add_argument("--export-path", help="Explicit model export folder.")
    parser.add_argument("--export-root", default=DEFAULT_EXPORT_ROOT, help="Root for --export-id.")
    parser.add_argument("--shadow-run-path", required=True, help="Folder containing shadow_predictions.tsv.")
    parser.add_argument(
        "--classifier-tolerance",
        type=float,
        default=DEFAULT_CLASSIFIER_TOLERANCE,
        help="Maximum allowed classifier absolute error.",
    )
    parser.add_argument(
        "--regressor-tolerance",
        type=float,
        default=DEFAULT_REGRESSOR_TOLERANCE,
        help="Maximum allowed regressor absolute error.",
    )
    parser.add_argument("--max-failures", type=int, default=5, help="Failure examples to print.")
    return parser


def resolve_export_path(args: argparse.Namespace) -> Path:
    export_path = Path(args.export_path) if args.export_path else Path(args.export_root) / args.export_id
    if not export_path.is_dir():
        raise ShadowPredictionComparisonError(f"Export folder does not exist: {export_path}")
    return export_path


def read_shadow_predictions(shadow_run_path: Path) -> list[dict[str, str]]:
    path = shadow_run_path / "shadow_predictions.tsv"
    if not path.exists():
        raise ShadowPredictionComparisonError(f"Missing shadow predictions: {path}")
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows:
        raise ShadowPredictionComparisonError("No shadow prediction rows found")
    missing_columns = [column for column in MODEL_FEATURE_COLUMNS if column not in rows[0]]
    if missing_columns:
        raise ShadowPredictionComparisonError("Missing feature columns: " + ", ".join(missing_columns))
    required_score_columns = ("signal_id", "classifier_score", "threshold_probability", "recommendation")
    missing_score_columns = [column for column in required_score_columns if column not in rows[0]]
    if missing_score_columns:
        raise ShadowPredictionComparisonError("Missing score columns: " + ", ".join(missing_score_columns))
    return rows


def is_scored(row: dict[str, str]) -> bool:
    score = row.get("classifier_score", "")
    return score not in ("", NULL_TOKEN)


def normalize_feature_rows(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    normalized: list[dict[str, object]] = []
    for row in rows:
        output: dict[str, object] = {}
        for column in MODEL_FEATURE_COLUMNS:
            value = row.get(column, "")
            if value == NULL_TOKEN:
                output[column] = None
            else:
                output[column] = value
        normalized.append(output)
    return normalized


def compare_scores(
    rows: list[dict[str, str]],
    expected_classifier: np.ndarray,
    expected_regressor: np.ndarray | None,
    classifier_tolerance: float,
    regressor_tolerance: float,
    max_failures: int,
) -> dict[str, object]:
    classifier_errors: list[float] = []
    regressor_errors: list[float] = []
    decision_matches = 0
    failures: list[str] = []

    for index, row in enumerate(rows):
        signal_id = row.get("signal_id", f"row_{index}")
        actual_classifier = float(row["classifier_score"])
        classifier_error = abs(actual_classifier - float(expected_classifier[index]))
        classifier_errors.append(classifier_error)
        threshold = float(row["threshold_probability"])
        expected_recommendation = "ALLOW" if float(expected_classifier[index]) >= threshold else "BLOCK"
        if row.get("recommendation") == expected_recommendation:
            decision_matches += 1
        elif len(failures) < max_failures:
            failures.append(
                f"{signal_id}: recommendation actual={row.get('recommendation')} expected={expected_recommendation}"
            )

        if classifier_error > classifier_tolerance and len(failures) < max_failures:
            failures.append(
                f"{signal_id}: classifier_error={classifier_error:.12g} "
                f"actual={actual_classifier:.12g} expected={float(expected_classifier[index]):.12g}"
            )

        regressor_value = row.get("regressor_score", "")
        if expected_regressor is not None and regressor_value not in ("", NULL_TOKEN):
            actual_regressor = float(regressor_value)
            regressor_error = abs(actual_regressor - float(expected_regressor[index]))
            regressor_errors.append(regressor_error)
            if regressor_error > regressor_tolerance and len(failures) < max_failures:
                failures.append(
                    f"{signal_id}: regressor_error={regressor_error:.12g} "
                    f"actual={actual_regressor:.12g} expected={float(expected_regressor[index]):.12g}"
                )

    classifier_max_error = max(classifier_errors) if classifier_errors else 0.0
    classifier_mean_error = float(np.mean(classifier_errors)) if classifier_errors else 0.0
    regressor_max_error = max(regressor_errors) if regressor_errors else None
    decision_agreement = decision_matches / len(rows) if rows else 0.0

    return {
        "row_count": len(rows),
        "classifier_max_error": classifier_max_error,
        "classifier_mean_error": classifier_mean_error,
        "regressor_max_error": regressor_max_error,
        "decision_agreement": decision_agreement,
        "failures": failures,
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        export_path = resolve_export_path(args)
        validate_export_artifact(export_path)
        rows = [row for row in read_shadow_predictions(Path(args.shadow_run_path)) if is_scored(row)]
        if not rows:
            raise ShadowPredictionComparisonError("No scored shadow prediction rows found")
        feature_map = read_feature_map(export_path)
        matrix = encode_rows(normalize_feature_rows(rows), feature_map)
        classifier_scores = score_classifier(export_path, matrix)
        regressor_scores: np.ndarray | None = None
        if any(row.get("regressor_score", "") not in ("", NULL_TOKEN) for row in rows):
            regressor_scores = score_regressor(export_path, matrix)
        report = compare_scores(
            rows,
            classifier_scores,
            regressor_scores,
            args.classifier_tolerance,
            args.regressor_tolerance,
            args.max_failures,
        )
    except (ModelArtifactValidationError, ShadowPredictionComparisonError, ValueError) as exc:
        parser.exit(1, f"shadow prediction comparison failed: {exc}\n")

    status = "PASS"
    if report["classifier_max_error"] > args.classifier_tolerance:
        status = "FAIL"
    if report["decision_agreement"] != 1.0:
        status = "FAIL"
    if report["regressor_max_error"] is not None and report["regressor_max_error"] > args.regressor_tolerance:
        status = "FAIL"
    if report["failures"]:
        status = "FAIL"

    print(
        "shadow prediction comparison "
        f"{status} | rows={report['row_count']} | "
        f"classifier_max_abs_error={report['classifier_max_error']:.12g} | "
        f"classifier_mean_abs_error={report['classifier_mean_error']:.12g} | "
        f"decision_agreement={report['decision_agreement']:.12g} | "
        f"regressor_max_abs_error={report['regressor_max_error']}"
    )
    for failure in report["failures"]:
        print("failure:", failure)
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
