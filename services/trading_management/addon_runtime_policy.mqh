//+------------------------------------------------------------------+
//|                           addon_runtime_policy.mqh               |
//| Maps EA inputs into shared license addon requests.               |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
#define _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_

#include "../shared/license_guard_v1/core/addon_catalog.mqh"

const double GRID_ADDON_DEFAULT_EXPONENTIAL_MULTIPLIER = 1.0;
const int GRID_ADDON_DEFAULT_LEVEL_POSITION_START = 0;
const int GRID_ADDON_DEFAULT_LEVEL_STOP_LIMIT = 1;

bool AddonPolicyDoubleEquals(const double left, const double right)
{
  return (MathAbs(left - right) <= 0.0000001);
}

bool AddonPolicyStringArrayContains(string &values[], const string needle)
{
  string normalized_needle = AddonCatalogNormalizeKey(needle);
  int total = ArraySize(values);
  for(int i = 0; i < total; i++)
  {
    if(AddonCatalogNormalizeKey(values[i]) == normalized_needle)
      return true;
  }
  return false;
}

bool SessionAddonRequestedForModes(const SessionTimeFilterModes asia_filter_mode,
                                   const SessionTimeFilterModes london_filter_mode,
                                   const SessionTimeFilterModes newyork_filter_mode)
{
  if(asia_filter_mode != SESSION_FILTER_OFF)
    return true;
  if(london_filter_mode != SESSION_FILTER_OFF)
    return true;
  if(newyork_filter_mode != SESSION_FILTER_OFF)
    return true;
  return false;
}

bool CandleAddonRequestedForMode(const CandleStrategyTypes candle_strategy_type)
{
  return (candle_strategy_type != OFF_CANDLE_STRUCTURE);
}

bool SupportResistanceRetestChainAddonRequested(const bool enabled)
{
  return enabled;
}

bool StructureTrailingAddonRequested(const TrailingStructureModes trailing_mode)
{
  return (ResolveTrailingStructureModeValue(trailing_mode) != TRAILING_OFF);
}

bool GridConfigAddonRequestedForValues(const double grid_exponential_multiplier,
                                       const int grid_level_position_start,
                                       const int grid_level_stop_limit)
{
  if(!AddonPolicyDoubleEquals(grid_exponential_multiplier,
                              GRID_ADDON_DEFAULT_EXPONENTIAL_MULTIPLIER))
    return true;
  if(grid_level_position_start != GRID_ADDON_DEFAULT_LEVEL_POSITION_START)
    return true;
  if(grid_level_stop_limit != GRID_ADDON_DEFAULT_LEVEL_STOP_LIMIT)
    return true;
  return false;
}

bool ResolveCompoundFamilyAddonKey(const TrendStructureCompoundModes mode,
                                   string &addon_key_out)
{
  addon_key_out = "";

  switch(mode)
  {
    case COMPOUND_MODE_TREND_RIDE_BUY:
    case COMPOUND_MODE_TREND_RIDE_SELL:
      addon_key_out = ADDON_KEY_COMPOUND_TREND_RIDE;
      return true;

    case COMPOUND_MODE_PULLBACK_CONTINUE_BUY:
    case COMPOUND_MODE_PULLBACK_CONTINUE_SELL:
      addon_key_out = ADDON_KEY_COMPOUND_PULLBACK_CONT;
      return true;

    case COMPOUND_MODE_REVERSAL_EARLY_BUY:
    case COMPOUND_MODE_REVERSAL_EARLY_SELL:
      addon_key_out = ADDON_KEY_COMPOUND_REVERSAL_EARLY;
      return true;

    case COMPOUND_MODE_BREAKOUT_READY_BUY:
    case COMPOUND_MODE_BREAKOUT_READY_SELL:
      addon_key_out = ADDON_KEY_COMPOUND_BREAKOUT_READY;
      return true;

    case COMPOUND_MODE_VOLATILITY_TRAP_BUY:
    case COMPOUND_MODE_VOLATILITY_TRAP_SELL:
      addon_key_out = ADDON_KEY_COMPOUND_VOLATILITY_TRAP;
      return true;

    default:
      return false;
  }
}

void AddonPolicyCollectRequestedAddonsForSettings(const SessionTimeFilterModes asia_filter_mode,
                                                  const SessionTimeFilterModes london_filter_mode,
                                                  const SessionTimeFilterModes newyork_filter_mode,
                                                  const CandleStrategyTypes candle_strategy_type,
                                                  const bool support_resistance_retest_chain_enabled,
                                                  const TrailingStructureModes trailing_mode,
                                                  const double grid_exponential_multiplier,
                                                  const int grid_level_position_start,
                                                  const int grid_level_stop_limit,
                                                  const TrendStructureCompoundModes compound_mode,
                                                  const bool fresh_structure_time,
                                                  string &addons_out[])
{
  ArrayResize(addons_out, 0);

  if(SessionAddonRequestedForModes(asia_filter_mode,
                                   london_filter_mode,
                                   newyork_filter_mode))
  {
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_SESSION_TIME_FILTER);
  }

  if(CandleAddonRequestedForMode(candle_strategy_type))
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_CANDLE_STRUCTURE_FILTER);

  if(SupportResistanceRetestChainAddonRequested(support_resistance_retest_chain_enabled))
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_SUPPORT_RESISTANCE_RETEST_CHAIN);

  if(StructureTrailingAddonRequested(trailing_mode))
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_STRUCTURE_TRAILING);

  if(GridConfigAddonRequestedForValues(grid_exponential_multiplier,
                                       grid_level_position_start,
                                       grid_level_stop_limit))
  {
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_GRID_STRATEGY_CONFIG);
  }

  if(compound_mode != COMPOUND_MODE_OFF)
  {
    string compound_addon = "";
    if(ResolveCompoundFamilyAddonKey(compound_mode, compound_addon))
      LicenseAppendRequestedAddon(addons_out, compound_addon);
  }

  if(fresh_structure_time && compound_mode == COMPOUND_MODE_OFF)
  {
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_COMPOUND_ANY_FAMILY);
  }
}

void CollectRequestedAddonsForCurrentInputs(string &addons_out[])
{
  AddonPolicyCollectRequestedAddonsForSettings(Session_Asia_Filter_Mode,
                                               Session_London_Filter_Mode,
                                               Session_NewYork_Filter_Mode,
                                               Candle_Strategy_Type,
                                               Support_Resistance_Retest_Chain_Enabled,
                                               Trailing_Structure_Mode,
                                               Grid_Exponential_Multiplier,
                                               Grid_Level_Position_Start,
                                               Grid_Level_Stop_Limit,
                                               Base_Structure_Compound_Filter,
                                               Base_Fresh_Structure_Time,
                                               addons_out);
}

#endif // _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
