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

ulong ResolveStableExecutionMagic()
{
  string source = "HFT_GRID_AI_PIVOT_FRACTAL_V1|" + _Symbol;
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

string PivotRunCompletionStatus(const int deinit_reason)
{
  if(MQLInfoInteger(MQL_TESTER) > 0 && deinit_reason == REASON_CLOSE)
    return "NATURAL";
  return "CENSORED";
}

int OnInit()
{
  ResetQueryDebugLogSession();
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
  PivotV9StatsInit();
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
  string completion_status = PivotRunCompletionStatus(reason);
  FinalizeActivePivotWindowsForExport(completion_status);
  PivotV9StatsDeinit(completion_status);
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

  ProcessPivotSignalLifecycle(tick);
  ProcessPivotFractalTick(tick);
  datetime current_time = TimeCurrent();
  if(FrontendRefreshDue(current_time))
    RefreshExecutionVisualization();
}

double OnTester()
{
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
