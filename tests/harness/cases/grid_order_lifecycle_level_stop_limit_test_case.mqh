#ifndef HFT_GRID_AI_TEST_CASE_GRID_ORDER_LIFECYCLE_LEVEL_STOP_LIMIT_MQH
#define HFT_GRID_AI_TEST_CASE_GRID_ORDER_LIFECYCLE_LEVEL_STOP_LIMIT_MQH

#include "../framework.mqh"

bool RunTest_grid_order_lifecycle_level_stop_limit_test(string &errors)
{
  errors = "";

  // Breakout activation gating should not trigger early.
  if(ShouldActivateBreakoutLimitEntry(BULLISH, 99.0, 100.0))
    errors += "breakout buy should not activate below trigger\n";
  if(!ShouldActivateBreakoutLimitEntry(BULLISH, 100.0, 100.0))
    errors += "breakout buy should activate at trigger\n";
  if(!ShouldActivateBreakoutLimitEntry(BULLISH, 101.0, 100.0))
    errors += "breakout buy should activate above trigger\n";

  if(ShouldActivateBreakoutLimitEntry(BEARISH, 101.0, 100.0))
    errors += "breakout sell should not activate above trigger\n";
  if(!ShouldActivateBreakoutLimitEntry(BEARISH, 100.0, 100.0))
    errors += "breakout sell should activate at trigger\n";
  if(!ShouldActivateBreakoutLimitEntry(BEARISH, 99.0, 100.0))
    errors += "breakout sell should activate below trigger\n";

  // Non-breakout limit activation must wait for a post-creation edge.
  SignalParams non_breakout_buy;
  non_breakout_buy.signal_type = BULLISH;
  non_breakout_buy.strategy_context = CONTEXT_SLOT_BASE;
  non_breakout_buy.entry_trigger_mode = LEVELS_AS_LIMITS;
  non_breakout_buy.entry_is_limit = true;

  GridOrderState buy_limit;
  buy_limit.level_index = 0;
  buy_limit.entry_reference_price = 100.0;

  if(!ShouldArmNonBreakoutLimitActivation(non_breakout_buy, buy_limit, 101.0))
    errors += "non-breakout bullish limit should arm only above trigger\n";
  if(ShouldArmNonBreakoutLimitActivation(non_breakout_buy, buy_limit, 100.0))
    errors += "non-breakout bullish limit should not arm at trigger\n";
  if(ShouldArmNonBreakoutLimitActivation(non_breakout_buy, buy_limit, 99.0))
    errors += "non-breakout bullish limit should not arm below trigger\n";

  SignalParams non_breakout_sell;
  non_breakout_sell.signal_type = BEARISH;
  non_breakout_sell.strategy_context = CONTEXT_SLOT_BASE;
  non_breakout_sell.entry_trigger_mode = LEVELS_AS_LIMITS;
  non_breakout_sell.entry_is_limit = true;

  GridOrderState sell_limit;
  sell_limit.level_index = 0;
  sell_limit.entry_reference_price = 100.0;

  if(!ShouldArmNonBreakoutLimitActivation(non_breakout_sell, sell_limit, 99.0))
    errors += "non-breakout bearish limit should arm only below trigger\n";
  if(ShouldArmNonBreakoutLimitActivation(non_breakout_sell, sell_limit, 100.0))
    errors += "non-breakout bearish limit should not arm at trigger\n";
  if(ShouldArmNonBreakoutLimitActivation(non_breakout_sell, sell_limit, 101.0))
    errors += "non-breakout bearish limit should not arm above trigger\n";

  if(!IsLimitTriggerReached(BULLISH, 99.0, 100.0))
    errors += "bullish limit trigger should activate at or below trigger\n";
  if(!IsLimitTriggerReached(BEARISH, 101.0, 100.0))
    errors += "bearish limit trigger should activate at or above trigger\n";

  // Focused controller gate behavior for Grid_Level_Stop_Limit using reached
  // level semantics (L1, L2, ...), independent from opens_position.
  if(ShouldBlockNextLevelByStopLimit(0, 10))
    errors += "level_stop_limit=0 must never block deeper levels\n";
  if(ShouldBlockNextLevelByStopLimit(-1, 10))
    errors += "negative level stop limit must not block\n";
  if(ShouldBlockNextLevelByStopLimit(1, -1))
    errors += "invalid active level index must not block\n";
  if(ShouldBlockNextLevelByStopLimit(2, 0))
    errors += "L1 should not block when stop limit is L2\n";
  if(!ShouldBlockNextLevelByStopLimit(1, 0))
    errors += "L1 should block when stop limit is L1\n";
  if(!ShouldBlockNextLevelByStopLimit(2, 1))
    errors += "L2 should block when stop limit is L2\n";

  SymbolTradingConstraints saved_constraints = g_symbol_constraints;
  double saved_bid = g_bid;
  double saved_ask = g_ask;

  g_symbol_constraints = SymbolTradingConstraints();
  g_symbol_constraints.point_size = 0.00001;
  g_symbol_constraints.tick_size = 0.00001;

  SignalParams next_level_signal;
  next_level_signal.signal_type = BULLISH;
  next_level_signal.strategy_context = CONTEXT_SLOT_BASE;
  next_level_signal.entry_trigger_mode = LEVELS_AS_LIMITS;
  next_level_signal.entry_is_limit = true;
  next_level_signal.entry_price = 1.10000;
  next_level_signal.grid_entry_reference_price = 1.10000;

  GridOrderState degenerate_next_level;
  degenerate_next_level.level_index = 0;
  degenerate_next_level.entry_reference_price = 1.10000;
  degenerate_next_level.next_level_price = 1.10000;

  g_ask = 1.10000;
  g_bid = 1.09998;
  if(GridShouldActivateNextLevelLimit(next_level_signal,
                                      degenerate_next_level,
                                      BULLISH))
  {
    errors += "same-price next level must not trigger immediately\n";
  }

  GridOrderState distinct_next_level = degenerate_next_level;
  distinct_next_level.next_level_price = 1.09990;
  g_ask = 1.09989;
  if(!GridShouldActivateNextLevelLimit(next_level_signal,
                                       distinct_next_level,
                                       BULLISH))
  {
    errors += "distinct next level should still trigger normally\n";
  }

  g_symbol_constraints = saved_constraints;
  g_bid = saved_bid;
  g_ask = saved_ask;

  // Comments/log labels must be one-based and aligned with chart levels.
  SignalParams comment_signal;
  comment_signal.signal_type = BULLISH;
  comment_signal.strategy_timeframe = PERIOD_M1;
  comment_signal.entry_time = D'2026.02.16 08:00';

  GridOrderState comment_state;
  comment_state.level_index = 1;
  string level_comment = GridComposeLevelComment(comment_signal, comment_state);
  if(StringFind(level_comment, "_L2") < 0)
    errors += "level comment should use one-based level numbering\n";

  return (errors == "");
}

#endif
