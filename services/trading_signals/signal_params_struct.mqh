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
  double entry_reference_price;

  datetime last_action_time;
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
    entry_reference_price       = 0.0;
    last_action_time            = 0;
    position_ticket             = 0;
    position_comment            = "";
    opens_position              = true;
  }
};

struct SignalParams
{
  SignalTypes                signal_type;
  SignalStates               signal_state;
  string                     grid_sequence_id;
  StrategyContextTypes       strategy_context;
  ENUM_TIMEFRAMES            strategy_timeframe;
  string                     strategy_context_label;
  StructureTriggerEntryModes entry_trigger_mode;
  double                     entry_price;
  bool                       entry_is_limit;
  double                     close_price;
  double                     stop_loss;
  double                     take_profit;
  double                     lot_size;
  double                     raw_profit;
  datetime                   entry_time;
  datetime                   close_time;

  bool   grid_initialized;
  double grid_base_distance_points;
  double grid_initial_indicator_distance_points;
  double grid_resolved_distance_points;
  double grid_base_lot_size;
  double grid_entry_reference_price;
  double grid_entry_gap_points;
  double grid_entry_offset_points;
  int    fib_level_offset_steps;
  datetime context_structure_snapshot_time;

  bool                      base_structure_valid;
  StochasticMarketStructure base_structure_data;

  bool                      trend_structure_valid;
  StochasticMarketStructure trend_structure_data;

  bool                      macro_structure_valid;
  StochasticMarketStructure macro_structure_data;

  bool                      session_structure_valid;
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
    entry_trigger_mode         = LEVELS_AS_LIMITS;
    entry_price                = 0.0;
    entry_is_limit             = false;
    close_price                = 0.0;
    stop_loss                  = 0.0;
    take_profit                = 0.0;
    lot_size                   = 0.0;
    raw_profit                 = 0.0;
    entry_time                 = 0;
    close_time                 = 0;
    grid_initialized           = false;
    grid_base_distance_points  = 0.0;
    grid_initial_indicator_distance_points = 0.0;
    grid_resolved_distance_points = 0.0;
    grid_base_lot_size         = 0.0;
    grid_entry_reference_price = 0.0;
    grid_entry_gap_points      = 0.0;
    grid_entry_offset_points   = 0.0;
    fib_level_offset_steps     = 1;
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
    grid_sequence_id           = signal_params.grid_sequence_id;
    strategy_context           = signal_params.strategy_context;
    strategy_timeframe         = signal_params.strategy_timeframe;
    strategy_context_label     = signal_params.strategy_context_label;
    entry_trigger_mode         = signal_params.entry_trigger_mode;
    entry_price                = signal_params.entry_price;
    entry_is_limit             = signal_params.entry_is_limit;
    close_price                = signal_params.close_price;
    stop_loss                  = signal_params.stop_loss;
    take_profit                = signal_params.take_profit;
    lot_size                   = signal_params.lot_size;
    raw_profit                 = signal_params.raw_profit;
    entry_time                 = signal_params.entry_time;
    close_time                 = signal_params.close_time;
    grid_initialized           = signal_params.grid_initialized;
    grid_base_distance_points  = signal_params.grid_base_distance_points;
    grid_initial_indicator_distance_points = signal_params.grid_initial_indicator_distance_points;
    grid_resolved_distance_points = signal_params.grid_resolved_distance_points;
    grid_base_lot_size         = signal_params.grid_base_lot_size;
    grid_entry_reference_price = signal_params.grid_entry_reference_price;
    grid_entry_gap_points      = signal_params.grid_entry_gap_points;
    grid_entry_offset_points   = signal_params.grid_entry_offset_points;
    fib_level_offset_steps     = signal_params.fib_level_offset_steps;
    context_structure_snapshot_time = signal_params.context_structure_snapshot_time;
    base_structure_valid       = signal_params.base_structure_valid;
    base_structure_data        = signal_params.base_structure_data;
    trend_structure_valid      = signal_params.trend_structure_valid;
    trend_structure_data       = signal_params.trend_structure_data;
    macro_structure_valid      = signal_params.macro_structure_valid;
    macro_structure_data       = signal_params.macro_structure_data;
    session_structure_valid    = signal_params.session_structure_valid;
    session_structure_data     = signal_params.session_structure_data;
    int orders_total = ArraySize(signal_params.grid_orders);
    ArrayResize(grid_orders, orders_total);
    for(int n = 0; n < orders_total; n++)
      grid_orders[n] = signal_params.grid_orders[n];
  }
};

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
