//+------------------------------------------------------------------+
//|      services/shared/license_guard_v1/core/addon_catalog.mqh     |
//+------------------------------------------------------------------+
#ifndef _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_ADDON_CATALOG_MQH_
#define _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_ADDON_CATALOG_MQH_

const string ADDON_KEY_SESSION_TIME_FILTER      = "addon_session_time_filter";

string AddonCatalogDisplayLabel(const string addon_key)
{
  string normalized_key = AddonCatalogNormalizeKey(addon_key);

  if(normalized_key == ADDON_KEY_SESSION_TIME_FILTER)
    return "Session Time Filter";

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

string AddonCatalogJoinKeys(const string &addons[])
{
  string keys = "";
  int total = ArraySize(addons);
  for(int i = 0; i < total; i++)
  {
    string normalized_key = AddonCatalogNormalizeKey(addons[i]);
    if(normalized_key == "")
      continue;

    if(keys != "")
      keys += ",";
    keys += normalized_key;
  }

  return keys;
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

#endif // _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_ADDON_CATALOG_MQH_
