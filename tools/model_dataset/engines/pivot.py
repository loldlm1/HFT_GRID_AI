"""Pivot first consumption, eight Macro lanes and exact broker parity."""

from decimal import Decimal

from ..reader import integer, near, number, require
from ..schema_contract import LEVELS


def validate(run):
    for key, value in {"expiry": run.profile.expiry, "reentry": "NONE", "ratios": "1,2,3,5", "virtual_cap": "2048"}.items():
        require(run.manifest[key] == value, "Pivot manifest policy: " + key)
    run.none("SELECT 1 FROM signal_events s JOIN pivot_origins p USING(signal_id) GROUP BY s.macro_window_id,p.level_id HAVING COUNT(*)>1 LIMIT 1", "Repeated pivot consumption")
    run.none("SELECT 1 FROM signal_events s LEFT JOIN entry_attempts a USING(signal_id) GROUP BY s.signal_id HAVING COUNT(a.attempt_id)<>1 LIMIT 1", "Pivot origin/attempt cardinality")
    tick = number(run.manifest["tick_size"])
    for signal in run.rows("signal_events.tsv"):
        origin = run.one("pivot_origins.tsv", "signal_id", signal["signal_id"])
        window = run.one("macro_windows.tsv", "window_id", signal["macro_window_id"])
        level = origin["level_id"]
        require(level in LEVELS and origin["identity_consumed"] == "1" and window["valid"] == "1", "Invalid consumed origin")
        direction = 1 if signal["direction"] == "BUY" else -1
        index = LEVELS.index(level)
        require(level == "PP" or (index < 3) == (direction == 1), "Pivot trigger direction mismatch")
        price = number(window["trade_" + level.lower() + "_price"])
        require(number(origin["pivot_trade_price"]) == price and direction * (number(signal["bid"]) - price) <= 0, "Bid did not touch origin")
        next_index = index - direction
        if 0 <= next_index < 7:
            stop = number(window["trade_" + LEVELS[next_index].lower() + "_price"])
        else:
            neighbor = number(window["trade_" + LEVELS[index + direction].lower() + "_price"])
            stop = 2 * price - neighbor
        near(number(origin["next_outward_pivot_price"]), stop, "Wrong structural stop", tick * Decimal("0.000001"))
        near(number(origin["midpoint_50_price"]), (price + stop) / 2, "Wrong midpoint", tick * Decimal("0.000001"))
        attempt = run.db.execute("SELECT * FROM entry_attempts WHERE signal_id=?", (signal["signal_id"],)).fetchone()
        require(attempt["entry_type"] == "PIVOT_ORIGIN" and attempt["parent_attempt_id"] is None and attempt["direction"] == signal["direction"], "Pivot acquired re-entry/changed direction")
        require(attempt["decision_time_msc"] == signal["signal_time_msc"], "Pivot decision is not trigger-time")
        virtuals = list(run.db.execute("SELECT * FROM trials WHERE attempt_id=? AND role='VIRTUAL'", (attempt["attempt_id"],)))
        if origin["h1_lanes_declared"] == "1":
            require(sorted((t["entry_policy"], int(t["rr"])) for t in virtuals) == sorted((policy, rr) for policy in ("STRUCTURAL", "MIDPOINT_50") for rr in (1, 2, 3, 5)), "Pivot eight-lane cardinality")
        else:
            require(not virtuals and origin["origin_terminal_status"] == "CAPACITY_REJECTED", "Missing declared virtual lanes")
        for t in virtuals:
            if t["eligibility"] == "ELIGIBLE":
                require(t["entry_time_msc"] is not None, "Eligible lane never entered")
            if t["entry_policy"] == "MIDPOINT_50" and t["entry_time_msc"] is not None:
                require(integer(t["entry_time_msc"]) >= integer(signal["signal_time_msc"]), "Midpoint predates origin")
                require(t["entry_bid"] is not None and t["entry_ask"] is not None, "Missing midpoint trigger quote")
                require(direction * (number(t["entry_bid"]) - number(origin["midpoint_50_price"])) <= tick * Decimal("0.000001"), "Midpoint lacks Bid touch")
                require(t["entry_price"] == t["entry_ask" if direction == 1 else "entry_bid"], "Wrong midpoint executable quote")
        brokers = list(run.db.execute("SELECT * FROM trials WHERE attempt_id=? AND role='BROKER'", (attempt["attempt_id"],)))
        parity = list(run.db.execute("SELECT * FROM trials WHERE attempt_id=? AND role='PARITY'", (attempt["attempt_id"],)))
        require(len(brokers) <= 1 and len(parity) == sum(t["eligibility"] == "ACCEPTED" for t in brokers), "Pivot one-request parity cardinality")
        for broker in brokers:
            require(broker["rr"] == "1" and broker["entry_policy"] == "STRUCTURAL", "Unauthorized Pivot broker lane")
            if broker["eligibility"] == "ACCEPTED":
                require(all(parity[0][k] == broker[k] for k in ("entry_price", "sl", "tp", "volume", "declared_time_msc")), "Pivot parity geometry changed")
                require(parity[0]["rr"] == "1", "Pivot parity ratio changed")
        for check in run.db.execute("SELECT * FROM execution_checks WHERE attempt_id=?", (attempt["attempt_id"],)):
            if check["send_succeeded"] == "1":
                require(check["send_performed"] == "1" and check["allowed"] == "1" and check["send_retcode"] in {"10008", "10009"}, "Inconsistent Pivot request result")
    if run.profile.expiry == "ENTRY_PLUS_MACRO":
        macro_ms = integer(run.manifest["macro_seconds"]) * 1000
        for trial in run.rows("trials.tsv"):
            reference = trial["declared_time_msc"] if trial["role"] == "BROKER" else trial["entry_time_msc"]
            if reference is not None and trial["eligibility"] in {"ACCEPTED", "ELIGIBLE"}:
                require(integer(trial["deadline_time_msc"]) == integer(reference) + macro_ms, "Pivot reference deadline mismatch")
        for outcome in run.rows("outcomes.tsv"):
            if outcome["entry_time_msc"] is not None:
                require(integer(outcome["deadline_time_msc"]) == integer(outcome["entry_time_msc"]) + macro_ms, "Pivot actual entry deadline mismatch")
            if outcome["status"] == "TIME_EXIT":
                require(integer(outcome["exit_time_msc"]) >= integer(outcome["deadline_time_msc"]), "Premature Pivot time exit")
            if outcome["status"] in {"TP_FIRST", "SL_FIRST"}:
                require(integer(outcome["exit_time_msc"]) < integer(outcome["deadline_time_msc"]), "Pivot deadline incorrectly labeled target")
