#property strict
#property version "1.01"
#property description "Independent Harami/Engulfing discovery with ATR risk and Macro-duration exits."

#include "services/core/enums.mqh"
#include "services/trading_management/pivot_fractal_engine_config.mqh"
#include "services/indicators/pivot_points_calculator.mqh"
#include "services/candle_pattern/config.mqh"
#include "services/trading_signals/execution_lot_math.mqh"
#include "services/candle_pattern/schema.mqh"
#include "services/candle_pattern/export.mqh"
#include "services/candle_pattern/context.mqh"
#include "services/candle_pattern/features.mqh"
#include "services/candle_pattern/state.mqh"
#include "services/candle_pattern/broker.mqh"
#include "services/candle_pattern/engine.mqh"

int OnInit()
{
  ArrayInitialize(g_candle_files, INVALID_HANDLE);
  ArrayInitialize(g_candle_bands, INVALID_HANDLE);
  ArrayInitialize(g_candle_stochastic, INVALID_HANDLE);
  g_macro_seconds = PeriodSeconds(Macro_Timeframe);
  g_micro_seconds = PeriodSeconds(Micro_Timeframe);
  if(!CandleTimeframeSupported(Macro_Timeframe) || !CandleTimeframeSupported(Micro_Timeframe) ||
     g_micro_seconds <= 0 || g_macro_seconds <= g_micro_seconds ||
     !CandleNumberValid(Lot_Strategy_Size) || Lot_Strategy_Size <= 0.0 ||
     (Lot_Type != EXECUTION_LOT_FIXED_SIZE && Lot_Type != EXECUTION_LOT_REFERENCE_BALANCE_PERCENT) ||
     (Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT && Lot_Strategy_Size > 100.0) ||
     _Point <= 0.0 || !CandleCellValid(_Symbol)) return INIT_PARAMETERS_INCORRECT;
  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    if(PositionGetTicket(i) == 0) return INIT_FAILED;
    if(PositionGetInteger(POSITION_MAGIC) == CANDLE_MAGIC && PositionGetString(POSITION_SYMBOL) == _Symbol)
    {
      Print("Candle discovery refuses to adopt an existing owned position after restart.");
      return INIT_FAILED;
    }
  }
  if(!CandleOpenIndicators()) return INIT_FAILED;
  if(!CandleOpenExport() && MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
  g_last_micro_bar = iTime(_Symbol, Micro_Timeframe, 0);
  if(!EventSetTimer(1))
  {
    CandleExportFail("TIMER_INITIALIZATION");
    return INIT_FAILED;
  }
  PrintFormat("Candle discovery ready | Macro=%s | Micro=%s | ATR=13/1.0/shift1 | fixed SL/TP | lot_type=%s | lot_size=%.8f | reference_balance=%.2f",
              EnumToString(Macro_Timeframe), EnumToString(Micro_Timeframe), EnumToString(Lot_Type),
              Lot_Strategy_Size, PIVOT_EXECUTION_REFERENCE_BALANCE);
  return INIT_SUCCEEDED;
}

void OnTick()
{
  if(g_candle_stopping) return;
  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick) || !CandleTickValid(tick)) return;
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  CandleRefreshContext(tick);
  CandleReconcile(tick);
  CandleResolveVirtuals(tick);
  CandleDiscover(tick);
  if(g_candle_export_failed && MQLInfoInteger(MQL_TESTER)) TesterStop();
}

void OnTimer()
{
  if(g_candle_stopping) return;
  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick) || !CandleTickValid(tick)) return;
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  CandleRefreshContext(tick);
  CandleReconcile(tick);
  if(g_candle_export_failed && MQLInfoInteger(MQL_TESTER)) TesterStop();
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request, const MqlTradeResult &result)
{
  if(g_candle_stopping || transaction.symbol != _Symbol) return;
  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick) || !CandleTickValid(tick)) return;
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  if(transaction.type == TRADE_TRANSACTION_REQUEST && result.request_id > 0)
  {
    for(int i = 0; i < g_candle_broker_extent; i++)
    {
      if(!g_candle_brokers[i].active || g_candle_brokers[i].request_id != result.request_id) continue;
      if(result.order > 0) g_candle_brokers[i].order = result.order;
      if(result.deal > 0) g_candle_brokers[i].deal = result.deal;
    }
  }
  CandleRefreshContext(tick);
  CandleReconcile(tick);
}

double OnTester()
{
  CandleFinish();
  return g_candle_export_failed ? 0.0 : TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  if(!g_candle_stopping) CandleExportFail("DEINITIALIZED_" + CandleInteger(reason));
  CandleFinish();
  CandleCloseIndicators();
  CandleCloseFiles();
}
