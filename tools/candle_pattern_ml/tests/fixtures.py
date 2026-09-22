"""Tiny synthetic Candle wire fixture; no account or retained tester data."""

import csv
from pathlib import Path

from ..schema_contract import CONTEXT_COLUMNS, FEATURE_COLUMNS, NULL, TABLE_COLUMNS, column_type


def make_run(parent: Path, *, lot_type: str | None = None) -> Path:
    path = parent / "CANDLE_FIXTURE"
    path.mkdir()
    rows = {name: [] for name in TABLE_COLUMNS}

    def add(name, **values):
        row = dict.fromkeys(TABLE_COLUMNS[name], None)
        row.update(values)
        if "run_id" in row:
            row["run_id"] = path.name
        rows[name].append(row)
        return row

    manifest = {
        "schema_version": "1", "engine": "CANDLE_PATTERN_ATR_V1", "feature_set": "candle_pattern_macro_micro_v1",
        "run_id": path.name, "symbol": "CANDLE_TEST", "macro_seconds": "3600", "micro_seconds": "180",
        "atr_period": "13", "atr_shift": "1", "atr_multiplier": "1", "lot_size": "1", "point": "1",
        "tick_size": "1", "currency": "USD", "ratios": "1,2,3", "protection": "FIXED_SUBMITTED",
        "expiry": "ENTRY_PLUS_MACRO", "allowance": "BROKER_MACRO_CANDLE", "categories": "PATTERN_AND_RELATIONSHIP",
        "reentry": "BROKER_SL_ONCE", "broker_cap": "2048", "virtual_cap": "6144",
    }
    if lot_type is not None:
        manifest.update(schema_version="2", lot_type=lot_type, reference_balance="1000000")
        if lot_type == "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT":
            manifest["lot_size"] = "0.0005"
    for key, value in manifest.items():
        add("run_manifest.tsv", key=key, value=value)
    levels = dict(zip(("s3", "s2", "s1", "pp", "r1", "r2", "r3"), (70, 80, 90, 100, 110, 120, 130), strict=True))
    window = "CANDLE_TEST:3600:3600"
    add("macro_windows.tsv", window_id=window, open_time_msc=3600000, source_time_msc=1,
        macro_seconds=3600, source_open=100, source_high=110, source_low=90, source_close=100,
        valid=1, reason="OK", **{f"pivot_{key}": value for key, value in levels.items()})
    root = "CANDLE_TEST:180:3960:ENGULFING"
    add("signal_events.tsv", root_id=root, sequence=10, symbol="CANDLE_TEST", pattern="ENGULFING",
        pattern_direction="BULLISH", signal_bar_time_msc=3780000, decision_time_msc=3960000,
        micro_seconds=180, admission="DISCOVERED", previous_open=104, previous_high=105, previous_low=99,
        previous_close=100, pattern_open=99, pattern_high=106, pattern_low=98, pattern_close=105)
    for index, (category, direction, entry, sign) in enumerate((("ALIGNED", "BUY", 102, 1), ("OPPOSED", "SELL", 101, -1))):
        attempt = f"{root}:{category}:0"
        values = dict.fromkeys((*CONTEXT_COLUMNS, *FEATURE_COLUMNS), None)
        for column in values:
            if column_type(column) == "bool":
                values[column] = 0
        values.update({f"pivot_{level}_price": value for level, value in levels.items()})
        add("entry_attempts.tsv", attempt_id=attempt, root_id=root, sequence=11 + index,
            entry_type="ORIGINAL", pattern="ENGULFING", category=category, direction=direction,
            decision_time_msc=3960000, macro_window_id=window, macro_open_time_msc=3600000,
            macro_seconds=3600, micro_seconds=180, bid=101, ask=102, point=1, tick_size=1,
            atr_0=6, atr_1=5, atr_source_time_msc=3780000, atr_shift=1, atr_multiplier=1,
            requested_volume=1, entry_interval="PP_TO_R1", **values)
        sl = entry - sign * 5
        add("execution_checks.tsv", attempt_id=attempt, action="ENTRY", time_msc=3960000,
            sequence=11 + index, allowed=1, reason="ACCEPTED", bid=101, ask=102, volume=1,
            entry_price=entry, sl=sl, tp=entry + sign * 5, margin=1, stop_profit=-5,
            check_retcode=0, send_retcode=10009, order_ticket=100 + index, deal_ticket=100 + index)
        for lane, rr in (("BROKER", 1), ("VIRTUAL", 2), ("VIRTUAL", 3), ("PARITY", 1)):
            trial = f"{attempt}:{lane}:{rr}"
            tp = entry + sign * 5 * rr
            add("trials.tsv", trial_id=trial, attempt_id=attempt, lane=lane, rr=rr,
                reference_entry_time_msc=3960000, reference_deadline_msc=7560000,
                entry_price=entry, sl=sl, tp=tp, volume=1, eligibility="ACCEPTED" if lane == "BROKER" else "ELIGIBLE")
            add("outcomes.tsv", trial_id=trial, attempt_id=attempt, lane=lane, rr=rr, status="TP_FIRST",
                broker_reason="DEAL_REASON_TP" if lane == "BROKER" else None,
                entry_time_msc=3960000, entry_macro_open_time_msc=3600000, deadline_msc=7560000,
                exit_time_msc=4000000, observed_time_msc=4000000, entry_price=entry, exit_price=tp,
                sl=sl, tp=tp, volume=1, gross_profit=5 * rr, costs=-1 if lane == "BROKER" else None,
                net_profit=4 if lane == "BROKER" else None, gross_r=rr, binary_label=1,
                position_id=100 + index if lane == "BROKER" else None,
                fill_deviation_points=0 if lane == "BROKER" else None)
    for name in tuple(TABLE_COLUMNS)[:-1]:
        add("run_summary.tsv", key=f"rows_{name}", value=len(rows[name]))
    for key, value in {"broker_peak": "2", "virtual_peak": "6", "last_time_msc": "4000000",
                       "failure": "NONE", "completion": "NATURAL", "status": "OK"}.items():
        add("run_summary.tsv", key=key, value=value)
    for name, data in rows.items():
        with (path / name).open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=TABLE_COLUMNS[name], delimiter="\t")
            writer.writeheader()
            writer.writerows({key: NULL if value is None else value for key, value in row.items()} for row in data)
    return path


def mutate(path, filename, change):
    with (path / filename).open(newline="") as handle:
        data = list(csv.DictReader(handle, delimiter="\t"))
    change(data)
    with (path / filename).open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=TABLE_COLUMNS[filename], delimiter="\t")
        writer.writeheader()
        writer.writerows(data)
