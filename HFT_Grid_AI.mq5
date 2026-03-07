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
#property description   "Fibonacci EA"

// STANDARD MQL5 LIBRARIES
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

// CUSTOM SERVICES - UTILITIES
#include "services/license_service_setup.mqh"

// CUSTOM SERVICES - AGGREGATORS
#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
#include "services/trading_management_strategies.mqh"
#include "services/trading_signals.mqh"
#include "services/frontend.mqh"

// GLOBAL VARIABLES
CTrade       g_position;
CAccountInfo g_account;
CSymbolInfo  g_symbol;
double       g_bid, g_ask, g_decimal_digits, g_points_spread, g_local_spread;
int          g_magic_number;
string       g_dataset_id = "";
bool         g_ea_running;
datetime     g_initial_ea_date;
SymbolTradingConstraints g_symbol_constraints;

bool ProcessPendingRemovalRequest()
{
  if(!EALifecycleHasPendingRemoval())
    return false;

  string removal_message = EALifecycleRemovalMessage();
  if(removal_message != "")
    Print("[EA] ", removal_message);
  else
    Print("[EA] Removal requested.");

  ExpertRemove();
  return true;
}

int OnInit()
{
  if(!LicenseServiceInit())
    return(INIT_FAILED);

  // INITIALIZE GLOBAL VARIABLES
  g_ea_running = false;
  SetManualSignalEntryEnabled(true);
  g_symbol.Name(_Symbol);
  g_decimal_digits  = pow(10.0, Digits());
  g_initial_ea_date = TimeCurrent();

  if(!RefreshSymbolTradingConstraints(_Symbol, g_symbol_constraints))
  {
    Print("ERROR LOADING BROKER CONSTRAINTS FOR SYMBOL: ", _Symbol);
    return INIT_FAILED;
  }
  if(Enable_Logs)
  {
    PrintFormat("Broker constraints loaded for %s | freeze=%.1f pts | stops=%.1f pts | step=%.2f",
                _Symbol,
                g_symbol_constraints.freeze_level_points,
                g_symbol_constraints.stops_level_points,
                g_symbol_constraints.volume_step);
  }

  // SET THE MAGIC NUMBER (strictly from successful license verify cache)
  long verified_magic_number = LicenseGetCachedMagicNumber();
  if(verified_magic_number <= 0)
  {
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return INIT_FAILED;
  }
  g_magic_number = (int)verified_magic_number;
  g_position.SetExpertMagicNumber(g_magic_number);

  // CHART SETUP
  ClearPersistentChartError();
  ResetGridVisualizationCache();
  ResetLightweightUiCache();
  ApplyDefaultChartStyle(ChartID());

  // INITIALIZE THE EA
  CreateLicensePanelLive();
  LoadAllIndicatorDefinitions();

  if(!EventSetTimer(LicenseServiceTimerSeconds()))
  {
    PrintFormat("[EA] Failed to set timer (%d seconds).",
                LicenseServiceTimerSeconds());
    return(INIT_FAILED);
  }

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  LicenseServiceOnDeinit();
  EventKillTimer();

  string removal_message = EALifecycleRemovalMessage();
  bool preserve_error_object = EALifecyclePreserveErrorObject();

  DeleteEAChartObjects(ChartID(), false);
  ResetGridVisualizationCache();
  ResetLightweightUiCache();

  if(preserve_error_object && removal_message != "")
    RenderPersistentChartError(removal_message);

  EALifecycleClearRemovalRequest();
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
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
  LicenseServiceOnTimer();

  if(ProcessPendingRemovalRequest())
    return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  RefreshCustomSymbolRates();
  DebugEquityGuardAllowsProcessing();
  ProtectionRiskMonitorTradeMode();
  ProtectionRiskFilterTick();
  g_ea_running                            = true;
  static datetime next_bar_open           = 0;
  static datetime next_minute_bar_open    = 0;
  datetime        current_time            = TimeCurrent();
  datetime        current_daily_time      = iTime(_Symbol, PERIOD_D1, 0);
  int             defined_tick_seconds    = PeriodSeconds(_Period);
  int             defined_tick_M1_seconds = PeriodSeconds(PERIOD_M1);

  // SESSION TIME FILTER CHECKS - PER MINUTE INSTEAD OF PER TICK
  if(current_time>=next_minute_bar_open)
  {
    SessionTimeFilterMonitorRuntime();
    SessionTimeFilterProcessPendingForceCloses();
    next_minute_bar_open=current_time;
    next_minute_bar_open-=next_minute_bar_open%defined_tick_M1_seconds;
    next_minute_bar_open+=defined_tick_M1_seconds;
  }

  // AVOID TICK SEQUENCE WHEN CRAZY TICKS AND MARKET IS CLOSED
  if(g_points_spread > Max_Spread || !IsMarketOpen())
  {
    g_ea_running = false;
    RefreshGridVisualization();
    return;
  }

  bool broker_disabled = (MarketStatusGet() == MARKET_STATUS_BROKER_DISABLED);

  //--- Phase 1 - check the emergence of a new bar and update the status
  if(current_time>=next_bar_open)
  {
    if(!broker_disabled)
      Main();

    //--- set the new bar opening time
    next_bar_open=current_time;
    next_bar_open-=next_bar_open%defined_tick_seconds;
    next_bar_open+=defined_tick_seconds;
  }

  // MANAGES THE BULLISH AND BEARISH SIGNALS
  if(!broker_disabled)
    Main_Tick();
  RefreshGridVisualization();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  HandleLightweightChartUiEvent(id, lparam, dparam, sparam);
}

// DETECT BULLISH AND BEARISH SIGNALS
void Main()
{
  DetectStrategySignals();
}

// MANAGE BULLISH AND BEARISH SIGNALS
void Main_Tick()
{
  CheckTickOpenBullishSignals();
  CheckTickOpenBearishSignals();
}

void RefreshCustomSymbolRates()
{
  g_symbol.Refresh();
  g_symbol.RefreshRates();
  g_ask           = g_symbol.Ask();
  g_bid           = g_symbol.Bid();
  g_local_spread  = MathAbs(g_ask-g_bid);
  g_points_spread = g_local_spread*g_decimal_digits;
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
