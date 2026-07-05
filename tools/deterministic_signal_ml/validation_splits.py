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


@dataclass(frozen=True)
class RobustSplitBundle:
    train_core_indices: list[int]
    early_stopping_indices: list[int]
    threshold_selection_indices: list[int]
    final_holdout_indices: list[int]
    gap_indices: list[int]
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
            "unique_entry_times": 0,
        }
    unique_entry_times = len({_entry_time(rows[index]) for index in indices})
    return {
        "row_count": len(indices),
        "start_index": indices[0],
        "end_index": indices[-1],
        "entry_time_start": _entry_time(rows[indices[0]]),
        "entry_time_end": _entry_time(rows[indices[-1]]),
        "unique_entry_times": unique_entry_times,
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


def _take_tail_groups(
    groups: list[tuple[str, list[int]]],
    target_rows: int,
) -> tuple[list[tuple[str, list[int]]], list[tuple[str, list[int]]]]:
    split_index = len(groups)
    row_count = 0
    while split_index > 0 and row_count < target_rows:
        split_index -= 1
        row_count += len(groups[split_index][1])
    return groups[:split_index], groups[split_index:]


def _take_tail_group_count(
    groups: list[tuple[str, list[int]]],
    group_count: int,
) -> tuple[list[tuple[str, list[int]]], list[tuple[str, list[int]]]]:
    if group_count <= 0:
        return groups, []
    split_index = max(0, len(groups) - group_count)
    return groups[:split_index], groups[split_index:]


def _metadata_for_groups(
    rows: list[dict[str, Any]],
    groups: list[tuple[str, list[int]]],
) -> dict[str, Any]:
    return _range_metadata(
        rows,
        _expand_group_indices(groups, list(range(len(groups)))),
    )


def _partition_target(row_count: int, fraction: float, min_rows: int) -> int:
    return max(min_rows, int(round(row_count * fraction)))


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


def build_robust_time_splits(
    rows: list[dict[str, Any]],
    final_holdout_fraction: float = 0.20,
    threshold_fraction: float = 0.20,
    early_stopping_fraction: float = 0.10,
    n_splits: int = 4,
    gap: int = 0,
    min_train_rows: int = 500,
    min_partition_rows: int = 30,
) -> RobustSplitBundle:
    if not 0.0 < final_holdout_fraction < 1.0:
        raise ValueError(
            f"final_holdout_fraction must be between 0 and 1: {final_holdout_fraction}"
        )
    if not 0.0 < threshold_fraction < 1.0:
        raise ValueError(f"threshold_fraction must be between 0 and 1: {threshold_fraction}")
    if not 0.0 < early_stopping_fraction < 1.0:
        raise ValueError(
            f"early_stopping_fraction must be between 0 and 1: {early_stopping_fraction}"
        )
    if final_holdout_fraction + threshold_fraction + early_stopping_fraction >= 0.85:
        raise ValueError("Robust validation partitions leave too little training data")
    if n_splits < 0:
        raise ValueError(f"n_splits cannot be negative: {n_splits}")
    if gap < 0:
        raise ValueError(f"gap cannot be negative: {gap}")

    _assert_chronological(rows)
    row_count = len(rows)
    groups = _entry_time_groups(rows)
    final_target = _partition_target(row_count, final_holdout_fraction, min_partition_rows)
    threshold_target = _partition_target(row_count, threshold_fraction, min_partition_rows)
    early_target = _partition_target(row_count, early_stopping_fraction, min_partition_rows)

    remaining, final_groups = _take_tail_groups(groups, final_target)
    remaining, gap_before_final = _take_tail_group_count(remaining, gap)
    remaining, threshold_groups = _take_tail_groups(remaining, threshold_target)
    remaining, gap_before_threshold = _take_tail_group_count(remaining, gap)
    remaining, early_groups = _take_tail_groups(remaining, early_target)
    train_groups, gap_before_early = _take_tail_group_count(remaining, gap)

    train_core_indices = _expand_group_indices(train_groups, list(range(len(train_groups))))
    early_stopping_indices = _expand_group_indices(
        early_groups,
        list(range(len(early_groups))),
    )
    threshold_selection_indices = _expand_group_indices(
        threshold_groups,
        list(range(len(threshold_groups))),
    )
    final_holdout_indices = _expand_group_indices(final_groups, list(range(len(final_groups))))
    gap_groups = gap_before_early + gap_before_threshold + gap_before_final
    gap_indices = _expand_group_indices(gap_groups, list(range(len(gap_groups))))

    partition_rows = {
        "train_core": len(train_core_indices),
        "early_stopping_validation": len(early_stopping_indices),
        "threshold_selection": len(threshold_selection_indices),
        "final_holdout": len(final_holdout_indices),
    }
    if partition_rows["train_core"] < min_train_rows:
        raise ValueError(
            "Not enough rows for robust train_core partition: "
            f"{partition_rows['train_core']} < {min_train_rows}"
        )
    for name, rows_in_partition in partition_rows.items():
        if name != "train_core" and rows_in_partition < min_partition_rows:
            raise ValueError(
                f"Not enough rows for robust {name} partition: "
                f"{rows_in_partition} < {min_partition_rows}"
            )

    fold_source_groups = train_groups + early_groups + threshold_groups
    folds: list[FoldSplit] = []
    if n_splits >= 2 and len(fold_source_groups) > n_splits + gap:
        splitter = TimeSeriesSplit(n_splits=n_splits, gap=gap)
        for fold_index, (local_train, local_test) in enumerate(
            splitter.split(list(range(len(fold_source_groups)))),
            start=1,
        ):
            fold_train = _expand_group_indices(
                fold_source_groups,
                [int(index) for index in local_train],
            )
            fold_test = _expand_group_indices(
                fold_source_groups,
                [int(index) for index in local_test],
            )
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
        "policy": "robust_chronological_train_early_threshold_holdout",
        "row_count": row_count,
        "unique_entry_times": len(groups),
        "gap_entry_time_groups": gap,
        "final_holdout_fraction": final_holdout_fraction,
        "threshold_fraction": threshold_fraction,
        "early_stopping_fraction": early_stopping_fraction,
        "walk_forward_splits": n_splits,
        "train_core": _metadata_for_groups(rows, train_groups),
        "early_stopping_validation": _metadata_for_groups(rows, early_groups),
        "threshold_selection": _metadata_for_groups(rows, threshold_groups),
        "final_holdout": _metadata_for_groups(rows, final_groups),
        "gaps": {
            "row_count": len(gap_indices),
            "unique_entry_times": len(gap_groups),
            "before_early_stopping_validation": _metadata_for_groups(
                rows,
                gap_before_early,
            ),
            "before_threshold_selection": _metadata_for_groups(rows, gap_before_threshold),
            "before_final_holdout": _metadata_for_groups(rows, gap_before_final),
        },
        "folds": [fold.metadata for fold in folds],
    }
    return RobustSplitBundle(
        train_core_indices=train_core_indices,
        early_stopping_indices=early_stopping_indices,
        threshold_selection_indices=threshold_selection_indices,
        final_holdout_indices=final_holdout_indices,
        gap_indices=gap_indices,
        folds=folds,
        metadata=metadata,
    )


