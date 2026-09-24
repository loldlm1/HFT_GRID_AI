"""Candle pattern, direction, ATR, expiry and re-entry policy."""

from decimal import Decimal

from ..reader import integer, number, require


def validate(run):
    m = run.manifest
    for key, value in {"expiry": "ENTRY_PLUS_MACRO", "reentry": "BROKER_SL_ONCE", "ratios": "1,2,3", "virtual_cap": "6144"}.items():
        require(m[key] == value, "Candle manifest policy: " + key)
    macro_ms, micro_ms = integer(m["macro_seconds"]) * 1000, integer(m["micro_seconds"]) * 1000
    tick = number(m["tick_size"])
    for signal in run.rows("signal_events.tsv"):
        facts = run.one("candle_signals.tsv", "signal_id", signal["signal_id"])
        po, pc, co, cc = (number(facts[k]) for k in ("previous_open", "previous_close", "pattern_open", "pattern_close"))
        require(min(po, pc, co, cc) > 0 and po != pc and co != cc and (pc > po) != (cc > co), "Invalid pattern candles")
        pl, ph, cl, ch = min(po, pc), max(po, pc), min(co, cc), max(co, cc)
        expected = "ENGULFING" if cl <= pl and ch >= ph and (cl < pl or ch > ph) else "HARAMI" if cl >= pl and ch <= ph and (cl > pl or ch < ph) else None
        require(facts["pattern"] == expected and facts["pattern_direction"] == ("BULLISH" if cc > co else "BEARISH"), "Pattern definition mismatch")
        require(signal["direction"] == ("BUY" if cc > co else "SELL"), "Signal pattern direction mismatch")
        require(integer(signal["source_time_msc"]) + micro_ms <= integer(signal["signal_time_msc"]), "Pattern uses unfinished source")
        for prefix in ("previous", "pattern"):
            lo, hi, op, close = (number(facts[prefix + "_" + k]) for k in ("low", "high", "open", "close"))
            require(0 < lo <= min(op, close) <= max(op, close) <= hi, "Invalid pattern OHLC")
    run.none("SELECT 1 FROM signal_events s LEFT JOIN entry_attempts a USING(signal_id) GROUP BY s.signal_id HAVING COUNT(CASE WHEN a.entry_type='ORIGINAL' THEN 1 END)<>2 OR COUNT(DISTINCT CASE WHEN a.entry_type='ORIGINAL' THEN a.direction END)<>2 LIMIT 1", "Candle requires two original directions")
    run.none("SELECT 1 FROM entry_attempts a JOIN candle_attempts c USING(attempt_id) GROUP BY a.signal_id,c.category,c.generation HAVING COUNT(*)<>1 LIMIT 1", "Duplicate direction/generation")
    for attempt in run.rows("entry_attempts.tsv"):
        extra = run.one("candle_attempts.tsv", "attempt_id", attempt["attempt_id"])
        signal = run.one("signal_events.tsv", "signal_id", attempt["signal_id"])
        facts = run.one("candle_signals.tsv", "signal_id", signal["signal_id"])
        require(extra["pattern"] == facts["pattern"] and extra["category"] in {"ALIGNED", "OPPOSED"}, "Candle attempt family")
        require((attempt["direction"] == signal["direction"]) == (extra["category"] == "ALIGNED"), "Candle direction relationship")
        generation = integer(extra["generation"])
        require(generation in (0, 1) and attempt["entry_type"] == ("ORIGINAL" if generation == 0 else "REENTRY"), "Invalid entry generation")
        require(extra["expiry_policy"] == "ENTRY_PLUS_MACRO" and extra["atr_shift"] == "1" and number(extra["atr_multiplier"]) == 1, "Candle execution policy")
        if extra["atr_1"] is not None:
            require(number(extra["atr_1"]) > 0 and integer(extra["atr_source_time_msc"]) + micro_ms <= integer(attempt["decision_time_msc"]), "Candle ATR source")
        if generation == 0:
            require(attempt["parent_attempt_id"] is None and extra["reentry_cause"] is None, "Original has parent")
        else:
            parent = run.one("entry_attempts.tsv", "attempt_id", attempt["parent_attempt_id"])
            require(parent["entry_type"] == "ORIGINAL" and parent["signal_id"] == attempt["signal_id"] and parent["direction"] == attempt["direction"], "Invalid re-entry parent")
            closed = run.db.execute("SELECT * FROM outcomes WHERE attempt_id=? AND role='BROKER'", (parent["attempt_id"],)).fetchone()
            require(closed is not None and closed["status"] == "SL_FIRST" and extra["reentry_cause"] == "BROKER_SL", "Re-entry lacks broker SL")
            require(integer(closed["observed_time_msc"]) <= integer(attempt["decision_time_msc"]) < integer(closed["deadline_time_msc"]), "Re-entry before observation/after deadline")
        trials = list(run.db.execute("SELECT * FROM trials WHERE attempt_id=?", (attempt["attempt_id"],)))
        counts = [(t["role"], t["rr"]) for t in trials]
        for required in (("BROKER", "1"), ("VIRTUAL", "2"), ("VIRTUAL", "3")):
            require(counts.count(required) == 1, "Candle trial cardinality")
        broker = next(t for t in trials if t["role"] == "BROKER")
        accepted = broker["eligibility"] == "ACCEPTED"
        require(broker["eligibility"] in {"ACCEPTED", "REJECTED"}, "Unresolved broker admission")
        require(counts.count(("PARITY", "1")) == int(accepted) and len(trials) == 3 + int(accepted), "Candle parity cardinality")
        checks = list(run.db.execute("SELECT * FROM execution_checks WHERE attempt_id=? AND action='ENTRY'", (attempt["attempt_id"],)))
        require(len(checks) == 1, "Missing/duplicate entry check")
        check = checks[0]
        require((check["reason"] == "ACCEPTED") == accepted, "Broker admission/check mismatch")
        require(all(check[k] == broker[k] for k in ("entry_price", "sl", "tp", "volume")), "Request geometry mismatch")
        if accepted:
            require(check["allowed"] == "1" and check["send_retcode"] in {"10008", "10009"} and (check["order_ticket"] or check["deal_ticket"]), "Unconfirmed accepted request")
        for t in trials:
            require(t["entry_policy"] == attempt["entry_type"], "Candle entry policy mismatch")
            require(t["declared_time_msc"] == attempt["decision_time_msc"], "Candle declaration changed")
            if t["deadline_time_msc"] is not None:
                require(integer(t["deadline_time_msc"]) == integer(t["declared_time_msc"]) + macro_ms, "Reference deadline mismatch")
            if t["role"] != "BROKER":
                require(all(t[k] == broker[k] for k in ("entry_price", "sl", "volume", "declared_time_msc")), "Shared Candle geometry changed")
            if t["eligibility"] in {"ELIGIBLE", "ACCEPTED"}:
                direction = 1 if attempt["direction"] == "BUY" else -1
                risk = direction * (number(t["entry_price"]) - number(t["sl"]))
                atr = number(extra["atr_1"])
                require(atr is not None and atr - tick * Decimal("0.000001") <= risk < atr + tick + tick * Decimal("0.000001"), "Candle stop is not ATR shift 1")
            if t["role"] == "PARITY":
                require(all(t[k] == broker[k] for k in ("entry_price", "sl", "tp", "volume")), "Parity changed request")
    for outcome in run.rows("outcomes.tsv"):
        if outcome["entry_time_msc"] is not None:
            require(integer(outcome["deadline_time_msc"]) == integer(outcome["entry_time_msc"]) + macro_ms, "Actual entry deadline mismatch")
        if outcome["status"] == "TIME_EXIT":
            require(integer(outcome["exit_time_msc"]) >= integer(outcome["deadline_time_msc"]), "Premature time exit")
        if outcome["status"] in {"TP_FIRST", "SL_FIRST"}:
            require(integer(outcome["exit_time_msc"]) < integer(outcome["deadline_time_msc"]), "Deadline incorrectly labeled target")
        if outcome["role"] == "BROKER" and outcome["status"] in {"TP_FIRST", "SL_FIRST", "TIME_EXIT", "OTHER_CLOSE"}:
            require(outcome["position_id"] is not None and outcome["costs"] is not None and outcome["net_profit"] is not None, "Missing actual broker facts")
