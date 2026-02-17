#ifndef HFT_GRID_AI_TEST_CASE_GRID_TARGET_PROFIT_MATH_MQH
#define HFT_GRID_AI_TEST_CASE_GRID_TARGET_PROFIT_MATH_MQH

#include "../framework.mqh"

bool GridTargetProfit_AssertClose(const string label,
                                  const double actual,
                                  const double expected,
                                  const double tolerance,
                                  string &errors)
{
  if(MathAbs(actual - expected) <= tolerance)
    return true;

  errors += StringFormat("%s expected %.6f got %.6f\n",
                         label,
                         expected,
                         actual);
  return false;
}

bool GridTargetProfit_AssertTrue(const string label,
                                 const bool condition,
                                 string &errors)
{
  if(condition)
    return true;

  errors += label + "\n";
  return false;
}

bool GridTargetProfit_TestTargetAmountScaling(string &errors)
{
  double currency_100 = ResolveTargetProfitAmountFromInputs(GRID_LOT_CURRENCY_BASED,
                                                             5.0,
                                                             100.0,
                                                             1000.0,
                                                             500.0);
  GridTargetProfit_AssertClose("currency_target_100",
                               currency_100,
                               5.0,
                               1e-6,
                               errors);

  double currency_130 = ResolveTargetProfitAmountFromInputs(GRID_LOT_CURRENCY_BASED,
                                                             5.0,
                                                             130.0,
                                                             1000.0,
                                                             500.0);
  GridTargetProfit_AssertClose("currency_target_130",
                               currency_130,
                               6.5,
                               1e-6,
                               errors);

  double currency_300 = ResolveTargetProfitAmountFromInputs(GRID_LOT_CURRENCY_BASED,
                                                             5.0,
                                                             300.0,
                                                             1000.0,
                                                             500.0);
  GridTargetProfit_AssertClose("currency_target_300",
                               currency_300,
                               15.0,
                               1e-6,
                               errors);

  double percent_with_balance = ResolveTargetProfitAmountFromInputs(GRID_LOT_PERCENTAGE_BASED,
                                                                     2.0,
                                                                     150.0,
                                                                     1000.0,
                                                                     500.0);
  GridTargetProfit_AssertClose("percent_target_balance",
                               percent_with_balance,
                               30.0,
                               1e-6,
                               errors);

  double percent_with_fallback = ResolveTargetProfitAmountFromInputs(GRID_LOT_PERCENTAGE_BASED,
                                                                      2.0,
                                                                      150.0,
                                                                      0.0,
                                                                      500.0);
  GridTargetProfit_AssertClose("percent_target_account_size_fallback",
                               percent_with_fallback,
                               15.0,
                               1e-6,
                               errors);

  double zero_tp_fallback = ResolveTargetProfitAmountFromInputs(GRID_LOT_CURRENCY_BASED,
                                                                 5.0,
                                                                 0.0,
                                                                 1000.0,
                                                                 500.0);
  GridTargetProfit_AssertClose("tp_percent_zero_defaults_to_100",
                               zero_tp_fallback,
                               5.0,
                               1e-6,
                               errors);

  return (errors == "");
}

bool GridTargetProfit_TestMultiplierScope(string &errors)
{
  GridTargetProfit_AssertTrue("multiplier should apply to GRID_LOT_SIZE",
                              GridShouldApplyLotMultiplier(GRID_LOT_SIZE),
                              errors);
  GridTargetProfit_AssertTrue("multiplier should be disabled for GRID_LOT_CURRENCY_BASED",
                              !GridShouldApplyLotMultiplier(GRID_LOT_CURRENCY_BASED),
                              errors);
  GridTargetProfit_AssertTrue("multiplier should be disabled for GRID_LOT_PERCENTAGE_BASED",
                              !GridShouldApplyLotMultiplier(GRID_LOT_PERCENTAGE_BASED),
                              errors);
  return (errors == "");
}

