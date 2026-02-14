#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_TOUCH_POLICY_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_TOUCH_POLICY_MQH

#include "../framework.mqh"

void TouchPolicy_PrepareBottomStructure(const double peak_price,
                                        const double bottom_price,
                                        const double current_bottom_percent,
                                        const datetime first_time,
                                        const datetime second_time,
                                        StochasticMarketStructure &structure_out)
{
  structure_out = StochasticMarketStructure();
  structure_out.first_structure_time = first_time;
  structure_out.second_structure_time = second_time;

  double current_bottom_price = GetFiboTrendBottomPrice(peak_price,
                                                        bottom_price,
                                                        current_bottom_percent);

  ArrayResize(structure_out.os_market_structures, 3);
  structure_out.os_market_structures[0].is_peak = false;
  structure_out.os_market_structures[0].extremum_low = current_bottom_price + 10.0;
  structure_out.os_market_structures[1].is_peak = true;
  structure_out.os_market_structures[1].extremum_high = peak_price;
  structure_out.os_market_structures[2].is_peak = false;
  structure_out.os_market_structures[2].extremum_low = current_bottom_price;
}

bool TouchPolicy_ResolveEntry(const StochasticMarketStructure &structure,
                              const double close_percent,
                              const double low_percent,
                              const double high_percent,
                              const SignalTypes direction,
                              const StructureTriggerEntryModes trigger_mode,
                              const datetime structure_time,
                              bool &in_zone,
                              bool &entry_is_limit,
                              string &errors)
{
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(structure, peak_price, bottom_price, current_is_bottom))
  {
    errors += "resolve reference range\n";
    return false;
  }

  double close_price = GetFiboTrendBottomPrice(peak_price, bottom_price, close_percent);
  double low_price = GetFiboTrendBottomPrice(peak_price, bottom_price, low_percent);
  double high_price = GetFiboTrendBottomPrice(peak_price, bottom_price, high_percent);

  double entry_price = 0.0;
  bool ok = ResolveStructureFibonacciEntryForPrices(structure,
                                                    close_price,
                                                    low_price,
                                                    high_price,
                                                    direction,
                                                    trigger_mode,
                                                    entry_price,
                                                    in_zone,
                                                    entry_is_limit,
                                                    CONTEXT_SLOT_BASE,
                                                    structure_time);
  if(!ok)
  {
    errors += "resolve entry failed\n";
    return false;
  }

  return true;
}

bool RunTest_structure_touch_policy_test(string &errors)
{
  errors = "";
  ClearStructureTouchPolicyRuntimeOverride();
  ClearStructureTouchPolicyState();

  LoadStructureFibonacciLevels("0.0,61.8,100.0",
                               "0.0,61.8,100.0");

  datetime time_a = D'2026.02.14 10:00';
  datetime time_b = D'2026.02.14 11:00';
  datetime time_c = D'2026.02.14 12:00';

  double peak_price = 11000.0;
  double bottom_price = 10000.0;

  StochasticMarketStructure touched_structure;
  TouchPolicy_PrepareBottomStructure(peak_price,
                                     bottom_price,
                                     80.0,
                                     D'2026.02.14 09:00',
                                     time_a,
                                     touched_structure);

  bool in_zone = false;
  bool entry_is_limit = false;

  // ALLOW_RETEST keeps legacy behavior.
  SetStructureTouchPolicyRuntime(ALLOW_RETEST);
  ClearStructureTouchPolicyState();
  if(!TouchPolicy_ResolveEntry(touched_structure,
                               30.0,
                               80.0,
                               30.0,
                               BULLISH,
                               LEVELS_AS_LIMITS,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(!in_zone || !entry_is_limit)
    errors += "allow retest should keep limit trigger\n";

  // FIRST_TOUCH_ONLY blocks limit placement once the target threshold was reached.
  SetStructureTouchPolicyRuntime(FIRST_TOUCH_ONLY);
  ClearStructureTouchPolicyState();
  if(!TouchPolicy_ResolveEntry(touched_structure,
                               30.0,
                               80.0,
                               30.0,
                               BULLISH,
                               LEVELS_AS_LIMITS,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(in_zone)
    errors += "first touch only should block touched limit\n";

  // FIRST_TOUCH_ONLY allows pre-touch pending setup.
  StochasticMarketStructure untouched_structure;
  TouchPolicy_PrepareBottomStructure(peak_price,
                                     bottom_price,
                                     40.0,
                                     D'2026.02.14 09:30',
                                     time_a,
                                     untouched_structure);
  ClearStructureTouchPolicyState();
  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               30.0,
                               40.0,
                               30.0,
                               BULLISH,
                               LEVELS_AS_LIMITS,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(!in_zone || !entry_is_limit)
    errors += "first touch only should allow untouched limit\n";

  // Zone mode: first touch with close confirmation passes, retest blocks.
  ClearStructureTouchPolicyState();
  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BULLISH,
                               LEVEL_AS_ZONE,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(!in_zone || entry_is_limit)
    errors += "first zone touch should allow market entry\n";

  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BULLISH,
                               LEVEL_AS_ZONE,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(in_zone)
    errors += "zone retest should be blocked\n";

  // BOTH_DIRECTION: bearish lane is independent from bullish lane.
  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BEARISH,
                               LEVEL_AS_ZONE,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(!in_zone)
    errors += "bearish first touch should remain independent\n";

  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BEARISH,
                               LEVEL_AS_ZONE,
                               time_a,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(in_zone)
    errors += "bearish zone retest should be blocked independently\n";

  // Zone requires close confirmation on touch candle; otherwise it is consumed.
  ClearStructureTouchPolicyState();
  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               50.0,
                               70.0,
                               50.0,
                               BULLISH,
                               LEVEL_AS_ZONE,
                               time_b,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(in_zone)
    errors += "zone should not open when close is outside touched band\n";

  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BULLISH,
                               LEVEL_AS_ZONE,
                               time_b,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(in_zone)
    errors += "zone should remain blocked after non-confirmed first touch\n";

  // New structure snapshot resets touch memory.
  if(!TouchPolicy_ResolveEntry(untouched_structure,
                               70.0,
                               70.0,
                               70.0,
                               BULLISH,
                               LEVEL_AS_ZONE,
                               time_c,
                               in_zone,
                               entry_is_limit,
                               errors))
    return false;
  if(!in_zone)
    errors += "new structure timestamp should reset touch policy state\n";

  ClearStructureTouchPolicyRuntimeOverride();
  ClearStructureTouchPolicyState();
  return (errors == "");
}

#endif
