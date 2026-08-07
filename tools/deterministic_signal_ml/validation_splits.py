"""Purged chronological splits grouped by Macro window across duplicate runs."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sklearn.model_selection import TimeSeriesSplit


GROUPING_POLICY = "macro_window_identity_across_runs"
ORIGIN_WEIGHT_POLICY = "sum_to_one_per_origin_within_subset"


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


@dataclass(frozen=True)
class _IdentityGroup:
    key: tuple[str, ...]
    first_time: datetime
    indices: list[int]


def _parse_time(value: Any, column: str) -> datetime:
    if isinstance(value, datetime):
        return value
    if value in (None, ""):
        raise ValueError(f"Training row lacks {column}")
    text = str(value)
    for pattern in ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M:%S"):
        try:
            return datetime.strptime(text[:19], pattern)
        except ValueError:
            continue
    raise ValueError(f"Invalid {column}: {value}")


def _trigger_time(row: dict[str, Any]) -> datetime:
    value = row.get("declared_broker_time", row.get("trigger_broker_time"))
    return _parse_time(value, "declared_broker_time")


def _close_time(row: dict[str, Any]) -> datetime:
    value = row.get("terminal_broker_time", row.get("close_broker_time"))
    return _parse_time(value, "terminal_broker_time")


def origin_balanced_weights(
    rows: list[dict[str, Any]],
    indices: list[int],
) -> list[float]:
    counts: dict[str, int] = {}
    for index in indices:
        origin_id = rows[index].get("origin_id")
        if origin_id in (None, ""):
            raise ValueError("Training row lacks origin_id for sample weighting")
        key = str(origin_id)
        counts[key] = counts.get(key, 0) + 1
    return [1.0 / counts[str(rows[index]["origin_id"])] for index in indices]


def _identity_key(row: dict[str, Any], grouping_policy: str) -> tuple[str, ...]:
    if grouping_policy != GROUPING_POLICY:
        raise ValueError(f"Unsupported grouping policy: {grouping_policy}")
    research_group_id = row.get("research_group_id")
    if research_group_id not in (None, ""):
        return (str(research_group_id),)
    values = (
        row.get("symbol"),
        row.get("macro_timeframe"),
        row.get("active_bar_open_broker_time"),
    )
    if any(value in (None, "") for value in values):
        raise ValueError("Training row lacks Macro window grouping facts")
    return tuple(str(value) for value in values)


def _groups(rows: list[dict[str, Any]], grouping_policy: str) -> list[_IdentityGroup]:
    grouped: dict[tuple[str, ...], list[int]] = {}
    for index, row in enumerate(rows):
        grouped.setdefault(_identity_key(row, grouping_policy), []).append(index)
    groups = [
        _IdentityGroup(
            key=key,
            first_time=min(_trigger_time(rows[index]) for index in indices),
            indices=indices,
        )
        for key, indices in grouped.items()
    ]
    groups.sort(key=lambda group: (group.first_time, group.key))
    return groups


def _expand(groups: list[_IdentityGroup], group_indices: list[int]) -> list[int]:
    return sorted(index for group_index in group_indices for index in groups[group_index].indices)


def _purge_closed_after(
    rows: list[dict[str, Any]],
    indices: list[int],
    boundary: datetime,
) -> list[int]:
    return [index for index in indices if _close_time(rows[index]) < boundary]


def _range_metadata(
    rows: list[dict[str, Any]],
    indices: list[int],
    grouping_policy: str,
) -> dict[str, Any]:
    if not indices:
        return {
            "row_count": 0,
            "group_count": 0,
            "first_trigger_time": None,
            "last_trigger_time": None,
        }
    times = [_trigger_time(rows[index]) for index in indices]
    return {
        "row_count": len(indices),
        "group_count": len(
            {_identity_key(rows[index], grouping_policy) for index in indices}
        ),
        "first_trigger_time": min(times).isoformat(sep=" "),
        "last_trigger_time": max(times).isoformat(sep=" "),
    }


def build_time_splits(
    rows: list[dict[str, Any]],
    holdout_fraction: float = 0.20,
    n_splits: int = 4,
    gap: int = 1,
    grouping_policy: str = GROUPING_POLICY,
) -> SplitBundle:
    if not rows:
        raise ValueError("Cannot split an empty binary cohort")
    if not 0.0 < holdout_fraction < 1.0:
        raise ValueError(f"holdout_fraction must be between 0 and 1: {holdout_fraction}")
    if n_splits < 2:
        raise ValueError(f"n_splits must be at least 2: {n_splits}")
    if gap < 0:
        raise ValueError(f"gap cannot be negative: {gap}")

    groups = _groups(rows, grouping_policy)
    holdout_target = max(1, math.ceil(len(rows) * holdout_fraction))
    holdout_group_count = 0
    holdout_rows = 0
    for group in reversed(groups):
        holdout_group_count += 1
        holdout_rows += len(group.indices)
        if holdout_rows >= holdout_target:
            break
    pre_holdout_count = len(groups) - holdout_group_count
    if pre_holdout_count <= n_splits + gap:
        raise ValueError(
            "Not enough pre-holdout Macro windows for "
            f"{n_splits} splits and gap {gap}: {pre_holdout_count}"
        )

    holdout_group_indices = list(range(pre_holdout_count, len(groups)))
    holdout_indices = _expand(groups, holdout_group_indices)
    holdout_boundary = min(_trigger_time(rows[index]) for index in holdout_indices)
    raw_train_group_end = pre_holdout_count - gap
    raw_train_indices = _expand(groups, list(range(raw_train_group_end)))
    train_indices = _purge_closed_after(rows, raw_train_indices, holdout_boundary)
    if not train_indices:
        raise ValueError("Close-time purge removed every pre-holdout training row")

    fold_groups = groups[:pre_holdout_count]
    splitter = TimeSeriesSplit(n_splits=n_splits, gap=gap)
    folds: list[FoldSplit] = []
    for fold_index, (local_train, local_test) in enumerate(
        splitter.split(list(range(len(fold_groups)))),
        start=1,
    ):
        test_indices = _expand(fold_groups, [int(index) for index in local_test])
        boundary = min(_trigger_time(rows[index]) for index in test_indices)
        raw_fold_train = _expand(
            fold_groups,
            [int(index) for index in local_train],
        )
        fold_train = _purge_closed_after(rows, raw_fold_train, boundary)
        if not fold_train:
            raise ValueError(f"Close-time purge removed every row from fold {fold_index}")
        folds.append(
            FoldSplit(
                fold_index=fold_index,
                train_indices=fold_train,
                test_indices=test_indices,
                metadata={
                    "fold_index": fold_index,
                    "validation_boundary": boundary.isoformat(sep=" "),
                    "raw_train_rows": len(raw_fold_train),
                    "purged_train_rows": len(raw_fold_train) - len(fold_train),
                    "train": _range_metadata(rows, fold_train, grouping_policy),
                    "test": _range_metadata(rows, test_indices, grouping_policy),
                },
            )
        )

    metadata = {
        "policy": "purged_chronological_holdout_plus_expanding_walk_forward",
        "grouping_policy": grouping_policy,
        "group_columns": [
            "symbol",
            "macro_timeframe",
            "active_bar_open_broker_time",
        ],
        "close_time_rule": (
            "training terminal_broker_time must be strictly earlier than validation boundary"
        ),
        "origin_weight_policy": ORIGIN_WEIGHT_POLICY,
        "holdout_fraction": holdout_fraction,
        "walk_forward_splits": n_splits,
        "walk_forward_gap_groups": gap,
        "row_count": len(rows),
        "group_count": len(groups),
        "holdout_boundary": holdout_boundary.isoformat(sep=" "),
        "raw_train_rows": len(raw_train_indices),
        "purged_train_rows": len(raw_train_indices) - len(train_indices),
        "train": _range_metadata(rows, train_indices, grouping_policy),
        "holdout": _range_metadata(rows, holdout_indices, grouping_policy),
        "folds": [fold.metadata for fold in folds],
    }
    return SplitBundle(
        train_indices=train_indices,
        holdout_indices=holdout_indices,
        folds=folds,
        metadata=metadata,
    )
