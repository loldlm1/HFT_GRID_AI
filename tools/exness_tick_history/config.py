"""Strict configuration without network, terminal, or filesystem mutations."""

from __future__ import annotations

import math
import re
import tomllib
from dataclasses import dataclass
from datetime import date
from pathlib import Path, PureWindowsPath
from types import MappingProxyType
from typing import Mapping

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SYMBOL_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._&#-]{0,30}", re.ASCII)
ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", re.ASCII)
DATE_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2}", re.ASCII)
COMPARISON_DEFAULTS = {
    "max_match_delta_ms": 500,
    "min_matched_fraction_each_feed": 0.95,
    "min_active_minute_jaccard": 0.999,
    "max_p99_bid_error_ticks": 5,
    "max_p99_ask_error_ticks": 5,
    "max_p99_spread_error_ticks": 5,
    "max_p99_m1_ohlc_error_ticks": 5,
    "max_unexplained_clock_offset_seconds": 0,
}


class ConfigError(ValueError):
    """A profile cannot be interpreted safely."""


def validate_symbol(value: str, field: str = "symbol") -> str:
    if not isinstance(value, str) or not SYMBOL_PATTERN.fullmatch(value):
        raise ConfigError(f"{field} must be a safe symbol name of at most 31 characters")
    return value


def _table(raw: dict, name: str, allowed: set[str]) -> dict:
    result = raw.get(name, {})
    if not isinstance(result, dict):
        raise ConfigError(f"[{name}] must be a table")
    if result.keys() - allowed:
        raise ConfigError(f"Unknown fields in [{name}]; check the documented schema")
    return result


def _text(raw: dict, key: str, default: str, *, empty: bool = False) -> str:
    value = raw.get(key, default)
    if not isinstance(value, str) or (not value and not empty) or "\x00" in value:
        raise ConfigError(f"{key} must be {'a' if empty else 'a nonempty'} string")
    return value


def _choice(raw: dict, key: str, default: str, choices: tuple[str, ...]) -> str:
    value = _text(raw, key, default)
    if value not in choices:
        raise ConfigError(f"{key} must be one of: {', '.join(choices)}")
    return value


def _number(raw: dict, key: str, default: int | float, minimum: float,
            maximum: float, *, integer: bool = False) -> int | float:
    value = raw.get(key, default)
    types = (int,) if integer else (int, float)
    if (type(value) not in types or not minimum <= value <= maximum
            or not math.isfinite(value)):
        raise ConfigError(f"{key} must be {'an integer' if integer else 'a number'} in [{minimum}, {maximum}]")
    return value


def parse_date(value: object, field: str) -> date:
    if type(value) is date:
        return value
    if isinstance(value, str) and DATE_PATTERN.fullmatch(value):
        try:
            return date.fromisoformat(value)
        except ValueError:
            pass
    raise ConfigError(f"{field} must be a valid YYYY-MM-DD date")


@dataclass(frozen=True)
class Instrument:
    base_symbol: str
    archive_symbol: str
    account_type: str
    broker_symbol: str
    broker_suffix: str
    account_mode: str
    server_alias: str
    feed_mapping_status: str


@dataclass(frozen=True)
class Selection:
    start: date
    end: date | str
    granularity: str


@dataclass(frozen=True)
class Limits:
    max_archive_bytes: int
    max_uncompressed_bytes: int
    max_members: int
    max_expansion_ratio: int
    memory_limit_mb: int
    temp_limit_mb: int
    disk_reserve_bytes: int


@dataclass(frozen=True)
class Network:
    timeout_seconds: float
    workers: int
    max_retries: int
    retry_max_seconds: float


@dataclass(frozen=True)
class Terminal:
    platform: str
    wine_prefix: Path | None
    host_root: Path | None
    windows_root: PureWindowsPath | None

    def windows_path(self, path: Path) -> PureWindowsPath:
        if self.host_root is None or self.windows_root is None:
            raise ConfigError("Terminal host_root and windows_root must be configured")
        try:
            relative = path.resolve().relative_to(self.host_root)
        except ValueError as exc:
            raise ConfigError("The path is outside the configured terminal host_root") from exc
        return self.windows_root.joinpath(*relative.parts)


