"""Causal Candle cohorts: one family/category, then type/node filters and first N."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable, Iterator, Mapping

from .reader import CandleRun, ContractError, number, require
from .schema_contract import CATEGORIES, CONTEXT_COLUMNS, FEATURE_COLUMNS, PATTERNS, column_type

CAUSAL_COLUMNS = frozenset((*FEATURE_COLUMNS, *CONTEXT_COLUMNS, "entry_interval", "context_level",
                           "context_role", "context_distance_points", "context_age_ms", "direction",
                           "atr_0", "atr_1", "atr_points", "spread_points"))


@dataclass(frozen=True)
class Clause:
    field: str
    operator: str
    value: str

    def __post_init__(self):
        require(self.field in CAUSAL_COLUMNS, "Node conditions require a causal Candle feature")
        require(self.operator in {"eq", "ne", "lt", "lte", "gt", "gte"}, "Unknown node operator")
        if column_type(self.field) in {"text", "bool"}:
            require(self.operator in {"eq", "ne"}, "State features support equality conditions")
            require(isinstance(self.value, str) and 0 < len(self.value) <= 100, "Invalid state value")
        else:
            require(number(str(self.value)) is not None, "Numeric condition requires a finite value")

    def matches(self, row: Mapping) -> bool:
        actual = row.get(self.field)
        if actual is None:
            return False
        expected = self.value
        if column_type(self.field) not in {"text", "bool"}:
            actual, expected = number(str(actual)), number(str(expected))
        return {"eq": lambda: actual == expected, "ne": lambda: actual != expected,
                "lt": lambda: actual < expected, "lte": lambda: actual <= expected,
                "gt": lambda: actual > expected, "gte": lambda: actual >= expected}[self.operator]()


@dataclass(frozen=True)
class SelectionPolicy:
    pattern: str
    category: str
    entry_type: str = "ALL"
    allowance: int = 0
    mode: str = "ANALYSIS"
    clauses: tuple[Clause, ...] = ()

    def __post_init__(self):
        require(self.pattern in PATTERNS and self.category in CATEGORIES, "Choose one pattern and one direction category")
        require(self.entry_type in {"ALL", "ORIGINAL", "REENTRY"}, "Unknown entry-type selector")
        require(type(self.allowance) is int and self.allowance >= 0, "Allowance must be a non-negative integer")
        require(self.mode in {"ANALYSIS", "STRATEGY"}, "Unknown selection mode")
        require(not (self.mode == "STRATEGY" and self.entry_type == "REENTRY"),
                "A broker-triggered strategy requires selected original trades; use analysis for re-entries alone")
        require(len(self.clauses) <= 16 and all(isinstance(clause, Clause) for clause in self.clauses), "Invalid node path")


def select_entries(rows: Iterable[Mapping], policy: SelectionPolicy) -> Iterator[tuple[Mapping, str]]:
    """Yield decisions in broker fill order without consulting terminal outcomes.

    Rows own one broker attempt, never a ratio row. Known entry deadlines bound
    parent membership to the current Macro duration; exits never refund slots.
    """
    previous = None
    current_window = None
    window_count = 0
    selected_parents = {}
    for row in rows:
        if row["pattern"] != policy.pattern or row["category"] != policy.category:
            continue
        if row["entry_time_msc"] is None:
            yield row, "NOT_ENTERED"
            continue
        clock = int(row["entry_time_msc"])
        key = (clock, int(row["sequence"]), row["attempt_id"])
        require(previous is None or key > previous, "Selection input must contain unique ordered attempts")
        previous = key
        selected_parents = {parent: deadline for parent, deadline in selected_parents.items() if deadline > clock}
        if policy.entry_type != "ALL" and row["entry_type"] != policy.entry_type:
            yield row, "ENTRY_TYPE"
            continue
        if not all(clause.matches(row) for clause in policy.clauses):
            yield row, "NODE_CONDITION"
            continue
        if policy.mode == "STRATEGY" and row["entry_type"] == "REENTRY" and row["parent_attempt_id"] not in selected_parents:
            yield row, "PARENT_NOT_SELECTED"
            continue
        window = (row["run_id"], row["entry_macro_open_time_msc"])
        if window != current_window:
            current_window, window_count = window, 0
        if policy.allowance and window_count >= policy.allowance:
            yield row, "ALLOWANCE"
            continue
        window_count += 1
        if row["entry_type"] == "ORIGINAL":
            selected_parents[row["attempt_id"]] = clock + int(row["macro_seconds"]) * 1000
        yield row, "SELECTED"


def run_selection(run: CandleRun, policy: SelectionPolicy) -> dict:
    run.db.execute("DROP TABLE IF EXISTS selected_attempts")
    run.db.execute("CREATE TEMP TABLE selected_attempts (attempt_id TEXT PRIMARY KEY)")

    def observations():
        query = """SELECT a.*, o.entry_time_msc, o.entry_macro_open_time_msc
                   FROM entry_attempts a JOIN outcomes o ON o.attempt_id=a.attempt_id AND o.lane='BROKER'
                   ORDER BY CAST(o.entry_time_msc AS INTEGER), CAST(a.sequence AS INTEGER), a.attempt_id"""
        for record in run.db.execute(query):
            row = dict(record)
            point = number(row["point"])
            row["atr_points"] = str(number(row["atr_1"]) / point) if row["atr_1"] is not None else None
            row["spread_points"] = str((number(row["ask"]) - number(row["bid"])) / point)
            yield row

    decisions = Counter()
    digest = __import__("hashlib").sha256()
    for row, reason in select_entries(observations(), policy):
        decisions[reason] += 1
        if reason == "SELECTED":
            run.db.execute("INSERT INTO selected_attempts VALUES (?)", (row["attempt_id"],))
            digest.update((row["attempt_id"] + "\n").encode())
    ratios = {}
    for rr, lane in ((1, "BROKER"), (2, "VIRTUAL"), (3, "VIRTUAL")):
        counts = Counter()
        gross = Decimal(0)
        costs = Decimal(0)
        realized = 0
        query = """SELECT o.* FROM outcomes o JOIN selected_attempts s USING(attempt_id)
                   WHERE o.lane=? AND o.rr=? ORDER BY CAST(o.entry_time_msc AS INTEGER), o.trial_id"""
        for row in run.db.execute(query, (lane, str(rr))):
            counts[row["status"]] += 1
            if row["gross_profit"] is not None:
                gross += number(row["gross_profit"])
                realized += 1
            if row["costs"] is not None:
                costs += number(row["costs"])
        binary = counts["TP_FIRST"] + counts["SL_FIRST"]
        ratios[str(rr)] = {"lane": lane, "outcomes": dict(counts), "realized_count": realized,
                           "win_rate": str(Decimal(counts["TP_FIRST"]) / binary) if binary else None,
                           "gross_profit": str(gross), "costs": str(costs) if rr == 1 else None,
                           "net_profit": str(gross + costs) if rr == 1 else None}
    return {"run_id": run.manifest["run_id"], "pattern": policy.pattern, "category": policy.category,
            "entry_type": policy.entry_type, "allowance": policy.allowance, "mode": policy.mode,
            "decisions": dict(decisions), "membership_sha256": digest.hexdigest(), "ratios": ratios,
            "limitation": "Observed-fill cohort; does not reproduce counterfactual margin or execution."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run")
    parser.add_argument("--pattern", choices=PATTERNS, required=True)
    parser.add_argument("--category", choices=CATEGORIES, required=True)
    parser.add_argument("--entry-type", choices=("ALL", "ORIGINAL", "REENTRY"), default="ALL")
    parser.add_argument("--allowance", type=int, default=0)
    parser.add_argument("--mode", choices=("ANALYSIS", "STRATEGY"), default="ANALYSIS")
    parser.add_argument("--where", nargs=3, action="append", default=[], metavar=("FEATURE", "OPERATOR", "VALUE"))
    args = parser.parse_args()
    try:
        policy = SelectionPolicy(args.pattern, args.category, args.entry_type, args.allowance, args.mode,
                                 tuple(Clause(*values) for values in args.where))
        with CandleRun(args.run) as run:
            print(json.dumps(run_selection(run, policy), indent=2))
    except (ContractError, OSError) as exc:
        parser.exit(1, f"Candle research failed: {exc}\n")


if __name__ == "__main__":
    main()
