//+------------------------------------------------------------------+
//|                                         signal_params_struct.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_

// TRADING SIGNALS STRUCTURES

struct GridOrderState
{
  int               level_index;
  GridOrderStatuses status;
  GridEntryStyles   entry_style;

  double lot_size;
  double next_level_price;
  double entry_price;
  double take_profit_price;
  double final_take_profit_price;
  double trailing_price;
  double entry_reference_price;
  double break_even_price;

  datetime last_action_time;
  bool     is_trailing_active;
  bool     tp_reached;
  bool     break_even_active;
  bool     partial_take_executed;
  ulong    position_ticket;
  string   position_comment;
  bool     opens_position;

  GridOrderState()
  {
    level_index                 = -1;
    status                      = GRID_ORDER_INACTIVE;
    entry_style                 = GRID_ENTRY_STYLE_STOP;
    lot_size                    = 0.0;
    next_level_price            = 0.0;
    entry_price                 = 0.0;
    take_profit_price           = 0.0;
    final_take_profit_price     = 0.0;
    trailing_price              = 0.0;
    entry_reference_price       = 0.0;
    break_even_price            = 0.0;
    last_action_time            = 0;
    is_trailing_active          = false;
    tp_reached                  = false;
    break_even_active           = false;
    partial_take_executed       = false;
    position_ticket             = 0;
    position_comment            = "";
    opens_position              = true;
  }
};

struct SignalParams
{
  SignalTypes               signal_type;
  SignalStates              signal_state;
  string                    grid_sequence_id;
  StrategyContextTypes      strategy_context;
  ENUM_TIMEFRAMES           strategy_timeframe;
  string                    strategy_context_label;
  StrategyEntryChannelModes entry_trigger_mode;
  StrategyEntryChannelModes entry_evaluation_mode;
  double                    entry_price;
  double                    close_price;
  double                    stop_loss;
  double                    take_profit;
  double                    lot_size;
  double                    raw_profit;
  datetime                  entry_time;
  datetime                  close_time;

  bool   grid_initialized;
  double grid_base_distance_points;
  double grid_initial_indicator_distance_points;
  double grid_resolved_distance_points;
  double grid_base_lot_size;
  double grid_entry_reference_price;
  double grid_entry_gap_points;
  double grid_entry_offset_points;
  double grid_trailing_points;
  bool   is_sar_signal;
  double sar_cumulative_loss;
  ulong  hedge_position_ticket;
  double hedge_entry_price;
  bool   hedge_sl_active;
  double hedge_sl_price;
  bool   hedge_finalized;
  bool   hedge_reset_done;
  double pandora_sl_points;
  double pandora_tp_points;
  double pandora_trailing_step_points;
  int    pandora_trailing_step_index;
  double pandora_trailing_stop_price;
  PandoraCloseOutcomes pandora_close_outcome;
  double pandora_close_epsilon_points;
  PandoraLocalEntryStatuses      pandora_local_entry_status;
  PandoraBrokerExecutionStatuses pandora_broker_execution_status;
  PandoraBrokerStopSyncStatuses  pandora_broker_stop_sync_status;
  PandoraLocalCloseMarkers       pandora_local_close_marker;
  bool     pandora_broker_send_attempted;
  int      pandora_broker_attempt_count;
  datetime pandora_local_entry_time;
  datetime pandora_local_close_time;
  datetime pandora_broker_attempt_time;
  datetime pandora_broker_retry_next_time;
  datetime pandora_broker_retry_deadline;
  datetime pandora_broker_stop_sync_time;
  double   pandora_local_entry_price;
  double   pandora_local_close_price;
  double   pandora_local_sl_price;
  double   pandora_local_tp_price;
  double   pandora_broker_sl_target_price;
  double   pandora_broker_tp_target_price;
  double   pandora_broker_sl_protection_price;
  double   pandora_broker_tp_protection_price;
  ulong    pandora_broker_retcode;
  int      pandora_broker_last_error;
  string   pandora_broker_reject_context;
  string   pandora_broker_reject_detail;
  string   pandora_marker_id;
  datetime context_structure_snapshot_time;

