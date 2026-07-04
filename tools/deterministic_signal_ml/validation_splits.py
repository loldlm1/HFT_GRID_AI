"""Chronological split policy for deterministic signal model validation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sklearn.model_selection import TimeSeriesSplit


@dataclass(frozen=True)
class FoldSplit:
    fold_index: int
    train_indices: list[int]
    test_indices: list[int]
    metadata: dict[str, Any]


@dataclass(frozen=True)
class SplitBundle:
    train_indices: list[int]
    holdout_indices: list[int]
    folds: list[FoldSplit]
    metadata: dict[str, Any]


def _entry_time(row: dict[str, Any]) -> str:
    return str(row.get("entry_time", ""))


def _range_metadata(rows: list[dict[str, Any]], indices: list[int]) -> dict[str, Any]:
    if not indices:
        return {
            "row_count": 0,
            "start_index": None,
            "end_index": None,
            "entry_time_start": None,
            "entry_time_end": None,
        }
    return {
        "row_count": len(indices),
        "start_index": indices[0],
        "end_index": indices[-1],
        "entry_time_start": _entry_time(rows[indices[0]]),
        "entry_time_end": _entry_time(rows[indices[-1]]),
    }


def _assert_chronological(rows: list[dict[str, Any]]) -> None:
    previous = ""
    for index, row in enumerate(rows):
        current = _entry_time(row)
        if current < previous:
            raise ValueError(f"Rows are not sorted by entry_time at row index {index}")
        previous = current


def _entry_time_groups(rows: list[dict[str, Any]]) -> list[tuple[str, list[int]]]:
    groups: list[tuple[str, list[int]]] = []
    current_time = ""
    current_indices: list[int] = []
    for index, row in enumerate(rows):
        entry_time = _entry_time(row)
        if not current_indices:
            current_time = entry_time
            current_indices.append(index)
            continue
        if entry_time == current_time:
            current_indices.append(index)
        else:
            groups.append((current_time, current_indices))
            current_time = entry_time
            current_indices = [index]
    if current_indices:
        groups.append((current_time, current_indices))
    return groups


def _expand_group_indices(groups: list[tuple[str, list[int]]], positions: list[int]) -> list[int]:
    indices: list[int] = []
    for position in positions:
        indices.extend(groups[position][1])
    return indices


def _split_holdout_groups(
    groups: list[tuple[str, list[int]]],
    target_holdout_rows: int,
) -> tuple[list[tuple[str, list[int]]], list[tuple[str, list[int]]]]:
    holdout_start = len(groups)
    holdout_rows = 0
    while holdout_start > 0 and holdout_rows < target_holdout_rows:
        holdout_start -= 1
        holdout_rows += len(groups[holdout_start][1])
    return groups[:holdout_start], groups[holdout_start:]


def build_time_splits(
    rows: list[dict[str, Any]],
    holdout_fraction: float,
    n_splits: int,
    gap: int,
) -> SplitBundle:
    if not 0.0 < holdout_fraction < 1.0:
        raise ValueError(f"holdout_fraction must be between 0 and 1: {holdout_fraction}")
    if n_splits < 2:
        raise ValueError(f"n_splits must be at least 2: {n_splits}")
    if gap < 0:
        raise ValueError(f"gap cannot be negative: {gap}")

    _assert_chronological(rows)
    row_count = len(rows)
    holdout_count = max(1, int(round(row_count * holdout_fraction)))
    entry_groups = _entry_time_groups(rows)
    train_groups, holdout_groups = _split_holdout_groups(entry_groups, holdout_count)
    if len(train_groups) <= n_splits + gap:
        raise ValueError(
            "Not enough pre-holdout entry_time groups for "
            f"{n_splits} splits and gap {gap}: {len(train_groups)}"
        )

    train_indices = _expand_group_indices(train_groups, list(range(len(train_groups))))
    holdout_indices = _expand_group_indices(holdout_groups, list(range(len(holdout_groups))))
    splitter = TimeSeriesSplit(n_splits=n_splits, gap=gap)

    folds: list[FoldSplit] = []
    for fold_index, (local_train, local_test) in enumerate(
        splitter.split(list(range(len(train_groups)))), start=1
    ):
        fold_train = _expand_group_indices(train_groups, [int(index) for index in local_train])
        fold_test = _expand_group_indices(train_groups, [int(index) for index in local_test])
        folds.append(
            FoldSplit(
                fold_index=fold_index,
                train_indices=fold_train,
                test_indices=fold_test,
                metadata={
                    "fold_index": fold_index,
                    "train": _range_metadata(rows, fold_train),
                    "test": _range_metadata(rows, fold_test),
                },
            )
        )

    metadata = {
        "policy": "chronological_holdout_plus_walk_forward",
        "holdout_fraction": holdout_fraction,
        "holdout_target_rows": holdout_count,
        "walk_forward_splits": n_splits,
        "walk_forward_gap": gap,
        "row_count": row_count,
        "unique_entry_times": len(entry_groups),
        "train": _range_metadata(rows, train_indices),
        "holdout": _range_metadata(rows, holdout_indices),
        "folds": [fold.metadata for fold in folds],
    }
    return SplitBundle(
        train_indices=train_indices,
        holdout_indices=holdout_indices,
        folds=folds,
        metadata=metadata,
    )
