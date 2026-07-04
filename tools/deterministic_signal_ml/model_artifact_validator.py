"""Read and score deterministic signal model export artifacts."""

from __future__ import annotations

import csv
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from model_artifact_contract import (
    CLASSIFIER_TREES_TSV,
    FEATURE_MAP_TSV,
    MANIFEST_TSV_COLUMNS,
    MODEL_MANIFEST_TSV,
    REGRESSOR_TREES_TSV,
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
