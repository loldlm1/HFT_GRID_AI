//+------------------------------------------------------------------+
//|                           addon_runtime_policy.mqh               |
//| Resolves requested addons from inputs and applies runtime locks. |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
#define _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_

const double GRID_ADDON_LOCKED_EXPONENTIAL_MULTIPLIER = 1.0;
const int GRID_ADDON_LOCKED_LEVEL_POSITION_START = 0;
const int GRID_ADDON_LOCKED_LEVEL_STOP_LIMIT = 1;

bool g_grid_level_stop_limit_runtime_override = false;
int g_grid_level_stop_limit_runtime_value = GRID_ADDON_LOCKED_LEVEL_STOP_LIMIT;

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

void AddonPolicyAppendUnique(string &values[], const string value)
{
  if(value == "")
    return;
  if(AddonPolicyStringArrayContains(values, value))
    return;

  int total = ArraySize(values);
  ArrayResize(values, total + 1);
  values[total] = AddonCatalogNormalizeKey(value);
}

string AddonPolicyJoinCsv(string &values[])
{
  string joined = "";
  int total = ArraySize(values);
  for(int i = 0; i < total; i++)
  {
    if(values[i] == "")
      continue;
    if(joined != "")
      joined += ",";
    joined += values[i];
  }
  return joined;
}

bool SessionAddonRequested()
{
  if(Session_Asia_Filter_Mode != SESSION_FILTER_OFF)
    return true;
  if(Session_London_Filter_Mode != SESSION_FILTER_OFF)
    return true;
  if(Session_NewYork_Filter_Mode != SESSION_FILTER_OFF)
    return true;
  return false;
}

bool CandleAddonRequested()
{
  return (Candle_Strategy_Type != OFF_CANDLE_STRUCTURE);
}

bool GridConfigAddonRequested()
{
  if(!AddonPolicyDoubleEquals(Grid_Exponential_Multiplier,
                              GRID_ADDON_LOCKED_EXPONENTIAL_MULTIPLIER))
    return true;
  if(Grid_Level_Position_Start != GRID_ADDON_LOCKED_LEVEL_POSITION_START)
    return true;
  if(Grid_Level_Stop_Limit != GRID_ADDON_LOCKED_LEVEL_STOP_LIMIT)
    return true;
  return false;
}

void AddonPolicyCollectRequestedAddons(string &addons_out[],
                                       bool &require_any_compound_family)
{
  ArrayResize(addons_out, 0);
  require_any_compound_family = false;

  if(SessionAddonRequested())
    AddonPolicyAppendUnique(addons_out, ADDON_KEY_SESSION_TIME_FILTER);

  if(CandleAddonRequested())
    AddonPolicyAppendUnique(addons_out, ADDON_KEY_CANDLE_STRUCTURE_FILTER);

  if(GridConfigAddonRequested())
    AddonPolicyAppendUnique(addons_out, ADDON_KEY_GRID_STRATEGY_CONFIG);

  if(Base_Structure_Compound_Filter != COMPOUND_MODE_OFF)
  {
    string compound_addon = "";
    if(ResolveCompoundFamilyAddonKey(Base_Structure_Compound_Filter, compound_addon))
      AddonPolicyAppendUnique(addons_out, compound_addon);
  }

  if(Base_Fresh_Structure_Time)
  {
    if(Base_Structure_Compound_Filter == COMPOUND_MODE_OFF)
      require_any_compound_family = true;
    else
    {
      string compound_addon = "";
      if(ResolveCompoundFamilyAddonKey(Base_Structure_Compound_Filter, compound_addon))
        AddonPolicyAppendUnique(addons_out, compound_addon);
    }
  }
}

string AddonPolicyResolveRequestedAddonsCsv()
{
  string requested[];
  bool require_any_compound_family = false;
  AddonPolicyCollectRequestedAddons(requested, require_any_compound_family);
  return AddonPolicyJoinCsv(requested);
}

void AddonPolicySyncRequestedAddonsForLicensePayload()
{
  string requested_csv = AddonPolicyResolveRequestedAddonsCsv();
  LicenseSetRequestedAddonsCsv(requested_csv);
}

bool AddonPolicyHasAnyCompoundFamilyEntitlement()
{
  string compound_addons[];
  AddonCatalogAllCompoundFamilies(compound_addons);

  int total = ArraySize(compound_addons);
  for(int i = 0; i < total; i++)
  {
    if(LicenseHasAddon(compound_addons[i]))
      return true;
  }
  return false;
}

void AddonPolicyResolveMissingAddons(string &requested_addons[],
                                     const bool require_any_compound_family,
                                     string &missing_addons_out[])
{
  ArrayResize(missing_addons_out, 0);

  int total = ArraySize(requested_addons);
  for(int i = 0; i < total; i++)
  {
    string addon_key = AddonCatalogNormalizeKey(requested_addons[i]);
    if(addon_key == "")
      continue;
    if(LicenseHasAddon(addon_key))
      continue;
    AddonPolicyAppendUnique(missing_addons_out, addon_key);
  }

  if(require_any_compound_family && !AddonPolicyHasAnyCompoundFamilyEntitlement())
    AddonPolicyAppendUnique(missing_addons_out, ADDON_KEY_COMPOUND_ANY_FAMILY);
}

string AddonPolicyBuildMissingAddonsLabel(const string &missing_addons[])
{
  return AddonCatalogJoinDisplayLabels(missing_addons);
}

bool AddonPolicyValidateEntitlementsForCurrentInputs(string &chart_message_out)
{
  chart_message_out = "";
  AddonPolicySyncRequestedAddonsForLicensePayload();

  if(LicenseIsTestingMode())
    return true;

  string requested_addons[];
  bool require_any_compound_family = false;
  AddonPolicyCollectRequestedAddons(requested_addons, require_any_compound_family);

  string missing_addons[];
  AddonPolicyResolveMissingAddons(requested_addons,
                                  require_any_compound_family,
                                  missing_addons);

  if(ArraySize(missing_addons) <= 0)
    return true;

  string missing_label = AddonPolicyBuildMissingAddonsLabel(missing_addons);
  chart_message_out = "HFT Grid AI disabled: missing addon(s): " + missing_label;

  PrintFormat("[AddonPolicy] Missing addon(s): %s", missing_label);
  return false;
}

void AddonPolicyApplyRuntimeLocks()
{
  g_grid_level_stop_limit_runtime_override = false;
  g_grid_level_stop_limit_runtime_value = GRID_ADDON_LOCKED_LEVEL_STOP_LIMIT;

  if(LicenseIsTestingMode())
    return;

  if(!LicenseHasAddon(ADDON_KEY_GRID_STRATEGY_CONFIG))
  {
    g_grid_level_stop_limit_runtime_override = true;
    g_grid_level_stop_limit_runtime_value = GRID_ADDON_LOCKED_LEVEL_STOP_LIMIT;
  }
}

int ResolveEffectiveGridLevelStopLimit()
{
  if(!g_grid_level_stop_limit_runtime_override)
    return Grid_Level_Stop_Limit;

  return g_grid_level_stop_limit_runtime_value;
}

#endif // _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
