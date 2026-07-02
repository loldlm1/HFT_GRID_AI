//+------------------------------------------------------------------+
//|                           addon_runtime_policy.mqh               |
//| Maps current EA inputs into shared license addon requests.        |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
#define _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_

#include "../shared/license_guard_v1/core/addon_catalog.mqh"

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

void AddonPolicyCollectRequestedAddonsForSettings(const SessionTimeFilterModes asia_filter_mode,
                                                  const SessionTimeFilterModes london_filter_mode,
                                                  const SessionTimeFilterModes newyork_filter_mode,
                                                  string &addons_out[])
{
  ArrayResize(addons_out, 0);

  if(SessionAddonRequestedForModes(asia_filter_mode,
                                   london_filter_mode,
                                   newyork_filter_mode))
  {
    LicenseAppendRequestedAddon(addons_out, ADDON_KEY_SESSION_TIME_FILTER);
  }
}

void CollectRequestedAddonsForCurrentInputs(string &addons_out[])
{
  AddonPolicyCollectRequestedAddonsForSettings(Session_Asia_Filter_Mode,
                                               Session_London_Filter_Mode,
                                               Session_NewYork_Filter_Mode,
                                               addons_out);
}

#endif // _SERVICES_TRADING_MANAGEMENT_ADDON_RUNTIME_POLICY_MQH_