def _self_test() -> None:
    rows: list[dict[str, Any]] = []
    for group_index in range(40):
        rows.append({"entry_time": f"2026-01-01 00:{group_index:02d}:00"})
        if group_index % 7 == 0:
            rows.append({"entry_time": f"2026-01-01 00:{group_index:02d}:00"})

    bundle = build_robust_time_splits(
        rows,
        final_holdout_fraction=0.20,
        threshold_fraction=0.20,
        early_stopping_fraction=0.10,
        n_splits=3,
        gap=1,
        min_train_rows=10,
        min_partition_rows=3,
    )
    assigned = (
        bundle.train_core_indices
        + bundle.early_stopping_indices
        + bundle.threshold_selection_indices
        + bundle.final_holdout_indices
        + bundle.gap_indices
    )
    if sorted(assigned) != list(range(len(rows))):
        raise AssertionError("robust split did not assign every row exactly once")
    for partition_name in (
        "train_core",
        "early_stopping_validation",
        "threshold_selection",
        "final_holdout",
    ):
        metadata = bundle.metadata[partition_name]
        if metadata["row_count"] <= 0:
            raise AssertionError(f"{partition_name} is empty")
    partition_by_time: dict[str, str] = {}
    for name, indices in (
        ("train_core", bundle.train_core_indices),
        ("early_stopping_validation", bundle.early_stopping_indices),
        ("threshold_selection", bundle.threshold_selection_indices),
        ("final_holdout", bundle.final_holdout_indices),
        ("gap", bundle.gap_indices),
    ):
        for index in indices:
            entry_time = _entry_time(rows[index])
            previous = partition_by_time.setdefault(entry_time, name)
            if previous != name:
                raise AssertionError(f"entry_time {entry_time} crosses split partitions")


if __name__ == "__main__":
    _self_test()
    print("validation_splits self-test ok")
