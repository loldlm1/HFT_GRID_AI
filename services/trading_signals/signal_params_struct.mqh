
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
  double stop_loss_points;
  double take_profit_points;
  double trailing_points;
  double lot_size;

  GridLevelPlan()
  {
    level_index          = 0;
    distance_points      = 0.0;
    pending_order_points = 0.0;
    stop_loss_points     = 0.0;
    take_profit_points   = 0.0;
    trailing_points      = 0.0;
    lot_size             = 0.0;
  }
};

struct GridMetadata
{
  bool        initialized;
  SignalTypes direction;
  double      base_distance_points;
  double      base_lot_size;
  GridLevelPlan levels[];

  GridMetadata()
  {
    initialized          = false;
    direction            = NO_SIGNAL;
    base_distance_points = 0.0;
    base_lot_size        = 0.0;
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
    ArrayCopy(bands_percent_data,          signal_params.bands_percent_data);
    ArrayCopy(stochastic_data,             signal_params.stochastic_data);
    ArrayCopy(body_ma_data,                signal_params.body_ma_data);
    ArrayCopy(stoch_market_structure_data, signal_params.stoch_market_structure_data);
    int levels_total = ArraySize(signal_params.grid_plan.levels);
    ArrayResize(grid_plan.levels, levels_total);
    for(int i = 0; i < levels_total; i++)
      grid_plan.levels[i] = signal_params.grid_plan.levels[i];

    grid_plan.initialized          = signal_params.grid_plan.initialized;
    grid_plan.direction            = signal_params.grid_plan.direction;
    grid_plan.base_distance_points = signal_params.grid_plan.base_distance_points;
    grid_plan.base_lot_size        = signal_params.grid_plan.base_lot_size;
  }
};

#endif // _SERVICES_TRADING_SIGNALS_SIGNAL_PARAMS_STRUCT_MQH_