  bool                      base_bpercent_valid;
  bool                      base_alligator_valid;
  bool                      base_stochastic_valid;
  bool                      base_structure_valid;
  bool                      base_body_ma_valid;
  BandsPercentStructure     base_bpercent_data;
  AlligatorStructure        base_alligator_data;
  StochasticStructure       base_stochastic_data;
  StochasticMarketStructure base_structure_data;
  BodyMAStructure           base_body_ma_data;

  bool                      trend_bpercent_valid;
  bool                      trend_alligator_valid;
  bool                      trend_stochastic_valid;
  bool                      trend_structure_valid;
  BandsPercentStructure     trend_bpercent_data;
  AlligatorStructure        trend_alligator_data;
  StochasticStructure       trend_stochastic_data;
  StrategyTrendModes        trend_filter_mode;
  StochasticMarketStructure trend_structure_data;

  bool                      macro_bpercent_valid;
  bool                      macro_alligator_valid;
  bool                      macro_stochastic_valid;
  bool                      macro_structure_valid;
  BandsPercentStructure     macro_bpercent_data;
  AlligatorStructure        macro_alligator_data;
  StochasticStructure       macro_stochastic_data;
  StrategyTrendModes        macro_filter_mode;
  StochasticMarketStructure macro_structure_data;

  bool                      session_bpercent_valid;
  bool                      session_alligator_valid;
  bool                      session_stochastic_valid;
  bool                      session_structure_valid;
  BandsPercentStructure     session_bpercent_data;
  AlligatorStructure        session_alligator_data;
  StochasticStructure       session_stochastic_data;
  StrategyTrendModes        session_filter_mode;
  StochasticMarketStructure session_structure_data;

  GridOrderState grid_orders[];

  SignalParams()
  {
    signal_type                = NO_SIGNAL;
    signal_state               = WAITING;
    grid_sequence_id           = "";
    strategy_context           = CONTEXT_SLOT_BASE;
    strategy_timeframe         = PERIOD_CURRENT;
    strategy_context_label     = "BASE";
    entry_trigger_mode         = ENTRY_MODE_MA_TREND;
    entry_evaluation_mode      = ENTRY_EVAL_OFF;
    entry_price                = 0.0;
    close_price                = 0.0;
    stop_loss                  = 0.0;
    take_profit                = 0.0;
    lot_size                   = 0.0;
    raw_profit                 = 0.0;
    entry_time                 = 0;
    close_time                 = 0;
    base_bpercent_valid        = false;
    base_alligator_valid       = false;
    base_stochastic_valid      = false;
    base_structure_valid       = false;
    base_body_ma_valid         = false;
    grid_initialized           = false;
    grid_base_distance_points  = 0.0;
    grid_initial_indicator_distance_points = 0.0;
    grid_resolved_distance_points = 0.0;
    grid_base_lot_size         = 0.0;
    grid_entry_reference_price = 0.0;
    grid_entry_gap_points      = 0.0;
    grid_entry_offset_points   = 0.0;
    grid_trailing_points       = 0.0;
    is_sar_signal              = false;
    sar_cumulative_loss        = 0.0;
    hedge_position_ticket      = 0;
    hedge_entry_price          = 0.0;
    hedge_sl_active            = false;
    hedge_sl_price             = 0.0;
    hedge_finalized            = false;
    hedge_reset_done           = false;
    pandora_sl_points          = 0.0;
    pandora_tp_points          = 0.0;
    pandora_trailing_step_points = 0.0;
    pandora_trailing_step_index = 0;
    pandora_trailing_stop_price = 0.0;
    pandora_close_outcome      = PANDORA_CLOSE_NONE;
    pandora_close_epsilon_points = 0.0;
    pandora_local_entry_status = PANDORA_LOCAL_ENTRY_NONE;
    pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
    pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NONE;
    pandora_local_close_marker = PANDORA_LOCAL_CLOSE_NONE;
    pandora_broker_send_attempted = false;
    pandora_broker_attempt_count = 0;
    pandora_local_entry_time   = 0;
    pandora_local_close_time   = 0;
    pandora_broker_attempt_time = 0;
    pandora_broker_retry_next_time = 0;
    pandora_broker_retry_deadline = 0;
    pandora_broker_stop_sync_time = 0;
    pandora_local_entry_price  = 0.0;
    pandora_local_close_price  = 0.0;
    pandora_local_sl_price     = 0.0;
    pandora_local_tp_price     = 0.0;
    pandora_broker_sl_target_price = 0.0;
    pandora_broker_tp_target_price = 0.0;
    pandora_broker_sl_protection_price = 0.0;
    pandora_broker_tp_protection_price = 0.0;
    pandora_broker_retcode     = 0;
    pandora_broker_last_error  = 0;
    pandora_broker_reject_context = "";
    pandora_broker_reject_detail = "";
    pandora_marker_id          = "";
    context_structure_snapshot_time = 0;
    trend_filter_mode          = TREND_OFF;
    trend_bpercent_valid       = false;
    trend_alligator_valid      = false;
    trend_stochastic_valid     = false;
    trend_structure_valid      = false;
    macro_filter_mode          = TREND_OFF;
    macro_bpercent_valid       = false;
    macro_alligator_valid      = false;
    macro_stochastic_valid     = false;
    macro_structure_valid      = false;
    session_filter_mode        = TREND_OFF;
    session_bpercent_valid     = false;
    session_alligator_valid    = false;
    session_stochastic_valid   = false;
    session_structure_valid    = false;
  }

