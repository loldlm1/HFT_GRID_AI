//+------------------------------------------------------------------+
//|                                         signal_params_struct.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_

// TRADING SIGNALS STRUCTURES

struct ExecutionLegState
{
  int               level_index;
  ExecutionLegStatuses status;
  ExecutionEntryStyles   entry_style;

  double lot_size;
  double initial_lot_size;
  double next_level_price;
  double entry_price;
  double take_profit_price;
  double initial_take_profit_price;
  double entry_reference_price;

  datetime last_action_time;
  ulong    position_ticket;
  string   position_comment;
  bool     opens_position;
  bool     limit_activation_armed;

  ExecutionLegState()
  {
    level_index                 = -1;
    status                      = EXECUTION_LEG_INACTIVE;
    entry_style                 = EXECUTION_ENTRY_STYLE_STOP;
    lot_size                    = 0.0;
    initial_lot_size            = 0.0;
    next_level_price            = 0.0;
    entry_price                 = 0.0;
    take_profit_price           = 0.0;
    initial_take_profit_price   = 0.0;
    entry_reference_price       = 0.0;
    last_action_time            = 0;
    position_ticket             = 0;
    position_comment            = "";
    opens_position              = true;
    limit_activation_armed      = true;
  }
};

struct ResolvedStructureEntryAnchor
{
  bool   valid;
  double percent;
  double price;

  ResolvedStructureEntryAnchor()
  {
    valid   = false;
    percent = 0.0;
    price   = 0.0;
  }
};

struct SignalParams
{
  SignalTypes                signal_type;
  SignalStates               signal_state;
  int                        strategy_id;
  string                     strategy_label;
  ENUM_TIMEFRAMES            strategy_base_timeframe;
  ENUM_TIMEFRAMES            strategy_macro_timeframe;
  int                        strategy_base_delay;
  int                        strategy_macro_delay;
  bool                       deterministic_strategy;
  string                     execution_sequence_id;
  string                     deterministic_source_key;
  int                        deterministic_source_attempt_index;
  StrategyContextTypes       strategy_context;
  ENUM_TIMEFRAMES            strategy_timeframe;
  string                     strategy_context_label;
  StructureTriggerEntryModes entry_trigger_mode;
  double                     entry_price;
  ResolvedStructureEntryAnchor  resolved_structure_entry;
  bool                       entry_is_limit;
  double                     close_price;
  double                     stop_loss;
  double                     take_profit;
  double                     lot_size;
  double                     raw_profit;
  int                        signal_lot_sequence_step;
  datetime                   entry_time;
  datetime                   close_time;
  datetime                   source_extremum_time;
  int                        source_extremum_slot;
  bool                       source_extremum_confirmed;
  bool                       source_extremum_is_peak;
  double                     source_extremum_price;
  double                     source_extremum_high;
  double                     source_extremum_low;
  double                     raw_entry_trigger_price;
  double                     raw_stop_anchor_price;
  double                     raw_take_profit_price;
  double                     raw_risk_distance;
  double                     realized_profit;
  double                     realized_closed_volume;
  double                     remaining_open_volume;
  bool                       broker_entry_confirmed;
  bool                       broker_close_confirmed;
  string                     broker_close_source;
  bool                       partial_tp1_confirmed;
  bool                       partial_tp2_confirmed;
  bool                       partial_tp3_confirmed;
  double                     partial_tp1_closed_volume;
  double                     partial_tp2_closed_volume;
  double                     partial_tp3_closed_volume;
  double                     partial_tp1_close_price;
  double                     partial_tp2_close_price;
  double                     partial_tp3_close_price;
  datetime                   partial_tp1_close_time;
  datetime                   partial_tp2_close_time;
  datetime                   partial_tp3_close_time;
  string                     deterministic_stats_signal_id;
  bool                       deterministic_stats_feature_exported;
  bool                       deterministic_stats_outcome_exported;
  string                     deterministic_stats_terminal_reason;
  ExecutionAdmissionStatuses admission_status;
  string                     admission_block_source;
  string                     admission_block_reason;
  datetime                   admission_updated_time;
  double                     admission_spread_points;
  double                     admission_max_spread;
  MarketStatusTypes          admission_market_status;
  string                     ml_shadow_signal_id;
  bool                       ml_shadow_evaluated;
  bool                       ml_shadow_available;
  bool                       ml_shadow_feature_valid;
  bool                       ml_shadow_classifier_scored;
  bool                       ml_shadow_regressor_scored;
  string                     ml_shadow_model_id;
  string                     ml_shadow_export_id;
  double                     ml_shadow_classifier_score;
  double                     ml_shadow_regressor_score;
  double                     ml_shadow_threshold;
  string                     ml_shadow_recommendation;
  string                     ml_shadow_reason;
  bool                       ml_shadow_outcome_exported;

