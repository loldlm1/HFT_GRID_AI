"""Chronological splits that keep each pivot window identity in one partition."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime
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


@dataclass(frozen=True)
class _IdentityGroup:
    key: tuple[str, ...]
    first_time: datetime
    indices: list[int]


def _trigger_time(row: dict[str, Any]) -> datetime:
    value = row.get("trigger_broker_time")
    if isinstance(value, datetime):
        return value
    if value in (None, ""):
        raise ValueError("Training row lacks trigger_broker_time")
    text = str(value)
    for pattern in ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M:%S"):
        try:
            return datetime.strptime(text[:19], pattern)
        except ValueError:
            continue
    raise ValueError(f"Invalid trigger_broker_time: {value}")


def _identity_key(
    row: dict[str, Any], grouping_policy: str = "pivot_window_identity"
) -> tuple[str, ...]:
    if grouping_policy == "symbol_d1_active_broker_window":
        value = row.get("research_group_id")
        if value in (None, ""):
            raise ValueError("Training row lacks research_group_id")
        return (str(value),)
    if grouping_policy != "pivot_window_identity":
        raise ValueError(f"Unsupported grouping policy: {grouping_policy}")
    values = (row.get("run_id"), row.get("symbol"), row.get("window_id"))
    if any(value in (None, "") for value in values):
        raise ValueError("Training row lacks run_id, symbol, or window_id")
    return tuple(str(value) for value in values)


def _groups(
    rows: list[dict[str, Any]], grouping_policy: str
) -> list[_IdentityGroup]:
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
    previous: datetime | None = None
    for group in groups:
        if previous is not None and group.first_time < previous:
            raise ValueError("Pivot identity groups are not chronological")
        previous = group.first_time
    return groups


def _expand(groups: list[_IdentityGroup], group_indices: list[int]) -> list[int]:
    return sorted(index for group_index in group_indices for index in groups[group_index].indices)


def _range_metadata(
    rows: list[dict[str, Any]], indices: list[int], grouping_policy: str
) -> dict[str, Any]:
    if not indices:
        return {"row_count": 0, "group_count": 0, "first_time": None, "last_time": None}
    times = [_trigger_time(rows[index]) for index in indices]
    return {
        "row_count": len(indices),
        "group_count": len(
            {_identity_key(rows[index], grouping_policy) for index in indices}
        ),
        "first_time": min(times).isoformat(sep=" "),
        "last_time": max(times).isoformat(sep=" "),
    }


def build_time_splits(
    rows: list[dict[str, Any]],
    holdout_fraction: float = 0.20,
    n_splits: int = 4,
    gap: int = 1,
    grouping_policy: str = "pivot_window_identity",
) -> SplitBundle:
    if not rows:
        raise ValueError("Cannot split an empty training matrix")
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
    train_groups = groups[:-holdout_group_count]
    holdout_groups = groups[-holdout_group_count:]
    if len(train_groups) <= n_splits + gap:
        raise ValueError(
            "Not enough pre-holdout pivot windows for "
            f"{n_splits} splits and gap {gap}: {len(train_groups)}"
        )

    train_indices = _expand(train_groups, list(range(len(train_groups))))
    holdout_indices = _expand(holdout_groups, list(range(len(holdout_groups))))
    splitter = TimeSeriesSplit(n_splits=n_splits, gap=gap)
    folds: list[FoldSplit] = []
    for fold_index, (local_train, local_test) in enumerate(
        splitter.split(list(range(len(train_groups)))),
        start=1,
    ):
        fold_train = _expand(train_groups, [int(index) for index in local_train])
        fold_test = _expand(train_groups, [int(index) for index in local_test])
        folds.append(
            FoldSplit(
                fold_index=fold_index,
                train_indices=fold_train,
                test_indices=fold_test,
                metadata={
                    "fold_index": fold_index,
                    "train": _range_metadata(rows, fold_train, grouping_policy),
                    "test": _range_metadata(rows, fold_test, grouping_policy),
                },
            )
        )

    metadata = {
        "policy": "chronological_grouped_holdout_plus_walk_forward",
        "grouping_policy": grouping_policy,
        "group_columns": (
            ["research_group_id"]
            if grouping_policy == "symbol_d1_active_broker_window"
            else ["run_id", "symbol", "window_id"]
        ),
        "holdout_fraction": holdout_fraction,
        "walk_forward_splits": n_splits,
        "walk_forward_gap_groups": gap,
        "row_count": len(rows),
        "group_count": len(groups),
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


if __name__ == "__main__":
    demo_rows = [
        {
            "run_id": "demo",
            "symbol": "EURUSD",
            "window_id": f"window_{index}",
            "trigger_broker_time": f"2026-01-{index + 1:02d} 10:00:00",
        }
        for index in range(16)
    ]
    bundle = build_time_splits(demo_rows, holdout_fraction=0.25, n_splits=2, gap=1)
    print(
        "validation_splits self-test ok | "
        f"train={len(bundle.train_indices)} | holdout={len(bundle.holdout_indices)}"
    )
