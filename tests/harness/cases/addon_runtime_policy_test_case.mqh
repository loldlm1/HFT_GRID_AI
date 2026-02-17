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
  bool require_any_compound_family = false;
  AddonPolicyCollectRequestedAddons(requested_addons, require_any_compound_family);

  if(ArraySize(requested_addons) != 0)
    errors += "default input profile should not request paid addons\n";
  if(require_any_compound_family)
    errors += "default input profile should not require any compound family\n";

  string synthetic_requested[];
  ArrayResize(synthetic_requested, 2);
  synthetic_requested[0] = ADDON_KEY_SESSION_TIME_FILTER;
  synthetic_requested[1] = ADDON_KEY_GRID_STRATEGY_CONFIG;

  string missing_addons[];
  AddonPolicyResolveMissingAddons(synthetic_requested, false, missing_addons);

#ifndef LICENSE_ENFORCEMENT_ENABLED
  if(ArraySize(missing_addons) != 0)
    errors += "compile-time-off mode should not report missing addons\n";
#endif

  AddonPolicyApplyRuntimeLocks();
#ifndef LICENSE_ENFORCEMENT_ENABLED
  if(ResolveEffectiveGridLevelStopLimit() != Grid_Level_Stop_Limit)
    errors += "compile-time-off mode should not force runtime grid level stop limit\n";
#endif

  return (errors == "");
}

#endif
