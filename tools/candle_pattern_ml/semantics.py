"""Semantic checks shared by the strict reader and its behavior fixtures."""

from decimal import Decimal
import re

from .clock import analysis_clock
from .schema_contract import LEVELS, TIMESTAMP_COLUMNS, analysis_columns


def validate_clocks(run):
    from .reader import ContractError, require

    if run.manifest["schema_version"] != "3":
        return
    session = run.manifest["broker_session"]

    def check(row, column):
        analysis_column, offset_column = analysis_columns(column)
        raw, analysis, offset = (row[key] for key in (column, analysis_column, offset_column))
        if raw is None:
            require(analysis is None and offset is None, f"Clock null mismatch: {column}")
            return
        require(analysis is not None and offset is not None, f"Missing analysis clock: {column}")
        require(all(re.fullmatch(r"-?(0|[1-9][0-9]*)", value) is not None and
                    -(2**63) <= int(value) < 2**63 for value in (raw, analysis, offset)),
                f"Invalid clock integer: {column}")
        try:
            expected = analysis_clock(int(raw), session)
            actual = (int(analysis), int(offset))
        except ValueError as exc:
            raise ContractError(f"Invalid clock {column}: {exc}") from exc
        require(actual == expected, f"Analysis clock mismatch: {column}")

    for filename, columns in TIMESTAMP_COLUMNS.items():
        for row in run.rows(filename):
            for column in columns:
                check(row, column)
    check(run.summary, "last_time_msc")
    require(run.summary["last_time_msc"] is not None or
            not any(run.counts[name] for name, columns in TIMESTAMP_COLUMNS.items() if columns),
            "Missing final clock for a nonempty run")


