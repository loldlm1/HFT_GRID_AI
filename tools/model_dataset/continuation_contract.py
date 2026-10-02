"""Pinned continuation wire and exhaustive, source-checked semantic state serializers.

This is a separate opt-in family. Existing complete-run schemas/readers are frozen.
The generated state functions observe engine owners; shared capture imports no engine.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from .schema_contract import MANIFEST_KEYS, NULL, PROFILES, SUMMARY_KEYS

FAMILY = "MQL5_MODEL_CONTINUATION"
VERSION = "1"
MAX_ROW_BYTES = 1024 * 1024
MAX_PAYLOAD_BYTES = 480 * 1024
ZERO = "0" * 64
FILES = {
    "segment_manifest.tsv": ("key", "value"),
    "input_events.tsv": (
        "record_ordinal", "first_input_ordinal", "last_input_ordinal", "boundary_callback",
        "first_broker_time_msc", "last_broker_time_msc", "first_observer_time_msc", "observer_time_msc",
        "first_monotonic_us", "monotonic_us",
        "input_count", "available_count", "unavailable_count", "tick_count", "timer_count",
        "trade_count", "input_chain_sha256", "quote_hex", "connected", "synchronized",
        "acquisition", "transaction_hex", "maximum_quote_age_msc", "last_quote_age_msc",
        "broker_estimate_time_msc", "history_observations", "history_chain_sha256",
        "maximum_observer_gap_msc", "maximum_monotonic_gap_us",
        "capture_status", "quote_status", "fresh_quote_count", "stale_quote_count",
        "missing_quote_count", "stale_tick_count", "stale_trade_count",
    ),
    "fact_events.tsv": (
        "fact_ordinal", "input_ordinal", "phase", "table_name", "row_key", "payload_hex",
    ),
    "window_births.tsv": (
        "birth_ordinal", "input_ordinal", "window_id", "open_time_msc",
        "source_time_msc", "source_close_time_msc", "macro_seconds",
        "source_open", "source_high", "source_low", "source_close", "valid", "reason",
        "raw_prices_hex", "trade_prices_hex", "first_observed_time_msc", "first_observed_bid",
    ),
    "state_checkpoint.tsv": ("boundary", "component", "object_id", "field", "value_type", "value"),
    "segment_seal.tsv": ("key", "value"),
}
WITNESS_FILES = {
    "witness_manifest.tsv": ("key", "value"),
    "input_prefix.tsv": FILES["input_events.tsv"],
    "fact_prefix.tsv": FILES["fact_events.tsv"],
    "window_prefix.tsv": FILES["window_births.tsv"],
    "state_checkpoint.tsv": FILES["state_checkpoint.tsv"],
    "witness_seal.tsv": ("key", "value"),
}
ENGINES = ("PIVOT_MACRO_V2", "CANDLE_PATTERN_ATR_V3")
ORIGIN_POLICIES = {
    "TESTER": {
        "acquisition_policy": "AUTHENTICATED_LOCAL_CUSTOM_TESTER_DELIVERY_V1",
        "startup_state_policy": "FIRST_DELIVERED_TICK_PRE_DISPATCH_FULL_STATE_V1",
        "history_binding_policy": "IMMUTABLE_ORIGINAL_ANCHOR_REGISTERED_PHYSICAL_JOB_HISTORY_V1",
        "observer_clock_basis": "TESTER_SIMULATED_QUOTE_SECONDS",
        "source_quality_policy": "HISTORICAL_SOURCE_GAPS_UNKNOWN_V1",
    },
    "LIVE_DEMO": {
        "acquisition_policy": "OBSERVED_CALLBACK_STREAM_FRESH_QUOTE_3S_V1",
        "startup_state_policy": "ONINIT_FULL_STATE_V1",
        "history_binding_policy": "INDEPENDENT_VERIFIED_NATIVE_HISTORY_RECEIPT_V1",
        "observer_clock_basis": "UTC_SECONDS",
        "source_quality_policy": "INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1",
    },
}
for _policy in ORIGIN_POLICIES.values():
    _policy.update(capture_liveness_policy="PHYSICAL_MONOTONIC_CALLBACK_OBSERVATION_V1",
                   quote_freshness_policy="NATIVE_BROKER_ESTIMATE_QUOTE_AGE_3S_V1",
                   closure_policy="INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1")

MANIFEST_KEYS_CONTINUATION = tuple("""
family continuation_version descriptor_sha256 engine origin source_id session_id physical_run_id
canonical_run_id source_proof configuration_proof history_proof segment_ordinal segment_seconds
predecessor_seal predecessor_state_sha256 replay_witness_id replay_witness_proof core_manifest_sha256
weekly_quote_sessions_hex weekly_trade_sessions_hex session_schedule_observed_time_msc
acquisition_policy closure_policy segment_phase observer_clock_basis capture_liveness_policy
quote_freshness_policy source_quality_policy startup_state_policy history_binding_policy
""".split())
SEAL_KEYS = tuple("""
completion first_input_ordinal last_input_ordinal first_fact_ordinal last_fact_ordinal
first_birth_ordinal last_birth_ordinal first_record_ordinal last_record_ordinal input_chain_sha256 end_state_sha256
""".split())
WITNESS_KEYS = tuple("""
family version descriptor_sha256 engine origin source_id session_id source_proof configuration_proof
history_proof core_manifest_sha256 last_input_ordinal last_fact_ordinal last_birth_ordinal predecessor_seal
anchor_state_sha256 end_state_sha256 legacy_source_proof native_fence_proof
""".split())
QUOTE_FIELDS = (
    ("time", "INT"), ("time_msc", "INT"), ("bid", "FLOAT64"), ("ask", "FLOAT64"),
    ("last", "FLOAT64"), ("volume", "UINT"), ("volume_real", "FLOAT64"), ("flags", "UINT"),
)
TRANSACTION_FIELDS = (
    ("transaction.type", "INT"), ("transaction.deal", "UINT"), ("transaction.order", "UINT"),
    ("transaction.symbol", "TEXT"), ("transaction.position", "UINT"), ("transaction.position_by", "UINT"),
    ("transaction.price", "FLOAT64"), ("transaction.price_sl", "FLOAT64"), ("transaction.price_tp", "FLOAT64"),
    ("transaction.volume", "FLOAT64"), ("transaction.order_type", "INT"), ("transaction.order_state", "INT"),
    ("transaction.deal_type", "INT"), ("transaction.time_type", "INT"), ("transaction.time_expiration", "INT"),
    ("transaction.price_trigger", "FLOAT64"), ("request_present", "BOOL"),
    ("request.action", "INT"), ("request.type", "INT"), ("request.magic", "UINT"),
    ("request.order", "UINT"), ("request.position", "UINT"), ("request.position_by", "UINT"),
    ("request.volume", "FLOAT64"), ("request.price", "FLOAT64"), ("request.sl", "FLOAT64"), ("request.tp", "FLOAT64"),
    ("request.deviation", "UINT"), ("request.type_filling", "INT"), ("request.type_time", "INT"),
    ("request.expiration", "INT"), ("request.comment_sha256", "HASH"), ("request.symbol", "TEXT"),
    ("request.stoplimit", "FLOAT64"), ("result.retcode", "UINT"), ("result.deal", "UINT"), ("result.order", "UINT"),
    ("result.volume", "FLOAT64"), ("result.price", "FLOAT64"), ("result.bid", "FLOAT64"), ("result.ask", "FLOAT64"),
    ("result.request_id", "UINT"), ("result.retcode_external", "INT"), ("result.comment_sha256", "HASH"),
)
PHYSICAL_SUMMARY_KEYS = ("buffer_peak",)
GENERATED_PATHS = (
    "services/model_features/continuation_schema.mqh",
    "services/model_features/continuation_shared_state.mqh",
    "services/trading_signals/pivot_continuation_state.mqh",
    "services/candle_pattern/continuation_state.mqh",
)
PYTHON_SEMANTIC_OWNERS = (
    "tools/model_dataset/schema_contract.py", "tools/model_dataset/feature_contract.py",
    "tools/model_dataset/clock.py", "tools/model_dataset/reader.py", "tools/model_dataset/semantics.py",
    "tools/model_dataset/engines/pivot.py", "tools/model_dataset/engines/candle.py",
    "tools/model_dataset/continuation_contract.py", "tools/model_dataset/continuation_reader.py",
    "tools/model_dataset/native_evidence.py",
)


def proof_keys(files) -> tuple[str, ...]:
    return tuple(f"{kind}_{name}" for name in files for kind in ("rows", "bytes", "chain"))


def manifest_keys() -> tuple[str, ...]:
    return MANIFEST_KEYS_CONTINUATION + tuple("core_" + key for key in MANIFEST_KEYS)


def seal_keys(engine: str, completion: str) -> tuple[str, ...]:
    keys = proof_keys(tuple(FILES)[:-1]) + SEAL_KEYS
    if completion in {"TERMINAL", "INTERRUPTED"}:
        keys += tuple("core_summary_" + key for key in SUMMARY_KEYS)
        keys += tuple("core_summary_rows_" + t.name for t in PROFILES[engine].tables if t.name != "run_summary.tsv")
    return keys


def semantic_source_pins(root: Path) -> dict[str, str]:
    # Pin source bytes, not timestamps or caller strings. Generated bodies are
    # checked separately against this registry to avoid a circular digest.
    paths = [root / name for name in PYTHON_SEMANTIC_OWNERS]
    paths += list(root.glob("*.mq5")) + list((root / "services").rglob("*.mqh"))
    paths = [p for p in paths if p.relative_to(root).as_posix() not in GENERATED_PATHS]
    if len(paths) > 256:
        raise ValueError("Unbounded semantic source inventory")
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}



def source_digest(root: Path | None = None) -> str:
    pins = semantic_source_pins(root or project_root())
    return hashlib.sha256(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


STRUCT_PATHS = {
    "PivotPriceLadder": "services/indicators/pivot_points_calculator.mqh",
    "EntryAdmissionFacts": "services/utils/broker_constraints_helper.mqh",
    "SymbolTradingConstraints": "services/utils/broker_constraints_helper.mqh",
    "ModelStructurePivot": "services/model_features/stochastic_structure.mqh",
    "ModelStructureState": "services/model_features/stochastic_structure.mqh",
    "PivotFractalWindowState": "services/trading_signals/pivot_fractal_engine_state.mqh",
    "BrokerExecutionCheck": "services/trading_signals/pivot_signal_struct.mqh",
    "PivotSignalRoute": "services/trading_signals/pivot_signal_struct.mqh",
    "PivotSignalExecution": "services/trading_signals/pivot_signal_struct.mqh",
    "PivotSignal": "services/trading_signals/pivot_signal_struct.mqh",
    "PivotTrialIdentity": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialOriginSnapshot": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialGeometry": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialMoneyPlan": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialEntry": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialParityLink": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotTrialActiveState": "services/trading_signals/pivot_trial_matrix_struct.mqh",
    "PivotDatasetPendingOrigin": "services/trading_signals/pivot_dataset_adapter.mqh",
    "CandleAttempt": "services/candle_pattern/state.mqh",
    "CandleBrokerRecord": "services/candle_pattern/state.mqh",
    "CandleVirtualRecord": "services/candle_pattern/state.mqh",
}
NATIVE_FIELDS = {
    "MqlRates": (
        ("datetime", "time", None), ("double", "open", None), ("double", "high", None),
        ("double", "low", None), ("double", "close", None), ("long", "tick_volume", None),
        ("int", "spread", None), ("long", "real_volume", None),
    ),
}
# Fields are serialized in declaration order. Enums preserve their native integer.
COMMON_SCALARS = (
    ("bool", "g_cont_anchor_pending"),
    ("string", "g_cont_history_chain"), ("long", "g_cont_history_observations"),
    ("bool", "g_model_failed"), ("long", "g_model_first_time"), ("long", "g_model_last_time"), ("long", "g_model_sequence"),
    ("long", "g_model_feature_gaps"), ("double", "g_model_point"), ("double", "g_model_tick_size"),
    ("string", "g_model_specification"), ("bool", "g_model_last_capture_complete"),
    ("datetime", "g_model_macro_open"), ("string", "g_model_window_id"),
    ("bool", "g_model_source_available"), ("bool", "g_model_window_written"),
    ("string", "g_model_window_reason"), ("int", "g_model_pp_arm"),
    ("long", "g_model_pp_arm_time"), ("double", "g_model_pp_arm_bid"),
    ("long", "g_model_window_first_time"), ("double", "g_model_window_first_bid"),
    ("double", "g_model_previous_bid"), ("int", "g_model_tested"),
    ("datetime", "g_model_structure_cutoff"), ("datetime", "g_model_structure_cursor"),
    ("long", "g_model_structure_first_date"), ("bool", "g_model_structure_initialized"),
    ("bool", "g_model_structure_history_changed"), ("bool", "g_model_structure_ready"),
    ("double", "g_model_structure_last_close"), ("double", "g_model_structure_last_k"),
    ("string", "g_model_structure_reason"), ("int", "g_model_warmup_count"),
    ("datetime", "g_model_warmup_first"), ("datetime", "g_model_warmup_last"),
    ("ulong", "g_model_warmup_fingerprint"), ("string", "g_model_warmup_status"),
)
PIVOT_SCALARS = (
    ("double", "g_bid"), ("double", "g_ask"), ("ulong", "g_execution_magic"),
    ("bool", "g_tester_interval_completed"), ("bool", "g_pivot_run_finalized"),
    ("int", "g_pivot_macro_seconds"), ("bool", "g_forced_stop_triggered"),
    ("bool", "g_debug_no_money_abort_pending"), ("bool", "g_pivot_startup_positions_block_entries"),
    ("datetime", "g_pivot_window_terminal_exported_open"),
    ("int", "g_pivot_trial_active_state_peak"), ("int", "g_pivot_trial_duplicate_identity_count"),
    ("bool", "g_pivot_trial_state_capacity_failed"), ("bool", "g_pivot_trial_state_allocation_failed"),
    ("bool", "g_pivot_dataset_research_discarded"), ("int", "g_pivot_dataset_broker_peak"),
    ("MarketStatusTypes", "g_market_status"), ("string", "g_market_status_reason"),
    ("datetime", "g_market_status_updated"),
)
CANDLE_SCALARS = (
    ("long", "g_candle_magic"), ("long", "g_candle_last_time"),
    ("int", "g_macro_seconds"), ("int", "g_micro_seconds"),
    ("long", "g_candle_sequence"), ("datetime", "g_last_micro_bar"),
    ("bool", "g_candle_stopping"), ("bool", "g_candle_tester_interval_completed"),
    ("int", "g_candle_broker_count"),
    ("int", "g_candle_virtual_count"), ("int", "g_candle_broker_extent"),
    ("int", "g_candle_virtual_extent"), ("int", "g_candle_broker_peak"),
    ("int", "g_candle_virtual_peak"), ("bool", "g_candle_broker_uncertain"),
    ("long", "g_candle_dataset_checks"),
)
COMMON_OBJECTS = (
    ("SHARED_LADDER", "PivotPriceLadder", "g_model_ladder", None, 1),
    ("SHARED_MACRO_SOURCE", "MqlRates", "g_model_macro_source", None, 1),
    ("SHARED_STRUCTURE", "ModelStructureState", "g_model_structure", None, 1),
    ("SHARED_CONFIRMED_HIGH", "ModelStructurePivot", "g_model_confirmed_high", None, 1),
    ("SHARED_CONFIRMED_LOW", "ModelStructurePivot", "g_model_confirmed_low", None, 1),
    ("SHARED_CONFIRMED_EVENT", "ModelStructurePivot", "g_model_confirmed_event", None, 1),
)
PIVOT_OBJECTS = (
    ("PIVOT_WINDOW", "PivotFractalWindowState", "g_pivot_fractal_window", None, 1),
    ("PIVOT_CONSTRAINTS", "SymbolTradingConstraints", "g_symbol_constraints", None, 1),
    ("PIVOT_SIGNAL", "PivotSignal", "g_pivot_signals", "ArraySize(g_pivot_signals)", 2048),
    ("PIVOT_DEFERRED_CLOSE", "PivotSignal", "g_pivot_deferred_closes", "ArraySize(g_pivot_deferred_closes)", 2048),
    ("PIVOT_PENDING_ORIGIN", "PivotDatasetPendingOrigin", "g_pivot_dataset_pending_origins", "ArraySize(g_pivot_dataset_pending_origins)", 7),
    ("PIVOT_PARITY", "PivotTrialParityLink", "g_pivot_dataset_parity_links", "ArraySize(g_pivot_dataset_parity_links)", 2048),
    ("PIVOT_TRIAL", "PivotTrialActiveState", "g_pivot_trial_active_states", "ArraySize(g_pivot_trial_active_states)", 2048),
    ("PIVOT_MIDPOINT_CHECK", "BrokerExecutionCheck", "g_pivot_midpoint_entry_facts", None, 1),
)
CANDLE_OBJECTS = (
    ("CANDLE_BROKER", "CandleBrokerRecord", "g_candle_brokers", "g_candle_broker_extent", 2048),
    ("CANDLE_VIRTUAL", "CandleVirtualRecord", "g_candle_virtuals", "g_candle_virtual_extent", 6144),
)
COMMON_ARRAYS = (
    ("long", "g_model_touch_time", 7), ("long", "g_model_touch_sequence", 7),
    ("int", "g_model_touch_role", 7), ("bool", "g_model_reclaimed", 7),
    ("bool", "g_model_gap_cross", 7),
)


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def struct_fields(root: Path) -> dict:
    result = dict(NATIVE_FIELDS)
    for name, filename in STRUCT_PATHS.items():
        text = (root / filename).read_text(encoding="utf-8-sig")
        match = re.search(r"\bstruct\s+" + name + r"\s*\{", text)
        if not match:
            raise ValueError("Missing state structure: " + name)
        tail = text[match.end():]
        depth, start, fields = 1, 0, []
        for index, char in enumerate(tail):
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    break
                if depth == 1:
                    start = index + 1
            elif char == ";" and depth == 1:
                token = tail[start:index].strip().split("\n")[-1].strip()
                declaration = re.fullmatch(r"(\w+)\s+(\w+)(?:\[([^\]]+)\])?", token)
                if declaration:
                    native, field, length = declaration.groups()
                    if length is not None:
                        if length != "PIVOT_LEVEL_COUNT":
                            raise ValueError("Unregistered state array: " + token)
                        length = 7
                    fields.append((native, field, length))
                elif token and "(" not in token and not token.startswith("//"):
                    raise ValueError("Unparsed state declaration: " + token)
                start = index + 1
        if not fields:
            raise ValueError("Empty state structure: " + name)
        result[name] = tuple(fields)
    return result


def scalar_type(native: str, field: str = "") -> str:
    if native == "string":
        return "HASH" if field.endswith("_comment") or field == "g_cont_history_chain" else "TEXT"
    if native in {"ulong", "uint", "ushort", "uchar"}:
        return "UINT"
    if native == "double":
        return "FLOAT64"
    if native == "bool":
        return "BOOL"
    return "INT"


def flatten(structs: dict, name: str, prefix: str = "") -> list[dict]:
    output = []
    for native, field, length in structs[name]:
        for index in range(length or 1):
            suffix = f"[{index}]" if length is not None else ""
            path = prefix + field + suffix
            if native in structs:
                output.extend(flatten(structs, native, path + "."))
            else:
                output.append({"field": path, "native_type": native, "value_type": scalar_type(native, field)})
    return output


def state_registry(root: Path | None = None) -> dict:
    structs = struct_fields(root or project_root())
    groups = {}
    for component, scalars in (
        ("SHARED_CONTROL", COMMON_SCALARS), ("PIVOT_CONTROL", PIVOT_SCALARS), ("CANDLE_CONTROL", CANDLE_SCALARS),
    ):
        groups[component] = {"maximum": 1, "fields": [
            {"field": name, "native_type": native, "value_type": scalar_type(native, name)}
            for native, name in scalars
        ]}
    for native, name, length in COMMON_ARRAYS:
        groups["SHARED_CONTROL"]["fields"].extend(
            {"field": f"{name}[{index}]", "native_type": native, "value_type": scalar_type(native, name)}
            for index in range(length)
        )
    for component, struct, _variable, _extent, maximum in (*COMMON_OBJECTS, *PIVOT_OBJECTS, *CANDLE_OBJECTS):
        groups[component] = {"maximum": maximum, "indexed": _extent is not None, "fields": flatten(structs, struct)}
    return groups


def descriptor(root: Path | None = None) -> dict:
    return {
        "family": FAMILY, "continuation_version": VERSION, "operational": False,
        "hash_policy": "SHA256_PREVIOUS32_PLUS_EXACT_UTF8_ROW_CRLF_V1",
        "native_text_policy": {"null": NULL, "empty": "-", "nonempty": "LOWERCASE_UTF8_HEX",
                               "scope": "TYPED_TEXT_STATE_AND_TRANSACTION_FIELDS_ONLY"},
        "native_double_policy": "FINITE_IEEE754_BINARY64_16_LOWERCASE_HEX_DBL_MAX_SENTINEL_AND_SIGNED_ZERO_V1",
        "private_text_hash_policy": "SHA256_MQL5_NATIVE_NULL_OR_EMPTY_OR_UTF8_CRLF_TAG_V1",
        "physical_identity": "EXPLICIT_PHYSICAL_RUN_TO_CANONICAL_SOURCE_SESSION_V1",
        "replay": "COMPLETE_CANONICAL_INPUT_CHAIN_EXACT_FACT_BIRTH_PREFIX_AND_PREFINALIZATION_STATE_V1",
        "origins": ["TESTER", "LIVE_DEMO"],
        "origin_policies": ORIGIN_POLICIES,
        "tester_delivery_evidence": "OUT_OF_BAND_NATIVE_OWNER_REGISTRY_EXACT_ORIGINAL_JOB_ARTIFACTS_V1",
        "tester_history_receipts": {"anchor": "IMMUTABLE_ORIGINAL_REGISTERED_SOURCE_HISTORY_RECEIPT",
                                    "physical_job": "EXACT_REGISTERED_DATED_NATIVE_JOB_HISTORY_RECEIPT"},
        "tester_cold_admission": "PROVISIONAL_DELIVERY_ONLY_PAIRED_REPLAY_AND_PENDING_FENCE_REQUIRED",
        "all_tick_capture_supported": False,
        "input_blocks": {"flush_span_msc": 60000, "maximum_span_msc": 63000, "maximum_callbacks": 65536,
                         "live_observer_gap_limit_msc": 3000, "live_monotonic_gap_limit_us": 3000000,
                         "tester_quote_gaps": "RETAINED_SOURCE_QUALITY_UNKNOWN",
                         "flush_on": ["SPAN_OR_CALLBACK_CAP", "TRADE", "COVERAGE_CHANGE", "GAP", "ROTATION"]},
        "closure_policy": "INDEPENDENT_VERIFIED_CALENDAR_RECEIPT_ONLY_V1",
        "operator_proofs": "AUTO_SOURCE_AND_OBSERVED_CONFIG_OPTIONAL_EXPECTED_PINS_HISTORY_INDEPENDENT_NATIVE_RECEIPT_V1",
        "native_fence_policy": "INDEPENDENT_NATIVE_TERMINAL_EFFECT_AUDIT_BEFORE_TESTER_REPLAY_V1",
        "seal_publication": "PAYLOAD_CLOSE_THEN_PRIVATE_SEAL_FILEMOVE_V1",
        "clocks": {"broker": "NATIVE_MILLISECONDS", "tester_observer": "TESTER_SIMULATED_QUOTE_SECONDS",
                   "demo_observer": "UTC_SECONDS", "heartbeat_limit_ms": 3000},
        "maximum_row_bytes": MAX_ROW_BYTES, "maximum_payload_bytes": MAX_PAYLOAD_BYTES,
        "files": [{"name": name, "columns": list(columns)} for name, columns in FILES.items()],
        "manifest_keys": list(manifest_keys()),
        "seal_keys": {engine: {status: list(seal_keys(engine, status)) for status in
                              ("ROTATED", "PRE_FINALIZATION", "TERMINAL", "INTERRUPTED")} for engine in ENGINES},
        "witness_manifest_keys": list(WITNESS_KEYS),
        "witness_seal_keys": list(proof_keys(tuple(WITNESS_FILES)[:-1])),
        "quote_fields": [{"field": field, "value_type": kind} for field, kind in QUOTE_FIELDS],
        "transaction_fields": [{"field": field, "value_type": kind} for field, kind in TRANSACTION_FIELDS],
        "transaction_request_policy": "REQUEST_AND_RESULT_PRESENT_ONLY_FOR_TRADE_TRANSACTION_REQUEST_V1",
        "semantic_source_sha256": semantic_source_pins(root or project_root()),
        "source_sha256": source_digest(root),
        "bootstrap": {"whole_original_source_required": True, "paired_terminal_branch_retained": True,
                      "extendable_completion": "ROTATED", "legacy_binding_is_acceptance": False,
                      "physical_summary_keys": list(PHYSICAL_SUMMARY_KEYS),
                      "semantic_summary_keys": [k for k in SUMMARY_KEYS if k not in PHYSICAL_SUMMARY_KEYS]},
        "state_exclusions": {
            "physical_export": "FILE_HANDLES_LAYOUT_BUFFERS_ROW_COUNTERS_AND_SEAL_FLAGS",
            "indicator_handles": "RECREATED_BY_EXACT_PINNED_CONFIG_CONSUMED_VALUES_HASHED",
            "diagnostics": "LOGGING_AUDIT_VISUAL_COUNTERS_WITHOUT_ENGINE_DECISIONS",
        },
        "witness_files": [{"name": name, "columns": list(columns)} for name, columns in WITNESS_FILES.items()],
        "profiles": {engine: {
            "engine": engine, "producer_version": PROFILES[engine].producer_version,
            "schema_version": "1", "feature_set": "macro_micro_standard_v1",
            "extension_version": "1", "outcome_policy": PROFILES[engine].outcome_policy,
            "tables": [
                {"name": table.name, "key": table.key, "fields": [
                    {"name": f.name, "type": f.type, "nullable": f.nullable, "choices": list(f.choices)}
                    for f in table.fields
                ]}
                for table in PROFILES[engine].tables
                if table.name not in {"run_manifest.tsv", "run_summary.tsv"}
            ],
            "components": list(
                ("SHARED_CONTROL", *(x[0] for x in COMMON_OBJECTS),
                 "PIVOT_CONTROL" if engine.startswith("PIVOT") else "CANDLE_CONTROL",
                 *(x[0] for x in (PIVOT_OBJECTS if engine.startswith("PIVOT") else CANDLE_OBJECTS)))
            ),
        } for engine in ENGINES},
        "state_registry": state_registry(root),
    }


def descriptor_digest(root: Path | None = None) -> str:
    return hashlib.sha256(json.dumps(descriptor(root), sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def mql_value(native: str, access: str, field: str) -> str:
    kind = scalar_type(native, field)
    if kind == "TEXT":
        return f'ModelContinuationHex({access}, "STATE:{field}")'
    if kind == "HASH":
        return access if field == "g_cont_history_chain" else f"ModelContinuationPrivateTextHash({access})"
    if kind == "FLOAT64":
        return f"ModelContinuationNumber({access})"
    if kind == "BOOL":
        return f"ModelBoolean({access})"
    if kind == "UINT":
        return f'StringFormat("%I64u", (ulong){access})'
    return f"ModelInteger((long){access})"


def generated_state(root: Path, scope: str) -> str:
    registry = state_registry(root)
    scalars = {"shared": COMMON_SCALARS, "pivot": PIVOT_SCALARS, "candle": CANDLE_SCALARS}[scope]
    objects = {"shared": COMMON_OBJECTS, "pivot": PIVOT_OBJECTS, "candle": CANDLE_OBJECTS}[scope]
    component = scope.upper() + "_CONTROL"
    name = scope.capitalize() + "ContinuationState"
    lines = [
        "// Generated by tools.model_dataset.continuation_contract; do not edit.",
        f"#ifndef MODEL_CONTINUATION_{scope.upper()}_STATE_MQH",
        f"#define MODEL_CONTINUATION_{scope.upper()}_STATE_MQH",
        "", f"void {name}()", "{",
    ]
    for native, variable in scalars:
        lines.append(f'  ModelContinuationState("{component}", "0", "{variable}", "{scalar_type(native, variable)}", {mql_value(native, variable, variable)});')
    if scope == "shared":
        for native, variable, length in COMMON_ARRAYS:
            for index in range(length):
                field = f"{variable}[{index}]"
                lines.append(f'  ModelContinuationState("{component}", "0", "{field}", "{scalar_type(native, variable)}", {mql_value(native, field, variable)});')
    for component, _struct, variable, extent, maximum in objects:
        if extent:
            lines.extend([
                f'  int count_{variable} = {extent};',
                f'  if(count_{variable} < 0 || count_{variable} > {maximum}) {{ ModelFail("CONTINUATION_STATE_CAP"); return; }}',
                f'  ModelContinuationState("{component}", "0", "_count", "INT", ModelInteger(count_{variable}));',
                f"  for(int index = 0; index < count_{variable}; index++)", "  {",
            ])
            object_id, access, indent = "ModelInteger(index)", variable + "[index]", "    "
        else:
            object_id, access, indent = '"0"', variable, "  "
        for field in registry[component]["fields"]:
            path = field["field"]
            lines.append(
                f'{indent}ModelContinuationState("{component}", {object_id}, "{path}", "{field["value_type"]}", '
                f'{mql_value(field["native_type"], access + "." + path, path)});'
            )
        if extent:
            lines.append("  }")
    lines.extend(["}", "", "#endif", ""])
    return "\n".join(lines)


def generated_wire(root: Path) -> str:
    lines = ["// Generated by tools.model_dataset.continuation_contract; do not edit.",
             "#ifndef MODEL_CONTINUATION_SCHEMA_MQH", "#define MODEL_CONTINUATION_SCHEMA_MQH",
             f'const string MODEL_CONTINUATION_DIGEST = "{descriptor_digest(root)}";',
             f'const string MODEL_CONTINUATION_SOURCE_SHA256 = "{source_digest(root)}";',
             f"enum {{ MODEL_CONTINUATION_FILE_COUNT = 6, MODEL_CONTINUATION_INPUT_WIDTH = {len(FILES['input_events.tsv'])}, MODEL_CONTINUATION_TRANSACTION_WIDTH = {len(TRANSACTION_FIELDS)} }};",
             "string ModelContinuationFilename(const int file)", "{", "  switch(file)", "  {"]
    for index, name in enumerate(FILES):
        lines.append(f'    case {index}: return "{name}";')
    lines.extend(['  }', '  return "";', '}', "string ModelContinuationHeader(const int file)", "{", "  switch(file)", "  {"])
    for index, columns in enumerate(FILES.values()):
        header = r"\t".join(columns)
        lines.append(f'    case {index}: return "{header}";')
    lines.extend(['  }', '  return "";', '}', "string ModelContinuationRowKey(const int file)", "{", "  switch(file)", "  {"])
    seen = set()
    for engine in ENGINES:
        for table in PROFILES[engine].tables:
            if table.name in seen or table.name in {"run_manifest.tsv", "run_summary.tsv"}:
                continue
            seen.add(table.name)
            enum = "MODEL_" + table.name.removesuffix(".tsv").upper()
            lines.append(f'    case {enum}: return "{table.key}";')
    lines.extend(['  }', '  return "";', '}'])
    for function, members in (("WitnessFilename", tuple(WITNESS_FILES)),
                              ("WitnessManifestKey", WITNESS_KEYS),
                              ("WitnessSealKey", proof_keys(tuple(WITNESS_FILES)[:-1]))):
        lines.extend([f"string ModelContinuation{function}(const int index)", "{", "  switch(index)", "  {"])
        for index, member in enumerate(members):
            lines.append(f'    case {index}: return "{member}";')
        lines.extend(['  }', '  return "";', '}'])
    lines.extend(['#endif', ''])
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-json", type=Path)
    parser.add_argument("--write-generated", action="store_true")
    parser.add_argument("--check-generated", action="store_true")
    args = parser.parse_args(argv)
    root = project_root()
    generated = {
        "services/model_features/continuation_schema.mqh": generated_wire(root),
        "services/model_features/continuation_shared_state.mqh": generated_state(root, "shared"),
        "services/trading_signals/pivot_continuation_state.mqh": generated_state(root, "pivot"),
        "services/candle_pattern/continuation_state.mqh": generated_state(root, "candle"),
    }
    if args.write_json:
        args.write_json.parent.mkdir(parents=True, exist_ok=True)
        args.write_json.write_text(json.dumps(descriptor(root), indent=2) + "\n", encoding="utf-8")
    for filename, content in generated.items():
        path = root / filename
        if args.write_generated:
            path.write_text(content, encoding="utf-8", newline="\n")
        if args.check_generated and (not path.exists() or path.read_text(encoding="utf-8") != content):
            parser.error("Generated continuation header mismatch: " + filename)
    print(json.dumps({"family": FAMILY, "version": VERSION, "descriptor_sha256": descriptor_digest(root),
                      "operational": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
