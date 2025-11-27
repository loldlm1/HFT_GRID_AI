//+------------------------------------------------------------------+
//|                                  market_signal_state.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];

datetime g_context_last_structure_time[4][2];
datetime g_context_last_bar_time[4];
bool     g_context_trend_ready[4];
bool     g_context_trend_pass[4][2];

const StrategyContextTypes STRATEGY_CONTEXT_EVALUATION_ORDER[] =
{
  CONTEXT_SLOT_SESSION,
  CONTEXT_SLOT_MACRO,
  CONTEXT_SLOT_TREND,
  CONTEXT_SLOT_BASE
};

struct StrategyContextIndicators
{
  StrategyContextTypes     context;
  ENUM_TIMEFRAMES          timeframe;
  datetime                 bar_time;

  bool                     bpercent_valid;
  BandsPercentStructure    bpercent_data;

  bool                     alligator_valid;
  AlligatorStructure       alligator_data;

  bool                     stochastic_valid;
  StochasticStructure      stochastic_data;

  bool                     body_ma_valid;
  BodyMAStructure          body_ma_data;

  bool                     structure_valid;
  StochasticMarketStructure structure_data;

  StrategyContextIndicators()
  {
    context           = CONTEXT_SLOT_BASE;
    timeframe         = PERIOD_CURRENT;
    bar_time          = 0;
    bpercent_valid    = false;
    alligator_valid   = false;
    stochastic_valid  = false;
    body_ma_valid     = false;
    structure_valid   = false;
  }
};

struct DailySignalStats
{
  datetime day_start;
  int total_signals;
  int losing_signals;

  DailySignalStats()
  {
    day_start      = 0;
    total_signals  = 0;
    losing_signals = 0;
  }
};

DailySignalStats g_daily_signal_stats[2];

const double BANDS_PERCENT_MID_LEVEL   = 50.0;
const double BANDS_PERCENT_UPPER_LEVEL = 100.0;
const double BANDS_PERCENT_LOWER_LEVEL = 0.0;

int DirectionIndex(const SignalTypes direction)
{
  return (direction == BEARISH) ? 1 : 0;
}

bool DirectionAllowed(const SignalTypes direction)
{
  if(Strategy_Direction_Mode == BOTH_DIRECTION)
    return true;
  if(Strategy_Direction_Mode == BULLISH_DIRECTION)
    return (direction == BULLISH);
  if(Strategy_Direction_Mode == BEARISH_DIRECTION)
    return (direction == BEARISH);
  return true;
}

int StrategyContextIndex(const StrategyContextTypes context)
{
  return (int)context;
}

int StrategyContextOrderIndex(const StrategyContextTypes context)
{
  int total = ArraySize(STRATEGY_CONTEXT_EVALUATION_ORDER);
  for(int i = 0; i < total; i++)
  {
    if(STRATEGY_CONTEXT_EVALUATION_ORDER[i] == context)
      return i;
  }
  return total - 1;
}

datetime GetLastContextStructureTime(const StrategyContextTypes context,
                                     const SignalTypes direction)
{
  int slot = StrategyContextIndex(context);
  int dir_idx = DirectionIndex(direction);
  return g_context_last_structure_time[slot][dir_idx];
}

void SetLastContextStructureTime(const StrategyContextTypes context,
                                 const SignalTypes direction,
                                 const datetime value)
{
  int slot = StrategyContextIndex(context);
  int dir_idx = DirectionIndex(direction);
  g_context_last_structure_time[slot][dir_idx] = value;
}

bool ContextTrendSatisfied(const StrategyContextTypes context,
                           const SignalTypes direction)
{
  if(!StrategyContextEnabled(context))
    return true;

  StrategyTrendModes trend_mode = StrategyContextTrendMode(context);
  if(!TrendModeUsesAlligator(trend_mode))
    return true;

  int slot = StrategyContextIndex(context);
  if(!g_context_trend_ready[slot])
    return false;

  return g_context_trend_pass[slot][DirectionIndex(direction)];
}

