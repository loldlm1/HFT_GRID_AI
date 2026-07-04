"""Read and score deterministic signal model export artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from model_artifact_contract import (
    CLASSIFIER_TREES_TSV,
    DEFAULT_EXPORT_ROOT,
    FEATURE_MAP_TSV,
    MANIFEST_TSV_COLUMNS,
    MODEL_MANIFEST_JSON,
    MODEL_MANIFEST_TSV,
    PARITY_REPORT_JSON,
    REGRESSOR_TREES_TSV,
    REQUIRED_MANIFEST_KEYS,
    THRESHOLD_POLICY_COLUMNS,
    THRESHOLD_POLICY_TSV,
    TREE_COLUMNS,
)


class ModelArtifactValidationError(RuntimeError):
    """Raised when exported model artifacts cannot be read or scored."""


@dataclass(frozen=True)
class TreeNode:
    node_index: int
    node_type: str
    feature_index: int | None
    threshold: float | None
    left_child: int | None
    right_child: int | None
    default_left: bool
    leaf_value: float | None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    export_group = parser.add_mutually_exclusive_group(required=True)
    export_group.add_argument("--export-id", help="Export ID under the export root.")
    export_group.add_argument("--export-path", help="Explicit export folder.")
    parser.add_argument("--export-root", default=DEFAULT_EXPORT_ROOT, help="Root for --export-id.")
    return parser


def resolve_export_path(args: argparse.Namespace) -> Path:
    export_path = Path(args.export_path) if args.export_path else Path(args.export_root) / args.export_id
    if not export_path.exists():
        raise ModelArtifactValidationError(f"Export folder does not exist: {export_path}")
    if not export_path.is_dir():
        raise ModelArtifactValidationError(f"Export path is not a folder: {export_path}")
    return export_path


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def read_manifest(export_path: Path) -> dict[str, str]:
    rows = read_tsv(export_path / MODEL_MANIFEST_TSV)
    if rows and tuple(rows[0].keys()) != MANIFEST_TSV_COLUMNS:
        raise ModelArtifactValidationError(f"Bad manifest header: {export_path / MODEL_MANIFEST_TSV}")
    return {row["key"]: row["value"] for row in rows}


def read_feature_map(export_path: Path) -> list[dict[str, str]]:
    rows = read_tsv(export_path / FEATURE_MAP_TSV)
    for expected_index, row in enumerate(rows):
        if int(row["encoded_index"]) != expected_index:
            raise ModelArtifactValidationError("Feature map indices are not contiguous")
    return rows


def read_tree_rows(path: Path) -> list[dict[str, str]]:
    rows = read_tsv(path)
    if rows and tuple(rows[0].keys()) != TREE_COLUMNS:
        raise ModelArtifactValidationError(f"Bad tree TSV header: {path}")
    return rows


def validate_export_artifact(export_path: Path) -> dict[str, object]:
    required_files = (
        MODEL_MANIFEST_TSV,
        MODEL_MANIFEST_JSON,
        FEATURE_MAP_TSV,
        CLASSIFIER_TREES_TSV,
        REGRESSOR_TREES_TSV,
        THRESHOLD_POLICY_TSV,
        PARITY_REPORT_JSON,
    )
    missing = [filename for filename in required_files if not (export_path / filename).exists()]
    if missing:
        raise ModelArtifactValidationError("Export is missing required files: " + ", ".join(missing))

    manifest = read_manifest(export_path)
    missing_keys = [key for key in REQUIRED_MANIFEST_KEYS if key not in manifest]
    if missing_keys:
        raise ModelArtifactValidationError("Manifest missing required keys: " + ", ".join(missing_keys))

    feature_map_rows = read_feature_map(export_path)
    encoded_feature_count = int(manifest["encoded_feature_count"])
    if len(feature_map_rows) != encoded_feature_count:
        raise ModelArtifactValidationError(
            f"Feature count mismatch: manifest={encoded_feature_count} map={len(feature_map_rows)}"
        )

    classifier_rows = read_tree_rows(export_path / CLASSIFIER_TREES_TSV)
    regressor_rows = read_tree_rows(export_path / REGRESSOR_TREES_TSV)
    classifier_tree_count = _validate_tree_references(
        classifier_rows,
        "classifier",
        encoded_feature_count,
    )
    regressor_tree_count = _validate_tree_references(
        regressor_rows,
        "regressor",
        encoded_feature_count,
    )
    if classifier_tree_count != int(manifest["classifier_tree_count"]):
        raise ModelArtifactValidationError("Classifier tree count does not match manifest")
    if regressor_tree_count != int(manifest["regressor_tree_count"]):
        raise ModelArtifactValidationError("Regressor tree count does not match manifest")

    threshold_rows = read_tsv(export_path / THRESHOLD_POLICY_TSV)
    if threshold_rows and tuple(threshold_rows[0].keys()) != THRESHOLD_POLICY_COLUMNS:
        raise ModelArtifactValidationError(f"Bad threshold policy header: {THRESHOLD_POLICY_TSV}")
    if not threshold_rows:
        raise ModelArtifactValidationError("Threshold policy has no rows")
    if threshold_rows[0]["research_only"] != "true":
        raise ModelArtifactValidationError("Threshold policy must be research_only=true")

    parity_report = json.loads((export_path / PARITY_REPORT_JSON).read_text(encoding="utf-8"))
    if parity_report.get("status") != "OK":
        raise ModelArtifactValidationError("Parity report status is not OK")

    return {
        "status": "OK",
        "export_id": manifest.get("export_id", export_path.name),
        "model_id": manifest.get("model_id", ""),
        "dataset_id": manifest.get("dataset_id", ""),
        "encoded_feature_count": encoded_feature_count,
        "classifier_tree_count": classifier_tree_count,
        "regressor_tree_count": regressor_tree_count,
        "parity_status": parity_report.get("status"),
        "mt5_runtime_ready": manifest.get("mt5_runtime_ready"),
        "research_only": manifest.get("research_only"),
    }


def _validate_tree_references(
    rows: list[dict[str, str]],
    model_role: str,
    feature_count: int,
) -> int:
    trees = _build_trees(rows, model_role)
    for tree_index, tree in enumerate(trees):
        if 0 not in tree:
            raise ModelArtifactValidationError(f"{model_role} tree {tree_index} is missing root")
        for node in tree.values():
            if node.node_type == "leaf":
                if node.leaf_value is None:
                    raise ModelArtifactValidationError(f"{model_role} leaf missing value")
                continue
            if node.feature_index is None or node.feature_index < 0 or node.feature_index >= feature_count:
                raise ModelArtifactValidationError(f"{model_role} split feature index is invalid")
            if node.threshold is None:
                raise ModelArtifactValidationError(f"{model_role} split threshold is missing")
            if node.left_child not in tree or node.right_child not in tree:
                raise ModelArtifactValidationError(f"{model_role} split child reference is invalid")
    return len(trees)


def encode_rows(rows: list[dict[str, Any]], feature_map_rows: list[dict[str, str]]) -> np.ndarray:
    matrix = np.zeros((len(rows), len(feature_map_rows)), dtype=np.float64)
    for row_index, row in enumerate(rows):
        for feature in feature_map_rows:
            output_index = int(feature["encoded_index"])
            source_column = feature["source_column"]
            if feature["encoding_type"] == "numeric":
                value = row.get(source_column)
                matrix[row_index, output_index] = np.nan if value is None else float(value)
            elif feature["encoding_type"] == "one_hot":
                raw_value = row.get(source_column)
                category = feature["category"]
                if raw_value is None or raw_value == "":
                    matrix[row_index, output_index] = 1.0 if category == "__MISSING__" else 0.0
                else:
                    matrix[row_index, output_index] = 1.0 if str(raw_value) == category else 0.0
            else:
                raise ModelArtifactValidationError(
                    f"Unknown feature encoding type: {feature['encoding_type']}"
                )
    return matrix


def score_classifier(export_path: Path, matrix: np.ndarray) -> np.ndarray:
    manifest = read_manifest(export_path)
    tree_rows = read_tree_rows(export_path / CLASSIFIER_TREES_TSV)
    margins = score_margin(
        matrix,
        tree_rows,
        base_score=float(manifest["classifier_base_score"]),
        model_role="classifier",
    )
    return 1.0 / (1.0 + np.exp(-margins))


def score_regressor(export_path: Path, matrix: np.ndarray) -> np.ndarray:
    manifest = read_manifest(export_path)
    tree_rows = read_tree_rows(export_path / REGRESSOR_TREES_TSV)
    return score_margin(
        matrix,
        tree_rows,
        base_score=float(manifest["regressor_base_score"]),
        model_role="regressor",
    )


def score_margin(
    matrix: np.ndarray,
    tree_rows: list[dict[str, str]],
    base_score: float,
    model_role: str,
) -> np.ndarray:
    trees = _build_trees(tree_rows, model_role)
    output = np.full(matrix.shape[0], base_score, dtype=np.float64)
    for row_index in range(matrix.shape[0]):
        features = matrix[row_index]
        value = base_score
        for tree in trees:
            value += _score_tree(tree, features)
        output[row_index] = value
    return output


def _build_trees(rows: list[dict[str, str]], model_role: str) -> list[dict[int, TreeNode]]:
    grouped: dict[int, dict[int, TreeNode]] = {}
    for row in rows:
        if row["model_role"] != model_role:
            continue
        tree_index = int(row["tree_index"])
        node_index = int(row["node_index"])
        grouped.setdefault(tree_index, {})[node_index] = TreeNode(
            node_index=node_index,
            node_type=row["node_type"],
            feature_index=_optional_int(row["feature_index"]),
            threshold=_optional_float(row["threshold"]),
            left_child=_optional_int(row["left_child"]),
            right_child=_optional_int(row["right_child"]),
            default_left=row["default_left"] == "1",
            leaf_value=_optional_float(row["leaf_value"]),
        )

    if not grouped:
        raise ModelArtifactValidationError(f"No tree rows found for model role: {model_role}")
    return [grouped[index] for index in sorted(grouped)]


def _score_tree(tree: dict[int, TreeNode], features: np.ndarray) -> float:
    node = tree.get(0)
    if node is None:
        raise ModelArtifactValidationError("Tree is missing root node 0")
    while node.node_type != "leaf":
        if node.feature_index is None or node.threshold is None:
            raise ModelArtifactValidationError(f"Split node is incomplete: {node.node_index}")
        value = np.float32(features[node.feature_index])
        threshold = np.float32(node.threshold)
        if math.isnan(value):
            next_index = node.left_child if node.default_left else node.right_child
        elif value < threshold:
            next_index = node.left_child
        else:
            next_index = node.right_child
        if next_index is None or next_index not in tree:
            raise ModelArtifactValidationError(f"Tree child reference is invalid: {node.node_index}")
        node = tree[next_index]
    if node.leaf_value is None:
        raise ModelArtifactValidationError(f"Leaf node is missing value: {node.node_index}")
    return node.leaf_value


def _optional_int(value: str) -> int | None:
    if value == "":
        return None
    return int(value)


def _optional_float(value: str) -> float | None:
    if value == "":
        return None
    return float(value)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        export_path = resolve_export_path(args)
        report = validate_export_artifact(export_path)
    except ModelArtifactValidationError as exc:
        parser.exit(1, f"model artifact validation failed: {exc}\n")

    print(
        "model artifact validation ok | "
        f"export_id={report['export_id']} | "
        f"model_id={report['model_id']} | "
        f"dataset_id={report['dataset_id']} | "
        f"encoded_features={report['encoded_feature_count']} | "
        f"classifier_trees={report['classifier_tree_count']} | "
        f"regressor_trees={report['regressor_tree_count']} | "
        f"mt5_runtime_ready={report['mt5_runtime_ready']} | "
        f"research_only={report['research_only']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
