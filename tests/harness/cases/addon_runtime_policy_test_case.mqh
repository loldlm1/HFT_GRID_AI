#ifndef HFT_GRID_AI_TEST_CASE_ADDON_RUNTIME_POLICY_MQH
#define HFT_GRID_AI_TEST_CASE_ADDON_RUNTIME_POLICY_MQH

#include "../framework.mqh"

bool AddonPolicyAssertCompoundFamilyMap(const string label,
                                        const TrendStructureCompoundModes mode,
                                        const string expected_addon,
                                        string &errors)
{
  string actual_addon = "";
  bool resolved = ResolveCompoundFamilyAddonKey(mode, actual_addon);
  if(!resolved)
  {
    errors += label + " expected mapping resolution\n";
    return false;
  }

  if(!AddonCatalogKeysEqual(actual_addon, expected_addon))
  {
    errors += label + " mapped to wrong addon\n";
    return false;
  }

  return true;
}

void AddonPolicyAssertRequestedAddon(const string label,
                                     string &addons[],
                                     const string expected_addon,
                                     string &errors)
{
  if(!AddonPolicyStringArrayContains(addons, expected_addon))
    errors += label + " expected requested addon\n";
}

void AddonPolicyAssertRequestedAddonCount(const string label,
                                          string &addons[],
                                          const int expected_count,
                                          string &errors)
{
  if(ArraySize(addons) != expected_count)
  {
    errors += label + " expected ";
    errors += IntegerToString(expected_count);
    errors += " requested addon(s)\n";
  }
}

bool RunTest_addon_runtime_policy_test(string &errors)
{
  errors = "";

  AddonPolicyAssertCompoundFamilyMap("trend ride buy",
                                     COMPOUND_MODE_TREND_RIDE_BUY,
                                     ADDON_KEY_COMPOUND_TREND_RIDE,
                                     errors);
  AddonPolicyAssertCompoundFamilyMap("trend ride sell",
                                     COMPOUND_MODE_TREND_RIDE_SELL,
                                     ADDON_KEY_COMPOUND_TREND_RIDE,
                                     errors);
  AddonPolicyAssertCompoundFamilyMap("pullback continue buy",
                                     COMPOUND_MODE_PULLBACK_CONTINUE_BUY,
                                     ADDON_KEY_COMPOUND_PULLBACK_CONT,
                                     errors);
  AddonPolicyAssertCompoundFamilyMap("reversal early sell",
                                     COMPOUND_MODE_REVERSAL_EARLY_SELL,
                                     ADDON_KEY_COMPOUND_REVERSAL_EARLY,
                                     errors);
  AddonPolicyAssertCompoundFamilyMap("breakout ready buy",
                                     COMPOUND_MODE_BREAKOUT_READY_BUY,
                                     ADDON_KEY_COMPOUND_BREAKOUT_READY,
                                     errors);
  AddonPolicyAssertCompoundFamilyMap("volatility trap sell",
                                     COMPOUND_MODE_VOLATILITY_TRAP_SELL,
                                     ADDON_KEY_COMPOUND_VOLATILITY_TRAP,
                                     errors);

  string requested_addons[];
  CollectRequestedAddonsForCurrentInputs(requested_addons);

  if(ArraySize(requested_addons) != 0)
    errors += "default input profile should not request paid addons\n";

  string session_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_ALLOW_RUN,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               OFF_CANDLE_STRUCTURE,
                                               1.0,
                                               0,
                                               1,
                                               COMPOUND_MODE_OFF,
                                               false,
                                               session_requested);
  AddonPolicyAssertRequestedAddon("session filter",
                                  session_requested,
                                  ADDON_KEY_SESSION_TIME_FILTER,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("session filter",
                                       session_requested,
                                       1,
                                       errors);

  string candle_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               BULLISH_CANDLE_STRUCTURE,
                                               1.0,
                                               0,
                                               1,
                                               COMPOUND_MODE_OFF,
                                               false,
                                               candle_requested);
  AddonPolicyAssertRequestedAddon("candle filter",
                                  candle_requested,
                                  ADDON_KEY_CANDLE_STRUCTURE_FILTER,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("candle filter",
                                       candle_requested,
                                       1,
                                       errors);

  string grid_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               OFF_CANDLE_STRUCTURE,
                                               1.20,
                                               0,
                                               3,
                                               COMPOUND_MODE_OFF,
                                               false,
                                               grid_requested);
  AddonPolicyAssertRequestedAddon("grid config",
                                  grid_requested,
                                  ADDON_KEY_GRID_STRATEGY_CONFIG,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("grid config",
                                       grid_requested,
                                       1,
                                       errors);

  string compound_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               OFF_CANDLE_STRUCTURE,
                                               1.0,
                                               0,
                                               1,
                                               COMPOUND_MODE_TREND_RIDE_BUY,
                                               false,
                                               compound_requested);
  AddonPolicyAssertRequestedAddon("compound mode",
                                  compound_requested,
                                  ADDON_KEY_COMPOUND_TREND_RIDE,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("compound mode",
                                       compound_requested,
                                       1,
                                       errors);

  string any_compound_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               OFF_CANDLE_STRUCTURE,
                                               1.0,
                                               0,
                                               1,
                                               COMPOUND_MODE_OFF,
                                               true,
                                               any_compound_requested);
  AddonPolicyAssertRequestedAddon("compound any family",
                                  any_compound_requested,
                                  ADDON_KEY_COMPOUND_ANY_FAMILY,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("compound any family",
                                       any_compound_requested,
                                       1,
                                       errors);

  string fresh_compound_requested[];
  AddonPolicyCollectRequestedAddonsForSettings(SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               SESSION_FILTER_OFF,
                                               OFF_CANDLE_STRUCTURE,
                                               1.0,
                                               0,
                                               1,
                                               COMPOUND_MODE_BREAKOUT_READY_BUY,
                                               true,
                                               fresh_compound_requested);
  AddonPolicyAssertRequestedAddon("fresh compound concrete family",
                                  fresh_compound_requested,
                                  ADDON_KEY_COMPOUND_BREAKOUT_READY,
                                  errors);
  AddonPolicyAssertRequestedAddonCount("fresh compound concrete family",
                                       fresh_compound_requested,
                                       1,
                                       errors);

  if(AddonCatalogDisplayLabel(ADDON_KEY_SESSION_TIME_FILTER) != "Session Time Filter")
    errors += "session addon display label mismatch\n";
  if(AddonCatalogDisplayLabel(ADDON_KEY_COMPOUND_ANY_FAMILY) != "Any Compound Family Addon")
    errors += "compound-any addon display label mismatch\n";

  string display_addons[];
  ArrayResize(display_addons, 2);
  display_addons[0] = ADDON_KEY_SESSION_TIME_FILTER;
  display_addons[1] = ADDON_KEY_GRID_STRATEGY_CONFIG;
  if(AddonCatalogJoinDisplayLabels(display_addons) != "Session Time Filter, Grid Strategy Settings")
    errors += "addon display list join mismatch\n";

  return (errors == "");
}

#endif
