//+------------------------------------------------------------------+
//|                                                   Pivot_Macro    |
//|                                                          loldlm1 |
//+------------------------------------------------------------------+
#property copyright     "https://tradingsniperpanel.com/"
#property description   "Copyright Trading Sniper Team."
#property version       "2.10"
#property description   "Support Contact @chu4xtrade"
#property description   "All Rights Reserved for the Trading Sniper Team."
#property description   "Pivot Macro Model Feature Collector And Broker Executor"

#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
#include "services/trading_signals.mqh"
#include "services/frontend.mqh"

double g_bid = 0.0;
double g_ask = 0.0;
ulong g_execution_magic = 0;
SymbolTradingConstraints g_symbol_constraints;
bool g_tester_interval_completed = false;
bool g_pivot_run_finalized = false;
int g_pivot_macro_seconds = 0;

ulong ResolveStableExecutionMagic()
{
  string source = "HFT_GRID_AI_PIVOT_MACRO_V2|" + _Symbol;
  ulong hash = 1469598103934665603;
  for(int i = 0; i < StringLen(source); i++)
  {
    hash ^= (ulong)StringGetCharacter(source, i);
    hash *= 1099511628211;
  }

  hash &= 0x7FFFFFFF;
  if(hash == 0)
    hash = 1;
  return hash;
}

bool IsExplicitSupportedPivotTimeframe(const ENUM_TIMEFRAMES timeframe)
{
  switch(timeframe)
  {
    case PERIOD_M1:
    case PERIOD_M2:
    case PERIOD_M3:
    case PERIOD_M4:
    case PERIOD_M5:
    case PERIOD_M6:
    case PERIOD_M10:
    case PERIOD_M12:
    case PERIOD_M15:
    case PERIOD_M20:
    case PERIOD_M30:
    case PERIOD_H1:
    case PERIOD_H2:
    case PERIOD_H3:
    case PERIOD_H4:
    case PERIOD_H6:
    case PERIOD_H8:
    case PERIOD_H12:
    case PERIOD_D1:
    case PERIOD_W1:
    case PERIOD_MN1:
      return true;
  }
  return false;
}

bool ValidatePivotTimeframeInputs(string &reason_out)
{
  reason_out = "";
  if(Macro_Timeframe == PERIOD_CURRENT)
  {
    reason_out = "Macro_Timeframe must be an explicit timeframe";
    return false;
  }
  if(Micro_Timeframe == PERIOD_CURRENT)
  {
    reason_out = "Micro_Timeframe must be an explicit timeframe";
    return false;
  }
  if(!IsExplicitSupportedPivotTimeframe(Macro_Timeframe))
  {
    reason_out = "Macro_Timeframe is not a supported MetaTrader timeframe";
    return false;
  }
  if(!IsExplicitSupportedPivotTimeframe(Micro_Timeframe))
  {
    reason_out = "Micro_Timeframe is not a supported MetaTrader timeframe";
    return false;
  }
  if(Macro_Timeframe == Micro_Timeframe)
  {
    reason_out = "Macro_Timeframe and Micro_Timeframe must be distinct";
    return false;
  }

  int macro_seconds = PeriodSeconds(Macro_Timeframe);
  int micro_seconds = PeriodSeconds(Micro_Timeframe);
  if(macro_seconds <= 0)
  {
    reason_out = "Macro_Timeframe duration is unavailable";
    return false;
  }
  if(micro_seconds <= 0)
  {
    reason_out = "Micro_Timeframe duration is unavailable";
    return false;
  }
  if(micro_seconds >= macro_seconds)
  {
    reason_out = "Timeframes must satisfy Micro_Timeframe < Macro_Timeframe";
    return false;
  }
  return true;
}

bool RefreshCustomSymbolRates(MqlTick &tick_out)
{
  ZeroMemory(tick_out);
  if(!SymbolInfoTick(_Symbol, tick_out))
  {
    g_bid = 0.0;
    g_ask = 0.0;
    return false;
  }
  g_bid = tick_out.bid;
  g_ask = tick_out.ask;
  return true;
}

void RefreshCustomSymbolRates()
{
  MqlTick tick;
  RefreshCustomSymbolRates(tick);
}

string PivotRunCompletionStatus()
{
  if(MQLInfoInteger(MQL_TESTER) > 0 && g_tester_interval_completed &&
     !g_model_failed)
    return "NATURAL";
  return "CENSORED";
}

void HandlePivotResearchFailureAtEventBoundary(const bool stop_tester = true)
{
  PivotDatasetCaptureResearchFailure();
  if(g_model_failed && !g_pivot_dataset_research_discarded)
  {
    FinalizePivotSignalTerminalStates();
    DiscardFailedPivotResearch();
  }
  if(stop_tester)
    ModelBoundary();
}