void ResetContextTrendState(const StrategyContextTypes context)
{
  int slot = StrategyContextIndex(context);
  g_context_trend_ready[slot] = false;
  g_context_trend_pass[slot][0] = false;
  g_context_trend_pass[slot][1] = false;
}

void UpdateContextTrendState(const StrategyContextTypes context,
                             const SignalTypes direction,
                             const bool ready,
                             const bool trend_pass)
{
  int slot = StrategyContextIndex(context);
  g_context_trend_ready[slot] = ready || g_context_trend_ready[slot];
  g_context_trend_pass[slot][DirectionIndex(direction)] = trend_pass;
}

bool StrategyCascadeAllowsSignal(const StrategyContextTypes context,
                                 const SignalTypes direction)
{
  int target_index = StrategyContextOrderIndex(context);
  for(int i = 0; i < target_index; i++)
  {
    StrategyContextTypes upstream = STRATEGY_CONTEXT_EVALUATION_ORDER[i];
    if(upstream != CONTEXT_SLOT_BASE && !StrategyContextEnabled(upstream))
      continue;
    if(!ContextTrendSatisfied(upstream, direction))
      return false;
  }
  return true;
}

bool SignalConcurrencyAllowsAttempt(const SignalTypes direction)
{
  if(Signal_Concurrency_Mode == MULTIPLE_RUNNING_SIGNALS)
    return true;

  if(direction == BULLISH && ArraySize(running_bullish_signals) >= 1)
    return false;
  if(direction == BEARISH && ArraySize(running_bearish_signals) >= 1)
    return false;

  return true;
}

void DebugForceCloseAllGrids()
{
  double point_size = GridResolvePointSize();

  int bullish_total = ArraySize(running_bullish_signals);
  for(int i = 0; i < bullish_total; i++)
    GridCloseAllLevels(running_bullish_signals[i], point_size);

  int bearish_total = ArraySize(running_bearish_signals);
  for(int j = 0; j < bearish_total; j++)
    GridCloseAllLevels(running_bearish_signals[j], point_size);
}

datetime ResolveCurrentDayStart()
{
  datetime day = iTime(_Symbol, PERIOD_D1, 0);
  if(day <= 0)
  {
    datetime now = TimeCurrent();
    day = (datetime)((long)now - ((long)now % 86400));
  }
  return day;
}

void DailySignalStatsEnsureDay(const SignalTypes direction)
{
  int idx = DirectionIndex(direction);
  datetime day = ResolveCurrentDayStart();
  if(g_daily_signal_stats[idx].day_start != day)
  {
    g_daily_signal_stats[idx].day_start      = day;
    g_daily_signal_stats[idx].total_signals  = 0;
    g_daily_signal_stats[idx].losing_signals = 0;
  }
}

bool DailySignalLimitAllowsAttempt(const SignalTypes direction)
{
  if(Daily_Signal_Limit <= 0)
    return true;

  DailySignalStatsEnsureDay(direction);
  DailySignalStats stats = g_daily_signal_stats[DirectionIndex(direction)];

  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS_ON_LOSS)
    return stats.losing_signals < Daily_Signal_Limit;

  return stats.total_signals < Daily_Signal_Limit;
}

void RegisterDailySignalStart(const SignalParams &signal_params)
{
  if(Daily_Signal_Limit <= 0)
    return;

  DailySignalStatsEnsureDay(signal_params.signal_type);

  if(Daily_Signal_Limit_Mode == STOP_DAILY_SIGNALS)
    g_daily_signal_stats[DirectionIndex(signal_params.signal_type)].total_signals++;
}

void RegisterDailySignalOutcome(const SignalTypes direction,
                                const double raw_profit)
{
  if(Daily_Signal_Limit <= 0)
    return;

  if(Daily_Signal_Limit_Mode != STOP_DAILY_SIGNALS_ON_LOSS)
    return;

  DailySignalStatsEnsureDay(direction);
  if(raw_profit < 0.0)
    g_daily_signal_stats[DirectionIndex(direction)].losing_signals++;
}

