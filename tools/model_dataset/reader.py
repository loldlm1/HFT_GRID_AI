"""Strict streaming validation of a sealed shared-engine dataset."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import tempfile
from contextlib import AbstractContextManager
from decimal import Decimal, InvalidOperation
from pathlib import Path

from .clock import analysis_clock
from .schema_contract import (
    COMMON_TABLES, FIXED_MANIFEST, MANIFEST_KEYS, NULL, PROFILES, SUMMARY_KEYS, SUMMARY_CLOCKS,
    Table, clock_companions,
)

INTEGER = re.compile(r"-?(0|[1-9][0-9]*)\Z")
NUMBER = re.compile(r"-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\Z")
MAX_DOUBLE = Decimal("1.7976931348623157e308")
MAX_ROW_BYTES = 1024 * 1024


class ContractError(ValueError):
    """Source facts cannot establish the declared contract."""


def require(condition, message: str) -> None:
    if not condition:
        raise ContractError(message)


def number(value: str | None) -> Decimal | None:
    if value is None or value == NULL:
        return None
    require(isinstance(value, str) and NUMBER.fullmatch(value), "Invalid decimal token")
    try:
        result = Decimal(value)
    except InvalidOperation as exc:
        raise ContractError("Invalid decimal") from exc
    require(result.is_finite() and abs(result) < MAX_DOUBLE, "Non-finite or sentinel decimal")
    return result


def integer(value: str | None) -> int:
    require(isinstance(value, str) and INTEGER.fullmatch(value), "Invalid integer token")
    require(len(value) <= 20, "Integer out of range")
    result = int(value)
    require(-(2**63) <= result < 2**63, "Integer out of range")
    return result


def near(a: Decimal | None, b: Decimal | None, message: str, tolerance=Decimal("0.0000001")) -> None:
    require(a is not None and b is not None and abs(a - b) <= tolerance, message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


class ModelRun(AbstractContextManager):
    """Bounded Python memory; a disposable disk index supports relational checks."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.db = None
        self.temp = None
        self.manifest = {}
        self.summary = {}
        self.counts = {}
        self.hashes = {}
        self.stats = {}
        self.tables = {}
        self.profile = None

    def __enter__(self):
        require(self.path.is_dir() and not self.path.is_symlink(), "Expected regular run directory")
        self.temp = tempfile.TemporaryDirectory(prefix="model-dataset-")
        self.db = sqlite3.connect(Path(self.temp.name) / "index.sqlite3")
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA cache_size=-8192")
        self.db.execute("PRAGMA temp_store=FILE")
        try:
            self._load(COMMON_TABLES[0])
            self.manifest = {r["key"]: r["value"] for r in self.rows("run_manifest.tsv")}
            self._manifest()
            self.tables = {t.name: t for t in self.profile.tables}
            require({p.name for p in self.path.iterdir()} == set(self.tables), "Unexpected/missing run files")
            for table in self.profile.tables[1:]:
                self._load(table)
            self.summary = {r["key"]: r["value"] for r in self.rows("run_summary.tsv")}
            self._seal()
            self._references()
            from .semantics import validate
            validate(self)
            self.verify_unchanged()
        except (TypeError, KeyError, InvalidOperation, UnicodeError, OverflowError, sqlite3.Error) as exc:
            self.__exit__(None, None, None)
            raise ContractError(f"Invalid or missing contract facts: {type(exc).__name__}") from exc
        except Exception:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if self.db is not None:
            self.db.close()
            self.db = None
        if self.temp is not None:
            self.temp.cleanup()
            self.temp = None

    def _load(self, table: Table) -> None:
        self.tables[table.name] = table
        path = self.path / table.name
        require(path.is_file() and not path.is_symlink(), "Expected regular file: " + table.name)
        self.stats[table.name] = path.stat()
        name = table.name.removesuffix(".tsv")
        fields = table.fields
        declarations = ",".join(f'"{f.name}" TEXT' for f in fields)
        self.db.execute(f'CREATE TABLE "{name}" ({declarations}, PRIMARY KEY("{table.key}"))')
        sql = f'INSERT INTO "{name}" VALUES ({",".join("?" for _ in fields)})'
        hash_state = hashlib.sha256()
        count = 0
        with path.open("rb") as stream:
            header = stream.readline(MAX_ROW_BYTES + 1)
            hash_state.update(header)
            require(header.endswith(b"\n") and header.rstrip(b"\r\n").decode("utf-8") == "\t".join(table.columns), "Header mismatch: " + table.name)
            while raw := stream.readline(MAX_ROW_BYTES + 1):
                count += 1
                require(len(raw) <= MAX_ROW_BYTES and raw.endswith(b"\n"), "Partial/oversized row: " + table.name)
                hash_state.update(raw)
                line = raw[:-2] if raw.endswith(b"\r\n") else raw[:-1]
                values = line.decode("utf-8").split("\t")
                require(len(values) == len(fields), f"Row width: {table.name}:{count + 1}")
                for f, value in zip(fields, values, strict=True):
                    require(len(value) <= 65536 and not any(c in value for c in "\r\n\x00"), "Invalid cell")
                    if value == NULL:
                        require(f.nullable, "Required field is null: " + f.name)
                        continue
                    if f.type == "bool":
                        require(value in {"0", "1"}, "Invalid boolean: " + f.name)
                    elif f.type in {"int", "clock"}:
                        integer(value)
                    elif f.type == "decimal":
                        number(value)
                    else:
                        require(value != "", "Empty text field: " + f.name)
                    require(not f.choices or value in f.choices, "Unknown field value: " + f.name)
                row = {f.name: None if v == NULL else v for f, v in zip(fields, values, strict=True)}
                if "run_id" in row:
                    require(row["run_id"] == self.manifest["run_id"], "Mixed run identity")
                for clock in table.clocks:
                    names = clock_companions(clock.name)
                    if row[clock.name] is None:
                        require(all(row[n] is None for n in names), "Partial null clock")
                    else:
                        expected, offset = analysis_clock(integer(row[clock.name]), self.manifest["broker_session"])
                        require(row[names[0]] == str(expected) and row[names[1]] == str(offset), "Clock policy mismatch")
                        require(row[names[2]] in {"SECOND", "MILLISECOND"}, "Unknown clock precision")
                        require(row[names[2]] != "SECOND" or integer(row[clock.name]) % 1000 == 0, "Invented subsecond precision")
                try:
                    self.db.execute(sql, tuple(row.values()))
                except sqlite3.IntegrityError as exc:
                    raise ContractError("Duplicate identity: " + table.name) from exc
                if count % 256 == 0:
                    self.db.commit()
        self.db.commit()
        self.counts[table.name] = count
        self.hashes[table.name] = hash_state.hexdigest()

    def rows(self, filename):
        require(filename in self.tables and self.db is not None, "Unknown table or closed run")
        for row in self.db.execute(f'SELECT * FROM "{filename.removesuffix(".tsv")}" ORDER BY rowid'):
            yield dict(row)

    def none(self, sql: str, message: str, parameters=()):
        require(self.db.execute(sql, parameters).fetchone() is None, message)

    def one(self, filename: str, key: str, value: str):
        require(filename in self.tables and key in self.tables[filename].columns, "Unknown indexed field")
        row = self.db.execute(f'SELECT * FROM "{filename.removesuffix(".tsv")}" WHERE "{key}"=?', (value,)).fetchone()
        require(row is not None, "Missing referenced row: " + filename)
        return dict(row)

    def _manifest(self):
        m = self.manifest
        require(set(m) == set(MANIFEST_KEYS), "Manifest key mismatch")
        require(m["engine"] in PROFILES, "Unknown engine")
        self.profile = PROFILES[m["engine"]]
        for key, value in {**FIXED_MANIFEST, "outcome_policy": self.profile.outcome_policy}.items():
            require(m[key] == value, "Manifest mismatch: " + key)
        require(m["run_id"] == self.path.name and re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9_.-]{0,63}", m["run_id"]) and ".." not in m["run_id"], "Unsafe/mismatched run identity")
        periods = {60 * n for n in (1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60, 120, 180, 240, 360, 480, 720, 1440, 10080)}
        macro, micro = integer(m["macro_seconds"]), integer(m["micro_seconds"])
        require(micro in periods and macro in periods and micro < macro, "Invalid timeframe ordering/support")
        for key in ("point", "tick_size", "volume_min", "volume_max", "volume_step", "contract_size", "lot_size"):
            require(number(m[key]) > 0, "Invalid instrument/sizing fact: " + key)
        require(number(m["volume_min"]) <= number(m["volume_max"]), "Invalid volume limits")
        require(0 <= integer(m["digits"]) <= 16, "Invalid price digits")
        require(integer(m["compiler_build"]) > 0, "Missing compiler build")
        require(m["mapping_status"] in {"VERIFIED", "UNMAPPED"} and (m["mapping_status"] == "UNMAPPED") == (m["canonical_symbol"] == "UNMAPPED"), "Invalid instrument mapping")
        require(m["lot_type"] in {"EXECUTION_LOT_FIXED_SIZE", "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT"}, "Invalid lot mode")
        require(m["lot_type"] != "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT" or number(m["lot_size"]) <= 100, "Invalid reference risk")
        policy = {"FIXED_TIME_SESSIONS": ("BROKER_NATIVE", "BROKER_FIXED_V1"), "EXNESS_SESSION": ("UTC_SHIFT_0", "EXNESS_NEW_YORK_V1")}
        require(m["broker_session"] in policy and (m["broker_time_basis"], m["analysis_clock_policy"]) == policy[m["broker_session"]], "Invalid clock provenance")

    def _seal(self):
        s = self.summary
        counts = {"rows_" + name for name in self.tables if name != "run_summary.tsv"}
        require(set(s) == set(SUMMARY_KEYS) | counts, "Summary key mismatch")
        require(s["export_status"] == "OK" and s["completion_status"] == "NATURAL" and s["failure"] == "NONE", "No successful natural seal")
        for name, count in self.counts.items():
            if name != "run_summary.tsv":
                require(s["rows_" + name] == str(count), "Seal count mismatch: " + name)
        for key, cap in (("broker_peak", int(self.manifest["broker_cap"])), ("virtual_peak", int(self.manifest["virtual_cap"])), ("handle_peak", 7), ("buffer_peak", 256), ("warmup_count", 4096)):
            require(0 <= integer(s[key]) <= cap, "Resource cap exceeded: " + key)
        require(integer(s["feature_gap_count"]) >= 0, "Invalid gap count")
        require(s["warmup_status"] in {"COMPLETE", "TRUNCATED", "UNAVAILABLE", "PARTIAL"}, "Invalid warmup status")
        count = integer(s["warmup_count"])
        if count:
            require(0 < integer(s["warmup_first_time_msc"]) <= integer(s["warmup_last_time_msc"]) < integer(s["first_time_msc"]) <= integer(s["last_time_msc"]), "Warmup source bounds")
            require(re.fullmatch(r"[0-9a-f]{16,64}", s["warmup_fingerprint"]), "Missing warmup fingerprint")
        else:
            require(s["warmup_first_time_msc"] == "NONE" and s["warmup_last_time_msc"] == "NONE" and s["warmup_fingerprint"] == "NONE", "Fabricated warmup")
        require(0 < integer(s["first_time_msc"]) <= integer(s["last_time_msc"]), "Invalid observed run bounds")
        for clock in SUMMARY_CLOCKS:
            names = clock_companions(clock)
            if s[clock] == "NONE":
                require(all(s[n] == "NONE" for n in names), "Partial summary clock")
            else:
                raw = integer(s[clock])
                analysis, offset = analysis_clock(raw, self.manifest["broker_session"])
                require(s[names[0]] == str(analysis) and s[names[1]] == str(offset), "Summary clock mismatch")
                require(s[names[2]] in {"SECOND", "MILLISECOND"} and (s[names[2]] != "SECOND" or raw % 1000 == 0), "Summary precision mismatch")

    def _references(self):
        links = [
            ("signal_events", "macro_window_id", "macro_windows", "window_id"),
            ("feature_snapshots", "signal_id", "signal_events", "signal_id"),
            ("feature_snapshots", "macro_window_id", "macro_windows", "window_id"),
            ("entry_attempts", "signal_id", "signal_events", "signal_id"),
            ("entry_attempts", "snapshot_id", "feature_snapshots", "snapshot_id"),
            ("entry_attempts", "parent_attempt_id", "entry_attempts", "attempt_id"),
            ("entry_attempts", "macro_window_id", "macro_windows", "window_id"),
            ("trials", "attempt_id", "entry_attempts", "attempt_id"),
            ("execution_checks", "attempt_id", "entry_attempts", "attempt_id"),
            ("outcomes", "trial_id", "trials", "trial_id"),
        ]
        owners = {"signal_id": "signal_events", "attempt_id": "entry_attempts", "snapshot_id": "feature_snapshots", "trial_id": "trials"}
        for table in self.profile.extensions:
            links.append((table.name.removesuffix(".tsv"), table.key, owners[table.key], table.key))
            self.none(f'SELECT 1 FROM "{owners[table.key]}" s LEFT JOIN "{table.name.removesuffix(".tsv")}" t USING("{table.key}") WHERE t."{table.key}" IS NULL LIMIT 1', "Missing engine extension")
        for source, key, target, target_key in links:
            self.db.execute(f'CREATE INDEX IF NOT EXISTS "{source}_{key}_link" ON "{source}" ("{key}")')
            self.none(f'SELECT 1 FROM "{source}" s LEFT JOIN "{target}" t ON s."{key}"=t."{target_key}" WHERE s."{key}" IS NOT NULL AND t."{target_key}" IS NULL LIMIT 1', "Orphan reference: " + source)
        self.none("SELECT 1 FROM trials t LEFT JOIN outcomes o USING(trial_id) WHERE o.trial_id IS NULL LIMIT 1", "Trial lacks sealed outcome")
        self.none("SELECT 1 FROM outcomes o JOIN trials t USING(trial_id) WHERE o.attempt_id<>t.attempt_id OR o.role<>t.role OR o.rr<>t.rr LIMIT 1", "Outcome changes trial identity")
        self.none("SELECT 1 FROM entry_attempts a JOIN feature_snapshots f USING(snapshot_id) WHERE a.signal_id<>f.signal_id LIMIT 1", "Attempt changes snapshot signal")

    def verify_unchanged(self):
        require({p.name for p in self.path.iterdir()} == set(self.tables), "Source file set changed")
        for name, expected in self.hashes.items():
            path = self.path / name
            require(path.is_file() and not path.is_symlink(), "Source replaced")
            old, new = self.stats[name], path.stat()
            require((old.st_ino, old.st_size, old.st_mtime_ns) == (new.st_ino, new.st_size, new.st_mtime_ns) and digest(path) == expected, "Source changed during validation")

    def report(self):
        return dict(status="PASS", engine=self.profile.engine, schema_version=self.manifest["schema_version"],
                    feature_set=self.manifest["feature_set"], run_id=self.manifest["run_id"], counts=self.counts,
                    hashes=self.hashes, feature_gap_count=int(self.summary["feature_gap_count"]),
                    parity_excluded=True, instrument_mapping=self.manifest["mapping_status"])


def compatibility_signature(manifest: dict) -> tuple:
    excluded = {"run_id", "config_id", "producer_version", "compiler_build"}
    return tuple((key, manifest[key]) for key in MANIFEST_KEYS if key not in excluded)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.report and args.report.resolve().is_relative_to(args.run.resolve()):
        parser.error("Reports must be outside the sealed run")
    try:
        with ModelRun(args.run) as run:
            report = run.report()
    except (ContractError, OSError, ValueError) as exc:
        parser.exit(1, f"INVALID: {exc}\n")
    content = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(content)
    print(content, end="")


if __name__ == "__main__":
    main()
