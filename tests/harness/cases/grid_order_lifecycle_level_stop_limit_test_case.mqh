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

  // Focused controller gate behavior for Level_Stop_Limit.
  if(ShouldBlockNextLevelByStopLimit(0, true, 999))
    errors += "level_stop_limit=0 must never block deeper levels\n";
  if(ShouldBlockNextLevelByStopLimit(-1, true, 999))
    errors += "negative level stop limit must not block\n";
  if(ShouldBlockNextLevelByStopLimit(2, false, 99))
    errors += "non-position levels must not be blocked by stop limit\n";
  if(ShouldBlockNextLevelByStopLimit(2, true, 1))
    errors += "position count below limit should not block\n";
  if(!ShouldBlockNextLevelByStopLimit(2, true, 2))
    errors += "position count at limit should block\n";

  return (errors == "");
}

#endif
