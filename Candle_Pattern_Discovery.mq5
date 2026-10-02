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
#include "services/candle_pattern/continuation_state.mqh"

void CandleContinuationSnapshot(const string boundary)
{
  ModelContinuationBeginState(boundary);
  SharedContinuationState();
  CandleContinuationState();
  ModelContinuationFinishState();
}

void CandleContinuationStart()
{
  if(ModelContinuationStart())
  {
    SharedContinuationState();
    CandleContinuationState();
    ModelContinuationFinishState();
  }
}

void CandleContinuationAcquireAnchor(const string callback, const MqlTick &tick, const bool acquired)
{
  if(!ModelContinuationAnchor(callback, tick, acquired)) return;
  SharedContinuationState();
  CandleContinuationState();
  ModelContinuationFinishState();
}

void CandleContinuationBoundary(const string callback)
{
  if(!ModelContinuationBoundaryDue(callback)) return;
  if(!ModelContinuationFlushInput("BOUNDARY")) return;
  CandleContinuationSnapshot("END");
  if(ModelContinuationRotate())
  {
    SharedContinuationState();
    CandleContinuationState();
    ModelContinuationFinishState();
  }
}

void CandleContinuationTerminalBegin()
{
  if(!g_cont_enabled || g_model_failed) return;
  if(g_cont_anchor_pending) { ModelFail("CONTINUATION_STARTUP_NOT_REACHED"); return; }
  if(g_cont_replaying) { ModelFail("CONTINUATION_PREFIX_NOT_REACHED"); return; }
  if(!ModelContinuationFlushInput("BOUNDARY")) return;
  CandleContinuationSnapshot("END");
  if(!ModelContinuationSeal("PRE_FINALIZATION") || !ModelContinuationCreateSegment(true)) return;
  CandleContinuationSnapshot("START");
  g_cont_terminal = true;
}

void CandleContinuationTerminalEnd(const bool natural)
{
  if(!g_cont_enabled) return;
  if(!g_model_failed)
  {
    CandleContinuationSnapshot("END");
    ModelContinuationSeal(natural ? "TERMINAL" : "INTERRUPTED");
  }
  ModelContinuationRelease();
}



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
  CandleContinuationStart();
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
  ZeroMemory(tick);
  bool acquired = SymbolInfoTick(_Symbol, tick) && CandleTickValid(tick);
  CandleContinuationAcquireAnchor("TICK", tick, acquired);
  ModelContinuationInput("TICK", tick, g_candle_sequence, acquired);
  if(!acquired) { CandleContinuationBoundary("TICK"); return; }
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  ModelObserve(tick, g_candle_sequence);
  CandleReconcile(tick);
  CandleResolveVirtuals(tick);
  CandleDiscover(tick);
  CandleContinuationBoundary("TICK");
  ModelBoundary();
}

void OnTimer()
{
  if(g_candle_stopping) return;
  MqlTick tick;
  ZeroMemory(tick);
  bool acquired = SymbolInfoTick(_Symbol, tick) && CandleTickValid(tick);
  CandleContinuationAcquireAnchor("TIMER", tick, acquired);
  ModelContinuationInput("TIMER", tick, g_candle_sequence, acquired);
  if(!acquired) { CandleContinuationBoundary("TIMER"); return; }
  g_candle_last_time = tick.time_msc;
  g_candle_sequence++;
  ModelObserve(tick, g_candle_sequence);
  CandleReconcile(tick);
  CandleContinuationBoundary("TIMER");
  ModelBoundary();
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request, const MqlTradeResult &result)
{
  if(g_candle_stopping || transaction.symbol != _Symbol) return;
  MqlTick tick;
  ZeroMemory(tick);
  bool acquired = SymbolInfoTick(_Symbol, tick) && CandleTickValid(tick);
  CandleContinuationAcquireAnchor("TRADE", tick, acquired);
  if(g_cont_enabled) ModelContinuationInput("TRADE", tick, g_candle_sequence, acquired, ModelContinuationTransaction(transaction, request, result));
  if(!acquired) { CandleContinuationBoundary("TRADE"); return; }
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
  CandleContinuationBoundary("TRADE");
  ModelBoundary();
}

double OnTester()
{
  g_candle_tester_interval_completed = true;
  CandleFinish();
  return g_model_failed ? 0.0 : TesterStatistics(STAT_PROFIT);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  if(!g_candle_stopping && !g_model_config.continuation) ModelFail("DEINITIALIZED_" + ModelInteger(reason));
  CandleFinish();
  if(g_atr_handle != INVALID_HANDLE && !IndicatorRelease(g_atr_handle)) Print("CANDLE_EXECUTION_ATR_RELEASE_FAILED");
  g_atr_handle = INVALID_HANDLE;
  ModelCloseIndicators();
}
