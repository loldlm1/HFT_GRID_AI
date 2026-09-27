"""Synthetic contract facts and an independent closed-prefix swing oracle."""

from copy import deepcopy
from decimal import Decimal
from pathlib import Path

from ..clock import analysis_clock
from ..feature_contract import SERIES, pivot_zone, structure_class
from ..schema_contract import (
    FIXED_MANIFEST, LEVELS, MANIFEST_KEYS, NULL, PROFILES, SUMMARY_CLOCKS,
    SUMMARY_KEYS, TABLE_BY_NAME, clock_companions,
)

NOW = 1439812980000
MACRO_OPEN = NOW // 3600000 * 3600000
PRICES = (82, 88, 94, 100, 106, 112, 118)


def row(table, **values):
    result = {f.name: None if f.nullable else {"text": "NONE", "int": "0", "decimal": "0", "bool": "0", "clock": str(NOW)}[f.type]
              for f in TABLE_BY_NAME[table].raw_fields}
    result.update({k: None if v is None else str(v) for k, v in values.items()})
    return result


def clocks(table, record, session):
    result = dict(record)
    for f in TABLE_BY_NAME[table].clocks:
        names = clock_companions(f.name)
        if result[f.name] is None:
            result.update(dict.fromkeys(names))
        else:
            raw = int(result[f.name])
            analysis, offset = analysis_clock(raw, session)
            result.update(zip(names, (str(analysis), str(offset), "MILLISECOND")))
    return result


def write_tables(path, tables, session="FIXED_TIME_SESSIONS"):
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    for name, records in tables.items():
        descriptor = TABLE_BY_NAME[name]
        with (path / name).open("w", encoding="utf-8", newline="") as out:
            out.write("\t".join(descriptor.columns) + "\r\n")
            for record in records:
                values = clocks(name, record, session)
                out.write("\t".join(NULL if values[c] is None else str(values[c]) for c in descriptor.columns) + "\r\n")


