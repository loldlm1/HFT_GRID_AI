"""Regenerate the deterministic strict V13 contract fixture."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timedelta
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parents[3]
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import schema_contract as contract

RUN_ID = "schema_v13_hft_deep_pivot_features"
CONFIG_ID = "cfg_v13_fixture"
SYMBOL = "EURUSD"
NULL = contract.NULL_TOKEN
ROOT = Path(__file__).resolve().parent


def _timestamp(value: datetime) -> str:
    return value.strftime("%Y.%m.%d %H:%M:%S")


def _row(columns: tuple[str, ...], **values: object) -> dict[str, str]:
    row = {column: NULL for column in columns}
    row.update({key: str(value) for key, value in values.items()})
    return row


def _triplet(row: dict[str, str], prefix: str, value: datetime, offset: int = 0) -> None:
    row[f"{prefix}_broker_time"] = _timestamp(value)
    row[f"{prefix}_analysis_time"] = _timestamp(value + timedelta(minutes=offset))
    row[f"{prefix}_offset_minutes"] = str(offset)


def _write(filename: str, rows: list[dict[str, str]]) -> None:
    columns = contract.TABLE_COLUMNS[filename]
    with (ROOT / filename).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def _features(row: dict[str, str], prefix: str, pivot_price: float) -> None:
    row[f"{prefix}_band_width_points_0"] = "100.0000000000"
    for series in contract.SIGNAL_SERIES:
        for shift in contract.FEATURE_SHIFTS:
            row[f"{prefix}_{series}_{shift}"] = "50.0000000000"
            row[f"{prefix}_{series}_sma_5_{shift}"] = "50.0000000000"
            row[f"{prefix}_{series}_sma_slope_{shift}"] = "0.0000000000"
            row[f"{prefix}_{series}_state_{shift}"] = "EQUAL"
    for shift in contract.FEATURE_SHIFTS:
        row[f"{prefix}_band_base_line_{shift}"] = f"{pivot_price:.10f}"
        row[f"{prefix}_band_base_line_slope_points_{shift}"] = "0.0000000000"


def _window(
    scope: str,
    timeframe: str,
    window_id: str,
    active: datetime,
    source: datetime,
    high: float,
    low: float,
    close: float,
    first_bid: float,
) -> dict[str, str]:
    source_range = high - low
    pp = (high + low + close) / 3.0
    levels = {
        "S3": low - 2.0 * (high - pp),
        "S2": pp - source_range,
        "S1": 2.0 * pp - high,
        "PP": pp,
        "R1": 2.0 * pp - low,
        "R2": pp + source_range,
        "R3": high + 2.0 * (pp - low),
    }
    row = _row(
        contract.PIVOT_WINDOW_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        window_id=window_id,
        window_scope=scope,
        symbol=SYMBOL,
        timeframe=timeframe,
        source_open=f"{(high + low) / 2.0:.10f}",
        source_high=f"{high:.10f}",
        source_low=f"{low:.10f}",
        source_close=f"{close:.10f}",
        source_range=f"{source_range:.10f}",
        first_observed_bid=f"{first_bid:.10f}",
        pp_initial_relation="ABOVE" if first_bid > pp else "BELOW",
        pp_role="BUY",
        window_state="VALID",
        invalid_reason=NULL,
        terminal_status="EXPIRED",
    )
    _triplet(row, "active_bar_open", active)
    _triplet(row, "source_bar_open", source)
    _triplet(row, "source_close_boundary", active)
    _triplet(row, "first_observed", active + timedelta(seconds=1))
    _triplet(row, "pp_arm", active + timedelta(seconds=1))
    _triplet(
        row,
        "terminal",
        active + timedelta(seconds=contract.TIMEFRAME_SECONDS[timeframe]),
    )
    row["pp_arm_bid"] = f"{first_bid:.10f}"
    for level, value in levels.items():
        row[f"raw_{level.lower()}_price"] = f"{value:.10f}"
        row[f"trade_{level.lower()}_price"] = f"{value:.10f}"
    return row


def _h1_trial(
    policy: str,
    ratio: int,
    trial_id: str,
    entry_time: datetime,
    bid: float,
    ask: float,
    role: str = "H1",
) -> dict[str, str]:
    stop = 1.0800
    entry = ask
    risk = entry - stop
    target = entry + ratio * risk
    row = _row(
        contract.VIRTUAL_TRIAL_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        trial_id=trial_id,
        parity_trial_id=NULL,
        origin_id="origin_s1_buy",
        window_id="win_h1_202601121000",
        broker_signal_id="broker_sig_s1" if role == "BROKER_PARITY" else NULL,
        trial_role=role,
        entry_policy=policy,
        tp_r_multiple=ratio,
        level_id="S1",
        direction="BUY",
        entry_bid=f"{bid:.10f}",
        entry_ask=f"{ask:.10f}",
        entry_price=f"{entry:.10f}",
        entry_quote_side="ASK",
        exit_quote_side="BID",
        midpoint_50_price="1.0850000000",
        midpoint_touched="1",
        requested_risk_distance_price=f"{risk:.10f}",
        requested_risk_distance_points=f"{risk / 0.0001:.10f}",
        normalized_risk_ticks=round(risk / 0.0001),
        normalized_risk_distance_price=f"{risk:.10f}",
        normalized_risk_distance_points=f"{risk / 0.0001:.10f}",
        stop_loss_price=f"{stop:.10f}",
        take_profit_price=f"{target:.10f}",
        geometry_equivalence_id=trial_id,
        spread_points="2.0000000000",
        point_size="0.0001000000",
        trade_tick_size="0.0001000000",
        stops_level_points="5.0000000000",
        freeze_level_points="2.0000000000",
        minimum_risk_distance_points="8.0000000000",
        distance_eligible="1",
        lot_mode=contract.REFERENCE_LOT_MODE,
        lot_strategy_size="0.01000000",
        reference_balance="1000000.00000000",
        account_currency="USD",
        risk_budget_amount="100.0000000000",
        requested_volume="0.1000000000",
        normalized_volume="0.1000000000",
        virtual_expected_stop_loss="-100.0000000000",
        virtual_expected_take_profit=f"{ratio * 100.0:.10f}",
        virtual_expected_reward_risk_ratio=f"{ratio:.10f}",
        virtual_money_plan_complete="1",
        eligibility_status="ACTIVE",
        ineligible_reason=NULL,
        origin_window_active_at_entry="1",
    )
    _triplet(row, "declared", entry_time)
    _triplet(row, "entry", entry_time)
    return row


def _h1_outcome(trial: dict[str, str], index: int) -> dict[str, str]:
    entry_time = datetime.strptime(trial["entry_broker_time"], "%Y.%m.%d %H:%M:%S")
    terminal = entry_time + timedelta(minutes=30 + index)
    ratio = int(trial["tp_r_multiple"])
    status = "SL_FIRST" if trial["entry_policy"] == "MIDPOINT_50" and ratio == 5 else "TP_FIRST"
    entry = float(trial["entry_price"])
    risk = abs(entry - float(trial["stop_loss_price"]))
    threshold = entry + ratio * risk if status == "TP_FIRST" else float(trial["stop_loss_price"])
    row = _row(
        contract.VIRTUAL_OUTCOME_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        outcome_id=f"out_{trial['trial_id']}",
        trial_id=trial["trial_id"],
        parity_trial_id=trial["parity_trial_id"],
        origin_id="origin_s1_buy",
        window_id="win_h1_202601121000",
        trial_role=trial["trial_role"],
        entry_policy=trial["entry_policy"],
        tp_r_multiple=ratio,
        direction="BUY",
        terminal_status=status,
        terminal_reason="TP_THRESHOLD" if status == "TP_FIRST" else "SL_THRESHOLD",
        threshold_price=f"{threshold:.10f}",
        observed_exit_bid=f"{threshold:.10f}",
        observed_exit_ask=f"{threshold + 0.0002:.10f}",
        observed_exit_price=f"{threshold:.10f}",
        exit_quote_side="BID",
        gap_points="0.0000000000",
        h1_structural_lifecycle_seconds=int((terminal - entry_time).total_seconds()),
        virtual_nominal_r=f"{ratio if status == 'TP_FIRST' else -1:.10f}",
        virtual_quote_gross_profit=f"{ratio * 100.0 if status == 'TP_FIRST' else -100.0:.10f}",
        virtual_quote_gross_r=f"{ratio if status == 'TP_FIRST' else -1:.10f}",
        virtual_binary_eligible="1",
        virtual_binary_target="1" if status == "TP_FIRST" else "0",
        virtual_exclusion_reason=NULL,
        first_touch_consistent="1",
    )
    _triplet(row, "terminal", terminal)
    return row


def generate() -> None:
    for path in ROOT.glob("*.tsv"):
        path.unlink()

    manifest = {
        "run_id": RUN_ID,
        "config_id": CONFIG_ID,
        "started_broker_time": "2026.01.12 09:59:50",
        "symbol": SYMBOL,
        "chart_period": "PERIOD_H1",
        "macro_timeframe": "PERIOD_H1",
        "deep_timeframe": "PERIOD_M10",
        "micro_timeframe": "PERIOD_M3",
        "lot_mode": contract.REFERENCE_LOT_MODE,
        "lot_strategy_size": "0.01000000",
        "account_currency": "USD",
        "broker_session": "FIXED_TIME_SESSIONS",
        "h1_active_state_cap": "2048",
        "deep_event_active_cap": "2048",
        "deep_link_active_cap": "4096",
        "deep_trial_active_cap": "6144",
        "deep_outcome_active_cap": "18432",
        **contract.FIXED_MANIFEST_VALUES,
    }
    _write(
        contract.RUN_MANIFEST_FILE,
        [_row(contract.MANIFEST_COLUMNS, schema_version=13, key=key, value=manifest[key]) for key in sorted(manifest)],
    )

    macro = _window(
        "MACRO", "PERIOD_H1", "win_h1_202601121000",
        datetime(2026, 1, 12, 10), datetime(2026, 1, 12, 9),
        1.1100, 1.0900, 1.1000, 1.1010,
    )
    deep = _window(
        "DEEP", "PERIOD_M10", "win_m10_202601121010",
        datetime(2026, 1, 12, 10, 10), datetime(2026, 1, 12, 10),
        1.1050, 1.0950, 1.1000, 1.1020,
    )
    _write(contract.PIVOT_WINDOWS_FILE, [macro, deep])

    trigger = datetime(2026, 1, 12, 10, 5)
    origin = _row(
        contract.SIGNAL_ORIGIN_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        origin_id="origin_s1_buy",
        window_id="win_h1_202601121000",
        broker_signal_id="broker_sig_s1",
        symbol=SYMBOL,
        macro_timeframe="PERIOD_H1",
        deep_timeframe="PERIOD_M10",
        micro_timeframe="PERIOD_M3",
        active_bar_open_broker_time="2026.01.12 10:00:00",
        level_id="S1",
        direction="BUY",
        trigger_bid="1.0900000000",
        trigger_ask="1.0902000000",
        spread_points="2.0000000000",
        point_size="0.0001000000",
        trade_tick_size="0.0001000000",
        stops_level_points="5.0000000000",
        freeze_level_points="2.0000000000",
        pivot_raw_price="1.0900000000",
        pivot_trade_price="1.0900000000",
        next_outward_pivot_price="1.0800000000",
        midpoint_50_price="1.0850000000",
        structural_entry_price="1.0902000000",
        structural_sl_price="1.0800000000",
        structural_take_profit="1.1004000000",
        origin_micro_features_complete="1",
        origin_macro_features_complete="1",
        origin_feature_snapshot_complete="1",
        origin_feature_invalid_reason=NULL,
        identity_consumed="1",
        h1_lanes_declared="1",
        broker_attempt_status="CLOSED",
        origin_terminal_status="WINDOW_EXPIRED",
    )
    _triplet(origin, "trigger", trigger)
    for level in contract.PIVOT_LEVELS:
        origin[f"raw_{level.lower()}_price"] = macro[f"raw_{level.lower()}_price"]
        origin[f"trade_{level.lower()}_price"] = macro[f"trade_{level.lower()}_price"]
    _features(origin, "origin_micro", 1.0900)
    _features(origin, "origin_macro", 1.0900)
    _write(contract.SIGNAL_ORIGINS_FILE, [origin])

    trials: list[dict[str, str]] = []
    for policy in contract.H1_ENTRY_POLICIES:
        for ratio in contract.H1_TP_R_MULTIPLES:
            midpoint = policy == "MIDPOINT_50"
            entry_time = trigger + timedelta(minutes=1) if midpoint else trigger
            trials.append(
                _h1_trial(
                    policy,
                    ratio,
                    f"trial_{policy.lower()}_tp{ratio}",
                    entry_time,
                    1.0850 if midpoint else 1.0900,
                    1.0852 if midpoint else 1.0902,
                )
            )
    parity = _h1_trial(
        "STRUCTURAL",
        1,
        "parity_broker_sig_s1",
        trigger,
        1.0900,
        1.0902,
        "BROKER_PARITY",
    )
    parity["parity_trial_id"] = "parity_broker_sig_s1"
    trials.append(parity)
    _write(contract.VIRTUAL_TRIALS_FILE, trials)
    _write(contract.VIRTUAL_OUTCOMES_FILE, [_h1_outcome(trial, index) for index, trial in enumerate(trials)])

    event_time = datetime(2026, 1, 12, 10, 19)
    event = _row(
        contract.DEEP_PIVOT_EVENT_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        deep_event_id="deep_event_s1",
        deep_window_id="win_m10_202601121010",
        symbol=SYMBOL,
        deep_timeframe="PERIOD_M10",
        micro_timeframe="PERIOD_M3",
        active_deep_bar_open_broker_time="2026.01.12 10:10:00",
        level_id="S1",
        direction="BUY",
        trigger_bid="1.0948000000",
        trigger_ask="1.0950000000",
        spread_points="2.0000000000",
        point_size="0.0001000000",
        trade_tick_size="0.0001000000",
        stops_level_points="5.0000000000",
        freeze_level_points="2.0000000000",
        pivot_raw_price="1.0950000000",
        pivot_trade_price="1.0950000000",
        next_outward_pivot_price="1.0900000000",
        deep_micro_features_complete="1",
        deep_feature_invalid_reason=NULL,
        identity_consumed="1",
        admission_status="ADMITTED",
        active_parent_count="2",
        required_link_slots="2",
        required_trial_slots="3",
        required_outcome_slots="6",
        reserved_link_slots="2",
        reserved_trial_slots="3",
        reserved_outcome_slots="6",
        capacity_rejection_reason=NULL,
    )
    _triplet(event, "trigger", event_time)
    _features(event, "deep_micro", 1.0950)
    _write(contract.DEEP_PIVOT_EVENTS_FILE, [event])

    links: list[dict[str, str]] = []
    for index, (trial_id, policy) in enumerate(
        (("trial_structural_tp1", "STRUCTURAL"), ("trial_midpoint_50_tp1", "MIDPOINT_50"))
    ):
        parent = next(trial for trial in trials if trial["trial_id"] == trial_id)
        entry_time = datetime.strptime(parent["entry_broker_time"], "%Y.%m.%d %H:%M:%S")
        links.append(
            _row(
                contract.DEEP_PIVOT_PARENT_LINK_COLUMNS,
                schema_version=13,
                run_id=RUN_ID,
                config_id=CONFIG_ID,
                parent_link_id=f"link_{index}",
                deep_event_id="deep_event_s1",
                origin_id="origin_s1_buy",
                parent_kind="VIRTUAL",
                parent_trial_id=trial_id,
                parent_broker_signal_id=parent["broker_signal_id"],
                parent_entry_policy=policy,
                parent_tp_r_multiple="1",
                direction="BUY",
                parent_entry_broker_time=_timestamp(entry_time),
                event_trigger_broker_time=_timestamp(event_time),
                m10_parent_age_seconds=int((event_time - entry_time).total_seconds()),
                link_status="ACTIVE",
            )
        )
    _write(contract.DEEP_PIVOT_PARENT_LINKS_FILE, links)

    deep_trials: list[dict[str, str]] = []
    for ratio in contract.DEEP_TP_R_MULTIPLES:
        risk = 1.0950 - 1.0900
        row = _row(
            contract.DEEP_VIRTUAL_TRIAL_COLUMNS,
            schema_version=13,
            run_id=RUN_ID,
            config_id=CONFIG_ID,
            deep_trial_id=f"deep_trial_s1_r{ratio}",
            deep_event_id="deep_event_s1",
            tp_r_multiple=ratio,
            level_id="S1",
            direction="BUY",
            entry_bid="1.0948000000",
            entry_ask="1.0950000000",
            entry_price="1.0950000000",
            entry_quote_side="ASK",
            exit_quote_side="BID",
            requested_risk_distance_price=f"{risk:.10f}",
            requested_risk_distance_points=f"{risk / 0.0001:.10f}",
            normalized_risk_ticks=round(risk / 0.0001),
            normalized_risk_distance_price=f"{risk:.10f}",
            normalized_risk_distance_points=f"{risk / 0.0001:.10f}",
            stop_loss_price="1.0900000000",
            take_profit_price=f"{1.0950 + ratio * risk:.10f}",
            geometry_equivalence_id=f"deep_geom_r{ratio}",
            spread_points="2.0000000000",
            point_size="0.0001000000",
            trade_tick_size="0.0001000000",
            stops_level_points="5.0000000000",
            freeze_level_points="2.0000000000",
            minimum_risk_distance_points="8.0000000000",
            distance_eligible="1",
            eligibility_status="ACTIVE",
            ineligible_reason=NULL,
        )
        _triplet(row, "declared", event_time)
        deep_trials.append(row)
    _write(contract.DEEP_VIRTUAL_TRIALS_FILE, deep_trials)

    deep_outcomes: list[dict[str, str]] = []
    for link_index, link in enumerate(links):
        for ratio in contract.DEEP_TP_R_MULTIPLES:
            status = "CENSORED_PARENT_EXIT" if link_index == 1 and ratio == 3 else "SL_FIRST" if ratio == 2 else "TP_FIRST"
            if status == "CENSORED_PARENT_EXIT":
                parent_outcome = _h1_outcome(
                    next(trial for trial in trials if trial["trial_id"] == link["parent_trial_id"]),
                    next(
                        index
                        for index, trial in enumerate(trials)
                        if trial["trial_id"] == link["parent_trial_id"]
                    ),
                )
                terminal = datetime.strptime(
                    parent_outcome["terminal_broker_time"],
                    "%Y.%m.%d %H:%M:%S",
                )
            else:
                terminal = event_time + timedelta(minutes=5 + ratio)
            trial = next(
                trial
                for trial in deep_trials
                if trial["deep_trial_id"] == f"deep_trial_s1_r{ratio}"
            )
            completed = status in ("TP_FIRST", "SL_FIRST")
            threshold = (
                trial["take_profit_price"]
                if status == "TP_FIRST"
                else trial["stop_loss_price"]
                if status == "SL_FIRST"
                else NULL
            )
            observed_bid = float(threshold) if completed else 1.1000
            gross_r = float(ratio) if status == "TP_FIRST" else -1.0
            row = _row(
                contract.DEEP_VIRTUAL_OUTCOME_COLUMNS,
                schema_version=13,
                run_id=RUN_ID,
                config_id=CONFIG_ID,
                deep_outcome_id=f"deep_out_{link_index}_{ratio}",
                parent_link_id=link["parent_link_id"],
                deep_trial_id=f"deep_trial_s1_r{ratio}",
                deep_event_id="deep_event_s1",
                origin_id="origin_s1_buy",
                tp_r_multiple=ratio,
                direction="BUY",
                terminal_status=status,
                terminal_reason=(
                    "TP_THRESHOLD"
                    if status == "TP_FIRST"
                    else "SL_THRESHOLD"
                    if status == "SL_FIRST"
                    else status
                ),
                threshold_price=threshold,
                observed_exit_bid=f"{observed_bid:.10f}",
                observed_exit_ask=f"{observed_bid + 0.0002:.10f}",
                observed_exit_price=f"{observed_bid:.10f}",
                exit_quote_side="BID",
                gap_points="0.0000000000" if completed else NULL,
                deep_lifecycle_seconds=int((terminal - event_time).total_seconds()) if completed else NULL,
                virtual_nominal_r=f"{gross_r:.10f}" if completed else NULL,
                virtual_quote_gross_profit=f"{gross_r * 100.0:.10f}" if completed else NULL,
                virtual_quote_gross_r=f"{gross_r:.10f}" if completed else NULL,
                virtual_binary_eligible="1" if completed else "0",
                virtual_binary_target="1" if status == "TP_FIRST" else "0" if status == "SL_FIRST" else NULL,
                virtual_exclusion_reason=NULL if completed else "PARENT_EXIT",
                first_touch_consistent="1",
            )
            _triplet(row, "terminal", terminal)
            deep_outcomes.append(row)
    _write(contract.DEEP_VIRTUAL_OUTCOMES_FILE, deep_outcomes)

    _write(contract.EXECUTION_CHECKS_FILE, [])
    _write(contract.BROKER_OUTCOMES_FILE, [])
    summary = _row(
        contract.SUMMARY_COLUMNS,
        schema_version=13,
        run_id=RUN_ID,
        config_id=CONFIG_ID,
        started_broker_time="2026.01.12 09:59:50",
        started_analysis_time="2026.01.12 09:59:50",
        started_offset_minutes=0,
        finished_broker_time="2026.01.12 11:00:00",
        finished_analysis_time="2026.01.12 11:00:00",
        finished_offset_minutes=0,
        pivot_window_rows=2,
        macro_window_rows=1,
        deep_window_rows=1,
        signal_origin_rows=1,
        h1_trial_rows=9,
        h1_structural_trial_rows=4,
        h1_midpoint_trial_rows=4,
        parity_trial_rows=1,
        h1_outcome_rows=9,
        h1_tp_rows=8,
        h1_sl_rows=1,
        h1_not_triggered_rows=0,
        h1_ineligible_rows=0,
        h1_run_censored_rows=0,
        deep_event_rows=1,
        deep_event_admitted_rows=1,
        deep_event_capacity_rejected_rows=0,
        deep_parent_link_rows=2,
        deep_trial_rows=3,
        deep_outcome_rows=6,
        deep_tp_rows=3,
        deep_sl_rows=2,
        deep_parent_exit_censored_rows=1,
        deep_run_censored_rows=0,
        deep_ineligible_rows=0,
        execution_check_rows=0,
        broker_outcome_rows=0,
        parity_pair_rows=0,
        h1_active_state_peak=9,
        h1_active_state_cap=2048,
        deep_event_active_peak=1,
        deep_event_active_cap=2048,
        deep_link_active_peak=2,
        deep_link_active_cap=4096,
        deep_trial_active_peak=3,
        deep_trial_active_cap=6144,
        deep_outcome_active_peak=6,
        deep_outcome_active_cap=18432,
        duplicate_identity_count=0,
        referential_integrity_error_count=0,
        row_integrity_error_count=0,
        export_status="OK",
        completion_status="NATURAL",
    )
    _write(contract.RUN_SUMMARY_FILE, [summary])
    file_hashes = {
        filename: hashlib.sha256((ROOT / filename).read_bytes()).hexdigest()
        for filename in contract.RUN_FILES
    }
    provenance = {
        "fixture_id": RUN_ID,
        "schema_version": contract.SUPPORTED_SCHEMA_VERSION,
        "feature_set_id": contract.SUPPORTED_FEATURE_SET_ID,
        "registry_sha256": contract.COLUMN_TYPE_REGISTRY_SHA256,
        "files": file_hashes,
        "generator": Path(__file__).name,
    }
    (ROOT / "fixture_provenance.json").write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n",
        encoding="ascii",
    )


if __name__ == "__main__":
    generate()
