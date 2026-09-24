"""Cross-engine causality, feature, geometry and terminal-state checks."""

from decimal import Decimal, ROUND_HALF_UP

from .feature_contract import SERIES, pivot_zone
from .reader import integer, near, number, require
from .schema_contract import LEVELS


def validate(run):
    manifest = run.manifest
    tick = number(manifest["tick_size"])
    macro, micro = int(manifest["macro_seconds"]), int(manifest["micro_seconds"])
    for row in run.rows("macro_windows.tsv"):
        require(int(row["macro_seconds"]) == macro, "Window role mismatch")
        if row["valid"] != "1":
            require(row["reason"] != "OK", "Invalid window marked valid")
            continue
        require(0 < integer(row["source_time_msc"]) < integer(row["open_time_msc"]), "Non-causal pivot source")
        require(integer(row["open_time_msc"]) % 1000 == 0, "Invalid native bar clock")
        opening, high, low, close = (number(row["source_" + key]) for key in ("open", "high", "low", "close"))
        require(0 < low <= min(opening, close) <= max(opening, close) <= high and high > low, "Invalid source candle")
        pp = (high + low + close) / 3
        raw = (low - 2 * (high - pp), pp - high + low, 2 * pp - high, pp,
               2 * pp - low, pp + high - low, high + 2 * (pp - low))
        prices = []
        for level, expected in zip(LEVELS, raw, strict=True):
            near(number(row["raw_" + level.lower() + "_price"]), expected, "Raw pivot formula", tick * Decimal("0.000001"))
            normalized = (expected / tick).quantize(Decimal(1), rounding=ROUND_HALF_UP) * tick
            price = number(row["trade_" + level.lower() + "_price"])
            near(price, normalized, "Pivot tick normalization", tick * Decimal("0.000001"))
            prices.append(price)
        require(all(a < b for a, b in zip(prices, prices[1:])), "Unordered pivot ladder")
    for filename in ("signal_events.tsv", "entry_attempts.tsv", "feature_snapshots.tsv"):
        last_sequence = -1
        for row in run.rows(filename):
            require(integer(row["sequence"]) > last_sequence, "Non-monotonic observed sequence: " + filename)
            last_sequence = integer(row["sequence"])
            require(0 < number(row["bid"]) <= number(row["ask"]), "Invalid observed quote")
    for row in run.rows("signal_events.tsv"):
        require(row["symbol"] == manifest["symbol"] and row["direction"] in {"BUY", "SELL"}, "Invalid signal identity")
        if row["source_time_msc"] is not None:
            require(integer(row["source_time_msc"]) <= integer(row["signal_time_msc"]), "Future signal source")
    for row in run.rows("entry_attempts.tsv"):
        signal = run.one("signal_events.tsv", "signal_id", row["signal_id"])
        snapshot = run.one("feature_snapshots.tsv", "snapshot_id", row["snapshot_id"])
        require(row["direction"] in {"BUY", "SELL"}, "Invalid attempt direction")
        require(integer(row["decision_time_msc"]) >= integer(signal["signal_time_msc"]) and integer(row["sequence"]) >= integer(signal["sequence"]), "Attempt precedes discovery")
        require(integer(snapshot["observed_time_msc"]) <= integer(row["decision_time_msc"]) and integer(snapshot["sequence"]) <= integer(row["sequence"]), "Future snapshot")
        require(row["macro_window_id"] == snapshot["macro_window_id"], "Snapshot/window identity mismatch")
        if manifest["engine"] == "CANDLE_PATTERN_ATR_V2":
            require(snapshot["observed_time_msc"] == row["decision_time_msc"] and snapshot["bid"] == row["bid"] and snapshot["ask"] == row["ask"], "Candle recaptured decision quote")
    gaps = 0
    for row in run.rows("feature_snapshots.tsv"):
        validate_snapshot(run, row, macro, micro)
        gaps += row["complete"] == "0"
    require(integer(run.summary["feature_gap_count"]) == gaps, "Feature gap count mismatch")
    validate_trials(run, tick)
    if manifest["engine"] == "CANDLE_PATTERN_ATR_V2":
        from .engines.candle import validate as engine_validate
    else:
        from .engines.pivot import validate as engine_validate
    engine_validate(run)


