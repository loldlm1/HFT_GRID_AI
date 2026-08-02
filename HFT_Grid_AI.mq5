//+------------------------------------------------------------------+
//|                                       HFT_Grid_AI_EA.mq5 |
//|                                                          loldlm1 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright     "https://tradingsniperpanel.com"
#property description   "Copyright BULLISH LIFE Team."
#property version       "2.00"
#property description   "Support Telegram Contact @chu4xtrade"
#property description   "All Rights Reserved for the BULLISH LIFE Team."
#property description   "PIVOT HFT EA"

// STANDARD MQL5 LIBRARIES
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

// CUSTOM SERVICES - UTILITIES
#include "services/license_service_setup.mqh"

// CUSTOM SERVICES - AGGREGATORS
#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
#include "services/trading_signals.mqh"
#include "services/frontend.mqh"

// GLOBAL VARIABLES
CTrade       g_position;
CAccountInfo g_account;
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
    EALifecycleRequestRemoval("Pivot HFT EA removed: legacy lane-magic positions are still open on this symbol.");
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

  if(!PivotHftHedgingAccountSupported())
  {
    Print("Pivot HFT requires an MT5 hedging account.");
    return INIT_FAILED;
  }
  if(!PivotHftTimeframesValid())
  {
    PrintFormat("Pivot HFT invalid timeframe pair | micro=%s | pivot=%s",
                EnumToString(Pivot_HFT_Micro_Timeframe),
                EnumToString(Pivot_HFT_Pivot_Timeframe));
    return INIT_FAILED;
  }

  if(Pivot_HFT_Retracement_Points < 0.0)
  {
    PrintFormat("Pivot HFT invalid retracement input | points=%.2f",
                Pivot_HFT_Retracement_Points);
    return INIT_PARAMETERS_INCORRECT;
  }

  if(Pivot_HFT_Max_Retries_Per_Level < 0)
  {
    PrintFormat("Pivot HFT invalid max retries input | retries=%d",
                Pivot_HFT_Max_Retries_Per_Level);
    return INIT_PARAMETERS_INCORRECT;
  }

  string risk_input_reason = "";
  if(!PivotHftValidateRiskGeometryInputs(risk_input_reason))
  {
    PrintFormat("Pivot HFT invalid exit geometry inputs | reason=%s",
                risk_input_reason);
    return INIT_PARAMETERS_INCORRECT;
  }

  PivotHftAuditInitialize();
  double initial_broker_floor_points = EffectiveBrokerDistancePoints(
    g_symbol_constraints,
    0.0,
    1.0);
  PivotHftAuditLog("CONFIG",
                   StringFormat("micro_tf=%s|pivot_tf=%s|direction=%s|retrace_pts=%.2f|max_retries_per_level=%d|bands_width_pct=%.2f|step_sl_ratio=%.4f|fixed_tp_sl_ratio=%.4f|lot=%.2f|max_spread=%.2f|daily_signal_limit=%d|daily_limit_mode=%s|broker_stops_pts=%.2f|broker_freeze_pts=%.2f|broker_floor_pts=%.2f|point=%.8f|tick=%.8f|visual=%d",
                                EnumToString(Pivot_HFT_Micro_Timeframe),
                                EnumToString(Pivot_HFT_Pivot_Timeframe),
                                EnumToString(Pivot_HFT_Direction_Mode),
                                Pivot_HFT_Retracement_Points,
                                Pivot_HFT_Max_Retries_Per_Level,
                                Pivot_HFT_Local_SL_Bands_Width_Percent,
                                Pivot_HFT_TP_Step_SL_Ratio,
                                Pivot_HFT_Fixed_TP_SL_Ratio,
                                Pivot_HFT_Lot_Size,
                                Max_Spread,
                                Daily_Signal_Limit,
                                EnumToString(Daily_Signal_Limit_Mode),
                                g_symbol_constraints.stops_level_points,
                                g_symbol_constraints.freeze_level_points,
                                initial_broker_floor_points,
                                g_symbol_constraints.point_size,
                                g_symbol_constraints.tick_size,
                                (int)Pivot_HFT_Enable_Visualization));

  // Rebuild the active pivot-set test state even when entry sessions are closed.
  PivotHftRefreshPivotSnapshot(true);
  ClearFrontendVisualization();

  // CHART SETUP
  if(PivotHftVisualizationEnabledForRuntime())
    ApplyDefaultChartStyle(ChartID());

  // INITIALIZE THE EA
  CreateLicensePanelLive();
  if(!PivotHftSetSignalResourcesActive(SessionTimeFilterWindowIsOpen()))
    return INIT_FAILED;
  if(!EventSetTimer(LicenseServiceTimerSeconds()))
  {
    PivotHftReleaseIndicators();
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
  PivotHftAuditShutdown(reason);
  LicenseServiceOnDeinit();
  EventKillTimer();
  PivotHftReleaseIndicators();
  PivotHftResetCampaign();
  PivotHftClearPositionStates();
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
  RefreshCustomSymbolRates(true);
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
  datetime current_time = TimeCurrent();
  bool debug_processing_allowed = DebugEquityGuardAllowsProcessing();

  static datetime next_market_status_check = 0;
  if(current_time >= next_market_status_check ||
     MarketStatusHasPendingForceClose())
  {
    ProtectionRiskMonitorTradeMode();
    next_market_status_check = current_time + 1;
  }
  ProtectionRiskFilterTick();
  bool signal_attempts_allowed = MarketStatusAllowsSignalAttempts();
  static datetime next_minute_bar_open    = 0;
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

  bool session_allows = SessionTimeFilterAllowsSignalAttempt();
  bool resources_ready = PivotHftSetSignalResourcesActive(session_allows);
  bool has_position_states = PivotHftHasPositionStates();
  if(session_allows || has_position_states)
    PivotHftBeginTickDataCache();
  bool has_live_positions = PivotHftHasLivePositionStates();
  bool quotes_ready = true;
  if((session_allows && resources_ready) || has_live_positions)
    quotes_ready = RefreshCustomSymbolRates(session_allows && resources_ready);

  bool market_open = false;
  bool spread_allowed = false;
  if(session_allows && resources_ready && quotes_ready)
  {
    market_open = IsMarketOpen();
    spread_allowed = (g_points_spread <= Max_Spread);
    if(!spread_allowed)
    {
      string spread_reason = StringFormat("spread=%.1f>%.1f",
                                          g_points_spread,
                                          Max_Spread);
      MarketStatusRegisterExecutionError("PIVOT_HFT_SPREAD_BLOCK",
                                         spread_reason,
                                         0,
                                         0);
    }
  }

  bool strategy_data_allowed = (debug_processing_allowed &&
                                session_allows &&
                                resources_ready &&
                                quotes_ready);
  bool execution_context_allowed = (signal_attempts_allowed &&
                                    market_open &&
                                    spread_allowed);
  bool allow_new_campaign = false;
  bool entry_intent_ready = false;
  if(strategy_data_allowed)
  {
    bool protection_allows = ProtectionRiskAllowsSignalAttempt();
    bool daily_budget_available =
      (DailySignalLimitAllowsAttempt(BULLISH) ||
       DailySignalLimitAllowsAttempt(BEARISH));
    bool execution_slot_available =
      (!PivotHftHasBlockingPositionLifecycle() &&
       !PivotHftHasManagedBrokerPosition());
    allow_new_campaign = (execution_context_allowed &&
                          protection_allows &&
                          daily_budget_available &&
                          execution_slot_available);
    entry_intent_ready = PivotHftDetectEntryIntent(allow_new_campaign);
  }

  if(entry_intent_ready && execution_context_allowed)
    PivotHftExecuteEntryIntent();

  g_ea_running = (strategy_data_allowed &&
                  execution_context_allowed &&
                  allow_new_campaign);
  UpdateEARunningMagic();

  if(has_position_states || PivotHftHasPositionStates())
    PivotHftProcessAllPositions();

  if((session_allows && resources_ready) || PivotHftHasLivePositionStates())
    RefreshPivotHftVisualization();
  else if(g_pivot_hft_visualization_visible)
    ClearFrontendVisualization();
}

