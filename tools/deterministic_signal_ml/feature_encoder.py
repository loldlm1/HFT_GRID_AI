"""Deterministic numeric and one-hot encoding for offline pivot research."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from schema_contract import CATEGORICAL_COLUMNS


MISSING_CATEGORY = "__MISSING__"


@dataclass(frozen=True)
class EncodedFeatures:
    matrix: np.ndarray
    encoded_feature_names: list[str]


@dataclass(frozen=True)
class FeatureEncoder:
    numeric_columns: list[str]
    categorical_columns: list[str]
    categories: dict[str, list[str]]
    encoded_feature_names: list[str]
    missing_category: str = MISSING_CATEGORY

    @classmethod
    def fit(
        cls,
        rows: list[dict[str, Any]],
        feature_columns: tuple[str, ...],
        categorical_columns: tuple[str, ...] | list[str] | None = None,
    ) -> "FeatureEncoder":
        if not rows:
            raise ValueError("Cannot fit feature encoder without rows")
        categorical_set = set(categorical_columns or CATEGORICAL_COLUMNS)
        if not categorical_set.issubset(set(feature_columns)):
            raise ValueError("Categorical feature list contains an unknown column")
        categorical_columns = [column for column in feature_columns if column in categorical_set]
        numeric_columns = [column for column in feature_columns if column not in categorical_set]
        categories: dict[str, list[str]] = {}
        for column in categorical_columns:
            values = {
                MISSING_CATEGORY
                if row.get(column) in (None, "")
                else str(row[column])
                for row in rows
            }
            values.add(MISSING_CATEGORY)
            categories[column] = sorted(values)

        encoded_feature_names = list(numeric_columns)
        for column in categorical_columns:
            encoded_feature_names.extend(
                f"{column}={category}" for category in categories[column]
            )
        return cls(
            numeric_columns=numeric_columns,
            categorical_columns=categorical_columns,
            categories=categories,
            encoded_feature_names=encoded_feature_names,
        )

    def transform(self, rows: list[dict[str, Any]]) -> EncodedFeatures:
        matrix = np.zeros((len(rows), len(self.encoded_feature_names)), dtype=np.float64)
        for row_index, row in enumerate(rows):
            output_index = 0
            for column in self.numeric_columns:
                value = row.get(column)
                matrix[row_index, output_index] = (
                    np.nan if value in (None, "") else float(value)
                )
                output_index += 1
            for column in self.categorical_columns:
                raw_value = row.get(column)
                category = (
                    self.missing_category
                    if raw_value in (None, "")
                    else str(raw_value)
                )
                known_categories = self.categories[column]
                if category not in known_categories:
                    category = self.missing_category
                for expected in known_categories:
                    matrix[row_index, output_index] = 1.0 if category == expected else 0.0
                    output_index += 1
        return EncodedFeatures(matrix=matrix, encoded_feature_names=self.encoded_feature_names)

    def to_dict(self) -> dict[str, Any]:
        return {
            "numeric_columns": self.numeric_columns,
            "categorical_columns": self.categorical_columns,
            "categories": self.categories,
            "encoded_feature_names": self.encoded_feature_names,
            "missing_category": self.missing_category,
        }

    def write_json(self, path: Path) -> None:
        path.write_text(
            json.dumps(self.to_dict(), indent=2, sort_keys=True),
            encoding="utf-8",
        )
