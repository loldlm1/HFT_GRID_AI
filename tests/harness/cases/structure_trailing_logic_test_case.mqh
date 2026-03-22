#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_TRAILING_LOGIC_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_TRAILING_LOGIC_MQH

#include "../framework.mqh"

void BuildStructureTrailingTestStructure(StochasticMarketStructure &structure_out,
                                         const double base_price,
                                         const double stop_candidate_price,
                                         const double tp_candidate_price,
                                         const double older_tp_price)
{
  structure_out = StochasticMarketStructure();
  ArrayResize(structure_out.os_market_structures, 4);

  structure_out.os_market_structures[0].is_peak = true;
  structure_out.os_market_structures[0].extremum_high = tp_candidate_price + (tp_candidate_price - base_price);
  structure_out.os_market_structures[0].extremum_time = D'2026.03.22 12:03';

  structure_out.os_market_structures[1].is_peak = true;
  structure_out.os_market_structures[1].extremum_high = tp_candidate_price;
  structure_out.os_market_structures[1].extremum_time = D'2026.03.22 12:02';

  structure_out.os_market_structures[2].is_peak = false;
  structure_out.os_market_structures[2].extremum_low = stop_candidate_price;
  structure_out.os_market_structures[2].extremum_time = D'2026.03.22 12:01';

  structure_out.os_market_structures[3].is_peak = true;
  structure_out.os_market_structures[3].extremum_high = older_tp_price;
  structure_out.os_market_structures[3].extremum_time = D'2026.03.22 12:00';
}

SignalParams BuildStructureTrailingActiveSignal(const SignalTypes direction,
                                                const double entry_price,
                                                const double lot_size,
                                                const double initial_tp)
{
  SignalParams signal;
  signal.signal_type = direction;
  signal.strategy_context = CONTEXT_SLOT_BASE;
  signal.strategy_timeframe = PERIOD_M1;
  signal.entry_time = D'2026.03.22 12:00';
  signal.grid_sequence_id = BuildSignalSequenceId(direction,
                                                  signal.entry_time,
                                                  signal.entry_time);

  GridOrderState level0;
  level0.level_index = 0;
  level0.status = GRID_ORDER_ACTIVE;
  level0.opens_position = true;
  level0.lot_size = lot_size;
  level0.initial_lot_size = lot_size;
  level0.entry_price = entry_price;
  level0.initial_take_profit_price = initial_tp;
  level0.take_profit_price = initial_tp;
  level0.position_ticket = 1;

  ArrayResize(signal.grid_orders, 1);
  signal.grid_orders[0] = level0;
  signal.trailing_first_level_take_profit_price = initial_tp;

  return signal;
}

