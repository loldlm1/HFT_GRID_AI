"""Stream a sealed CandlePatternV1 run through a bounded, temporary index."""

from __future__ import annotations

import csv
import hashlib
import json
import re
import sqlite3
import tempfile
from contextlib import AbstractContextManager
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from pathlib import Path
from typing import Iterator

from .schema_contract import CATEGORIES, ENGINE, FEATURE_SET, LEVELS, NULL, PATTERNS, SCHEMA_VERSION, TABLE_COLUMNS, column_type


class ContractError(ValueError):
    """The source cannot establish the frozen Candle contract."""


def number(value: str | None) -> Decimal | None:
    if value is None or value == NULL:
        return None
    try:
        result = Decimal(value)
    except (InvalidOperation, ValueError) as exc:
        raise ContractError(f"Invalid numeric value: {value!r}") from exc
    if not result.is_finite():
        raise ContractError("Non-finite number")
    return result


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


class CandleRun(AbstractContextManager):
    """Validate without retaining all feature vectors in Python memory.

    The temporary SQLite file is a disposable offline index, never the Django
    application database. Consumers can iterate the validated source afterwards.
    """

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.temp: tempfile.TemporaryDirectory | None = None
        self.db: sqlite3.Connection | None = None
        self.manifest: dict[str, str] = {}
        self.summary: dict[str, str] = {}
        self.counts: dict[str, int] = {}
        self.hashes: dict[str, str] = {}

    def __enter__(self) -> "CandleRun":
        require(self.path.is_dir() and not self.path.is_symlink(), "Expected a regular run directory")
        require({p.name for p in self.path.iterdir()} == set(TABLE_COLUMNS), "Run must contain exactly the eight Candle TSVs")
        self.temp = tempfile.TemporaryDirectory(prefix="candle-contract-")
        self.db = sqlite3.connect(Path(self.temp.name) / "index.sqlite3")
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA cache_size=-16384")
        self.db.execute("PRAGMA temp_store=FILE")
        try:
            for filename, columns in TABLE_COLUMNS.items():
                source = self.path / filename
                require(source.is_file() and not source.is_symlink(), f"Not a regular source file: {filename}")
                before = source.stat()
                table = filename.removesuffix(".tsv")
                fields = ",".join(f'"{column}" TEXT' for column in columns)
                self.db.execute(f'CREATE TABLE "{table}" ({fields})')
                placeholders = ",".join("?" for _ in columns)
                count = 0
                with source.open(encoding="utf-8", newline="") as handle:
                    reader = csv.reader(handle, delimiter="\t", strict=True)
                    require(next(reader, None) == list(columns), f"Header mismatch: {filename}")
                    for values in reader:
                        count += 1
                        require(len(values) == len(columns), f"Row width: {filename}:{count + 1}")
                        for column, value in zip(columns, values, strict=True):
                            require(not any(char in value for char in "\x00\t\r\n") and len(value) <= 65536, "Invalid field size/content")
                            if filename in {"run_manifest.tsv", "run_summary.tsv"} or value == NULL:
                                continue
                            kind = column_type(column)
                            if kind == "bool":
                                require(value in {"0", "1"}, f"Invalid boolean: {column}")
                            elif kind == "int":
                                require(re.fullmatch(r"-?(0|[1-9][0-9]*)", value) is not None and
                                        -(2**63) <= int(value) < 2**63, f"Invalid integer: {column}")
                            elif kind == "decimal":
                                number(value)
                        self.db.execute(f'INSERT INTO "{table}" VALUES ({placeholders})', tuple(None if v == NULL else v for v in values))
                        if count % 500 == 0:
                            self.db.commit()
                self.db.commit()
                digest = hashlib.sha256()
                with source.open("rb") as handle:
                    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                        digest.update(chunk)
                after = source.stat()
                require((before.st_size, before.st_mtime_ns, before.st_ino) == (after.st_size, after.st_mtime_ns, after.st_ino), "Source changed during validation")
                self.counts[filename] = count
                self.hashes[filename] = digest.hexdigest()
            self._validate()
        except (TypeError, KeyError, InvalidOperation) as exc:
            self.__exit__(None, None, None)
            raise ContractError("Missing or invalid required field") from exc
        except Exception:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        if self.db is not None:
            self.db.close()
            self.db = None
        if self.temp is not None:
            self.temp.cleanup()
            self.temp = None

    def rows(self, filename: str) -> Iterator[dict[str, str | None]]:
        require(filename in TABLE_COLUMNS and self.db is not None, "Unknown table or closed run")
        for row in self.db.execute(f'SELECT * FROM "{filename.removesuffix(".tsv")}" ORDER BY rowid'):
            yield dict(row)

    def _none(self, query: str, reason: str) -> None:
        require(self.db.execute(query).fetchone() is None, reason)

    def _validate(self) -> None:
        for table, key in (("run_manifest", "key"), ("run_summary", "key"), ("macro_windows", "window_id"),
                           ("signal_events", "root_id"), ("entry_attempts", "attempt_id"), ("trials", "trial_id"), ("outcomes", "trial_id")):
            self._none(f'SELECT 1 FROM "{table}" WHERE "{key}" IS NULL OR "{key}" = \'\' LIMIT 1', f"Missing identity: {table}")
            try:
                self.db.execute(f'CREATE UNIQUE INDEX "{table}_identity" ON "{table}" ("{key}")')
            except sqlite3.IntegrityError as exc:
                raise ContractError(f"Duplicate identity: {table}") from exc
        for table, key in (("entry_attempts", "root_id"), ("entry_attempts", "parent_attempt_id"), ("trials", "attempt_id"), ("outcomes", "attempt_id"), ("execution_checks", "attempt_id")):
            self.db.execute(f'CREATE INDEX "{table}_{key}" ON "{table}" ("{key}")')
        self.manifest = {r["key"]: r["value"] for r in self.rows("run_manifest.tsv")}
        self.summary = {r["key"]: r["value"] for r in self.rows("run_summary.tsv")}
        expected = {
            "schema_version": SCHEMA_VERSION, "engine": ENGINE, "feature_set": FEATURE_SET,
            "atr_period": "13", "atr_shift": "1", "atr_multiplier": "1", "ratios": "1,2,3",
            "protection": "FIXED_SUBMITTED", "expiry": "ENTRY_PLUS_MACRO", "allowance": "BROKER_MACRO_CANDLE",
            "categories": "PATTERN_AND_RELATIONSHIP", "reentry": "BROKER_SL_ONCE", "broker_cap": "2048", "virtual_cap": "6144",
        }
        require(set(self.manifest) == set(expected) | {"run_id", "symbol", "macro_seconds", "micro_seconds", "lot_size", "point", "tick_size", "currency"}, "Manifest keys do not match Candle contract")
        for key, value in expected.items():
            require(self.manifest.get(key) == value, f"Manifest mismatch: {key}")
        macro, micro = int(self.manifest["macro_seconds"]), int(self.manifest["micro_seconds"])
        require(0 < micro < macro, "Invalid timeframe ordering")
        require(number(self.manifest["point"]) > 0 and number(self.manifest["tick_size"]) > 0 and number(self.manifest["lot_size"]) > 0, "Invalid instrument/volume facts")
        require(self.manifest["run_id"] == self.path.name, "Directory/run identity mismatch")
        require(re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9_.-]{0,63}", self.path.name) is not None and ".." not in self.path.name, "Unsafe run identity")
        require(set(self.summary) == {f"rows_{name}" for name in tuple(TABLE_COLUMNS)[:-1]} |
                {"broker_peak", "virtual_peak", "last_time_msc", "failure", "completion", "status"}, "Summary keys mismatch")
        require(0 <= int(self.summary["broker_peak"]) <= 2048 and 0 <= int(self.summary["virtual_peak"]) <= 6144,
                "Resource peaks exceed contract")
        require(self.summary.get("status") == "OK" and self.summary.get("completion") == "NATURAL" and self.summary.get("failure") == "NONE", "Run has no successful natural seal")
        for filename in tuple(TABLE_COLUMNS)[:-1]:
            require(self.summary.get(f"rows_{filename}") == str(self.counts[filename]), f"Seal count mismatch: {filename}")
        for filename in tuple(TABLE_COLUMNS)[1:-1]:
            table = filename.removesuffix(".tsv")
            bad = self.db.execute(f'SELECT 1 FROM "{table}" WHERE run_id IS NULL OR run_id <> ? LIMIT 1', (self.manifest["run_id"],)).fetchone()
            require(bad is None, f"Mixed run identities: {filename}")
        for source, target, key in (("entry_attempts", "signal_events", "root_id"), ("trials", "entry_attempts", "attempt_id"), ("execution_checks", "entry_attempts", "attempt_id"), ("outcomes", "trials", "trial_id")):
            self._none(f'SELECT 1 FROM "{source}" s LEFT JOIN "{target}" t ON s."{key}"=t."{key}" WHERE t."{key}" IS NULL LIMIT 1', f"Orphan {source}")
        self._none("SELECT 1 FROM trials t LEFT JOIN outcomes o USING(trial_id) WHERE o.trial_id IS NULL LIMIT 1", "Trial has no sealed outcome")
        self._none("SELECT 1 FROM outcomes o JOIN trials t USING(trial_id) WHERE o.attempt_id<>t.attempt_id OR o.lane<>t.lane OR o.rr<>t.rr LIMIT 1", "Outcome changes trial identity")
        self._none("SELECT 1 FROM entry_attempts GROUP BY root_id HAVING SUM(entry_type='ORIGINAL')<>2 OR COUNT(DISTINCT CASE WHEN entry_type='ORIGINAL' THEN category END)<>2 LIMIT 1", "Original directions are incomplete")
        self._none("SELECT 1 FROM signal_events s LEFT JOIN entry_attempts a USING(root_id) WHERE a.attempt_id IS NULL LIMIT 1", "Signal has no attempts")
        self._none("SELECT 1 FROM entry_attempts a LEFT JOIN trials t USING(attempt_id) GROUP BY a.attempt_id HAVING SUM(t.lane='BROKER' AND t.rr='1')<>1 OR SUM(t.lane='VIRTUAL' AND t.rr='2')<>1 OR SUM(t.lane='VIRTUAL' AND t.rr='3')<>1 LIMIT 1", "Invalid ratio cardinality")
        self._validate_windows(macro)
        self._validate_events(micro)
        self._validate_attempts(macro, micro)
        self._validate_outcomes(macro)
        from .semantics import validate_details

        try:
            validate_details(self)
        except (TypeError, KeyError, InvalidOperation) as exc:
            raise ContractError("Missing or invalid required semantic field") from exc

    def _validate_windows(self, macro: int) -> None:
        tick = number(self.manifest["tick_size"])
        for row in self.rows("macro_windows.tsv"):
            opening = int(row["open_time_msc"])
            require(int(row["macro_seconds"]) == macro, "Window timeframe mismatch")
            if row["valid"] != "1":
                require(row["reason"] != "OK", "Invalid window marked OK")
                continue
            require(0 < int(row["source_time_msc"]) < opening, "Non-causal pivot source")
            high, low, close = (number(row[f"source_{key}"]) for key in ("high", "low", "close"))
            require(0 < low <= close <= high and high > low, "Invalid pivot source range")
            pp = (high + low + close) / 3
            raw = (low - 2 * (high - pp), pp - high + low, 2 * pp - high, pp, 2 * pp - low, pp + high - low, high + 2 * (pp - low))
            levels = [number(row[f"pivot_{level.lower()}"]) for level in LEVELS]
            require(all(a < b for a, b in zip(levels, levels[1:])), "Unordered pivot ladder")
            for value, price in zip(levels, raw, strict=True):
                expected = (price / tick).quantize(Decimal(1), rounding=ROUND_HALF_UP) * tick
                require(abs(value - expected) <= tick * Decimal("0.000001"), "Pivot formula/normalization mismatch")

    def _validate_events(self, micro: int) -> None:
        for row in self.rows("signal_events.tsv"):
            require(row["pattern"] in PATTERNS and row["symbol"] == self.manifest["symbol"], "Signal family/symbol mismatch")
            require(int(row["micro_seconds"]) == micro and int(row["signal_bar_time_msc"]) + micro * 1000 <= int(row["decision_time_msc"]), "Signal uses an unfinished candle")
            po, pc, co, cc = (number(row[name]) for name in ("previous_open", "previous_close", "pattern_open", "pattern_close"))
            require(min(po, pc, co, cc) > 0 and po != pc and co != cc and (pc > po) != (cc > co), "Invalid pattern candles")
            pl, ph, cl, ch = min(po, pc), max(po, pc), min(co, cc), max(co, cc)
            expected = "ENGULFING" if cl <= pl and ch >= ph and (cl < pl or ch > ph) else "HARAMI" if cl >= pl and ch <= ph and (cl > pl or ch < ph) else None
            require(row["pattern"] == expected and row["pattern_direction"] == ("BULLISH" if cc > co else "BEARISH"), "Pattern definition mismatch")

    def _validate_attempts(self, macro: int, micro: int) -> None:
        for row in self.rows("entry_attempts.tsv"):
            root = self.db.execute("SELECT * FROM signal_events WHERE root_id=?", (row["root_id"],)).fetchone()
            require(row["pattern"] == root["pattern"] and row["category"] in CATEGORIES and row["direction"] in {"BUY", "SELL"}, "Attempt category mismatch")
            aligned_direction = "BUY" if root["pattern_direction"] == "BULLISH" else "SELL"
            require((row["direction"] == aligned_direction) == (row["category"] == "ALIGNED"), "Execution relationship mismatch")
            require(row["entry_type"] in {"ORIGINAL", "REENTRY"}, "Unknown attempt type")
            generation = "0" if row["entry_type"] == "ORIGINAL" else "1"
            require(row["attempt_id"] == f'{row["root_id"]}:{row["category"]}:{generation}', "Attempt identity mismatch")
            clock = int(row["decision_time_msc"])
            require(int(row["macro_seconds"]) == macro and int(row["micro_seconds"]) == micro and row["atr_shift"] == "1" and number(row["atr_multiplier"]) == 1, "Attempt policy mismatch")
            require(clock >= int(root["decision_time_msc"]), "Attempt predates its signal")
            require(0 < number(row["bid"]) <= number(row["ask"]), "Invalid executable quote")
            if row["atr_1"] is not None:
                require(number(row["atr_1"]) > 0 and int(row["atr_source_time_msc"]) + micro * 1000 <= clock, "Non-causal ATR")
            if row["macro_window_id"] is not None:
                window = self.db.execute("SELECT * FROM macro_windows WHERE window_id=?", (row["macro_window_id"],)).fetchone()
                require(window is not None and row["macro_open_time_msc"] == window["open_time_msc"], "Missing Macro context")
                require(int(window["open_time_msc"]) <= clock < int(window["open_time_msc"]) + macro * 1000, "Wrong active Macro candle")
            for level in LEVELS:
                touched = row[f"pivot_{level.lower()}_touch_time_msc"]
                if touched is not None:
                    require(int(row["macro_open_time_msc"]) <= int(touched) <= clock, "Pivot context leaked across its window")
            if row["entry_type"] == "ORIGINAL":
                require(row["parent_attempt_id"] is None, "Original has a parent")
            else:
                parent = self.db.execute("SELECT a.*,o.status AS parent_status,o.exit_time_msc AS parent_close,o.deadline_msc AS parent_deadline FROM entry_attempts a JOIN outcomes o ON a.attempt_id=o.attempt_id AND o.lane='BROKER' WHERE a.attempt_id=?", (row["parent_attempt_id"],)).fetchone()
                require(parent is not None and parent["entry_type"] == "ORIGINAL" and parent["root_id"] == row["root_id"] and parent["category"] == row["category"] and parent["direction"] == row["direction"], "Invalid re-entry lineage")
                require(parent["parent_status"] == "SL_FIRST" and int(parent["parent_close"]) <= clock < int(parent["parent_deadline"]), "Re-entry lacks a timely confirmed broker SL")
            for prefix in ("macro", "micro"):
                if row[f"{prefix}_complete"] == "1":
                    for series in ("b_percent", "stochastic_main_line", "stochastic_signal_line"):
                        for shift in range(6):
                            require(row[f"{prefix}_{series}_{shift}"] is not None and row[f"{prefix}_{series}_state_{shift}"] in {"ABOVE", "BELOW", "EQUAL"}, "Incomplete feature block marked complete")
                    for series in ("b_percent", "stochastic_main_line", "stochastic_signal_line"):
                        for shift in (0, 1):
                            expected = sum(number(row[f"{prefix}_{series}_{i}"]) for i in range(shift, shift + 5)) / 5
                            actual = number(row[f"{prefix}_{series}_sma_5_{shift}"])
                            require(actual is not None and abs(expected - actual) <= max(abs(expected), Decimal(1)) * Decimal("1e-12"), "Feature SMA mismatch")

    def _validate_outcomes(self, macro: int) -> None:
        terminal = {"TP_FIRST", "SL_FIRST", "TIME_EXIT", "OTHER_CLOSE", "CENSORED_RUN_END", "REJECTED", "CAPACITY_REJECTED", "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY"}
        for row in self.rows("outcomes.tsv"):
            require(row["status"] in terminal, "Unknown terminal state")
            expected_label = "1" if row["status"] == "TP_FIRST" else "0" if row["status"] == "SL_FIRST" else None
            require(row["binary_label"] == expected_label, "Non-binary outcome was relabeled")
            if row["entry_time_msc"] is None:
                require(row["deadline_msc"] is None and row["binary_label"] is None, "Unentered trial has completed evidence")
                continue
            entry, deadline = int(row["entry_time_msc"]), int(row["deadline_msc"])
            require(deadline == entry + macro * 1000, "Deadline does not belong to its entry")
            require(row["entry_macro_open_time_msc"] is not None and int(row["entry_macro_open_time_msc"]) <= entry < int(row["entry_macro_open_time_msc"]) + macro * 1000, "Entry allowance window mismatch")
            if row["exit_time_msc"] is not None:
                exit_time = int(row["exit_time_msc"])
                require(entry <= exit_time <= int(row["observed_time_msc"]), "Reversed broker/outcome chronology")
                if row["status"] in {"TP_FIRST", "SL_FIRST"}:
                    require(exit_time < deadline, "Binary outcome occurred after expiry")
                if row["status"] == "TIME_EXIT":
                    require(exit_time >= deadline, "Early time exit")
            elif row["status"] != "CENSORED_RUN_END":
                raise ContractError("Completed outcome has no exit")
            gross, costs, net = (number(row[key]) for key in ("gross_profit", "costs", "net_profit"))
            if net is not None:
                require(gross is not None and costs is not None and abs(net - gross - costs) <= Decimal("0.00000001"), "Money reconciliation mismatch")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    args = parser.parse_args()
    try:
        with CandleRun(args.run) as run:
            print(json.dumps({"status": "PASS", "run_id": run.manifest["run_id"], "counts": run.counts, "hashes": run.hashes}, indent=2))
    except (ContractError, OSError, csv.Error, ValueError, sqlite3.Error) as exc:
        parser.exit(1, f"Candle validation failed: {exc}\n")


if __name__ == "__main__":
    main()
