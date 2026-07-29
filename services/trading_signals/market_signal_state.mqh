//+------------------------------------------------------------------+
//|                                  market_signal_state.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];
bool        g_forced_stop_triggered = false;

void RemoveExecutionLevels(const long chart_id,
                           const SignalParams &signal_params);
void ExecutionLogDeterministicSignalExpired(const SignalParams &signal_params,
                                            const int new_source_slot,
                                            const datetime new_source_time,
                                            const bool new_source_is_peak,
                                            const double new_source_price,
                                            const string reason);
void ExecutionLogDeterministicPendingCanceled(const SignalParams &signal_params,
                                              const string reason);
bool SignalHasBrokerExposure(const SignalParams &signal_params);
bool DeterministicSignalStatsRecordDecisionCheck(SignalParams &signal_params,
                                                 const string phase,
                                                 const bool allowed,
                                                 const string block_source,
                                                 const string block_reason);

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

const int DETERMINISTIC_SOURCE_STATE_RESERVE = 128;

struct DeterministicSourceOutcomeState
{
  string   source_key;
  int      attempt_count;
  bool     consumed_after_tp;
  datetime first_signal_time;
  datetime consumed_time;
  string   terminal_outcome;

  DeterministicSourceOutcomeState()
  {
    source_key        = "";
    attempt_count     = 0;
    consumed_after_tp = false;
    first_signal_time = 0;
    consumed_time     = 0;
    terminal_outcome  = "";
  }

  DeterministicSourceOutcomeState(const DeterministicSourceOutcomeState &state)
  {
    source_key        = state.source_key;
    attempt_count     = state.attempt_count;
    consumed_after_tp = state.consumed_after_tp;
    first_signal_time = state.first_signal_time;
    consumed_time     = state.consumed_time;
    terminal_outcome  = state.terminal_outcome;
  }
};

DeterministicSourceOutcomeState g_deterministic_source_outcomes[];


void ResetDeterministicSourceOutcomeState()
{
  ArrayResize(g_deterministic_source_outcomes, 0, DETERMINISTIC_SOURCE_STATE_RESERVE);
}

int FindDeterministicSourceOutcomeIndex(const string source_key)
{
  if(source_key == "")
    return -1;

  int total = ArraySize(g_deterministic_source_outcomes);
  for(int i = 0; i < total; i++)
  {
    if(g_deterministic_source_outcomes[i].source_key == source_key)
      return i;
  }

  return -1;
}

int EnsureDeterministicSourceOutcomeIndex(const string source_key,
                                          const datetime signal_time)
{
  if(source_key == "")
    return -1;

  int existing_index = FindDeterministicSourceOutcomeIndex(source_key);
  if(existing_index >= 0)
    return existing_index;

  int total = ArraySize(g_deterministic_source_outcomes);
  ArrayResize(g_deterministic_source_outcomes,
              total + 1,
              DETERMINISTIC_SOURCE_STATE_RESERVE);
  g_deterministic_source_outcomes[total].source_key = source_key;
  g_deterministic_source_outcomes[total].first_signal_time = signal_time;
  return total;
}

bool ResolveDeterministicSourceConsumedAfterTp(const string source_key,
                                               int &attempt_count_out,
                                               string &terminal_outcome_out,
                                               datetime &consumed_time_out)
{
  attempt_count_out = 0;
  terminal_outcome_out = "";
  consumed_time_out = 0;

  int index = FindDeterministicSourceOutcomeIndex(source_key);
  if(index < 0)
    return false;

  attempt_count_out = g_deterministic_source_outcomes[index].attempt_count;
  terminal_outcome_out = g_deterministic_source_outcomes[index].terminal_outcome;
  consumed_time_out = g_deterministic_source_outcomes[index].consumed_time;
  return g_deterministic_source_outcomes[index].consumed_after_tp;
}

int ResolveDeterministicSourceAttemptCount(const string source_key)
{
  int index = FindDeterministicSourceOutcomeIndex(source_key);
  if(index < 0)
    return 0;

  return g_deterministic_source_outcomes[index].attempt_count;
}

bool ResolveDeterministicSourceConsumedAfterTp(const int engine_id,
                                               const SignalTypes direction,
                                               const int source_slot,
                                               const datetime extremum_time,
                                               const bool source_is_peak,
                                               const double source_price,
                                               int &attempt_count_out,
                                               string &terminal_outcome_out,
                                               datetime &consumed_time_out)
{
  string source_key = BuildExtremumEngineSourceKey(engine_id,
                                                 direction,
                                                 source_slot,
                                                 extremum_time,
                                                 source_is_peak,
                                                 source_price);
  return ResolveDeterministicSourceConsumedAfterTp(source_key,
                                                  attempt_count_out,
                                                  terminal_outcome_out,
                                                  consumed_time_out);
}