def make_run(path, engine="CANDLE_PATTERN_ATR_V2", *, empty=False, session="FIXED_TIME_SESSIONS"):
    path = Path(path)
    profile = PROFILES[engine]
    candle = profile.kind == "CANDLE"
    tables = {t.name: [] for t in profile.tables}
    m = {key: "NONE" for key in MANIFEST_KEYS}
    m.update(FIXED_MANIFEST)
    m.update(engine=engine, producer_version=profile.producer_version, outcome_policy=profile.outcome_policy, run_id=path.name, config_id="SYNTHETIC_CONFIG",
             compiler_build="6184", symbol="SYNTHETIC_TEST", broker="SYNTHETIC", feed="SYNTHETIC",
             canonical_symbol="UNMAPPED", mapping_status="UNMAPPED", point="0.01", digits="2", tick_size="0.01",
             volume_min="0.01", volume_max="100", volume_step="0.01", contract_size="100",
             calculation_mode="0", chart_mode="0", base_currency="XAU", profit_currency="USD", margin_currency="USD",
             account_currency="USD", macro_seconds="3600", micro_seconds="180", broker_session=session,
             broker_time_basis="BROKER_NATIVE" if session == "FIXED_TIME_SESSIONS" else "UTC_SHIFT_0",
             analysis_clock_policy="BROKER_FIXED_V1" if session == "FIXED_TIME_SESSIONS" else "EXNESS_NEW_YORK_V1",
             lot_type="EXECUTION_LOT_FIXED_SIZE", lot_size="0.01", virtual_cap="6144" if candle else "2048",
             expiry=profile.expiry, reentry="BROKER_SL_ONCE" if candle else "NONE",
             ratios="1,2,3" if candle else "1,2,3,5")
    tables["run_manifest.tsv"] = [dict(key=k, value=m[k]) for k in MANIFEST_KEYS]
    def append(name, **values):
        result = row(name, run_id=path.name, **values)
        tables[name].append(result)
        return result
    if not empty:
        window = append("macro_windows.tsv", window_id="W", open_time_msc=MACRO_OPEN,
                        source_time_msc=MACRO_OPEN-3600000, source_close_time_msc=MACRO_OPEN,
                        macro_seconds=3600, source_open=100, source_high=106, source_low=94, source_close=100,
                        valid=1, reason="OK")
        for level, price in zip(LEVELS, PRICES, strict=True):
            window["raw_" + level.lower() + "_price"] = str(price)
            window["trade_" + level.lower() + "_price"] = str(price)
        bid = Decimal("101" if candle else "94")
        ask = bid + Decimal("0.1")
        append("signal_events.tsv", signal_id="S", sequence=1, symbol=m["symbol"], direction="BUY",
               signal_time_msc=NOW, source_time_msc=NOW-180000 if candle else MACRO_OPEN-3600000,
               macro_window_id="W", bid=bid, ask=ask, admission="DISCOVERED")
        if candle:
            append("candle_signals.tsv", signal_id="S", pattern="ENGULFING", pattern_direction="BULLISH",
                   previous_open=100, previous_high=101, previous_low=98, previous_close=99,
                   pattern_open=98, pattern_high=102, pattern_low=97, pattern_close=101)
        else:
            append("pivot_origins.tsv", signal_id="S", broker_signal_id=1, level_id="S1", pivot_raw_price=94,
                   pivot_trade_price=94, next_outward_pivot_price=88, midpoint_50_price=91,
                   structural_entry_price=ask, structural_sl_price=88, structural_take_profit=ask+ask-88,
                   stops_level_points=0, freeze_level_points=0, identity_consumed=1, h1_lanes_declared=1,
                   broker_attempt_status="ACCEPTED", origin_terminal_status="COMPLETE")
        for index, direction in enumerate((1, -1) if candle else (1,)):
            attempt_id = "A" + str(index)
            snapshot_id = "F" + str(index)
            snapshot = append("feature_snapshots.tsv", snapshot_id=snapshot_id, signal_id="S", sequence=2+index,
                              capture_stage="CANDLE_DECISION" if candle else "PIVOT_ORIGIN", observed_time_msc=NOW,
                              macro_window_id="W", bid=bid, ask=ask, point=m["point"], tick_size=m["tick_size"],
                              macro_seconds=3600, micro_seconds=180, complete=1, macro_complete=1, micro_complete=1,
                              macro_reason="OK", micro_reason="OK", pivot_complete=1, structure_complete=1,
                              structure_reason="INITIAL", structure_last_closed_time_msc=NOW-60000,
                              structure_observed_bar_time_msc=NOW, forming_status="INITIAL")
            for role, seconds in (("macro",3600),("micro",180)):
                for family in ("stochastic", "percent_b", "atr"):
                    snapshot[f"{role}_{family}_complete"] = "1"
                for s in range(6):
                    snapshot[f"{role}_source_{s}_time_msc"] = str((NOW//(seconds*1000)-s)*seconds*1000)
                    for series in SERIES:
                        snapshot[f"{role}_{series}_{s}"] = "1" if series.startswith("atr") else "50"
            zone, lower, upper = pivot_zone(bid, tuple(Decimal(p) for p in PRICES))
            snapshot.update(signal_zone=zone, zone_lower_price=str(lower) if lower is not None else None,
                            zone_upper_price=str(upper) if upper is not None else None, signal_vs_tested_pivot="UNTESTED")
            for level, price in zip(LEVELS, PRICES, strict=True):
                snapshot[f"pivot_{level.lower()}_price"] = str(price)
            entry_type = "ORIGINAL" if candle else "PIVOT_ORIGIN"
            append("entry_attempts.tsv", attempt_id=attempt_id, signal_id="S", snapshot_id=snapshot_id,
                   sequence=2+index, entry_type=entry_type, direction="BUY" if direction==1 else "SELL",
                   decision_time_msc=NOW, macro_window_id="W", bid=bid, ask=ask)
            if candle:
                append("candle_attempts.tsv", attempt_id=attempt_id, pattern="ENGULFING",
                       category="ALIGNED" if direction==1 else "OPPOSED", generation=0, atr_0=1, atr_1=1,
                       atr_source_time_msc=NOW-180000, atr_shift=1, atr_multiplier=1, requested_volume="0.01",
                       entry_interval=zone, expiry_policy="ENTRY_PLUS_MACRO")
            origin_entry = ask if direction == 1 else bid
            origin_sl = origin_entry-direction if candle else Decimal(88)
            lanes = [("BROKER", 1, entry_type if candle else "STRUCTURAL"), ("PARITY",1,entry_type if candle else "STRUCTURAL")]
            lanes += [("VIRTUAL",rr,entry_type) for rr in (2,3)] if candle else [("VIRTUAL",rr,policy) for policy in ("STRUCTURAL","MIDPOINT_50") for rr in (1,2,3,5)]
            for role, rr, policy in lanes:
                entry = Decimal(91) if policy == "MIDPOINT_50" else origin_entry
                sl = origin_sl
                tp = entry+direction*rr*(direction*(entry-sl))
                at = NOW+1000 if policy == "MIDPOINT_50" else NOW
                trial_id = f"{attempt_id}:{role}:{policy}:{rr}"
                append("trials.tsv", trial_id=trial_id, attempt_id=attempt_id, role=role, entry_policy=policy,
                       rr=rr, declared_time_msc=NOW, entry_time_msc=at,
                       deadline_time_msc=at+3600000 if profile.expiry == "ENTRY_PLUS_MACRO" else None, entry_price=entry, sl=sl, tp=tp,
                       volume="0.01", eligibility="ACCEPTED" if role=="BROKER" else "ELIGIBLE")
                if policy == "MIDPOINT_50":
                    tables["trials.tsv"][-1].update(entry_bid=str(entry), entry_ask=str(entry))
                if profile.entry_policy != "LEGACY":
                    entry_bid, entry_ask = (entry, entry) if policy == "MIDPOINT_50" else (bid, ask)
                    risk = direction * (entry - sl)
                    tables["trials.tsv"][-1].update(entry_bid=str(entry_bid), entry_ask=str(entry_ask),
                        point_size="0.01", trade_tick_size="0.01", stops_level_points="0", freeze_level_points="0",
                        spread_points=str((entry_ask-entry_bid)/Decimal("0.01")),
                        normalized_risk_distance_price=str(risk), normalized_risk_distance_points=str(risk/Decimal("0.01")),
                        minimum_risk_distance_points=str((3*(entry_ask-entry_bid)+Decimal("0.01"))/Decimal("0.01")), distance_eligible="1")
                gross = direction*(tp-entry)
                append("outcomes.tsv", trial_id=trial_id, attempt_id=attempt_id, role=role, rr=rr,
                       status="TP_FIRST", broker_reason="DEAL_REASON_TP" if role=="BROKER" else None,
                       entry_time_msc=at, entry_macro_open_time_msc=MACRO_OPEN,
                       deadline_time_msc=at+3600000 if profile.expiry == "ENTRY_PLUS_MACRO" else None, exit_time_msc=at+120000,
                       observed_time_msc=at+120000, entry_price=entry, exit_price=tp, sl=sl, tp=tp,
                       volume="0.01", gross_profit=gross, costs="-0.1" if role=="BROKER" else None,
                       net_profit=gross-Decimal("0.1") if role=="BROKER" else None, gross_r=rr,
                       binary_label=1 if role!="PARITY" else None, binary_eligible=int(role!="PARITY"),
                       exclusion_reason="PARITY" if role=="PARITY" else None,
                       position_id=index+1 if role=="BROKER" else None,
                       fill_deviation_points=0 if role=="BROKER" else None,duration_ms=120000)
            append("execution_checks.tsv", check_id="C"+str(index), attempt_id=attempt_id, action="ENTRY",
                   time_msc=NOW, sequence=4+index, allowed=1, reason="ACCEPTED", bid=bid, ask=ask,
                   volume="0.01", entry_price=origin_entry, sl=origin_sl, tp=origin_entry+direction*(direction*(origin_entry-origin_sl)),
                   margin=10, stop_profit=-1, check_retcode=0, send_retcode=10009, order_ticket=index+1, deal_ticket=index+1)
    seal = dict.fromkeys(SUMMARY_KEYS, "0")
    seal.update(export_status="OK",completion_status="NATURAL",failure="NONE",broker_peak="2" if candle else "1",
                virtual_peak="6" if candle else "9",handle_peak="7",buffer_peak="1",feature_gap_count="0",
                warmup_count="1",warmup_first_time_msc=str(NOW-60000),warmup_last_time_msc=str(NOW-60000),
                warmup_fingerprint="0123456789abcdef",warmup_status="PARTIAL",first_time_msc=str(NOW),last_time_msc=str(NOW+600000))
    for clock in SUMMARY_CLOCKS:
        raw=int(seal[clock]); analysis,offset=analysis_clock(raw,session)
        seal.update(zip(clock_companions(clock),(str(analysis),str(offset),"SECOND")))
    seal.update({"rows_"+name:str(len(records)) for name,records in tables.items() if name!="run_summary.tsv"})
    tables["run_summary.tsv"]=[dict(key=k,value=v) for k,v in seal.items()]
    write_tables(path,tables,session)
    return tables


def rewrite(path, tables, session="FIXED_TIME_SESSIONS"):
    seal = {r['key']:r['value'] for r in tables['run_summary.tsv']}
    for name,records in tables.items():
        if name!='run_summary.tsv': seal['rows_'+name]=str(len(records))
    tables['run_summary.tsv']=[dict(key=k,value=v) for k,v in seal.items()]
    write_tables(path,tables,session)


def structure_prefix(observations, tick=Decimal("0.01")):
    """Replay source prefix from scratch; observations are (bar, close, K, next_open)."""
    kind=0; candidate=None; candidate_at=None; previous={1:None,-1:None}; confirmed=[]; last=-1
    for bar,close,k,next_open in observations:
        if bar==last: continue
        if bar<last or next_open<=bar: raise ValueError('Non-chronological prefix')
        last=bar; close=Decimal(str(close)); k=Decimal(str(k))
        if not 0<=k<=100 or close<=0: raise ValueError('Invalid source')
        desired=1 if k>80 else -1 if k<20 else 0
        if kind==0:
            if desired: kind,candidate,candidate_at=desired,close,bar
            continue
        reversal=desired==-kind and kind*(candidate-close)>0
        if reversal:
            confirmed.append((kind,structure_class(kind,candidate,previous[kind],tick),candidate,candidate_at,next_open))
            previous[kind]=candidate;kind,candidate,candidate_at=-kind,close,bar
        elif kind*(close-candidate)>0:
            candidate,candidate_at=close,bar
    forming=(kind,structure_class(kind,candidate,previous[kind],tick),candidate,candidate_at) if kind else None
    return confirmed,forming


def project(observations, bar, close, k, tick=Decimal("0.01")):
    confirmed,_=structure_prefix(observations,tick)
    _,forming=structure_prefix([*observations,(bar,close,k,bar+60)],tick)
    return deepcopy(confirmed),forming