bool RefreshCustomSymbolRates(const bool include_spread)
{
  MqlTick current_tick;
  if(!SymbolInfoTick(_Symbol, current_tick))
  {
    g_ask = 0.0;
    g_bid = 0.0;
    return false;
  }

  g_ask = current_tick.ask;
  g_bid = current_tick.bid;
  if(g_ask <= 0.0 || g_bid <= 0.0)
  {
    g_ask = 0.0;
    g_bid = 0.0;
    return false;
  }
  if(!include_spread)
    return true;

  g_local_spread  = MathAbs(g_ask-g_bid);
  double point_size = g_symbol_constraints.point_size;
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size > 0.0)
    g_points_spread = g_local_spread / point_size;
  else
    g_points_spread = g_local_spread*g_decimal_digits;
  return true;
}

double OnTester()
{
  // Return a zero score when the run was forcibly stopped (no money or debug aborts).
  if(g_forced_stop_triggered || g_debug_no_money_abort_pending)
    return 0.0;

  double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
  double net_profit      = TesterStatistics(STAT_PROFIT);
  double sharpe_ratio    = TesterStatistics(STAT_SHARPE_RATIO);
  double trades_total    = TesterStatistics(STAT_TRADES);

  if(initial_deposit <= 0.0 || trades_total <= 0.0)
    return 0.0;

  double growth = net_profit / initial_deposit; // STAT_PROFIT is already net profit.
  if(growth < 0.0)
    growth = 0.0;

  double sharpe_component = MathMax(0.0, sharpe_ratio);
  double volume_component = MathLog(1.0 + trades_total); // more trades => more confidence

  double score = growth * volume_component * sharpe_component;
  return score;
}