bool RunTest_structure_trailing_logic_test(string &errors)
{
  errors = "";

  double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  if(volume_step <= 0.0)
    volume_step = 0.01;
  double base_lot = NormalizeVolumeForSymbol(_Symbol, volume_step * 4.0);
  if(base_lot <= 0.0)
    base_lot = volume_step * 4.0;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  double base_price = 100.0 * point_size * 1000.0;
  if(base_price <= 0.0)
    base_price = 1000.0;
  double entry_price = base_price;
  double stop_candidate_price = base_price + 50.0 * point_size;
  double prior_stop_price = base_price + 30.0 * point_size;
  double older_loss_stop_price = base_price - 100.0 * point_size;
  double tp_anchor_price = base_price + 120.0 * point_size;
  double tp_candidate_price = base_price + 150.0 * point_size;
  double older_tp_price = base_price + 100.0 * point_size;
  double non_improving_tp_price = base_price + 160.0 * point_size;

  StochasticMarketStructure structure;
  BuildStructureTrailingTestStructure(structure,
                                      base_price,
                                      stop_candidate_price,
                                      tp_candidate_price,
                                      older_tp_price);

  SignalParams bullish_signal = BuildStructureTrailingActiveSignal(BULLISH,
                                                                   entry_price,
                                                                   base_lot,
                                                                   tp_anchor_price);
  bullish_signal.trailing_last_sl_price = prior_stop_price;
  bullish_signal.trailing_last_tp_price = older_tp_price;

  double stop_price = 0.0;
  datetime stop_time = 0;
  if(!FindNextTrailingCandidate(bullish_signal,
                                structure,
                                true,
                                stop_price,
                                stop_time))
  {
    errors += "bullish trailing stop candidate should resolve from closed bottom\n";
  }
  else
  {
    if(MathAbs(stop_price - stop_candidate_price) > (point_size * 0.1))
      errors += "bullish trailing stop should use the newest closed bottom price\n";
    if(stop_time != D'2026.03.22 12:01')
      errors += "bullish trailing stop should use the newest closed bottom time\n";
  }

  double tp_price = 0.0;
  datetime tp_time = 0;
  if(!FindNextTrailingCandidate(bullish_signal,
                                structure,
                                false,
                                tp_price,
                                tp_time))
  {
    errors += "bullish trailing tp candidate should resolve from closed peak\n";
  }
  else
  {
    if(MathAbs(tp_price - tp_candidate_price) > (point_size * 0.1))
      errors += "bullish trailing tp should ignore slot[0] and use slot[1]\n";
    if(tp_time != D'2026.03.22 12:02')
      errors += "bullish trailing tp should use the newest closed peak time\n";
  }

  bullish_signal.trailing_last_tp_price = non_improving_tp_price;
  if(FindNextTrailingCandidate(bullish_signal,
                               structure,
                               false,
                               tp_price,
                               tp_time))
  {
    errors += "bullish trailing tp should reject non-improving peaks\n";
  }

  SetStructureTrailingRuntime(TRAILING_BY_STRUCTURE_TP_BE, 25.0);

  bullish_signal = BuildStructureTrailingActiveSignal(BULLISH,
                                                      entry_price,
                                                      base_lot,
                                                      tp_anchor_price);
  bullish_signal.realized_profit = 0.0;
  RefreshSignalExposureState(bullish_signal);

  if(!CanAdvanceTrailingStopToBreakEven(bullish_signal, entry_price))
    errors += "break-even stop at entry should pass tp/be stop rule\n";
  if(CanAdvanceTrailingStopToBreakEven(bullish_signal, older_loss_stop_price))
    errors += "loss-making stop should fail tp/be stop rule\n";

  if(!CanAdvanceTrailingTpBeyondInitialTarget(bullish_signal, 0, tp_anchor_price))
    errors += "tp equal to first level initial tp should pass tp/be rule\n";
  if(CanAdvanceTrailingTpBeyondInitialTarget(bullish_signal, 0, tp_anchor_price - 20.0 * point_size))
    errors += "tp below first level initial tp should fail tp/be rule\n";

  GridOrderState level1 = bullish_signal.grid_orders[0];
  level1.level_index = 1;
  level1.initial_take_profit_price = tp_anchor_price + 40.0 * point_size;
  ArrayResize(bullish_signal.grid_orders, 2);
  bullish_signal.grid_orders[1] = level1;
  if(!CanAdvanceTrailingTpBeyondInitialTarget(bullish_signal, 1, level1.initial_take_profit_price))
    errors += "grid active level tp anchor should use the current grid level initial tp\n";
  if(CanAdvanceTrailingTpBeyondInitialTarget(bullish_signal, 1, level1.initial_take_profit_price - 20.0 * point_size))
    errors += "grid tp below current active level anchor should fail\n";

  RefreshSignalExposureState(bullish_signal);
  double expected_slice = NormalizeVolumeForSymbol(_Symbol, bullish_signal.trailing_reference_total_volume * 0.25);
  double requested_slice = ResolveSignalRequestedPartialCloseVolume(bullish_signal);
  if(MathAbs(requested_slice - expected_slice) > (volume_step + 0.0000001))
    errors += "requested trailing partial close volume should match one fixed slice of total exposure\n";

  string object_name = GridSignalObjectName(bullish_signal, "TP");
  if(StringFind(object_name, bullish_signal.grid_sequence_id) < 0)
    errors += "grid object names should include the unique signal identifier\n";

  ClearStructureTrailingRuntimeOverride();
  return (errors == "");
}

#endif