def validate_snapshot(run, row, macro, micro):
    now = integer(row["observed_time_msc"])
    require(integer(run.summary["first_time_msc"]) <= now <= integer(run.summary["last_time_msc"]), "Capture outside run bounds")
    require((integer(row["macro_seconds"]), integer(row["micro_seconds"])) == (macro, micro), "Feature role mismatch")
    for key in ("point", "tick_size"):
        require(number(row[key]) == number(run.manifest[key]), "Feature instrument specification changed")
    expected_stage = "CANDLE_DECISION" if run.profile.engine == "CANDLE_PATTERN_ATR_V2" else "PIVOT_ORIGIN"
    require(row["capture_stage"] == expected_stage, "Unexpected capture stage")
    for role in ("macro", "micro"):
        source = [row[f"{role}_source_{s}_time_msc"] for s in range(6)]
        present = [integer(t) for t in source if t is not None]
        require(all(t <= now for t in present) and all(a > b for a, b in zip(present, present[1:])), "Non-causal feature source bars")
        family_flags = []
        for family, series in (("stochastic", SERIES[:2]), ("percent_b", SERIES[2:4]), ("atr", SERIES[4:])):
            complete = row[f"{role}_{family}_complete"] == "1"
            values = [number(row[f"{role}_{name}_{s}"]) for name in series for s in range(6)]
            require(complete == all(v is not None for v in values), "Family completeness mismatch")
            require(complete or all(v is None for v in values), "Partial family values")
            if complete:
                require(len(present) == 6, "Missing feature source clocks")
                if family == "stochastic":
                    require(all(0 <= v <= 100 for v in values), "Stochastic outside native range")
                if family == "atr":
                    require(all(v >= 0 for v in values), "Negative ATR")
                if family != "stochastic":
                    for s in (0, 1):
                        expected = sum(values[s:s + 5], Decimal(0)) / 5
                        near(values[6 + s], expected, "SMA5 alignment", max(Decimal("1e-9"), abs(expected) * Decimal("1e-12")))
            family_flags.append(complete)
        require((row[role + "_complete"] == "1") == all(family_flags), "Role completeness mismatch")
    if row["pivot_complete"] == "1":
        window = run.one("macro_windows.tsv", "window_id", row["macro_window_id"])
        require(window["valid"] == "1", "Context uses invalid ladder")
        prices = tuple(number(window[f"trade_{level.lower()}_price"]) for level in LEVELS)
        zone, lower, upper = pivot_zone(number(row["bid"]), prices)
        require(row["signal_zone"] == zone and number(row["zone_lower_price"]) == lower and number(row["zone_upper_price"]) == upper, "Signal zone mismatch")
        touched = []
        for index, (level, price) in enumerate(zip(LEVELS, prices, strict=True)):
            prefix = f"pivot_{level.lower()}"
            require(number(row[prefix + "_price"]) == price, "Context changed ladder")
            facts = [row[prefix + suffix] for suffix in ("_touch_time_msc", "_touch_sequence", "_role")]
            require(all(v is None for v in facts) or all(v is not None for v in facts), "Partial pivot touch")
            if facts[0] is None:
                require(row[prefix + "_reclaimed"] == row[prefix + "_gap_cross"] == "0", "Untested pivot has touch flags")
                continue
            at, sequence, role = integer(facts[0]), integer(facts[1]), facts[2]
            require(integer(window["open_time_msc"]) <= at <= now and 0 < sequence <= integer(row["sequence"]), "Touch outside causal Macro window")
            allowed_roles = {"SUPPORT", "RESISTANCE"} if index == 3 else {"SUPPORT" if index < 3 else "RESISTANCE"}
            require(role in allowed_roles, "Pivot touch role mismatch")
            if index == 3:
                require(window["pp_arm_time_msc"] is not None and integer(window["pp_arm_time_msc"]) <= at and window["pp_role"] == role, "PP touch lacks departure")
            touched.append((sequence, abs(index - 3), level))
        if touched:
            latest = max((sequence, depth) for sequence, depth, _ in touched)
            require(row["tested_level"] in {level for sequence, depth, level in touched if (sequence, depth) == latest}, "Tested pivot is not latest outermost touch")
            prefix = "pivot_" + row["tested_level"].lower()
            for suffix in ("touch_time_msc", "role", "reclaimed", "gap_cross"):
                require(row["tested_" + suffix] == row[prefix + "_" + suffix], "Selected pivot touch facts disagree")
            require(row["tested_sequence"] == row[prefix + "_touch_sequence"], "Selected pivot sequence disagrees")
        else:
            require(row["tested_level"] is None, "Selected pivot was never touched")
        if row["tested_level"] is None:
            require(row["signal_vs_tested_pivot"] == "UNTESTED", "Missing tested pivot is not UNTESTED")
            require(all(row[key] is None for key in ("tested_price", "tested_role", "tested_distance_price", "tested_distance_points", "tested_age_ms", "tested_touch_time_msc", "tested_sequence", "tested_reclaimed", "tested_gap_cross")), "Untested context contains touch facts")
        else:
            require(row["tested_level"] in LEVELS and row["tested_role"] in {"SUPPORT", "RESISTANCE"}, "Invalid tested level")
            price = prices[LEVELS.index(row["tested_level"])]
            bid = number(row["bid"])
            relationship = ("ABOVE" if bid > price else "BELOW" if bid < price else "AT") + "_" + row["tested_role"]
            require(row["signal_vs_tested_pivot"] == relationship and number(row["tested_price"]) == price, "Tested pivot relationship mismatch")
            near(number(row["tested_distance_price"]), bid - price, "Tested price distance")
            near(number(row["tested_distance_points"]), (bid - price) / number(row["point"]), "Tested point distance", Decimal("0.00001"))
            require(integer(row["tested_age_ms"]) == now - integer(row["tested_touch_time_msc"]) >= 0 and integer(row["tested_sequence"]) <= integer(row["sequence"]), "Non-causal touch")
    else:
        require(row["signal_zone"] is None and row["signal_vs_tested_pivot"] is None, "Missing ladder fabricated a zone")
    for side in ("high", "low", "event"):
        prefix = "confirmed_" + side
        group = ("kind", "class", "price", "pivot_time_msc", "confirmation_time_msc")
        values = [row[prefix + "_" + field] for field in group]
        require(all(v is None for v in values) or all(v is not None for v in values), "Partial confirmed structure")
        if all(v is not None for v in values):
            validate_class(row[prefix + "_kind"], row[prefix + "_class"])
            require(side == "event" or row[prefix + "_kind"] == side.upper(), "Confirmed high/low ownership mismatch")
            require(integer(row[prefix + "_pivot_time_msc"]) < integer(row[prefix + "_confirmation_time_msc"]) <= now, "Future structure confirmation")
            require(integer(row[prefix + "_confirmation_time_msc"]) <= integer(row["structure_observed_bar_time_msc"]), "Live observation committed confirmation")
    require(row["forming_status"] in {"FORMING", "INITIAL", "UNAVAILABLE"}, "Invalid forming status")
    if row["structure_complete"] == "1":
        require(integer(row["structure_observed_bar_time_msc"]) <= now and row["forming_status"] != "UNAVAILABLE", "Missing current structure source")
        if row["structure_last_closed_time_msc"] is not None:
            require(integer(row["structure_last_closed_time_msc"]) < integer(row["structure_observed_bar_time_msc"]), "Structure committed a forming candle")
    else:
        require(row["forming_status"] == "UNAVAILABLE", "Incomplete structure exposes a live candidate")
    if row["forming_status"] == "FORMING":
        validate_class(row["forming_kind"], row["forming_class"])
        require(number(row["forming_price"]) > 0 and integer(row["forming_pivot_time_msc"]) <= now, "Invalid forming pivot")
    else:
        require(all(row[k] is None for k in ("forming_kind", "forming_class", "forming_price", "forming_pivot_time_msc")), "Fabricated forming candidate")
    require((row["complete"] == "1") == all(row[k] == "1" for k in ("macro_complete", "micro_complete", "pivot_complete", "structure_complete")), "Snapshot completeness mismatch")