bool GridTargetProfit_TestRequiredLotSolver(string &errors)
{
  double solved_required_lot = 0.0;
  if(!ResolveRequiredLotForTarget(6.5, -8.0, 4.0, solved_required_lot))
  {
    errors += "algebra lot solver failed\n";
    return false;
  }
  GridTargetProfit_AssertClose("algebra required lot",
                               solved_required_lot,
                               3.625,
                               1e-6,
                               errors);

  double algebra_total = -8.0 + 4.0 * solved_required_lot;
  GridTargetProfit_AssertClose("algebra basket target",
                               algebra_total,
                               6.5,
                               1e-6,
                               errors);

  if(!ResolveRequiredLotForTarget(7.0, 10.0, 2.0, solved_required_lot))
  {
    errors += "algebra solver should support non-positive required lot\n";
    return false;
  }
  GridTargetProfit_AssertTrue("algebra non-positive required lot expected",
                              solved_required_lot <= 0.0,
                              errors);

  double symbol_point_value = ResolveSymbolPointValuePerLot(_Symbol);
  if(symbol_point_value <= 0.0)
    return (errors == "");

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
  {
    errors += "point_size unavailable\n";
    return false;
  }

  double anchor_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  if(anchor_price <= 0.0)
    anchor_price = 100.0;

  SignalParams bullish_signal;
  bullish_signal.signal_type = BULLISH;
  ArrayResize(bullish_signal.grid_orders, 3);

  bullish_signal.grid_orders[0].level_index = 0;
  bullish_signal.grid_orders[0].status = GRID_ORDER_ACTIVE;
  bullish_signal.grid_orders[0].opens_position = true;
  bullish_signal.grid_orders[0].entry_price = anchor_price;
  bullish_signal.grid_orders[0].lot_size = 0.30;

  bullish_signal.grid_orders[1].level_index = 1;
  bullish_signal.grid_orders[1].status = GRID_ORDER_ACTIVE;
  bullish_signal.grid_orders[1].opens_position = true;
  bullish_signal.grid_orders[1].entry_price = anchor_price - 60.0 * point_size;
  bullish_signal.grid_orders[1].lot_size = 0.20;

  bullish_signal.grid_orders[2].level_index = 2;
  bullish_signal.grid_orders[2].status = GRID_ORDER_STOP_TRAILING_ACTIVE;
  bullish_signal.grid_orders[2].opens_position = true;
  bullish_signal.grid_orders[2].entry_reference_price = anchor_price - 120.0 * point_size;

  double bullish_tp = anchor_price - 40.0 * point_size;
  double bullish_target = 6.5;
  double bullish_required_lot = 0.0;

  if(!ResolveRequiredLotForTargetAtPrice(bullish_signal,
                                         2,
                                         bullish_signal.grid_orders[2].entry_reference_price,
                                         bullish_tp,
                                         bullish_target,
                                         bullish_required_lot))
  {
    errors += "bullish required lot solver failed\n";
    return false;
  }

  GridTargetProfit_AssertTrue("bullish required lot should be positive",
                              bullish_required_lot > 0.0,
                              errors);

  double bullish_existing = ResolveProjectedBasketProfitAtPrice(bullish_signal,
                                                                bullish_tp,
                                                                2);
  double bullish_per_lot = ResolveProjectedGridOrderProfitAtPrice(BULLISH,
                                                                   bullish_signal.grid_orders[2].entry_reference_price,
                                                                   bullish_tp,
                                                                   1.0);
  double bullish_total = bullish_existing + bullish_per_lot * bullish_required_lot;
  GridTargetProfit_AssertClose("bullish basket target",
                               bullish_total,
                               bullish_target,
                               1e-4,
                               errors);

  SignalParams bearish_signal;
  bearish_signal.signal_type = BEARISH;
  ArrayResize(bearish_signal.grid_orders, 3);

  bearish_signal.grid_orders[0].level_index = 0;
  bearish_signal.grid_orders[0].status = GRID_ORDER_ACTIVE;
  bearish_signal.grid_orders[0].opens_position = true;
  bearish_signal.grid_orders[0].entry_price = anchor_price;
  bearish_signal.grid_orders[0].lot_size = 0.25;

  bearish_signal.grid_orders[1].level_index = 1;
  bearish_signal.grid_orders[1].status = GRID_ORDER_ACTIVE;
  bearish_signal.grid_orders[1].opens_position = true;
  bearish_signal.grid_orders[1].entry_price = anchor_price + 60.0 * point_size;
  bearish_signal.grid_orders[1].lot_size = 0.20;

  bearish_signal.grid_orders[2].level_index = 2;
  bearish_signal.grid_orders[2].status = GRID_ORDER_STOP_TRAILING_ACTIVE;
  bearish_signal.grid_orders[2].opens_position = true;
  bearish_signal.grid_orders[2].entry_reference_price = anchor_price + 120.0 * point_size;

  double bearish_tp = anchor_price + 40.0 * point_size;
  double bearish_target = 7.0;
  double bearish_required_lot = 0.0;

  if(!ResolveRequiredLotForTargetAtPrice(bearish_signal,
                                         2,
                                         bearish_signal.grid_orders[2].entry_reference_price,
                                         bearish_tp,
                                         bearish_target,
                                         bearish_required_lot))
  {
    errors += "bearish required lot solver failed\n";
    return false;
  }

  GridTargetProfit_AssertTrue("bearish required lot should be positive",
                              bearish_required_lot > 0.0,
                              errors);

  double bearish_existing = ResolveProjectedBasketProfitAtPrice(bearish_signal,
                                                                bearish_tp,
                                                                2);
  double bearish_per_lot = ResolveProjectedGridOrderProfitAtPrice(BEARISH,
                                                                   bearish_signal.grid_orders[2].entry_reference_price,
                                                                   bearish_tp,
                                                                   1.0);
  double bearish_total = bearish_existing + bearish_per_lot * bearish_required_lot;
  GridTargetProfit_AssertClose("bearish basket target",
                               bearish_total,
                               bearish_target,
                               1e-4,
                               errors);

  return (errors == "");
}

bool GridTargetProfit_TestInfeasibleLotDetection(string &errors)
{
  double normalized = 0.0;
  bool infeasible = false;

  if(!NormalizeTargetModeRequiredLot(_Symbol, 0.0, normalized, infeasible))
    errors += "zero lot normalization should succeed\n";
  if(normalized != 0.0)
    errors += "zero lot normalization should return 0\n";
  if(infeasible)
    errors += "zero lot normalization should not be infeasible\n";

  double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  if(max_vol > 0.0)
  {
    normalized = 0.0;
    infeasible = false;
    if(NormalizeTargetModeRequiredLot(_Symbol,
                                      max_vol * 1.5,
                                      normalized,
                                      infeasible))
    {
      errors += "required lot above max volume should fail\n";
    }
    if(!infeasible)
      errors += "required lot above max volume should mark infeasible\n";
  }

  return (errors == "");
}

bool RunTest_grid_target_profit_math_test(string &errors)
{
  errors = "";

  GridTargetProfit_TestTargetAmountScaling(errors);
  GridTargetProfit_TestMultiplierScope(errors);
  GridTargetProfit_TestRequiredLotSolver(errors);
  GridTargetProfit_TestInfeasibleLotDetection(errors);

  return (errors == "");
}

#endif
