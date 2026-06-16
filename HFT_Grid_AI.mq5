//+------------------------------------------------------------------+
//|                                       HFT_Grid_AI_EA.mq5 |
//|                                                          loldlm1 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright     "https://tradingsniperpanel.com"
#property description   "Copyright BULLISH LIFE Team."
#property version       "1.10"
#property description   "Support Telegram Contact @chu4xtrade"
#property description   "All Rights Reserved for the BULLISH LIFE Team."
#property description   "PANDORA BOX EA"

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
long         g_magic_number;
string       g_dataset_id = "";
bool         g_ea_running;
datetime     g_initial_ea_date;
SymbolTradingConstraints g_symbol_constraints;

ulong EARuntimeMagicHash(const string input_value)
{
  ulong hash = 1469598103934665603;
  int len = StringLen(input_value);
  for(int i = 0; i < len; i++)
  {
    hash ^= (ulong)(uchar)StringGetCharacter(input_value, i);
    hash *= 1099511628211;
  }
  return hash;
}

long ResolveTesterRuntimeMagicNumber()
{
  if(Custom_Magic > 0)
    return (long)Custom_Magic;

  string seed = StringFormat("%s|%s|%d|%I64d",
                             "pandora_box",
                             _Symbol,
                             (int)_Period,
                             (long)ChartID());
  ulong hash = EARuntimeMagicHash(seed);
  long magic = (long)(hash % (ulong)(2147483646)) + 1;
  return magic;
}

bool HasLegacyLaneMagicPositions(const long lane_magic,
                                 const long runtime_magic)
{
  if(lane_magic <= 0 || runtime_magic <= 0 || lane_magic == runtime_magic)
    return false;

  int total_positions = PositionsTotal();
  for(int i = total_positions - 1; i >= 0; i--)
  {
    ulong position_ticket = PositionGetTicket(i);
    if(position_ticket == 0)
      continue;
    if(!PositionSelectByTicket(position_ticket))
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != lane_magic)
      continue;

    PrintFormat("[EA] Legacy lane-magic position detected | symbol=%s | ticket=%I64u | lane_magic=%I64d | runtime_magic=%I64d",
                _Symbol,
                position_ticket,
                lane_magic,
                runtime_magic);
    return true;
  }

  return false;
}

bool ResolveRuntimeTradeMagicNumber(long &runtime_magic)
{
  runtime_magic = 0;

  if(LicenseIsTestingMode())
  {
    runtime_magic = ResolveTesterRuntimeMagicNumber();
    return (runtime_magic > 0);
  }

  runtime_magic = LicenseGetCachedMagicNumber();
  if(runtime_magic <= 0)
  {
    Print("[EA] Missing backend instance-scoped magic_number after license verification.");
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage(""));
    return false;
  }

  long lane_magic = LicenseGetCachedLaneMagicNumber();
  if(HasLegacyLaneMagicPositions(lane_magic, runtime_magic))
  {
    EALifecycleRequestRemoval("Pandora Box EA removed: legacy lane-magic positions are still open on this symbol.");
    return false;
  }

  if(Custom_Magic > 0 && (long)Custom_Magic != runtime_magic)
  {
    PrintFormat("[EA] Custom_Magic=%d ignored. Using backend instance magic=%I64d.",
                Custom_Magic,
                runtime_magic);
  }

  return true;
}

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
  g_symbol.Name(_Symbol);
  g_decimal_digits  = pow(10.0, Digits());
  g_initial_ea_date = TimeCurrent();

  if(!RefreshBrokerConstraintsForAction(_Symbol, g_symbol_constraints, "EA_INIT"))
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

  // SET THE MAGIC NUMBER
  if(!ResolveRuntimeTradeMagicNumber(g_magic_number))
    return INIT_FAILED;
  g_position.SetExpertMagicNumber((ulong)g_magic_number);

  // CHART SETUP
  ApplyDefaultChartStyle(ChartID());

  // INITIALIZE THE EA
  CreateLicensePanelLive();
  LoadAllIndicatorDefinitions();
  if(!EventSetTimer(LicenseServiceTimerSeconds()))
  {
    PrintFormat("[EA] Failed to set timer (%d seconds).",
                LicenseServiceTimerSeconds());
    return INIT_FAILED;
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
  ClearFrontendVisualization();
  Comment("");
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
  ProcessPendingRemovalRequest();
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
  bool signal_attempts_allowed            = MarketStatusAllowsSignalAttempts();
  bool broker_actions_allowed             = MarketStatusAllowsBrokerActions();
  g_ea_running                            = MarketStatusPlatformTradeAllowed();
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

  bool market_open = IsMarketOpen();
  if(PandoraRuntimeCanUseIdleFastPath() && !MarketStatusHasPendingForceClose())
  {
    RefreshGridVisualization();
    return;
  }

  bool pandora_observed_this_tick = false;
  if(signal_attempts_allowed && market_open && PandoraStrategyEnabled())
  {
    PandoraDetectSignals();
    pandora_observed_this_tick = true;
  }

  // AVOID BROKER/LIFECYCLE SEQUENCE WHEN CRAZY TICKS OR MARKET IS CLOSED
  if(g_points_spread > Max_Spread || !market_open)
  {
    if(g_points_spread > Max_Spread)
    {
      string spread_reason = StringFormat("spread=%.1f>%.1f",
                                          g_points_spread,
                                          Max_Spread);
      MarketStatusRegisterExecutionError("PANDORA_BROKER_SPREAD_BLOCK", spread_reason, 0, 0);
    }
    g_ea_running = false;
    RefreshGridVisualization();
    return;
  }

  // UPDATES THE STATUS COMMENT
  UpdateEARunningMagic();

  //--- Phase 1 - check the emergence of a new bar and update the status
  if(current_time>=next_bar_open)
  {
    if(signal_attempts_allowed)
      Main(pandora_observed_this_tick);

    //--- set the new bar opening time
    next_bar_open=current_time;
    next_bar_open-=next_bar_open%defined_tick_seconds;
    next_bar_open+=defined_tick_seconds;
  }

  // MANAGES THE BULLISH AND BEARISH SIGNALS
  if(broker_actions_allowed)
    Main_Tick(signal_attempts_allowed && market_open,
              pandora_observed_this_tick);
  RefreshGridVisualization();
}

// DETECT BULLISH AND BEARISH SIGNALS
void Main(const bool pandora_already_observed = false)
{
  if(pandora_already_observed && PandoraStrategyEnabled())
    return;
  DetectStrategySignals();
}

// MANAGE BULLISH AND BEARISH SIGNALS
void Main_Tick(const bool pandora_detection_allowed = true,
               const bool pandora_already_observed = false)
{
  // Pandora strategy needs tick-based detection so breakout triggers arm immediately after the box window closes.
  if(pandora_detection_allowed &&
     !pandora_already_observed &&
     PandoraStrategyEnabled())
    PandoraDetectSignals();

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
