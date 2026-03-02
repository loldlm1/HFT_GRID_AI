//+------------------------------------------------------------------+
//|                                 services/core/addon_catalog.mqh  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_CORE_ADDON_CATALOG_MQH_
#define _SERVICES_CORE_ADDON_CATALOG_MQH_

const string ADDON_KEY_SESSION_TIME_FILTER      = "addon_session_time_filter";
const string ADDON_KEY_GRID_STRATEGY_CONFIG     = "addon_grid_strategy_config";
const string ADDON_KEY_CANDLE_STRUCTURE_FILTER  = "addon_candle_structure";
const string ADDON_KEY_COMPOUND_TREND_RIDE      = "addon_compound_trend_ride";
const string ADDON_KEY_COMPOUND_PULLBACK_CONT   = "addon_compound_pullback_continue";
const string ADDON_KEY_COMPOUND_REVERSAL_EARLY  = "addon_compound_reversal_early";
const string ADDON_KEY_COMPOUND_BREAKOUT_READY  = "addon_compound_breakout_ready";
const string ADDON_KEY_COMPOUND_VOLATILITY_TRAP = "addon_compound_volatility_trap";
const string ADDON_KEY_COMPOUND_ANY_FAMILY      = "addon_compound_family_any";

string AddonCatalogDisplayLabel(const string addon_key)
{
  string normalized_key = AddonCatalogNormalizeKey(addon_key);

  if(normalized_key == ADDON_KEY_SESSION_TIME_FILTER)
    return "Session Time Filter";
  if(normalized_key == ADDON_KEY_GRID_STRATEGY_CONFIG)
    return "Grid Strategy Settings";
  if(normalized_key == ADDON_KEY_CANDLE_STRUCTURE_FILTER)
    return "Candle Structure Filter";
  if(normalized_key == ADDON_KEY_COMPOUND_TREND_RIDE)
    return "Compound Trend Ride";
  if(normalized_key == ADDON_KEY_COMPOUND_PULLBACK_CONT)
    return "Compound Pullback Continue";
  if(normalized_key == ADDON_KEY_COMPOUND_REVERSAL_EARLY)
    return "Compound Reversal Early";
  if(normalized_key == ADDON_KEY_COMPOUND_BREAKOUT_READY)
    return "Compound Breakout Ready";
  if(normalized_key == ADDON_KEY_COMPOUND_VOLATILITY_TRAP)
    return "Compound Volatility Trap";
  if(normalized_key == ADDON_KEY_COMPOUND_ANY_FAMILY)
    return "Any Compound Family Addon";

  if(normalized_key == "")
    return "";

  return normalized_key;
}

string AddonCatalogJoinDisplayLabels(const string &addons[])
{
  string labels = "";
  int total = ArraySize(addons);
  for(int i = 0; i < total; i++)
  {
    string label = AddonCatalogDisplayLabel(addons[i]);
    if(label == "")
      continue;

    if(labels != "")
      labels += ", ";
    labels += label;
  }

  return labels;
}

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

bool ResolveCompoundFamilyAddonKey(const int mode,
                                   string &addon_key_out)
{
  addon_key_out = "";

  // Numeric mapping follows TrendStructureCompoundModes values used by strategy inputs.
  switch(mode)
  {
    case 1: // COMPOUND_MODE_TREND_RIDE_BUY
    case 2: // COMPOUND_MODE_TREND_RIDE_SELL
      addon_key_out = ADDON_KEY_COMPOUND_TREND_RIDE;
      return true;

    case 3: // COMPOUND_MODE_PULLBACK_CONTINUE_BUY
    case 4: // COMPOUND_MODE_PULLBACK_CONTINUE_SELL
      addon_key_out = ADDON_KEY_COMPOUND_PULLBACK_CONT;
      return true;

    case 5: // COMPOUND_MODE_REVERSAL_EARLY_BUY
    case 6: // COMPOUND_MODE_REVERSAL_EARLY_SELL
      addon_key_out = ADDON_KEY_COMPOUND_REVERSAL_EARLY;
      return true;

    case 7: // COMPOUND_MODE_BREAKOUT_READY_BUY
    case 8: // COMPOUND_MODE_BREAKOUT_READY_SELL
      addon_key_out = ADDON_KEY_COMPOUND_BREAKOUT_READY;
      return true;

    case 9:  // COMPOUND_MODE_VOLATILITY_TRAP_BUY
    case 10: // COMPOUND_MODE_VOLATILITY_TRAP_SELL
      addon_key_out = ADDON_KEY_COMPOUND_VOLATILITY_TRAP;
      return true;

    default:
      return false;
  }
}

#endif // _SERVICES_CORE_ADDON_CATALOG_MQH_
