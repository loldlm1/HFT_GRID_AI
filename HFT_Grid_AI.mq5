//+------------------------------------------------------------------+
//|                                       HFT_Grid_AI_EA.mq5 |
//|                                                          loldlm1 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright     "https://t.me/TradingAlgoritmicoFx"
#property description   "Copyright Traders Capital Team."
#property version       "1.10"
#property description   "Support Contact @loldlm"
#property description   "All Rights Reserved for the Traders Capital Team."
#property description   "HFT Grid AI EA"

// STANDARD MQL5 LIBRARIES
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>

// CUSTOM SERVICES - AGGREGATORS
#include "services/trading_tools.mqh"
#include "services/trading_management.mqh"
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

int OnInit()
{
  // INITIALIZE GLOBAL VARIABLES
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

  // SET THE MAGIC NUMBER
  string rand_number = (string)MathRand() + "0";
  g_magic_number     = Custom_Magic > 0 ? Custom_Magic : (int)rand_number + ChartWindowPosition();
  g_position.SetExpertMagicNumber(g_magic_number);

  // CHART SETUP
  ApplyDefaultChartStyle(ChartID());

  // INITIALIZE THE EA
  CreateLicensePanelLive();
  LoadAllIndicatorDefinitions();

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  EventKillTimer();
  Comment("");
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
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  RefreshCustomSymbolRates();
  g_ea_running                          = true;
  static datetime next_bar_open        = 0;
  datetime        current_time         = TimeCurrent();
  datetime        current_daily_time   = iTime(_Symbol, PERIOD_D1, 0);
  int              defined_tick_seconds = PeriodSeconds(_Period);

  // AVOID TICK SEQUENCE WHEN CRAZY TICKS AND MARKET IS CLOSED
  if(g_points_spread > Max_Spread || !IsMarketOpen())
  {
    g_ea_running = false;
    return;
  }

  // UPDATES THE STATUS COMMENT
  UpdateEARunningMagic();

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
  RefreshGridVisualization();
}

// DETECT BULLISH AND BEARISH SIGNALS
void Main()
{
  DetectBullishSignal();
  DetectBearishSignal();
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