  bool   execution_initialized;
  double execution_base_distance_points;
  double execution_initial_indicator_distance_points;
  double execution_resolved_distance_points;
  double execution_base_lot_size;
  double execution_entry_reference_price;
  double execution_entry_gap_points;
  double execution_entry_offset_points;
  bool   execution_risk_plan_valid;
  string execution_risk_plan_reason;
  double execution_risk_target_amount;
  double execution_expected_sl_loss;
  double execution_expected_tp_profit;
  double execution_raw_lot_size;
  double execution_normalized_lot_size;
  double execution_target_error_amount;
  int    structure_range_step_offset;
  datetime context_structure_snapshot_time;

  bool                      base_structure_valid;
  StochasticMarketStructure base_structure_data;

  bool                      trend_structure_valid;
  StochasticMarketStructure trend_structure_data;

  bool                      macro_structure_valid;
  StochasticMarketStructure macro_structure_data;

  bool                      session_structure_valid;
  StochasticMarketStructure session_structure_data;

  ExecutionLegState execution_legs[];

  SignalParams()
  {
    signal_type                = NO_SIGNAL;
    signal_state               = WAITING;
    strategy_id                = DETERMINISTIC_STRATEGY_NONE;
    strategy_label             = "BASE";
    strategy_base_timeframe    = PERIOD_CURRENT;
    strategy_macro_timeframe   = PERIOD_CURRENT;
    strategy_base_delay        = 0;
    strategy_macro_delay       = 0;
    deterministic_strategy     = false;
    execution_sequence_id       = "";
    deterministic_source_key    = "";
    deterministic_source_attempt_index = 0;
    strategy_context           = CONTEXT_SLOT_BASE;
    strategy_timeframe         = PERIOD_CURRENT;
    strategy_context_label     = "BASE";
    entry_trigger_mode         = LEVELS_AS_LIMITS;
    entry_price                = 0.0;
    resolved_structure_entry   = ResolvedStructureEntryAnchor();
    entry_is_limit             = false;
    close_price                = 0.0;
    stop_loss                  = 0.0;
    take_profit                = 0.0;
    lot_size                   = 0.0;
    raw_profit                 = 0.0;
    signal_lot_sequence_step   = 0;
    entry_time                 = 0;
    close_time                 = 0;
    source_extremum_time       = 0;
    source_extremum_slot       = -1;
    source_extremum_confirmed  = false;
    source_extremum_is_peak    = false;
    source_extremum_price      = 0.0;
    source_extremum_high       = 0.0;
    source_extremum_low        = 0.0;
    raw_entry_trigger_price    = 0.0;
    raw_stop_anchor_price      = 0.0;
    raw_take_profit_price      = 0.0;
    raw_risk_distance          = 0.0;
    realized_profit            = 0.0;
    realized_closed_volume     = 0.0;
    remaining_open_volume      = 0.0;
    broker_entry_confirmed     = false;
    broker_close_confirmed     = false;
    broker_close_source        = "";
    partial_tp1_confirmed      = false;
    partial_tp2_confirmed      = false;
    partial_tp3_confirmed      = false;
    partial_tp1_closed_volume  = 0.0;
    partial_tp2_closed_volume  = 0.0;
    partial_tp3_closed_volume  = 0.0;
    partial_tp1_close_price    = 0.0;
    partial_tp2_close_price    = 0.0;
    partial_tp3_close_price    = 0.0;
    partial_tp1_close_time     = 0;
    partial_tp2_close_time     = 0;
    partial_tp3_close_time     = 0;
    deterministic_stats_signal_id = "";
    deterministic_stats_feature_exported = false;
    deterministic_stats_outcome_exported = false;
    deterministic_stats_terminal_reason = "";
    admission_status          = EXECUTION_ADMISSION_NOT_EVALUATED;
    admission_block_source    = "";
    admission_block_reason    = "";
    admission_updated_time    = 0;
    admission_spread_points   = 0.0;
    admission_max_spread      = 0.0;
    admission_market_status   = MARKET_STATUS_ACTIVE;
    ml_shadow_signal_id = "";
    ml_shadow_evaluated = false;
    ml_shadow_available = false;
    ml_shadow_feature_valid = false;
    ml_shadow_classifier_scored = false;
    ml_shadow_regressor_scored = false;
    ml_shadow_model_id = "";
    ml_shadow_export_id = "";
    ml_shadow_classifier_score = 0.0;
    ml_shadow_regressor_score = 0.0;
    ml_shadow_threshold = 0.0;
    ml_shadow_recommendation = "";
    ml_shadow_reason = "";
    ml_shadow_outcome_exported = false;
    execution_initialized       = false;
    execution_base_distance_points = 0.0;
    execution_initial_indicator_distance_points = 0.0;
    execution_resolved_distance_points = 0.0;
    execution_base_lot_size         = 0.0;
    execution_entry_reference_price = 0.0;
    execution_entry_gap_points      = 0.0;
    execution_entry_offset_points   = 0.0;
    execution_risk_plan_valid       = false;
    execution_risk_plan_reason      = "";
    execution_risk_target_amount    = 0.0;
    execution_expected_sl_loss      = 0.0;
    execution_expected_tp_profit    = 0.0;
    execution_raw_lot_size          = 0.0;
    execution_normalized_lot_size   = 0.0;
    execution_target_error_amount   = 0.0;
    structure_range_step_offset     = 1;
    context_structure_snapshot_time = 0;
    base_structure_valid       = false;
    trend_structure_valid      = false;
    macro_structure_valid      = false;
    session_structure_valid    = false;
  }