@dataclass(frozen=True)
class Profile:
    profile_id: str
    instrument: Instrument
    selection: Selection
    data_root: Path
    limits: Limits
    network: Network
    terminal: Terminal
    comparison_status: str
    comparison_limits: Mapping[str, int | float]

    def summary(self) -> dict:
        instrument = self.instrument
        unresolved = []
        if instrument.account_mode == "unverified":
            unresolved.append("reference_account_mode")
        if not instrument.server_alias:
            unresolved.append("reference_server_identity")
        if instrument.feed_mapping_status != "operator_confirmed":
            unresolved.append("archive_to_broker_feed_mapping")
        if self.terminal.host_root is None:
            unresolved.append("terminal_path_mapping")
        if self.comparison_status != "PINNED":
            unresolved.append("comparison_profile")
        return {
            "status": "CONFIG_VALID",
            "schema_version": 1,
            "profile_id": self.profile_id,
            "instrument": {
                "base_symbol": instrument.base_symbol,
                "archive_symbol": instrument.archive_symbol,
                "account_type": instrument.account_type,
                "broker_symbol": instrument.broker_symbol,
                "broker_suffix": instrument.broker_suffix,
                "account_mode": instrument.account_mode,
                "server_identity_configured": bool(instrument.server_alias),
                "feed_mapping_status": instrument.feed_mapping_status,
            },
            "selection": {
                "start": self.selection.start.isoformat(),
                "end_exclusive": str(self.selection.end),
                "granularity": self.selection.granularity,
                "latest_cutoff_resolved": self.selection.end != "latest-published",
            },
            "data_root": str(self.data_root),
            "terminal_platform": self.terminal.platform,
            "comparison_status": self.comparison_status,
            "comparison_limits": dict(self.comparison_limits),
            "unresolved_operational_requirements": unresolved,
            "native_specification_and_import_verification_required": True,
        }


