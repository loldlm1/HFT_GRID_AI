//+------------------------------------------------------------------+
//|                                  market_signal_state.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];
bool        g_forced_stop_triggered = false;
bool        g_manual_signal_entry_enabled = true;

struct StrategyContextRuntime
{
  datetime last_bar_time;
  datetime last_structure_time[2];

  StrategyContextRuntime()
  {
    last_bar_time = 0;
    last_structure_time[0] = 0;
    last_structure_time[1] = 0;
  }
};

StrategyContextRuntime g_context_runtime[4];

const StrategyContextTypes STRATEGY_CONTEXT_EVALUATION_ORDER[] =
{
  CONTEXT_SLOT_BASE
};

struct StrategyContextIndicators
{
  StrategyContextTypes     context;
  ENUM_TIMEFRAMES          timeframe;
  datetime                 bar_time;

  bool                     structure_valid;
  StochasticMarketStructure structure_data;

  StrategyContextIndicators()
  {
    context           = CONTEXT_SLOT_BASE;
    timeframe         = PERIOD_CURRENT;
    bar_time          = 0;
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
  return g_context_runtime[slot].last_structure_time[dir_idx];
}

void SetLastContextStructureTime(const StrategyContextTypes context,
                                 const SignalTypes direction,
                                 const datetime value)
{
  int slot = StrategyContextIndex(context);
  int dir_idx = DirectionIndex(direction);
  g_context_runtime[slot].last_structure_time[dir_idx] = value;
}

bool StrategyCascadeAllowsSignal(const StrategyContextTypes context,
                                 const SignalTypes direction)
{
  return true;
}

bool SignalMatchesStructureIdentity(const SignalParams &signal_params,
                                    const StrategyContextTypes context,
                                    const datetime structure_time)
{
  if(structure_time <= 0)
    return false;

  if(signal_params.signal_state == CLOSED)
    return false;

  if(signal_params.strategy_context != context)
    return false;

  if(signal_params.context_structure_snapshot_time <= 0)
    return false;

  return (signal_params.context_structure_snapshot_time == structure_time);
}

bool HasRunningSignalForStructure(const StrategyContextTypes context,
                                  const SignalTypes direction,
                                  const datetime structure_time)
{
  if(structure_time <= 0)
    return false;

  if(direction == BULLISH)
  {
    int total = ArraySize(running_bullish_signals);
    for(int i = 0; i < total; i++)
    {
      if(SignalMatchesStructureIdentity(running_bullish_signals[i], context, structure_time))
        return true;
    }
    return false;
  }

  if(direction == BEARISH)
  {
    int total = ArraySize(running_bearish_signals);
    for(int i = 0; i < total; i++)
    {
      if(SignalMatchesStructureIdentity(running_bearish_signals[i], context, structure_time))
        return true;
    }
    return false;
  }

  return false;
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
    g_forced_stop_triggered = true;
    g_debug_no_money_abort_pending = false;
    Print("TesterStop triggered: order send rejected due to insufficient funds while Debug_Stop_On_Negative_Equity is enabled.");
    DebugForceCloseAllGrids();
    TesterStop();
    return false;
  }

  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  if(equity <= 0.0)
  {
    g_forced_stop_triggered = true;
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
                    StructureTypeFiltersRequested(trend_ctx);
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
                    StructureTypeFiltersRequested(macro_ctx);
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
                    StructureTypeFiltersRequested(session_ctx);
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

void SetManualSignalEntryEnabled(const bool enabled)
{
  g_manual_signal_entry_enabled = enabled;
}

bool ManualSignalEntryEnabled()
{
  return g_manual_signal_entry_enabled;
}

bool TerminalAlgoTradingEnabled()
{
  bool terminal_allowed = (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) > 0);
  bool mql_allowed = (MQLInfoInteger(MQL_TRADE_ALLOWED) > 0);
  return (terminal_allowed && mql_allowed);
}

bool ResolveSignalAttemptPermission(const SignalTypes signal_type,
                                    const bool run_debug_side_effects,
                                    string &block_source_out,
                                    string &block_reason_out)
{
  block_source_out = "";
  block_reason_out = "";

  if(!ManualSignalEntryEnabled())
  {
    block_source_out = "manual_toggle";
    block_reason_out = "Manual toggle is OFF";
    return false;
  }

  if(!TerminalAlgoTradingEnabled())
  {
    block_source_out = "algo_trading";
    block_reason_out = "MT5 Algo Trading is OFF";
    return false;
  }

  if(!ProtectionRiskAllowsSignalAttempt())
  {
    block_source_out = "protection_risk";

    if(!MarketStatusAllowsSignalAttempts())
      block_reason_out = "Market status blocked: " + MarketStatusToString(MarketStatusGet());
    else if((Protection_Risk_Mode == ENABLED_GRID_PROTECTION_DAILY ||
             Protection_Risk_Mode == ENABLED_GRID_PROTECTION_WEEKLY) &&
            ProtectionRiskDailyLockActive())
      block_reason_out = "Risk protection lock is active";
    else
      block_reason_out = "Protection risk filter blocked entries";

    return false;
  }

  if(run_debug_side_effects && !DebugEquityGuardAllowsProcessing())
  {
    block_source_out = "debug_equity_guard";
    block_reason_out = "Debug equity guard stopped processing";
    return false;
  }

  if(!SessionTimeFilterAllowsSignalAttempt())
  {
    block_source_out = "session_time_filter";
    block_reason_out = "Outside configured session windows";
    return false;
  }

  if(!DailySignalLimitAllowsAttempt(signal_type))
  {
    block_source_out = "daily_signal_limit";
    block_reason_out = "Daily signal limit reached";
    if(Enable_Logs && run_debug_side_effects)
      Print("Daily signal limit reached for direction: ", EnumToString(signal_type));
    return false;
  }

  if(!DirectionAllowed(signal_type))
  {
    block_source_out = "direction_mode";
    block_reason_out = "Direction mode disabled this side";
    return false;
  }

  if(!SignalConcurrencyAllowsAttempt(signal_type))
  {
    block_source_out = "signal_concurrency";
    block_reason_out = "Signal concurrency limit reached";
    return false;
  }

  return true;
}

bool ResolveAnyDirectionAttemptPermission(string &block_source_out,
                                          string &block_reason_out)
{
  block_source_out = "";
  block_reason_out = "";

  bool direction_considered = false;
  SignalTypes directions[2] = {BULLISH, BEARISH};
  for(int i = 0; i < 2; i++)
  {
    SignalTypes direction = directions[i];
    if(!DirectionAllowed(direction))
      continue;

    direction_considered = true;

    string source = "";
    string reason = "";
    if(ResolveSignalAttemptPermission(direction, false, source, reason))
      return true;

    if(block_source_out == "")
    {
      block_source_out = source;
      block_reason_out = reason;
    }
  }

  if(!direction_considered)
  {
    block_source_out = "direction_mode";
    block_reason_out = "All directions disabled by configuration";
    return false;
  }

  return false;
}

bool CanAttemptSignal(const SignalTypes signal_type)
{
  string block_source = "";
  string block_reason = "";
  return ResolveSignalAttemptPermission(signal_type,
                                        true,
                                        block_source,
                                        block_reason);
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