  SignalParams(const SignalParams &signal_params)
  {
    signal_type                = signal_params.signal_type;
    signal_state               = signal_params.signal_state;
    strategy_id                = signal_params.strategy_id;
    strategy_label             = signal_params.strategy_label;
    strategy_base_timeframe    = signal_params.strategy_base_timeframe;
    strategy_macro_timeframe   = signal_params.strategy_macro_timeframe;
    strategy_base_delay        = signal_params.strategy_base_delay;
    strategy_macro_delay       = signal_params.strategy_macro_delay;
    deterministic_strategy     = signal_params.deterministic_strategy;
    execution_sequence_id       = signal_params.execution_sequence_id;
    deterministic_source_key    = signal_params.deterministic_source_key;
    deterministic_source_attempt_index = signal_params.deterministic_source_attempt_index;
    strategy_context           = signal_params.strategy_context;
    strategy_timeframe         = signal_params.strategy_timeframe;
    strategy_context_label     = signal_params.strategy_context_label;
    entry_trigger_mode         = signal_params.entry_trigger_mode;
    entry_price                = signal_params.entry_price;
    resolved_structure_entry   = signal_params.resolved_structure_entry;
    entry_is_limit             = signal_params.entry_is_limit;
    close_price                = signal_params.close_price;
    stop_loss                  = signal_params.stop_loss;
    take_profit                = signal_params.take_profit;
    lot_size                   = signal_params.lot_size;
    raw_profit                 = signal_params.raw_profit;
    signal_lot_sequence_step   = signal_params.signal_lot_sequence_step;
    entry_time                 = signal_params.entry_time;
    close_time                 = signal_params.close_time;
    source_extremum_time       = signal_params.source_extremum_time;
    source_extremum_slot       = signal_params.source_extremum_slot;
    source_extremum_confirmed  = signal_params.source_extremum_confirmed;
    source_extremum_is_peak    = signal_params.source_extremum_is_peak;
    source_extremum_price      = signal_params.source_extremum_price;
    source_extremum_high       = signal_params.source_extremum_high;
    source_extremum_low        = signal_params.source_extremum_low;
    raw_entry_trigger_price    = signal_params.raw_entry_trigger_price;
    raw_stop_anchor_price      = signal_params.raw_stop_anchor_price;
    raw_take_profit_price      = signal_params.raw_take_profit_price;
    raw_risk_distance          = signal_params.raw_risk_distance;
    realized_profit            = signal_params.realized_profit;
    realized_closed_volume     = signal_params.realized_closed_volume;
    remaining_open_volume      = signal_params.remaining_open_volume;
    broker_entry_confirmed     = signal_params.broker_entry_confirmed;
    broker_close_confirmed     = signal_params.broker_close_confirmed;
    broker_close_source        = signal_params.broker_close_source;
    partial_tp1_confirmed      = signal_params.partial_tp1_confirmed;
    partial_tp2_confirmed      = signal_params.partial_tp2_confirmed;
    partial_tp3_confirmed      = signal_params.partial_tp3_confirmed;
    partial_tp1_closed_volume  = signal_params.partial_tp1_closed_volume;
    partial_tp2_closed_volume  = signal_params.partial_tp2_closed_volume;
    partial_tp3_closed_volume  = signal_params.partial_tp3_closed_volume;
    partial_tp1_close_price    = signal_params.partial_tp1_close_price;
    partial_tp2_close_price    = signal_params.partial_tp2_close_price;
    partial_tp3_close_price    = signal_params.partial_tp3_close_price;
    partial_tp1_close_time     = signal_params.partial_tp1_close_time;
    partial_tp2_close_time     = signal_params.partial_tp2_close_time;
    partial_tp3_close_time     = signal_params.partial_tp3_close_time;
    deterministic_stats_signal_id = signal_params.deterministic_stats_signal_id;
    deterministic_stats_feature_exported = signal_params.deterministic_stats_feature_exported;
    deterministic_stats_outcome_exported = signal_params.deterministic_stats_outcome_exported;
    deterministic_stats_terminal_reason = signal_params.deterministic_stats_terminal_reason;
    admission_status          = signal_params.admission_status;
    admission_block_source    = signal_params.admission_block_source;
    admission_block_reason    = signal_params.admission_block_reason;
    admission_updated_time    = signal_params.admission_updated_time;
    admission_spread_points   = signal_params.admission_spread_points;
    admission_max_spread      = signal_params.admission_max_spread;
    admission_market_status   = signal_params.admission_market_status;
    ml_shadow_signal_id = signal_params.ml_shadow_signal_id;
    ml_shadow_evaluated = signal_params.ml_shadow_evaluated;
    ml_shadow_available = signal_params.ml_shadow_available;
    ml_shadow_feature_valid = signal_params.ml_shadow_feature_valid;
    ml_shadow_classifier_scored = signal_params.ml_shadow_classifier_scored;
    ml_shadow_regressor_scored = signal_params.ml_shadow_regressor_scored;
    ml_shadow_model_id = signal_params.ml_shadow_model_id;
    ml_shadow_export_id = signal_params.ml_shadow_export_id;
    ml_shadow_classifier_score = signal_params.ml_shadow_classifier_score;
    ml_shadow_regressor_score = signal_params.ml_shadow_regressor_score;
    ml_shadow_threshold = signal_params.ml_shadow_threshold;
    ml_shadow_recommendation = signal_params.ml_shadow_recommendation;
    ml_shadow_reason = signal_params.ml_shadow_reason;
    ml_shadow_outcome_exported = signal_params.ml_shadow_outcome_exported;
    execution_initialized       = signal_params.execution_initialized;
    execution_base_distance_points = signal_params.execution_base_distance_points;
    execution_initial_indicator_distance_points = signal_params.execution_initial_indicator_distance_points;
    execution_resolved_distance_points = signal_params.execution_resolved_distance_points;
    execution_base_lot_size         = signal_params.execution_base_lot_size;
    execution_entry_reference_price = signal_params.execution_entry_reference_price;
    execution_entry_gap_points      = signal_params.execution_entry_gap_points;
    execution_entry_offset_points   = signal_params.execution_entry_offset_points;
    execution_risk_plan_valid       = signal_params.execution_risk_plan_valid;
    execution_risk_plan_reason      = signal_params.execution_risk_plan_reason;
    execution_risk_target_amount    = signal_params.execution_risk_target_amount;
    execution_expected_sl_loss      = signal_params.execution_expected_sl_loss;
    execution_expected_tp_profit    = signal_params.execution_expected_tp_profit;
    execution_raw_lot_size          = signal_params.execution_raw_lot_size;
    execution_normalized_lot_size   = signal_params.execution_normalized_lot_size;
    execution_target_error_amount   = signal_params.execution_target_error_amount;
    structure_range_step_offset     = signal_params.structure_range_step_offset;
    context_structure_snapshot_time = signal_params.context_structure_snapshot_time;
    base_structure_valid       = signal_params.base_structure_valid;
    base_structure_data        = signal_params.base_structure_data;
    trend_structure_valid      = signal_params.trend_structure_valid;
    trend_structure_data       = signal_params.trend_structure_data;
    macro_structure_valid      = signal_params.macro_structure_valid;
    macro_structure_data       = signal_params.macro_structure_data;
    session_structure_valid    = signal_params.session_structure_valid;
    session_structure_data     = signal_params.session_structure_data;
    int legs_total = ArraySize(signal_params.execution_legs);
    ArrayResize(execution_legs, legs_total);
    for(int n = 0; n < legs_total; n++)
      execution_legs[n] = signal_params.execution_legs[n];
  }
};