def load_profile(path: Path, *, workspace: Path = PROJECT_ROOT) -> Profile:
    try:
        with path.open("rb") as stream:
            raw = tomllib.load(stream)
    except OSError as exc:
        raise ConfigError("Cannot read the configuration file") from exc
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError("Invalid TOML configuration") from exc
    allowed = {"schema_version", "profile_id", "instrument", "selection", "storage",
               "network", "terminal", "comparison"}
    if raw.keys() - allowed:
        raise ConfigError("Unknown top-level configuration fields")
    if type(raw.get("schema_version")) is not int or raw["schema_version"] != 1:
        raise ConfigError("schema_version must be integer 1")
    profile_id = _text(raw, "profile_id", "xauusd-pro")
    if not ID_PATTERN.fullmatch(profile_id):
        raise ConfigError("profile_id must be a safe identifier of at most 64 characters")

    item = _table(raw, "instrument", {"base_symbol", "archive_symbol", "account_type",
                  "broker_symbol", "broker_suffix", "account_mode", "server_alias", "feed_mapping_status"})
    base = validate_symbol(_text(item, "base_symbol", "XAUUSD"), "base_symbol")
    archive = validate_symbol(_text(item, "archive_symbol", base), "archive_symbol")
    suffix = _text(item, "broker_suffix", "", empty=True)
    if not re.fullmatch(r"[A-Za-z0-9._&#-]*", suffix, re.ASCII):
        raise ConfigError("broker_suffix contains unsupported characters")
    broker = validate_symbol(_text(item, "broker_symbol", base + suffix), "broker_symbol")
    if "broker_suffix" in item and "broker_symbol" in item and broker != base + suffix:
        raise ConfigError("broker_symbol conflicts with base_symbol plus broker_suffix")
    account_type = _choice(item, "account_type", "pro", ("pro", "standard", "raw_spread", "zero"))
    mode = _choice(item, "account_mode", "unverified", ("demo", "live", "unverified"))
    server = _text(item, "server_alias", "", empty=True)
    if server and not ID_PATTERN.fullmatch(server):
        raise ConfigError("server_alias must be an opaque safe identifier, not account credentials")
    mapping = _choice(item, "feed_mapping_status", "unverified", ("unverified", "operator_confirmed"))

    selected = _table(raw, "selection", {"start", "end", "granularity"})
    start = parse_date(selected.get("start", "2015-01-01"), "start")
    end_value = selected.get("end", "latest-published")
    end = "latest-published" if end_value == "latest-published" else parse_date(end_value, "end")
    if isinstance(end, date) and end <= start:
        raise ConfigError("end is exclusive and must be after start")
    granularity = _choice(selected, "granularity", "auto", ("auto", "year", "month", "day"))

    storage = _table(raw, "storage", {"data_root", "max_archive_bytes", "max_uncompressed_bytes",
                     "max_members", "max_expansion_ratio", "memory_limit_mb", "temp_limit_mb", "disk_reserve_bytes"})
    root = Path(_text(storage, "data_root", "artifacts/exness_tick_history")).expanduser()
    workspace = workspace.resolve()
    root = (workspace / root).resolve() if not root.is_absolute() else root.resolve()
    if root == Path(root.anchor) or root == Path.home().resolve() or root == workspace:
        raise ConfigError("data_root must be a dedicated data directory")
    if root.is_relative_to(workspace) and not root.is_relative_to(workspace / "artifacts/exness_tick_history"):
        raise ConfigError("An in-project data_root must be under artifacts/exness_tick_history")
    limits = Limits(
        _number(storage, "max_archive_bytes", 4 * 1024**3, 1, 1024**4, integer=True),
        _number(storage, "max_uncompressed_bytes", 32 * 1024**3, 1, 8 * 1024**4, integer=True),
        _number(storage, "max_members", 128, 1, 4096, integer=True),
        _number(storage, "max_expansion_ratio", 200, 1, 10000, integer=True),
        _number(storage, "memory_limit_mb", 512, 64, 1048576, integer=True),
        _number(storage, "temp_limit_mb", 4096, 1, 104857600, integer=True),
        _number(storage, "disk_reserve_bytes", 1024**3, 0, 1024**4, integer=True),
    )
    net = _table(raw, "network", {"timeout_seconds", "workers", "max_retries", "retry_max_seconds"})
    network = Network(
        _number(net, "timeout_seconds", 30, 1, 300),
        _number(net, "workers", 2, 1, 8, integer=True),
        _number(net, "max_retries", 4, 0, 10, integer=True),
        _number(net, "retry_max_seconds", 60, 1, 600),
    )

    term = _table(raw, "terminal", {"platform", "wine_prefix", "host_root", "windows_root"})
    platform = _choice(term, "platform", "wine", ("wine", "windows"))
    wine_prefix = _text(term, "wine_prefix", "", empty=True)
    host = _text(term, "host_root", "", empty=True)
    windows = _text(term, "windows_root", "", empty=True)
    if bool(host) != bool(windows):
        raise ConfigError("terminal host_root and windows_root must be configured together")
    if host and not Path(host).expanduser().is_absolute():
        raise ConfigError("terminal host_root must be absolute")
    if wine_prefix and not Path(wine_prefix).expanduser().is_absolute():
        raise ConfigError("wine_prefix must be absolute")
    win_path = PureWindowsPath(windows) if windows else None
    if win_path is not None and (not win_path.is_absolute() or ".." in win_path.parts):
        raise ConfigError("terminal windows_root must be an absolute Windows path without traversal")
    terminal = Terminal(platform, Path(wine_prefix).expanduser().resolve() if wine_prefix else None,
                        Path(host).expanduser().resolve() if host else None, win_path)

    comparison = _table(raw, "comparison", {"status", *COMPARISON_DEFAULTS})
    status = _choice(comparison, "status", "PROPOSED", ("PROPOSED", "PINNED"))
    if status == "PINNED" and not COMPARISON_DEFAULTS.keys() <= comparison.keys():
        raise ConfigError("A PINNED comparison profile must explicitly set every threshold")
    thresholds = {}
    for key, default in COMPARISON_DEFAULTS.items():
        maximum = 1 if key.startswith("min_") else 86400000
        minimum = 0.000001 if key.startswith("min_") else 0
        thresholds[key] = _number(comparison, key, default, minimum, maximum,
                                  integer=key.endswith("_ms") or key.endswith("_seconds"))
    if thresholds["max_unexplained_clock_offset_seconds"] != 0:
        raise ConfigError("Exact clock alignment requires max_unexplained_clock_offset_seconds = 0")
    return Profile(profile_id, Instrument(base, archive, account_type, broker, suffix, mode, server, mapping),
                   Selection(start, end, granularity), root, limits, network, terminal,
                   status, MappingProxyType(thresholds))