int RegisterDeterministicSourceAttempt(SignalParams &signal_params)
{
  if(!signal_params.deterministic_strategy)
    return 0;

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
  {
    source_key = BuildExtremumEngineSignalSourceKey(signal_params);
    signal_params.deterministic_source_key = source_key;
  }

  if(source_key == "")
    return 0;

  int index = EnsureDeterministicSourceOutcomeIndex(source_key, signal_params.entry_time);
  if(index < 0)
    return 0;

  g_deterministic_source_outcomes[index].attempt_count++;
  if(g_deterministic_source_outcomes[index].first_signal_time <= 0)
    g_deterministic_source_outcomes[index].first_signal_time = signal_params.entry_time;

  signal_params.deterministic_source_attempt_index =
    g_deterministic_source_outcomes[index].attempt_count;

  return signal_params.deterministic_source_attempt_index;
}

bool RegisterDeterministicSourceConsumedTp(const SignalParams &signal_params,
                                           int &attempt_count_out)
{
  attempt_count_out = 0;
  if(!signal_params.deterministic_strategy)
    return false;

  string source_key = signal_params.deterministic_source_key;
  if(source_key == "")
    source_key = BuildExtremumEngineSignalSourceKey(signal_params);
  if(source_key == "")
    return false;

  int index = EnsureDeterministicSourceOutcomeIndex(source_key, signal_params.entry_time);
  if(index < 0)
    return false;

  if(g_deterministic_source_outcomes[index].attempt_count <
     signal_params.deterministic_source_attempt_index)
  {
    g_deterministic_source_outcomes[index].attempt_count =
      signal_params.deterministic_source_attempt_index;
  }

  if(g_deterministic_source_outcomes[index].attempt_count <= 0)
    g_deterministic_source_outcomes[index].attempt_count = 1;

  attempt_count_out = g_deterministic_source_outcomes[index].attempt_count;
  bool newly_consumed = !g_deterministic_source_outcomes[index].consumed_after_tp;

  g_deterministic_source_outcomes[index].consumed_after_tp = true;
  g_deterministic_source_outcomes[index].terminal_outcome = "TP";
  g_deterministic_source_outcomes[index].consumed_time = TimeCurrent();

  return newly_consumed;
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

bool SignalMatchesDeterministicIdentity(const SignalParams &signal_params,
                                        const int engine_id,
                                        const SignalTypes direction,
                                        const int source_slot,
                                        const datetime extremum_time,
                                        const bool source_is_peak,
                                        const double source_price)
{
  if(extremum_time <= 0)
    return false;

  if(signal_params.signal_state == CLOSED)
    return false;

  if(signal_params.engine_id != engine_id)
    return false;

  if(signal_params.signal_type != direction)
    return false;

  if(signal_params.source_extremum_time <= 0)
    return false;

  if(signal_params.source_extremum_slot != source_slot)
    return false;

  if(signal_params.source_extremum_time != extremum_time)
    return false;

  if(signal_params.source_extremum_is_peak != source_is_peak)
    return false;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  return (MathAbs(signal_params.source_extremum_price - source_price) <= point_size);
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

bool HasRunningDeterministicSignal(const int engine_id,
                                   const SignalTypes direction,
                                   const int source_slot,
                                   const datetime extremum_time,
                                   const bool source_is_peak,
                                   const double source_price)
{
  if(extremum_time <= 0)
    return false;

  if(direction == BULLISH)
  {
    int total = ArraySize(running_bullish_signals);
    for(int i = 0; i < total; i++)
    {
      if(SignalMatchesDeterministicIdentity(running_bullish_signals[i],
                                            engine_id,
                                            direction,
                                            source_slot,
                                            extremum_time,
                                            source_is_peak,
                                            source_price))
        return true;
    }
    return false;
  }

  if(direction == BEARISH)
  {
    int total = ArraySize(running_bearish_signals);
    for(int i = 0; i < total; i++)
    {
      if(SignalMatchesDeterministicIdentity(running_bearish_signals[i],
                                            engine_id,
                                            direction,
                                            source_slot,
                                            extremum_time,
                                            source_is_peak,
                                            source_price))
        return true;
    }
    return false;
  }

  return false;
}

bool DeterministicSignalMatchesSourceExtremum(const SignalParams &signal_params,
                                              const int source_slot,
                                              const datetime source_time,
                                              const bool source_is_peak,
                                              const double source_price)
{
  if(source_time <= 0 || source_price <= 0.0)
    return false;

  if(signal_params.source_extremum_time <= 0)
    return false;

  if(signal_params.source_extremum_slot != source_slot)
    return false;

  if(signal_params.source_extremum_time != source_time)
    return false;

  if(signal_params.source_extremum_is_peak != source_is_peak)
    return false;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  return (MathAbs(signal_params.source_extremum_price - source_price) <= point_size);
}

bool DeterministicSignalHasBrokerExposure(const SignalParams &signal_params)
{
  return SignalHasBrokerExposure(signal_params);
}

void ExpirePendingDeterministicSignalsForSourceExtremum(const int source_slot,
                                                        const datetime source_time,
                                                        const bool source_is_peak,
                                                        const double source_price)
{
  if(source_time <= 0 || source_price <= 0.0)
    return;

  for(int i = ArraySize(running_bullish_signals) - 1; i >= 0; i--)
  {
    if(!running_bullish_signals[i].deterministic_strategy)
      continue;
    if(DeterministicSignalMatchesSourceExtremum(running_bullish_signals[i],
                                                source_slot,
                                                source_time,
                                                source_is_peak,
                                                source_price))
      continue;
    if(DeterministicSignalHasBrokerExposure(running_bullish_signals[i]))
      continue;

    ExecutionLogDeterministicSignalExpired(running_bullish_signals[i],
                                           source_slot,
                                           source_time,
                                           source_is_peak,
                                           source_price,
                                           "source_extremum_changed");
    running_bullish_signals[i].signal_state = CLOSED;
    ExecutionLogDeterministicPendingCanceled(running_bullish_signals[i],
                                             "source_extremum_changed_no_broker_outcome");
    running_bullish_signals[i].execution.state = EXECUTION_ORDER_CANCELED;
    running_bullish_signals[i].execution.terminal_reason = "source_extremum_changed";
    DeterministicSignalStatsRecordDecisionCheck(running_bullish_signals[i],
                                                "LIFECYCLE_CANCELED",
                                                false,
                                                "source_extremum",
                                                "source_extremum_changed");
    RemoveExecutionLevels(ChartID(), running_bullish_signals[i]);
    RemoveElementFromArray(running_bullish_signals, i);
  }

  for(int j = ArraySize(running_bearish_signals) - 1; j >= 0; j--)
  {
    if(!running_bearish_signals[j].deterministic_strategy)
      continue;
    if(DeterministicSignalMatchesSourceExtremum(running_bearish_signals[j],
                                                source_slot,
                                                source_time,
                                                source_is_peak,
                                                source_price))
      continue;
    if(DeterministicSignalHasBrokerExposure(running_bearish_signals[j]))
      continue;

    ExecutionLogDeterministicSignalExpired(running_bearish_signals[j],
                                           source_slot,
                                           source_time,
                                           source_is_peak,
                                           source_price,
                                           "source_extremum_changed");
    running_bearish_signals[j].signal_state = CLOSED;
    ExecutionLogDeterministicPendingCanceled(running_bearish_signals[j],
                                             "source_extremum_changed_no_broker_outcome");
    running_bearish_signals[j].execution.state = EXECUTION_ORDER_CANCELED;
    running_bearish_signals[j].execution.terminal_reason = "source_extremum_changed";
    DeterministicSignalStatsRecordDecisionCheck(running_bearish_signals[j],
                                                "LIFECYCLE_CANCELED",
                                                false,
                                                "source_extremum",
                                                "source_extremum_changed");
    RemoveExecutionLevels(ChartID(), running_bearish_signals[j]);
    RemoveElementFromArray(running_bearish_signals, j);
  }
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
    TesterStop();
    return false;
  }

  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  if(equity <= 0.0)
  {
    g_forced_stop_triggered = true;
    Print("TesterStop triggered: equity <= 0 and Debug_Stop_On_Negative_Equity is enabled.");
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

  if(run_debug_side_effects && !DebugEquityGuardAllowsProcessing())
  {
    block_source_out = "debug_equity_guard";
    block_reason_out = "Debug equity guard stopped processing";
    return false;
  }

  if(signal_type != BULLISH && signal_type != BEARISH)
  {
    block_source_out = "direction";
    block_reason_out = "Invalid structural direction";
    return false;
  }

  return true;
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