string BuildDeterministicSignalSequenceId(const int strategy_id,
                                           const SignalTypes direction,
                                           const datetime entry_time,
                                           const datetime structure_time)
{
  string direction_token = (direction == BULLISH) ? "B" : "S";
  return StringFormat("%s_%s_%d_%d",
                      DeterministicStrategyLabel(strategy_id),
                      direction_token,
                      (int)entry_time,
                      (int)structure_time);
}

string BuildDeterministicSourceKey(const int strategy_id,
                                   const SignalTypes direction,
                                   const int source_slot,
                                   const datetime extremum_time,
                                   const bool source_is_peak,
                                   const double source_price)
{
  if(strategy_id <= DETERMINISTIC_STRATEGY_NONE)
    return "";
  if(direction != BULLISH && direction != BEARISH)
    return "";
  if(source_slot < 0 || extremum_time <= 0 || source_price <= 0.0)
    return "";

  int digits = Digits();
  if(digits <= 0)
    digits = 5;

  string direction_token = (direction == BULLISH) ? "BULLISH" : "BEARISH";
  string type_token = source_is_peak ? "PEAK" : "BOTTOM";
  double normalized_price = NormalizeDouble(source_price, digits);
  return StringFormat("%s|%s|slot=%d|%s|time=%d|price=%s",
                      DeterministicStrategyLabel(strategy_id),
                      direction_token,
                      source_slot,
                      type_token,
                      (int)extremum_time,
                      DoubleToString(normalized_price, digits));
}