bool DebugEquityGuardAllowsProcessing()
{
  if(!Debug_Stop_On_Negative_Equity || MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  if(g_debug_no_money_abort_pending)
  {
    g_debug_no_money_abort_pending = false;
    Print("TesterStop triggered: order send rejected due to insufficient funds while Debug_Stop_On_Negative_Equity is enabled.");
    DebugForceCloseAllGrids();
    TesterStop();
    return false;
  }

  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  if(equity <= 0.0)
  {
    Print("TesterStop triggered: equity <= 0 and Debug_Stop_On_Negative_Equity is enabled.");
    DebugForceCloseAllGrids();
    TesterStop();
    return false;
  }

  return true;
}

bool TrendStructureFiltersRequested()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  return StructureFiltersRequested(trend_ctx);
}

bool TrendStructureTypeFiltersRequested()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  return StructureTypeFiltersRequested(trend_ctx);
}

bool TrendStructureDataRequired()
{
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();
  if(!trend_ctx.enabled)
    return false;
  bool needs_data = StructureFiltersRequested(trend_ctx) ||
                    StructureTypeFiltersRequested(trend_ctx) ||
                    Trend_Fresh_Structure_Time;
  if(!needs_data)
    return false;
  return trend_ctx.uses_trend_dataset;
}

bool MacroStructureFiltersRequested()
{
  StrategyStructureLayerContext macro_ctx = BuildMacroStructureLayerContext();
  return StructureFiltersRequested(macro_ctx);
}

bool MacroStructureTypeFiltersRequested()
{
  StrategyStructureLayerContext macro_ctx = BuildMacroStructureLayerContext();
  return StructureTypeFiltersRequested(macro_ctx);
}

bool MacroStructureDataRequired()
{
  StrategyStructureLayerContext macro_ctx = BuildMacroStructureLayerContext();
  if(!macro_ctx.enabled)
    return false;
  bool needs_data = StructureFiltersRequested(macro_ctx) ||
                    StructureTypeFiltersRequested(macro_ctx) ||
                    Macro_Fresh_Structure_Time;
  if(!needs_data)
    return false;
  return true;
}

bool SessionStructureFiltersRequested()
{
  StrategyStructureLayerContext session_ctx = BuildSessionStructureLayerContext();
  return StructureFiltersRequested(session_ctx);
}

bool SessionStructureTypeFiltersRequested()
{
  StrategyStructureLayerContext session_ctx = BuildSessionStructureLayerContext();
  return StructureTypeFiltersRequested(session_ctx);
}

bool SessionStructureDataRequired()
{
  StrategyStructureLayerContext session_ctx = BuildSessionStructureLayerContext();
  if(!session_ctx.enabled)
    return false;
  bool needs_data = StructureFiltersRequested(session_ctx) ||
                    StructureTypeFiltersRequested(session_ctx) ||
                    Session_Fresh_Structure_Time;
  if(!needs_data)
    return false;
  return true;
}

bool TrendSanityCheck(const string reason)
{
  if(!Enable_Trend_Filter_Sanity_Stop)
    return true;

  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return true;

  Print("Trend sanity check triggered: ", reason);
  TesterStop();
  return false;
}

bool CanAttemptSignal(const SignalTypes signal_type)
{
  if(!ProtectionRiskAllowsSignalAttempt())
    return false;

  if(!DebugEquityGuardAllowsProcessing())
    return false;

  if(!SessionTimeFilterAllowsSignalAttempt())
    return false;

  if(!DailySignalLimitAllowsAttempt(signal_type))
  {
    if(Enable_Logs)
      Print("Daily signal limit reached for direction: ", EnumToString(signal_type));
    return false;
  }

  if(!DirectionAllowed(signal_type))
    return false;

  if(!SignalConcurrencyAllowsAttempt(signal_type))
    return false;

  return true;
}

void RegisterFreshStructureUsage(const SignalParams &signal_params)
{
  if(signal_params.context_structure_snapshot_time <= 0)
    return;

  if(!StrategyContextFreshStructureEnabled(signal_params.strategy_context))
    return;

  SetLastContextStructureTime(signal_params.strategy_context,
                              signal_params.signal_type,
                              signal_params.context_structure_snapshot_time);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
