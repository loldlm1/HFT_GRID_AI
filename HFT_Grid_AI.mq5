//+------------------------------------------------------------------+
//|                                               HFT_Grid_AI_EA.mq5 |
//|                                                          loldlm1 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright     "https://tradingsniperpanel.com/"
#property description   "Copyright Trading Sniper Team."
#property version       "1.10"
#property description   "Support Contact @chu4xtrade"
#property description   "All Rights Reserved for the Trading Sniper Team."
#property description   "Market Data Collector And Broker Executor"

// CUSTOM SERVICES - AGGREGATORS
#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
#include "services/trading_signals.mqh"
#include "services/frontend.mqh"

// GLOBAL VARIABLES
double       g_bid, g_ask;
ulong        g_execution_magic;
SymbolTradingConstraints g_symbol_constraints;

ulong ResolveStableExecutionMagic()
{
  string source = "HFT_GRID_AI_MARKET_DATA_V1|" + _Symbol;
  ulong hash = 1469598103934665603;
  int total = StringLen(source);
  for(int i = 0; i < total; i++)
  {
    hash ^= (ulong)StringGetCharacter(source, i);
    hash *= 1099511628211;
  }

  hash &= 0x7FFFFFFF;
  if(hash == 0)
    hash = 1;
  return hash;
}

int OnInit()
{
  ResetQueryDebugLogSession();
  ResetDeterministicSourceOutcomeState();
  ResetExtremumEngineState();
  if(!RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints))
  {
    Print("Broker constraints unavailable at initialization; market-data collection remains active and execution will fail closed: ",
          _Symbol);
  }
  else if(Enable_Logs)
  {
    PrintFormat("Broker constraints loaded for %s | freeze=%.1f pts | stops=%.1f pts | step=%.2f",
                _Symbol,
                g_symbol_constraints.freeze_level_points,
                g_symbol_constraints.stops_level_points,
                g_symbol_constraints.volume_step);
  }

  g_execution_magic = ResolveStableExecutionMagic();

  DeterministicSignalStatsInit();
  PatternAuditPlaybackInit();
  DeterministicSignalMLShadowInit();

  RefreshCustomSymbolRates();
  ResetExecutionVisualizationCache();
  FrontendResetRefreshThrottle();

  LoadAllIndicatorDefinitions();

  if(FrontendChartWorkEnabled())
  {
    RefreshExecutionVisualization();
    ChartRedraw(ChartID());
  }

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  if(g_extremum_engine_cycle.active)
    ExtremumEngineFinalizeCycle("CENSORED", TimeCurrent());
  DeterministicSignalMLShadowDeinit();
  PatternAuditPlaybackDeinit();
  DeterministicSignalStatsDeinit();
  CloseAppendFileLog();
  ReleaseAllIndicatorDefinitions();
  FrontendResetRefreshThrottle();

  if(FrontendChartWorkEnabled())
  {
    DeleteEAChartObjects(ChartID());
    ResetExecutionVisualizationCache();
  }
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
  RefreshCustomSymbolRates();
  ReconcileRunningSignalsAfterTradeTransaction();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  RefreshCustomSymbolRates();
  DeterministicSignalStatsUpdatePathTracker();
  if(!DebugEquityGuardAllowsProcessing())
    return;
  static datetime next_bar_open           = 0;
  datetime        current_time            = TimeCurrent();
  int             defined_tick_seconds    = PeriodSeconds(EXTREMUM_ENGINE_TIMEFRAME);

  //--- Phase 1 - check the emergence of a new bar and update the status
  if(current_time>=next_bar_open)
  {
    Main();

    //--- set the new bar opening time
    next_bar_open=current_time;
    next_bar_open-=next_bar_open%defined_tick_seconds;
    next_bar_open+=defined_tick_seconds;
  }

  // MANAGES THE BULLISH AND BEARISH SIGNALS
  Main_Tick();
  if(FrontendRefreshDue(current_time))
    RefreshExecutionVisualization();
}

// DETECT BULLISH AND BEARISH SIGNALS
void Main()
{
  DetectStrategySignals();
}

// MANAGE BULLISH AND BEARISH SIGNALS
void Main_Tick()
{
  CheckTickOpenSignals();
}

void RefreshCustomSymbolRates()
{
  MqlTick tick;
  ZeroMemory(tick);
  if(!SymbolInfoTick(_Symbol, tick))
  {
    g_bid = 0.0;
    g_ask = 0.0;
    return;
  }

  g_bid = tick.bid;
  g_ask = tick.ask;
}

double OnTester()
{
  // Return a zero score when the run was forcibly stopped (no money or debug aborts).
  if(g_forced_stop_triggered || g_debug_no_money_abort_pending)
    return 0.0;

  double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
  double final_balance   = TesterStatistics(STAT_PROFIT);
  double sharpe_ratio    = TesterStatistics(STAT_SHARPE_RATIO);
  double trades_total    = TesterStatistics(STAT_TRADES);

  if(initial_deposit <= 0.0 || trades_total <= 0.0)
    return 0.0;

  double growth = (final_balance - initial_deposit) / initial_deposit; // normalized growth
  if(growth < 0.0)
    growth = 0.0;

  double sharpe_component = MathMax(0.0, sharpe_ratio);
  double volume_component = MathLog(1.0 + trades_total); // more trades => more confidence

  double score = growth * volume_component * sharpe_component;
  return score;
}