def validate_class(kind, classification):
    require(kind in {"HIGH", "LOW"}, "Invalid structure kind")
    require(classification in ({"HIGH", "HH", "LH", "EQ"} if kind == "HIGH" else {"LOW", "HL", "LL", "EQ"}), "Structure class/kind mismatch")


def validate_trials(run, tick):
    tolerance = tick * Decimal("0.000001")
    completed = {"TP_FIRST", "SL_FIRST", "TIME_EXIT", "OTHER_CLOSE"}
    statuses = completed | {"CENSORED_RUN_END", "REJECTED", "NOT_TRIGGERED", "CAPACITY_REJECTED",
                            "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY", "INELIGIBLE_MONEY_PLAN"}
    for trial in run.rows("trials.tsv"):
        require(trial["role"] in {"BROKER", "VIRTUAL", "PARITY"}, "Invalid trial role")
        require(integer(trial["rr"]) in {1, 2, 3, 5}, "Invalid trial ratio")
        attempt = run.one("entry_attempts.tsv", "attempt_id", trial["attempt_id"])
        direction = 1 if attempt["direction"] == "BUY" else -1
        entry, sl, tp = (number(trial[k]) for k in ("entry_price", "sl", "tp"))
        allowed_eligibility = {"ACCEPTED", "REJECTED"} if trial["role"] == "BROKER" else {"ELIGIBLE", "NOT_TRIGGERED", "CAPACITY_REJECTED", "INELIGIBLE_GEOMETRY", "INELIGIBLE_DISTANCE", "INELIGIBLE_MONEY", "INELIGIBLE_MONEY_PLAN"}
        require(trial["eligibility"] in allowed_eligibility, "Unknown trial eligibility")
        eligible = trial["eligibility"] in {"ELIGIBLE", "ACCEPTED"}
        if eligible:
            require(None not in (entry, sl, tp) and number(trial["volume"]) > 0, "Missing eligible geometry")
            risk = direction * (entry - sl)
            require(risk > 0, "Non-positive risk")
            near(tp, entry + direction * integer(trial["rr"]) * risk, "Incorrect integer-R target", tolerance)
        outcome = run.one("outcomes.tsv", "trial_id", trial["trial_id"])
        require(outcome["status"] in statuses, "Unknown terminal status")
        require(all(trial[k] == outcome[k] for k in ("sl", "tp", "volume")), "Submitted geometry changed")
        done, entered = outcome["status"] in completed, outcome["entry_time_msc"] is not None
        require(not done or entered, "Completed unentered trial")
        if entered:
            require(integer(outcome["entry_time_msc"]) >= integer(trial["declared_time_msc"]), "Entry precedes declaration")
            require(number(outcome["entry_price"]) > 0, "Missing entry price")
        if done:
            duration = integer(outcome["exit_time_msc"]) - integer(outcome["entry_time_msc"])
            require(integer(outcome["duration_ms"]) == duration >= 0, "Duration mismatch")
            require(integer(outcome["observed_time_msc"]) >= integer(outcome["exit_time_msc"]), "Close observed before it happened")
            require(number(outcome["exit_price"]) > 0, "Missing close price")
        else:
            require(outcome["duration_ms"] is None and outcome["exit_time_msc"] is None, "Censor/unentered has a completed clock")
        require((outcome["binary_label"] is not None) == (outcome["binary_eligible"] == "1"), "Binary eligibility mismatch")
        if outcome["binary_eligible"] == "1":
            require(outcome["role"] != "PARITY" and outcome["status"] in {"TP_FIRST", "SL_FIRST"} and outcome["binary_label"] == ("1" if outcome["status"] == "TP_FIRST" else "0"), "Invalid target label")
        if outcome["role"] != "BROKER":
            require(all(outcome[k] is None for k in ("costs", "net_profit", "position_id", "fill_deviation_points")), "Virtual result fabricated broker facts")
            if outcome["status"] == "TP_FIRST":
                require(direction * (number(outcome["exit_price"]) - tp) >= -tolerance, "Virtual target without touch")
            if outcome["status"] == "SL_FIRST":
                require(direction * (number(outcome["exit_price"]) - sl) <= tolerance, "Virtual stop without touch")
        if outcome["net_profit"] is not None:
            near(number(outcome["net_profit"]), number(outcome["gross_profit"]) + number(outcome["costs"]), "Net profit mismatch", Decimal("0.00001"))
        if done and outcome["gross_r"] is not None:
            actual = number(outcome["entry_price"])
            risk = direction * (actual - sl)
            require(risk > 0, "Invalid realized risk")
            near(number(outcome["gross_r"]), direction * (number(outcome["exit_price"]) - actual) / risk, "Realized R mismatch", Decimal("0.00001"))
        if not done:
            require(all(outcome[k] is None for k in ("gross_profit", "gross_r", "net_profit", "binary_label")), "Censored result has realized target/returns")
