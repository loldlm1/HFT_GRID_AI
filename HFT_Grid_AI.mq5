//+------------------------------------------------------------------+
//|                                               HFT_Grid_AI_EA    |
//|                                                          loldlm1 |
//+------------------------------------------------------------------+
#property copyright     "https://tradingsniperpanel.com/"
#property description   "Copyright Trading Sniper Team."
#property version       "1.20"
#property description   "Support Contact @chu4xtrade"
#property description   "All Rights Reserved for the Trading Sniper Team."
#property description   "Pivot Fractal Market Data Collector And Broker Executor"

#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
#include "services/trading_signals.mqh"
#include "services/frontend.mqh"

double g_bid = 0.0;
double g_ask = 0.0;
ulong g_execution_magic = 0;
SymbolTradingConstraints g_symbol_constraints;
bool g_tester_interval_completed = false;

ulong ResolveStableExecutionMagic()
{
  string source = "HFT_GRID_AI_PIVOT_FRACTAL_V2|" + _Symbol;
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
    reason_out = "Micro_Timeframe must be shorter than Macro_Timeframe";
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
  if(PivotSignalLifecycleHasOutstandingAttempts() ||
     PivotTrialMatrixHasOutstandingState())
    return "CENSORED";
  if(MQLInfoInteger(MQL_TESTER) > 0 && g_tester_interval_completed)
    return "NATURAL";
  return "CENSORED";
}

int OnInit()
{
  g_tester_interval_completed = false;
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
  if(!PivotV11StatsInit())
  {
    Print("Schema V11 export initialization failed; EA initialization stopped");
    return INIT_FAILED;
  }
  LoadAllIndicatorDefinitions();
  InitializePivotFractalRuntime();
  InitializePivotBrokerOwnershipBoundary();
  RefreshCustomSymbolRates();

  ResetExecutionVisualizationCache();
  FrontendResetRefreshThrottle();
  if(FrontendChartWorkEnabled())
  {
    RefreshExecutionVisualization();
    ChartRedraw(ChartID());
  }
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  ReconcileAndFinalizePivotSignals();
  string completion_status = PivotRunCompletionStatus();
  FinalizePivotSignalAttemptsForExport();
  FinalizePivotTrialMatrixForExport();
  FinalizeActivePivotWindowsForExport();
  PivotV11StatsDeinit(completion_status);
  CloseAppendFileLog();
  ReleaseAllIndicatorDefinitions();
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
  RefreshCustomSymbolRates();
  ReconcileAndFinalizePivotSignals();
}

void OnTick()
{
  MqlTick tick;
  RefreshCustomSymbolRates(tick);
  if(!DebugEquityGuardAllowsProcessing())
    return;

  ProcessPivotSignalLifecycle();
  bool pivot_context_ready =
    RefreshPivotFractalRuntimeContext(tick.time);
  ProcessPivotTrialMatrixTick(tick);
  if(pivot_context_ready)
    ProcessPreparedPivotFractalTick(tick);
  datetime current_time = TimeCurrent();
  if(FrontendRefreshDue(current_time))
    RefreshExecutionVisualization();
}

double OnTester()
{
  g_tester_interval_completed =
    !g_forced_stop_triggered && !g_debug_no_money_abort_pending;
  if(g_forced_stop_triggered || g_debug_no_money_abort_pending)
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
