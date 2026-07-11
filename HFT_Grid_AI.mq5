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
#property description   "Execution Foundation EA"

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

bool ExtremumEngineRequiresHedgingAccount()
{
  long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  if(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    return true;

  PrintFormat("Unsupported account margin mode for extremum engine: %d. Hedging account required.",
              (int)margin_mode);
  return false;
}

int OnInit()
{
  if(!LicenseServiceInit())
    return(INIT_FAILED);

  if(!ExtremumEngineRequiresHedgingAccount())
    return(INIT_FAILED);

  // INITIALIZE GLOBAL VARIABLES
  g_ea_running = false;
  SetManualSignalEntryEnabled(true);
  g_symbol.Name(_Symbol);
  g_decimal_digits  = pow(10.0, Digits());
  g_initial_ea_date = TimeCurrent();
  ResetQueryDebugLogSession();
  ResetDeterministicSourceOutcomeState();
  ResetExtremumEngineState();
  DeterministicSignalStatsInit();
  PatternAuditPlaybackInit();
  DeterministicSignalMLShadowInit();

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
  if(verified_magic_number <= 0 && is_testing == false)
  {
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return INIT_FAILED;
  }
  g_magic_number = (int)verified_magic_number;
  g_position.SetExpertMagicNumber(g_magic_number);

  // CHART SETUP
  RefreshCustomSymbolRates();
  ResetExecutionVisualizationCache();
  ResetLightweightUiCache();
  FrontendResetRefreshThrottle();
  InvalidateLightweightUiLayout();
  if(FrontendChartWorkEnabled())
  {
    ClearPersistentChartError();
    ApplyDefaultChartStyle(ChartID());
  }

  // INITIALIZE THE EA
  if(FrontendChartWorkEnabled())
    CreateLicensePanelLive();
  LoadAllIndicatorDefinitions();

  if(!EventSetTimer(LicenseServiceTimerSeconds()))
  {
    PrintFormat("[EA] Failed to set timer (%d seconds).",
                LicenseServiceTimerSeconds());
    return(INIT_FAILED);
  }

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
  LicenseServiceOnDeinit();
  EventKillTimer();
  ReleaseAllIndicatorDefinitions();
  ReleaseExecutionIndicatorCache();
  FrontendResetRefreshThrottle();

  string removal_message = EALifecycleRemovalMessage();
  bool preserve_error_object = EALifecyclePreserveErrorObject();

  if(FrontendChartWorkEnabled())
  {
    DeleteEAChartObjects(ChartID(), false);
    ResetExecutionVisualizationCache();
    ResetLightweightUiCache();

    if(preserve_error_object && removal_message != "")
      RenderPersistentChartError(removal_message);
  }

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
  ReconcileRunningSignalsAfterTradeTransaction();
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
  DeterministicSignalStatsUpdatePathTracker();
  DebugEquityGuardAllowsProcessing();
  ProtectionRiskMonitorTradeMode();
  ProtectionRiskFilterTick();
  g_ea_running                            = true;
  static datetime next_bar_open           = 0;
  static datetime next_minute_bar_open    = 0;
  static bool     admission_blocked_last_tick = false;
  datetime        current_time            = TimeCurrent();
  datetime        current_daily_time      = iTime(_Symbol, PERIOD_D1, 0);
  int             defined_tick_seconds    = PeriodSeconds(EXTREMUM_ENGINE_TIMEFRAME);
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

  bool admission_blocked = (g_points_spread > Max_Spread || !IsMarketOpen());
  if(admission_blocked != admission_blocked_last_tick)
    FrontendForceNextRefresh();

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
  Main_Tick();
  admission_blocked_last_tick = admission_blocked;
  if(FrontendRefreshDue(current_time))
    RefreshExecutionVisualization();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  if(!FrontendChartWorkEnabled())
    return;

  if(HandleLightweightChartUiEvent(id, lparam, dparam, sparam))
  {
    FrontendForceNextRefresh();
    RefreshExecutionVisualization();
    ChartRedraw(ChartID());
  }
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
