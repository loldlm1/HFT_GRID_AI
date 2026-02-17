//+------------------------------------------------------------------+
//|                                 services/core/addon_catalog.mqh  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_CORE_ADDON_CATALOG_MQH_
#define _SERVICES_CORE_ADDON_CATALOG_MQH_

#include "enums.mqh"

const string ADDON_KEY_SESSION_TIME_FILTER      = "addon_session_time_filter";
const string ADDON_KEY_GRID_STRATEGY_CONFIG     = "addon_grid_strategy_config";
const string ADDON_KEY_CANDLE_STRUCTURE_FILTER  = "addon_candle_structure";
const string ADDON_KEY_COMPOUND_TREND_RIDE      = "addon_compound_trend_ride";
const string ADDON_KEY_COMPOUND_PULLBACK_CONT   = "addon_compound_pullback_continue";
const string ADDON_KEY_COMPOUND_REVERSAL_EARLY  = "addon_compound_reversal_early";
const string ADDON_KEY_COMPOUND_BREAKOUT_READY  = "addon_compound_breakout_ready";
const string ADDON_KEY_COMPOUND_VOLATILITY_TRAP = "addon_compound_volatility_trap";

void AddonCatalogAllCompoundFamilies(string &addons_out[])
{
  ArrayResize(addons_out, 5);
  addons_out[0] = ADDON_KEY_COMPOUND_TREND_RIDE;
  addons_out[1] = ADDON_KEY_COMPOUND_PULLBACK_CONT;
  addons_out[2] = ADDON_KEY_COMPOUND_REVERSAL_EARLY;
  addons_out[3] = ADDON_KEY_COMPOUND_BREAKOUT_READY;
  addons_out[4] = ADDON_KEY_COMPOUND_VOLATILITY_TRAP;
}

string AddonCatalogNormalizeKey(const string raw_key)
{
  string normalized = raw_key;
  StringTrimLeft(normalized);
  StringTrimRight(normalized);
  StringToLower(normalized);
  return normalized;
}

bool AddonCatalogKeysEqual(const string left, const string right)
{
  return (AddonCatalogNormalizeKey(left) == AddonCatalogNormalizeKey(right));
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

#endif // _SERVICES_CORE_ADDON_CATALOG_MQH_