string BuildDeterministicSignalSourceKey(const SignalParams &signal_params)
{
  return BuildDeterministicSourceKey(signal_params.strategy_id,
                                     signal_params.signal_type,
                                     signal_params.source_extremum_slot,
                                     signal_params.source_extremum_time,
                                     signal_params.source_extremum_is_peak,
                                     signal_params.source_extremum_price);
}

string BuildDeterministicSignalSourceFamilyKey(const SignalParams &signal_params)
{
  if(signal_params.signal_type != BULLISH && signal_params.signal_type != BEARISH)
    return "";
  if(signal_params.source_extremum_slot < 0 ||
     signal_params.source_extremum_time <= 0 ||
     signal_params.source_extremum_price <= 0.0)
    return "";

  int digits = Digits();
  if(digits <= 0)
    digits = 5;

  string direction_token = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string type_token = signal_params.source_extremum_is_peak ? "PEAK" : "BOTTOM";
  double normalized_price = NormalizeDouble(signal_params.source_extremum_price, digits);
  return StringFormat("%s|slot=%d|%s|time=%d|price=%s",
                      direction_token,
                      signal_params.source_extremum_slot,
                      type_token,
                      (int)signal_params.source_extremum_time,
                      DoubleToString(normalized_price, digits));
}

string BuildSignalSequenceId(const SignalTypes direction,
                             const datetime entry_time,
                             const datetime structure_time)
{
  string direction_token = (direction == BULLISH) ? "B" : "S";
  return StringFormat("%s_%d_%d",
                      direction_token,
                      (int)entry_time,
                      (int)structure_time);
}

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
