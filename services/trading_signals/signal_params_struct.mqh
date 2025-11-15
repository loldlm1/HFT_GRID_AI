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
  ulong    position_ticket;
  string   position_comment;

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
    position_ticket             = 0;
    position_comment            = "";
  }
};

struct SignalParams
{
  SignalTypes               signal_type;
  SignalStates              signal_state;
  string                    grid_sequence_id;
  double                    entry_price;
  double                    close_price;
  double                    stop_loss;
  double                    take_profit;
  double                    lot_size;
  double                    raw_profit;
  datetime                  entry_time;
  datetime                  close_time;
  BandsPercentStructure     bands_percent_data[];
  AlligatorStructure        alligator_data[];
  StochasticStructure       stochastic_data[];
  StochasticMarketStructure stoch_market_structure_data[];
  BodyMAStructure           body_ma_data[];

  bool   grid_initialized;
  double grid_base_distance_points;
  double grid_resolved_distance_points;
  double grid_base_lot_size;
  double grid_entry_reference_price;
  double grid_entry_gap_points;
  double grid_entry_offset_points;
  double grid_trailing_points;
  datetime base_structure_snapshot_time;
  datetime trend_structure_snapshot_time;

  bool                      trend_bpercent_valid;
  bool                      trend_alligator_valid;
  bool                      trend_stochastic_valid;
  bool                      trend_structure_valid;
  BandsPercentStructure     trend_bpercent_data;
  AlligatorStructure        trend_alligator_data;
  StochasticStructure       trend_stochastic_data;
  StrategyTrendModes        trend_filter_mode;
  StochasticMarketStructure trend_structure_data;

  GridOrderState grid_orders[];

  SignalParams()
  {
    signal_type                = NO_SIGNAL;
    signal_state               = WAITING;
    grid_sequence_id           = "";
    entry_price                = 0.0;
    close_price                = 0.0;
    stop_loss                  = 0.0;
    take_profit                = 0.0;
    lot_size                   = 0.0;
    raw_profit                 = 0.0;
    entry_time                 = 0;
    close_time                 = 0;
    grid_initialized           = false;
    grid_base_distance_points  = 0.0;
    grid_resolved_distance_points = 0.0;
    grid_base_lot_size         = 0.0;
    grid_entry_reference_price = 0.0;
    grid_entry_gap_points      = 0.0;
    grid_entry_offset_points   = 0.0;
    grid_trailing_points       = 0.0;
    base_structure_snapshot_time = 0;
    trend_structure_snapshot_time = 0;
    trend_filter_mode          = TREND_OFF;
    trend_bpercent_valid       = false;
    trend_alligator_valid      = false;
    trend_stochastic_valid     = false;
    trend_structure_valid      = false;
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

    int bands_total = ArraySize(signal_params.bands_percent_data);
    ArrayResize(bands_percent_data, bands_total);
    for(int i = 0; i < bands_total; i++)
      bands_percent_data[i] = signal_params.bands_percent_data[i];

    int alligator_total = ArraySize(signal_params.alligator_data);
    ArrayResize(alligator_data, alligator_total);
    for(int j = 0; j < alligator_total; j++)
      alligator_data[j] = signal_params.alligator_data[j];

    int stoch_total = ArraySize(signal_params.stochastic_data);
    ArrayResize(stochastic_data, stoch_total);
    for(int j = 0; j < stoch_total; j++)
      stochastic_data[j] = signal_params.stochastic_data[j];

    int body_total = ArraySize(signal_params.body_ma_data);
    ArrayResize(body_ma_data, body_total);
    for(int k = 0; k < body_total; k++)
      body_ma_data[k] = signal_params.body_ma_data[k];

    int stoch_struct_total = ArraySize(signal_params.stoch_market_structure_data);
    ArrayResize(stoch_market_structure_data, stoch_struct_total);
    for(int m = 0; m < stoch_struct_total; m++)
      stoch_market_structure_data[m] = signal_params.stoch_market_structure_data[m];

    grid_initialized            = signal_params.grid_initialized;
    grid_base_distance_points   = signal_params.grid_base_distance_points;
    grid_resolved_distance_points = signal_params.grid_resolved_distance_points;
    grid_base_lot_size          = signal_params.grid_base_lot_size;
    grid_entry_reference_price  = signal_params.grid_entry_reference_price;
    grid_entry_gap_points       = signal_params.grid_entry_gap_points;
    grid_entry_offset_points    = signal_params.grid_entry_offset_points;
    grid_trailing_points        = signal_params.grid_trailing_points;
    base_structure_snapshot_time = signal_params.base_structure_snapshot_time;
    trend_structure_snapshot_time = signal_params.trend_structure_snapshot_time;
    trend_filter_mode           = signal_params.trend_filter_mode;
    trend_bpercent_valid        = signal_params.trend_bpercent_valid;
    trend_alligator_valid       = signal_params.trend_alligator_valid;
    trend_bpercent_data         = signal_params.trend_bpercent_data;
    trend_alligator_data        = signal_params.trend_alligator_data;
    trend_stochastic_data       = signal_params.trend_stochastic_data;
    trend_stochastic_valid      = signal_params.trend_stochastic_valid;
    trend_structure_valid       = signal_params.trend_structure_valid;
    trend_structure_data        = signal_params.trend_structure_data;

    int orders_total = ArraySize(signal_params.grid_orders);
    ArrayResize(grid_orders, orders_total);
    for(int n = 0; n < orders_total; n++)
      grid_orders[n] = signal_params.grid_orders[n];
  }
};

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
