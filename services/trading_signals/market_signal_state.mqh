//+------------------------------------------------------------------+
//|                                  market_signal_state.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];
datetime g_last_base_structure_time[2]  = {0, 0};
datetime g_last_trend_structure_time[2] = {0, 0};
datetime g_last_macro_structure_time[2] = {0, 0};
datetime g_last_session_structure_time[2] = {0, 0};

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
  if(!TrendFilterIndicatorsAvailable())
    return false;
  if(!MacroFilterIndicatorsAvailable())
    return false;
  if(!SessionFilterIndicatorsAvailable())
    return false;

  if(Debug_Stop_On_Negative_Equity && MQLInfoInteger(MQL_TESTER) > 0)
  {
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
  }

  if(!DailySignalLimitAllowsAttempt(signal_type))
  {
    if(Enable_Logs)
      Print("Daily signal limit reached for direction: ", EnumToString(signal_type));
    return false;
  }

  bool base_mode_uses_bpercent  = StrategyModeUsesAnyBPercent(Strategy_Base_Mode);
  bool base_mode_uses_alligator = StrategyModeUsesAlligator(Strategy_Base_Mode);
  bool base_bpercent_required   = base_mode_uses_bpercent || Base_BPercent_Slope_Filter;
  bool base_alligator_required  = base_mode_uses_alligator || Base_Alligator_Slope_Filter;
  bool require_structure_data = true;

  if(Strategy_Direction_Mode == BULLISH_DIRECTION && signal_type == BEARISH)
  {
    return false;
  }
  if(Strategy_Direction_Mode == BEARISH_DIRECTION && signal_type == BULLISH)
  {
    return false;
  }

  if(!SignalConcurrencyAllowsAttempt(signal_type))
    return false;

  if(base_bpercent_required && ArraySize(ExtBPercentIndicatorsHandle) <= 0)
    return false;

  if(base_alligator_required && ArraySize(ExtAlligatorIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStochIndicatorsHandle) <= 0)
    return false;

  if(require_structure_data && ArraySize(ExtStructStochIndicatorsHandle) <= 0)
    return false;

  if(TrendStructureDataRequired())
  {
    if(TrendStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
      return false;
  }

  if(MacroStructureDataRequired())
  {
    if(MacroStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
      return false;
  }

  if(SessionStructureDataRequired())
  {
    if(SessionStructStochIndicatorHandle.indicator_handle == INVALID_HANDLE)
      return false;
  }

  return true;
}

void RegisterFreshStructureUsage(const SignalParams &signal_params)
{
  int idx = DirectionIndex(signal_params.signal_type);

  if(Base_Fresh_Structure_Time && signal_params.base_structure_snapshot_time > 0)
    g_last_base_structure_time[idx] = signal_params.base_structure_snapshot_time;

  if(Trend_Fresh_Structure_Time && signal_params.trend_structure_snapshot_time > 0)
    g_last_trend_structure_time[idx] = signal_params.trend_structure_snapshot_time;

  if(Macro_Fresh_Structure_Time && signal_params.macro_structure_snapshot_time > 0)
    g_last_macro_structure_time[idx] = signal_params.macro_structure_snapshot_time;

  if(Session_Fresh_Structure_Time && signal_params.session_structure_snapshot_time > 0)
    g_last_session_structure_time[idx] = signal_params.session_structure_snapshot_time;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_STATE_MQH_
