
//+------------------------------------------------------------------+
//|                                         signal_params_struct.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
#define _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_

// Structures are already included by the trading_signals.mqh aggregator
// No need to include them here to avoid circular dependencies

// TRADING SIGNALS STRUCTURES

struct GridLevelPlan
{
  int    level_index;
  double distance_points;
  double pending_order_points;
  double activation_points;
  double take_profit_points;
  double final_take_profit_points;
  double trailing_points;
  double lot_size;

  GridLevelPlan()
  {
    level_index          = 0;
    distance_points      = 0.0;
    pending_order_points = 0.0;
    activation_points    = 0.0;
    take_profit_points   = 0.0;
    final_take_profit_points = 0.0;
    trailing_points      = 0.0;
    lot_size             = 0.0;
  }
};

struct GridMetadata
{
  bool        initialized;
  SignalTypes direction;
  double      base_distance_points;
  double      base_anchor_price;
  double      base_lot_size;
  GridLevelPlan levels[];

  GridMetadata()
  {
    initialized          = false;
    direction            = NO_SIGNAL;
    base_distance_points = 0.0;
    base_anchor_price    = 0.0;
    base_lot_size        = 0.0;
  }
};

struct GridTelemetryStats
{
  datetime activation_time;
  datetime last_update_time;
  double   max_favorable_points;
  double   max_adverse_points;
  double   total_positive_points;
  double   total_negative_points;
  int      completed_levels;

  GridTelemetryStats()
  {
    activation_time      = 0;
    last_update_time     = 0;
    max_favorable_points = 0.0;
    max_adverse_points   = 0.0;
    total_positive_points = 0.0;
    total_negative_points = 0.0;
    completed_levels      = 0;
  }

  double ProfitFactor() const
  {
    if(total_positive_points <= 0.0)
      return 0.0;
    if(total_negative_points <= 0.0)
      return total_positive_points;
    return total_positive_points / total_negative_points;
  }
};

struct GridOrderState
{
  int               level_index;
  GridOrderStatuses status;
  double            last_pending_price;
  double            entry_price;
  double            stop_loss_price;
  double            take_profit_price;
  double            trailing_points;
  double            realized_points;
  datetime          last_action_time;
  double            anchor_price;
  double            next_level_price;
  double            trailing_price;
  bool              is_trailing_active;
  bool              tp_reached;
  double            final_take_profit_price;
  ulong             position_ticket;
  string            position_comment;

  GridOrderState()
  {
    level_index          = -1;
    status               = GRID_ORDER_INACTIVE;
    last_pending_price   = 0.0;
    entry_price          = 0.0;
    stop_loss_price      = 0.0;
    take_profit_price    = 0.0;
    trailing_points      = 0.0;
    realized_points      = 0.0;
    last_action_time     = 0;
    anchor_price         = 0.0;
    next_level_price     = 0.0;
    trailing_price       = 0.0;
    is_trailing_active   = false;
    tp_reached           = false;
    final_take_profit_price = 0.0;
    position_ticket      = 0;
    position_comment     = "";
  }
};

struct SignalParams
{
  SignalTypes               signal_type;
  SignalStates               signal_state;
  string                     ticket_id;
  double                     entry_price;
  double                     close_price;
  double                     stop_loss;
  double                     take_profit;
  double                     lot_size;
  double                     raw_profit;
  datetime                   entry_time;
  datetime                   close_time;
  BandsPercentStructure     bands_percent_data[];
  StochasticStructure       stochastic_data[];
  StochasticMarketStructure stoch_market_structure_data[];
  BodyMAStructure           body_ma_data[];
  GridMetadata              grid_plan;
  GridOrderState            grid_orders[];
  GridTelemetryStats        grid_stats;

  // DEFAULT CONSTRUCTOR
  SignalParams()
  {
    signal_type        = NO_SIGNAL;
    signal_state        = WAITING;
    ticket_id          = "";
    entry_price        = 0.0;
    close_price        = 0.0;
    stop_loss          = 0.0;
    take_profit        = 0.0;
    lot_size           = 0.0;
    raw_profit         = 0.0;
    entry_time         = 0;
    close_time         = 0;
  }

  // COPY CONSTRUCTOR
  SignalParams(const SignalParams &signal_params)
  {
    signal_type           = signal_params.signal_type;
    signal_state           = signal_params.signal_state;
    ticket_id             = signal_params.ticket_id;
    entry_price           = signal_params.entry_price;
    close_price           = signal_params.close_price;
    stop_loss             = signal_params.stop_loss;
    take_profit           = signal_params.take_profit;
    lot_size              = signal_params.lot_size;
    raw_profit            = signal_params.raw_profit;
    entry_time            = signal_params.entry_time;
    close_time            = signal_params.close_time;

    // DEEP COPY OF ARRAYS
    int bands_total = ArraySize(signal_params.bands_percent_data);
    ArrayResize(bands_percent_data, bands_total);
    for(int i = 0; i < bands_total; i++)
      bands_percent_data[i] = signal_params.bands_percent_data[i];

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
    int levels_total = ArraySize(signal_params.grid_plan.levels);
    ArrayResize(grid_plan.levels, levels_total);
    for(int i = 0; i < levels_total; i++)
      grid_plan.levels[i] = signal_params.grid_plan.levels[i];

    grid_plan.initialized          = signal_params.grid_plan.initialized;
    grid_plan.direction            = signal_params.grid_plan.direction;
    grid_plan.base_distance_points = signal_params.grid_plan.base_distance_points;
    grid_plan.base_anchor_price    = signal_params.grid_plan.base_anchor_price;
    grid_plan.base_lot_size        = signal_params.grid_plan.base_lot_size;

    int orders_total = ArraySize(signal_params.grid_orders);
    ArrayResize(grid_orders, orders_total);
    for(int n = 0; n < orders_total; n++)
      grid_orders[n] = signal_params.grid_orders[n];

    grid_stats = signal_params.grid_stats;
  }
};

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