  SignalParams(const SignalParams &signal_params)
  {
    signal_type                = signal_params.signal_type;
    signal_state               = signal_params.signal_state;
    grid_sequence_id           = signal_params.grid_sequence_id;
    entry_price                = signal_params.entry_price;
    close_price                = signal_params.close_price;
    stop_loss                  = signal_params.stop_loss;
    take_profit                = signal_params.take_profit;
    lot_size                   = signal_params.lot_size;
    raw_profit                 = signal_params.raw_profit;
    entry_time                 = signal_params.entry_time;
    close_time                 = signal_params.close_time;
    base_bpercent_valid        = signal_params.base_bpercent_valid;
    base_bpercent_data         = signal_params.base_bpercent_data;
    base_alligator_valid       = signal_params.base_alligator_valid;
    base_alligator_data        = signal_params.base_alligator_data;
    base_stochastic_valid      = signal_params.base_stochastic_valid;
    base_stochastic_data       = signal_params.base_stochastic_data;
    base_structure_valid       = signal_params.base_structure_valid;
    base_structure_data        = signal_params.base_structure_data;
    base_body_ma_valid         = signal_params.base_body_ma_valid;
    base_body_ma_data          = signal_params.base_body_ma_data;

    grid_initialized            = signal_params.grid_initialized;
    grid_base_distance_points   = signal_params.grid_base_distance_points;
    grid_initial_indicator_distance_points = signal_params.grid_initial_indicator_distance_points;
    grid_resolved_distance_points = signal_params.grid_resolved_distance_points;
    grid_base_lot_size          = signal_params.grid_base_lot_size;
    grid_entry_reference_price  = signal_params.grid_entry_reference_price;
    grid_entry_gap_points       = signal_params.grid_entry_gap_points;
    grid_entry_offset_points    = signal_params.grid_entry_offset_points;
    grid_trailing_points        = signal_params.grid_trailing_points;
    is_sar_signal               = signal_params.is_sar_signal;
    sar_cumulative_loss         = signal_params.sar_cumulative_loss;
    hedge_position_ticket       = signal_params.hedge_position_ticket;
    hedge_entry_price           = signal_params.hedge_entry_price;
    hedge_sl_active             = signal_params.hedge_sl_active;
    hedge_sl_price              = signal_params.hedge_sl_price;
    hedge_finalized             = signal_params.hedge_finalized;
    hedge_reset_done            = signal_params.hedge_reset_done;
    pandora_sl_points           = signal_params.pandora_sl_points;
    pandora_tp_points           = signal_params.pandora_tp_points;
    pandora_trailing_step_points = signal_params.pandora_trailing_step_points;
    pandora_trailing_step_index = signal_params.pandora_trailing_step_index;
    pandora_trailing_stop_price = signal_params.pandora_trailing_stop_price;
    pandora_close_outcome       = signal_params.pandora_close_outcome;
    pandora_close_epsilon_points = signal_params.pandora_close_epsilon_points;
    pandora_local_entry_status   = signal_params.pandora_local_entry_status;
    pandora_broker_execution_status = signal_params.pandora_broker_execution_status;
    pandora_broker_stop_sync_status = signal_params.pandora_broker_stop_sync_status;
    pandora_local_close_marker   = signal_params.pandora_local_close_marker;
    pandora_broker_send_attempted = signal_params.pandora_broker_send_attempted;
    pandora_broker_attempt_count = signal_params.pandora_broker_attempt_count;
    pandora_local_entry_time     = signal_params.pandora_local_entry_time;
    pandora_local_close_time     = signal_params.pandora_local_close_time;
    pandora_broker_attempt_time  = signal_params.pandora_broker_attempt_time;
    pandora_broker_retry_next_time = signal_params.pandora_broker_retry_next_time;
    pandora_broker_retry_deadline = signal_params.pandora_broker_retry_deadline;
    pandora_broker_stop_sync_time = signal_params.pandora_broker_stop_sync_time;
    pandora_local_entry_price    = signal_params.pandora_local_entry_price;
    pandora_local_close_price    = signal_params.pandora_local_close_price;
    pandora_local_sl_price       = signal_params.pandora_local_sl_price;
    pandora_local_tp_price       = signal_params.pandora_local_tp_price;
    pandora_broker_sl_target_price = signal_params.pandora_broker_sl_target_price;
    pandora_broker_tp_target_price = signal_params.pandora_broker_tp_target_price;
    pandora_broker_sl_protection_price = signal_params.pandora_broker_sl_protection_price;
    pandora_broker_tp_protection_price = signal_params.pandora_broker_tp_protection_price;
    pandora_broker_retcode       = signal_params.pandora_broker_retcode;
    pandora_broker_last_error    = signal_params.pandora_broker_last_error;
    pandora_broker_reject_context = signal_params.pandora_broker_reject_context;
    pandora_broker_reject_detail = signal_params.pandora_broker_reject_detail;
    pandora_marker_id            = signal_params.pandora_marker_id;
    strategy_context           = signal_params.strategy_context;
    strategy_timeframe         = signal_params.strategy_timeframe;
    strategy_context_label     = signal_params.strategy_context_label;
    entry_trigger_mode         = signal_params.entry_trigger_mode;
    entry_evaluation_mode      = signal_params.entry_evaluation_mode;
    context_structure_snapshot_time = signal_params.context_structure_snapshot_time;
    trend_filter_mode           = signal_params.trend_filter_mode;
    trend_bpercent_valid        = signal_params.trend_bpercent_valid;
    trend_alligator_valid       = signal_params.trend_alligator_valid;
    trend_bpercent_data         = signal_params.trend_bpercent_data;
    trend_alligator_data        = signal_params.trend_alligator_data;
    trend_stochastic_data       = signal_params.trend_stochastic_data;
    trend_stochastic_valid      = signal_params.trend_stochastic_valid;
    trend_structure_valid       = signal_params.trend_structure_valid;
    trend_structure_data        = signal_params.trend_structure_data;
    macro_filter_mode           = signal_params.macro_filter_mode;
    macro_bpercent_valid        = signal_params.macro_bpercent_valid;
    macro_alligator_valid       = signal_params.macro_alligator_valid;
    macro_bpercent_data         = signal_params.macro_bpercent_data;
    macro_alligator_data        = signal_params.macro_alligator_data;
    macro_stochastic_data       = signal_params.macro_stochastic_data;
    macro_stochastic_valid      = signal_params.macro_stochastic_valid;
    macro_structure_valid       = signal_params.macro_structure_valid;
    macro_structure_data        = signal_params.macro_structure_data;
    session_filter_mode         = signal_params.session_filter_mode;
    session_bpercent_valid      = signal_params.session_bpercent_valid;
    session_alligator_valid     = signal_params.session_alligator_valid;
    session_bpercent_data       = signal_params.session_bpercent_data;
    session_alligator_data      = signal_params.session_alligator_data;
    session_stochastic_data     = signal_params.session_stochastic_data;
    session_stochastic_valid    = signal_params.session_stochastic_valid;
    session_structure_valid     = signal_params.session_structure_valid;
    session_structure_data      = signal_params.session_structure_data;
    int orders_total = ArraySize(signal_params.grid_orders);
    ArrayResize(grid_orders, orders_total);
    for(int n = 0; n < orders_total; n++)
      grid_orders[n] = signal_params.grid_orders[n];
  }
};

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
