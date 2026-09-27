#property strict
#property version "2.10"
#property description "Independent Harami/Engulfing discovery with ATR risk and Macro-duration exits."

#include "services/core/enums.mqh"
#include "services/utils/broker_constraints_helper.mqh"
#include "services/candle_pattern/config.mqh"
#include "services/trading_signals/execution_lot_math.mqh"
#include "services/model_features.mqh"
#include "services/candle_pattern/state.mqh"
#include "services/candle_pattern/dataset_adapter.mqh"
#include "services/candle_pattern/broker.mqh"
#include "services/candle_pattern/engine.mqh"

int OnInit()
{
  g_candle_magic = (long)(0x434e443300000000 | (ModelFingerprint(0xcbf29ce484222325, _Symbol) & 0x00000000ffffffff));
  g_macro_seconds = PeriodSeconds(Macro_Timeframe);
  g_micro_seconds = PeriodSeconds(Micro_Timeframe);
  if(!CandleTimeframeSupported(Macro_Timeframe) || !CandleTimeframeSupported(Micro_Timeframe) ||
     g_micro_seconds <= 0 || g_macro_seconds <= g_micro_seconds ||
     !ModelNumberValid(Lot_Strategy_Size) || Lot_Strategy_Size <= 0.0 ||
     (Lot_Type != EXECUTION_LOT_FIXED_SIZE && Lot_Type != EXECUTION_LOT_REFERENCE_BALANCE_PERCENT) ||
     (Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT && Lot_Strategy_Size > 100.0) ||
     (Broker_Session != FIXED_TIME_SESSIONS && Broker_Session != EXNESS_SESSION) ||
     _Point <= 0.0 || !ModelCellValid(_Symbol)) return INIT_PARAMETERS_INCORRECT;
  for(int i = PositionsTotal() - 1; i >= 0; i--)
  {
    if(PositionGetTicket(i) == 0) return INIT_FAILED;
    if(PositionGetInteger(POSITION_MAGIC) == g_candle_magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
    {
      Print("Candle discovery refuses to adopt an existing owned position after restart.");
      return INIT_FAILED;
    }
  }
  if(MQLInfoInteger(MQL_TESTER)) TesterHideIndicators(true);
  g_atr_handle = iATR(_Symbol, Micro_Timeframe, CANDLE_ATR_PERIOD);
  if(g_atr_handle == INVALID_HANDLE) return INIT_FAILED;
  if(!CandleDatasetInitialize() && MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
  g_last_micro_bar = iTime(_Symbol, Micro_Timeframe, 0);
  if(!EventSetTimer(1))
  {
    ModelFail("TIMER_INITIALIZATION");
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
  ModelObserve(tick, g_candle_sequence);
  CandleReconcile(tick);
  CandleResolveVirtuals(tick);
  CandleDiscover(tick);
  ModelBoundary();
}

void OnTimer()
{
  if(g_candle_stopping) return;
  MqlTick tick;
  if(!SymbolInfoTick(_Symbol, tick) || !CandleTickValid(tick)) return;
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  ModelObserve(tick, g_candle_sequence);
  CandleReconcile(tick);
  ModelBoundary();
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
  ModelObserve(tick, g_candle_sequence);
  CandleReconcile(tick);
  ModelBoundary();
}

double OnTester()
{
  CandleFinish();
  return g_model_failed ? 0.0 : TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  if(!g_candle_stopping) ModelFail("DEINITIALIZED_" + ModelInteger(reason));
  CandleFinish();
  if(g_atr_handle != INVALID_HANDLE && !IndicatorRelease(g_atr_handle)) Print("CANDLE_EXECUTION_ATR_RELEASE_FAILED");
  g_atr_handle = INVALID_HANDLE;
  ModelCloseIndicators();
}