int OnInit()
{
  g_tester_interval_completed = false;
  g_pivot_run_finalized = false;
  g_pivot_macro_seconds = PeriodSeconds(Macro_Timeframe);
  ResetQueryDebugLogSession();
  string timeframe_reason = "";
  if(!ValidatePivotTimeframeInputs(timeframe_reason))
  {
    PrintFormat("Invalid pivot timeframe inputs | Macro=%s | Micro=%s | reason=%s",
                EnumToString(Macro_Timeframe),
                EnumToString(Micro_Timeframe),
                timeframe_reason);
    return INIT_PARAMETERS_INCORRECT;
  }

  if(!RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints))
  {
    Print("Broker constraints unavailable at initialization; collection remains active and execution fails closed: ",
          _Symbol);
  }
  else if(Enable_Logs)
  {
    PrintFormat("Broker constraints loaded for %s | freeze=%.1f pts | stops=%.1f pts | step=%.8f",
                _Symbol,
                g_symbol_constraints.freeze_level_points,
                g_symbol_constraints.stops_level_points,
                g_symbol_constraints.volume_step);
  }

  g_execution_magic = ResolveStableExecutionMagic();
  if(Enable_Logs)
    PrintFormat("Pivot timeframe order | Micro=%s | Macro=%s",
                EnumToString(Micro_Timeframe),
                EnumToString(Macro_Timeframe));
  if(!PivotDatasetInitialize())
  {
    if(MQLInfoInteger(MQL_TESTER) > 0)
    {
      Print("Model dataset export initialization failed; tester initialization stopped");
      return INIT_FAILED;
    }
    Print("Model dataset export initialization failed; live broker processing remains active");
  }
  InitializePivotFractalRuntime();
  InitializePivotBrokerOwnershipBoundary();
  RefreshCustomSymbolRates();
  HandlePivotResearchFailureAtEventBoundary(false);

  ResetExecutionVisualizationCache();
  FrontendResetRefreshThrottle();
  if(FrontendChartWorkEnabled())
  {
    RefreshExecutionVisualization();
    ChartRedraw(ChartID());
  }
  if(!EventSetTimer(1))
  {
    PivotDatasetFail("TIMER_INITIALIZATION");
    return INIT_FAILED;
  }
  return INIT_SUCCEEDED;
}

void FinalizePivotRunExport()
{
  if(g_pivot_run_finalized)
    return;
  g_pivot_run_finalized = true;
  ReconcileAndFinalizePivotSignals();
  if(ModelReady() && ArraySize(g_pivot_deferred_closes) > 0)
    PivotDatasetFail("RUN_END_CLOSE_OBSERVATION_UNAVAILABLE");
  PivotDatasetCaptureResearchFailure();
  if(!g_model_failed)
    FinalizePivotSignalAttemptsForExport();
  if(!g_model_failed)
    FinalizePivotTrialLanesForExport();
  if(!g_model_failed)
    FinalizeActivePivotWindowsForExport();
  HandlePivotResearchFailureAtEventBoundary(false);
  ModelSeal(g_pivot_dataset_broker_peak, PivotTrialActiveStatePeak(), PivotRunCompletionStatus());
  HandlePivotResearchFailureAtEventBoundary(false);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  FinalizePivotRunExport();
  CloseAppendFileLog();
  ModelCloseIndicators();
  FrontendResetRefreshThrottle();

  if(FrontendChartWorkEnabled())
  {
    DeleteEAChartObjects(ChartID());
    ResetExecutionVisualizationCache();
  }
}

void OnTrade()
{
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
  MqlTick tick;
  if(RefreshCustomSymbolRates(tick) && tick.time_msc > 0) ModelObserve(tick, g_model_sequence + 1);
  ProcessPivotSignalLifecycle(tick);
  HandlePivotResearchFailureAtEventBoundary();
}

void OnTimer()
{
  if(g_pivot_run_finalized) return;
  MqlTick tick;
  if(!RefreshCustomSymbolRates(tick) || !PivotTrialQuoteValid(tick) || tick.time_msc <= 0) return;
  // Lifecycle clock only: timer callbacks cannot discover origins or capture features.
  if(g_model_first_time == 0) g_model_first_time = tick.time_msc;
  if(tick.time_msc >= g_model_last_time) g_model_last_time = tick.time_msc;
  g_model_sequence++;
  ProcessPivotSignalLifecycle(tick);
  ProcessPivotTrialLanesTick(tick, true);
  HandlePivotResearchFailureAtEventBoundary();
}

void OnTick()
{
  MqlTick tick;
  RefreshCustomSymbolRates(tick);
  if(tick.time_msc > 0) ModelObserve(tick, g_model_sequence + 1);
  if(!DebugEquityGuardAllowsProcessing())
  {
    HandlePivotResearchFailureAtEventBoundary();
    return;
  }

  ProcessPivotSignalLifecycle(tick);
  bool pivot_context_ready =
    RefreshPivotFractalRuntimeContext(tick.time);
  ProcessPivotTrialLanesTick(tick);
  if(pivot_context_ready)
    ProcessPreparedPivotFractalTick(tick);
  datetime current_time = TimeCurrent();
  if(FrontendRefreshDue(current_time))
    RefreshExecutionVisualization();
  HandlePivotResearchFailureAtEventBoundary();
}

double OnTester()
{
  PivotDatasetCaptureResearchFailure();
  g_tester_interval_completed =
    !g_forced_stop_triggered && !g_debug_no_money_abort_pending &&
    !g_model_failed;
  // Seal before scoring: TesterStop also invokes OnTester, and a final flush
  // can discover the first failure after the final tick.
  FinalizePivotRunExport();
  if(g_model_failed)
    g_tester_interval_completed = false;
  if(!g_tester_interval_completed)
    return 0.0;

  double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
  double total_profit = TesterStatistics(STAT_PROFIT);
  double sharpe_ratio = TesterStatistics(STAT_SHARPE_RATIO);
  double trades_total = TesterStatistics(STAT_TRADES);
  if(initial_deposit <= 0.0 || trades_total <= 0.0)
    return 0.0;

  double growth = total_profit / initial_deposit;
  if(growth < 0.0)
    growth = 0.0;
  double sharpe_component = MathMax(0.0, sharpe_ratio);
  double volume_component = MathLog(1.0 + trades_total);
  return growth * volume_component * sharpe_component;
}