def validate_details(run):
    # Import here so the reader remains the public error/type boundary.
    from .reader import number, require

    macro = int(run.manifest["macro_seconds"])
    point = number(run.manifest["point"])
    tick = number(run.manifest["tick_size"])
    tolerance = tick * Decimal("0.000001")
    validate_clocks(run)
    sizing_version = run.manifest["schema_version"] in {"2", "3"}
    reference_sizing = sizing_version and run.manifest["lot_type"] == "EXECUTION_LOT_REFERENCE_BALANCE_PERCENT"
    risk_budget = number(run.manifest["reference_balance"]) * number(run.manifest["lot_size"]) / 100 if reference_sizing else None

    def near(actual, expected, message, absolute_tolerance=Decimal(0)):
        require(actual is not None and expected is not None and
                abs(actual - expected) <= max(absolute_tolerance, max(abs(expected), Decimal(1)) * Decimal("1e-11")), message)

    for table, clock in (("signal_events", "decision_time_msc"), ("entry_attempts", "decision_time_msc")):
        previous = (-1, -1)
        for row in run.rows(f"{table}.tsv"):
            current = (int(row[clock]), int(row["sequence"]))
            require(current[0] >= previous[0] and current[1] > previous[1], "Unordered causal sequence")
            previous = current

    for row in run.rows("entry_attempts.tsv"):
        root = run.db.execute("SELECT * FROM signal_events WHERE root_id=?", (row["root_id"],)).fetchone()
        require(int(row["sequence"]) > int(root["sequence"]), "Attempt precedes signal sequence")
        near(number(row["point"]), point, "Point changed")
        near(number(row["tick_size"]), tick, "Tick size changed")
        requested_volume = number(row["requested_volume"])
        require((reference_sizing and requested_volume is None) or
                (requested_volume is not None and requested_volume > 0), "Missing requested volume")
        if sizing_version and not reference_sizing:
            near(requested_volume, number(run.manifest["lot_size"]), "Fixed requested volume differs from lot size")
        require(row["macro_window_id"] is not None, "Missing broker Macro membership")
        if row["entry_type"] == "ORIGINAL":
            require(row["decision_time_msc"] == root["decision_time_msc"], "Original is not at discovery")
        else:
            parent = run.db.execute("SELECT sequence FROM entry_attempts WHERE attempt_id=?", (row["parent_attempt_id"],)).fetchone()
            require(int(row["sequence"]) > int(parent["sequence"]), "Re-entry precedes parent sequence")
        window = run.db.execute("SELECT * FROM macro_windows WHERE window_id=?", (row["macro_window_id"],)).fetchone()
        candidates = []
        prices = []
        for index, level in enumerate(LEVELS):
            prefix = f"pivot_{level.lower()}"
            price = number(row[f"{prefix}_price"])
            require(price == number(window[prefix]), "Context changed its Macro ladder")
            prices.append(price)
            touched = row[f"{prefix}_touch_time_msc"]
            sequence = row[f"{prefix}_touch_sequence"]
            role = row[f"{prefix}_role"]
            if touched is None:
                require(sequence is None and role is None and row[f"{prefix}_reclaimed"] == "0" and
                        row[f"{prefix}_gap_cross"] == "0", "Untested pivot has evidence")
            else:
                require(sequence is not None and 0 < int(sequence) < int(row["sequence"]), "Future pivot evidence")
                require(role in ({"SUPPORT"} if index < 3 else {"RESISTANCE"} if index > 3 else {"SUPPORT", "RESISTANCE"}), "Wrong tested pivot role")
                candidates.append((int(sequence), abs(index - 3), level, int(touched), role))
        quote = number(row["ask"] if row["direction"] == "BUY" else row["bid"])
        if window["valid"] == "1":
            interval = "ABOVE_R3"
            for index, price in enumerate(prices):
                if quote == price:
                    interval = f"AT_{LEVELS[index]}"
                    break
                if quote < price:
                    interval = "BELOW_S3" if index == 0 else f"{LEVELS[index - 1]}_TO_{LEVELS[index]}"
                    break
            require(row["entry_interval"] == interval, "Wrong executable entry interval")
        else:
            require(row["entry_interval"] is None and not candidates, "Invalid ladder has context")
        if candidates:
            latest = max(candidates)
            require(row["context_level"] == latest[2] and row["context_role"] == latest[4], "Context is not latest/outermost tested pivot")
            require(int(row["context_age_ms"]) == int(row["decision_time_msc"]) - latest[3], "Wrong context age")
            near(number(row["context_distance_points"]), (quote - prices[LEVELS.index(latest[2])]) / point, "Wrong context distance", abs(quote / point) * Decimal("4e-16"))
        else:
            require(all(row[key] is None for key in ("context_level", "context_role", "context_age_ms", "context_distance_points")), "Context without test evidence")

        for prefix in ("macro", "micro"):
            for series in ("b_percent", "pivot_b_percent", "stochastic_main_line", "stochastic_signal_line"):
                complete = row[f"{prefix}_pivot_complete" if series == "pivot_b_percent" else f"{prefix}_complete"] == "1"
                for shift in range(6):
                    key = f"{prefix}_{series}"
                    raw, sma, slope = (number(row[f"{key}{suffix}_{shift}"]) for suffix in ("", "_sma_5", "_sma_slope"))
                    state = row[f"{key}_state_{shift}"]
                    values = (raw, sma, slope, state)
                    require(all(value is not None for value in values) or all(value is None for value in values), "Partial feature tuple")
                    if complete:
                        require(raw is not None, "Incomplete feature marked complete")
                    if raw is None:
                        continue
                    difference = raw - sma
                    expected_state = "ABOVE" if difference > Decimal("1e-7") else "BELOW" if difference < Decimal("-1e-7") else "EQUAL"
                    require(state == expected_state, "Feature state mismatch")
                    if series.startswith("stochastic"):
                        require(Decimal("-1e-7") <= raw <= Decimal("100.0000001"), "Stochastic outside domain")
                    if shift < 5 and row[f"{key}_sma_5_{shift + 1}"] is not None:
                        near(slope, sma - number(row[f"{key}_sma_5_{shift + 1}"]), "Feature slope mismatch")
                    if shift < 2 and all(row[f"{key}_{i}"] is not None for i in range(shift, shift + 5)):
                        near(sma, sum(number(row[f"{key}_{i}"]) for i in range(shift, shift + 5)) / 5, "Feature SMA mismatch")
            if row[f"{prefix}_complete"] == "1":
                require(number(row[f"{prefix}_band_width_points_0"]) > 0, "Invalid band width")
                for shift in range(6):
                    require(number(row[f"{prefix}_band_base_line_{shift}"]) > 0 and
                            row[f"{prefix}_band_base_line_slope_points_{shift}"] is not None, "Missing band base")
                    if shift < 5:
                        near(number(row[f"{prefix}_band_base_line_slope_points_{shift}"]),
                             (number(row[f"{prefix}_band_base_line_{shift}"]) - number(row[f"{prefix}_band_base_line_{shift + 1}"])) / point,
                             "Band base slope mismatch", abs(number(row[f"{prefix}_band_base_line_{shift}"]) / point) * Decimal("4e-16"))
            if row[f"{prefix}_pivot_complete"] == "1":
                require(bool(candidates), "Pivot feature has no context")

    for row in run.rows("trials.tsv"):
        rr = int(row["rr"])
        lane = row["lane"]
        require((lane in {"BROKER", "PARITY"} and rr == 1) or (lane == "VIRTUAL" and rr in {2, 3}), "Unknown lane/ratio")
        require(row["trial_id"] == f'{row["attempt_id"]}:{lane}:{rr}', "Trial identity mismatch")
        attempt = run.db.execute("SELECT * FROM entry_attempts WHERE attempt_id=?", (row["attempt_id"],)).fetchone()
        direction = 1 if attempt["direction"] == "BUY" else -1
        entry, sl, tp = (number(row[key]) for key in ("entry_price", "sl", "tp"))
        reference = int(row["reference_entry_time_msc"])
        require(reference >= int(attempt["decision_time_msc"]) and int(row["reference_deadline_msc"]) == reference + macro * 1000, "Wrong submitted chronology")
        if row["eligibility"] in {"ACCEPTED", "ELIGIBLE"}:
            require(None not in (entry, sl, tp) and min(entry, sl, tp) > 0 and number(row["volume"]) > 0, "Invalid eligible geometry/volume")
        if None not in (entry, sl, tp):
            risk = direction * (entry - sl)
            require(risk > 0 and abs(tp - entry - direction * rr * risk) <= tolerance, "Wrong reward geometry")
            atr = number(attempt["atr_1"])
            require(atr is not None and atr - tolerance <= risk < atr + tick + tolerance, "Stop does not use ATR shift 1")
            for price in (sl, tp):
                require(abs(price / tick - (price / tick).to_integral_value()) <= Decimal("0.000001"), "Protection off tick grid")
        outcome = run.db.execute("SELECT * FROM outcomes WHERE trial_id=?", (row["trial_id"],)).fetchone()
        require(outcome["sl"] == row["sl"] and outcome["tp"] == row["tp"], "Submitted protection changed")
        if lane != "BROKER":
            if sizing_version:
                broker = run.db.execute("SELECT * FROM trials WHERE attempt_id=? AND lane='BROKER'", (row["attempt_id"],)).fetchone()
                require(all(row[key] == broker[key] for key in ("entry_price", "sl", "volume", "reference_entry_time_msc")), "Ratio changed shared execution sizing")
            require(row["eligibility"] in {"ELIGIBLE", "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY", "CAPACITY_REJECTED"}, "Unknown virtual eligibility")
            if row["eligibility"] == "ELIGIBLE":
                require(outcome["entry_price"] == row["entry_price"] and outcome["entry_time_msc"] == row["reference_entry_time_msc"] and outcome["volume"] == row["volume"], "Virtual entry changed")
            else:
                require(outcome["status"] == row["eligibility"] and outcome["entry_time_msc"] is None, "Ineligible virtual was entered")
        else:
            require(row["eligibility"] in {"ACCEPTED", "REJECTED"}, "Unresolved broker admission")
            checks = run.db.execute("SELECT * FROM execution_checks WHERE attempt_id=? AND action='ENTRY'", (row["attempt_id"],)).fetchall()
            require(len(checks) == 1, "Expected one broker entry check")
            check = checks[0]
            accepted = row["eligibility"] == "ACCEPTED"
            if reference_sizing:
                stop_profit = number(check["stop_profit"])
                require(not accepted or (stop_profit is not None and stop_profit < 0), "Missing reference stop risk")
                if stop_profit is not None:
                    require(stop_profit < 0 and -stop_profit <= risk_budget * Decimal("1.000000001"), "Submitted volume exceeds reference risk budget")
            require((check["reason"] == "ACCEPTED") == accepted, "Broker admission mismatch")
            require(check["entry_price"] == row["entry_price"] and check["sl"] == row["sl"] and check["tp"] == row["tp"] and check["volume"] == row["volume"], "Trial changed request")
            if accepted:
                require(check["allowed"] == "1" and check["send_retcode"] in {"10008", "10009"} and (check["order_ticket"] or check["deal_ticket"]), "Unconfirmed broker acceptance")
            else:
                require(outcome["status"] == "REJECTED", "Rejected broker entry has an outcome")
            parity = run.db.execute("SELECT * FROM trials WHERE attempt_id=? AND lane='PARITY'", (row["attempt_id"],)).fetchall()
            require(len(parity) == int(accepted), "Parity cardinality mismatch")
            if parity:
                require(all(parity[0][key] == row[key] for key in ("entry_price", "sl", "tp", "volume", "reference_entry_time_msc")), "Parity changed submitted request")

    for row in run.rows("outcomes.tsv"):
        trial = run.db.execute("SELECT * FROM trials WHERE trial_id=?", (row["trial_id"],)).fetchone()
        entered = row["entry_time_msc"] is not None
        completed = row["status"] in {"SL_FIRST", "TP_FIRST", "TIME_EXIT", "OTHER_CLOSE"}
        require(not completed or entered, "Completed outcome was never entered")
        if not entered:
            require(all(row[key] is None for key in ("entry_price", "entry_macro_open_time_msc", "exit_time_msc", "exit_price", "gross_profit", "costs", "net_profit", "gross_r", "position_id", "fill_deviation_points")), "Unentered outcome has execution facts")
            continue
        require(int(row["entry_time_msc"]) >= int(trial["reference_entry_time_msc"]), "Fill precedes request")
        if completed:
            require(row["exit_price"] is not None and row["gross_profit"] is not None, "Completed exit lacks price/money")
        if row["status"] == "CENSORED_RUN_END":
            require(row["gross_r"] is None and row["gross_profit"] is None and row["net_profit"] is None, "Run censor has realized returns")
        if row["lane"] == "BROKER":
            require(row["position_id"] is not None and int(row["position_id"]) > 0, "Missing broker position identity")
            near(number(row["fill_deviation_points"]), (number(row["entry_price"]) - number(trial["entry_price"])) / point, "Fill deviation mismatch", abs(number(row["entry_price"]) / point) * Decimal("4e-16"))
            if completed:
                require(row["costs"] is not None and row["net_profit"] is not None, "Missing broker costs")
        else:
            require(row["position_id"] is None and row["fill_deviation_points"] is None and row["costs"] is None and row["net_profit"] is None, "Virtual outcome fabricated broker facts")
            require(row["status"] != "OTHER_CLOSE", "Virtual trial has external close")
        if completed:
            attempt = run.db.execute("SELECT direction FROM entry_attempts WHERE attempt_id=?", (row["attempt_id"],)).fetchone()
            direction = 1 if attempt["direction"] == "BUY" else -1
            entry, exit_price, sl, tp = (number(row[key]) for key in ("entry_price", "exit_price", "sl", "tp"))
            risk = direction * (entry - sl)
            if risk > 0:
                near(number(row["gross_r"]), direction * (exit_price - entry) / risk, "Wrong realized R")
            if row["lane"] != "BROKER" and row["status"] == "SL_FIRST":
                require(direction * (exit_price - sl) <= tolerance, "Virtual SL without touch")
            if row["lane"] != "BROKER" and row["status"] == "TP_FIRST":
                require(direction * (exit_price - tp) >= -tolerance, "Virtual TP without touch")
