//+------------------------------------------------------------------+
//|                                        services/SecurityLicense  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_SECURITY_LICENSE_MQH_
#define _SERVICES_SECURITY_LICENSE_MQH_

// Compile-time switches
// Keep both OFF in repository for local/manual testing.
// Production build: uncomment both lines below.
#define LICENSE_ENFORCEMENT_ENABLED
#define LICENSE_DAILY_RESULTS_ENABLED

#ifdef LICENSE_DAILY_RESULTS_ENABLED
#ifndef LICENSE_ENFORCEMENT_ENABLED
#undef LICENSE_DAILY_RESULTS_ENABLED
#endif
#endif

#ifndef LICENSE_SERVICE_TIMER_SECONDS
#define LICENSE_SERVICE_TIMER_SECONDS 60
#endif

// Shared license service guide for new EAs:
// 1) Include this file in the entrypoint.
// 2) Call LicenseServiceInit() in OnInit before trading setup.
// 3) Forward OnTimer/OnDeinit to LicenseServiceOnTimer()/LicenseServiceOnDeinit().
// 4) Use LicenseGetCachedMagicNumber() as the EA magic after successful init.

bool   g_ea_removal_requested             = false;
bool   g_ea_removal_preserve_chart_error  = false;
string g_ea_removal_chart_message         = "";

void EALifecycleRequestRemoval(const string chart_message,
                               const bool preserve_chart_error = true)
{
  g_ea_removal_requested            = true;
  g_ea_removal_preserve_chart_error = preserve_chart_error;
  g_ea_removal_chart_message        = chart_message;
}

bool EALifecycleHasPendingRemoval()
{
  return g_ea_removal_requested;
}

bool EALifecyclePreserveErrorObject()
{
  return g_ea_removal_preserve_chart_error;
}

string EALifecycleRemovalMessage()
{
  return g_ea_removal_chart_message;
}

void EALifecycleClearRemovalRequest()
{
  g_ea_removal_requested            = false;
  g_ea_removal_preserve_chart_error = false;
  g_ea_removal_chart_message        = "";
}

string LicenseServiceBuildRemovalMessage(const string fallback_message)
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  string error_code = license_last_error;
  StringToLower(error_code);

  if(error_code == "request_failed")
    return "Pandora Box EA removed: license server connection failed.";
  if(error_code == "expired" || error_code == "license_not_found")
    return "Pandora Box EA removed: license expired.";
  if(error_code == "addons_required")
    return "Pandora Box EA removed: required addon entitlement missing.";
  if(error_code == "invalid_key" || error_code == "invalid_source")
    return "Pandora Box EA removed: license validation failed.";
  if(error_code == "missing_magic_number" || error_code == "invalid_magic_number")
    return "Pandora Box EA removed: backend magic number validation failed.";
  if(error_code == "online_limit_reached")
    return LicenseFriendlyOnlineLimitMessage();
  if(error_code == "invalid_granted_addons" || error_code == "invalid_expires_at")
    return "Pandora Box EA removed: invalid license response.";

  if(license_last_http_status >= 500)
    return "Pandora Box EA removed: license server unavailable.";

  if(error_code != "")
    return "Pandora Box EA removed: license error (" + error_code + ").";
#endif

  if(fallback_message != "")
    return fallback_message;

  return "Pandora Box EA removed: license validation failed.";
}

#ifdef LICENSE_ENFORCEMENT_ENABLED
#include "Bcrypt.mqh"
#include "SecurityLicenseOnline.mqh"
#ifdef LICENSE_DAILY_RESULTS_ENABLED
#include "BrokerAccountDailyResultsOnline.mqh"
#endif
#else
bool is_testing = false;
string license_addons = "";
#endif

int LicenseServiceTimerSeconds()
{
  return LICENSE_SERVICE_TIMER_SECONDS;
}

bool LicenseServiceInit()
{
  is_testing = (MQLInfoInteger(MQL_TESTER) > 0);

#ifndef LICENSE_ENFORCEMENT_ENABLED
  Print("[License] Enforcement disabled at compile-time. Online validation/reporting skipped.");
  return true;
#else
  if(!VerifyLicense())
  {
    if(LicenseLastFailureWasStartupOnlineLimit())
    {
      Print("[License] Startup verification failed with online_limit_reached. Requester chart removed.");
      EALifecycleRequestRemoval(LicenseFriendlyOnlineLimitMessage());
      return false;
    }

    if(license_last_http_status > 0)
      PrintFormat("[License] Startup verification failed (HTTP %d, error=%s).",
                  license_last_http_status,
                  (license_last_error == "" ? "unknown" : license_last_error));
    else
      PrintFormat("[License] Startup verification failed (error=%s).",
                  (license_last_error == "" ? "request_failed" : license_last_error));
    EALifecycleRequestRemoval(LicenseServiceBuildRemovalMessage("Pandora Box EA removed: startup license verification failed."));
    return false;
  }

#ifdef LICENSE_DAILY_RESULTS_ENABLED
  DailyResults_ResetRuntime();
#endif
  return true;
#endif
}

void LicenseServiceOnTimer()
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  LicenseOnline_OnTimer();
#ifdef LICENSE_DAILY_RESULTS_ENABLED
  DailyResults_OnTimer();
#endif
#endif
}

void LicenseServiceOnDeinit()
{
#ifdef LICENSE_ENFORCEMENT_ENABLED
  LicenseOnline_OnDeinit();
#endif
}

#ifndef LICENSE_ENFORCEMENT_ENABLED
string EncryptEA(string account = "", string type = "Testing", string name = "", int days = 30)
{
  return "";
}

bool DecryptEA()
{
  return true;
}

bool VerifyOnlyValidEAs(string ea_name)
{
  return true;
}

bool VerifyLicense()
{
  return true;
}

bool VerifyLicenseType()
{
  return true;
}

bool VerifyValidLicenseTime()
{
  return true;
}

bool LicenseErrorIsHardAuth(const string)
{
  return false;
}

bool LicenseErrorIsRetryable(const string, const int)
{
  return false;
}

bool LicenseErrorIsOnlineLimitReached(const string)
{
  return false;
}

bool LicenseShouldRemoveForOnlineLimit(const bool, const int)
{
  return false;
}

bool LicenseLastFailureWasStartupOnlineLimit()
{
  return false;
}

string LicenseFriendlyOnlineLimitMessage()
{
  return "No license seat is currently available for this EA. Please close another active session or try again shortly.";
}

bool LicenseOnline_RequestLeaderReverify(const string)
{
  return false;
}

bool LicenseHasValidCachedMagicNumber()
{
  return false;
}

long LicenseGetCachedMagicNumber()
{
  return 0;
}

void LicenseSetRequestedAddonsCsv(const string addons_csv)
{
  license_addons = addons_csv;
}

string LicenseGetRequestedAddonsCsv()
{
  return license_addons;
}

bool LicenseIsTestingMode()
{
  return is_testing;
}

bool LicenseHasAddon(const string)
{
  return true;
}

bool LicenseHasAnyCompoundFamilyAddon()
{
  return true;
}

int LicenseGrantedAddonCount()
{
  return 0;
}

void LicenseCopyGrantedAddons(string &addons_out[])
{
  ArrayResize(addons_out, 0);
}

bool IsAdmin()
{
  return false;
}

bool CanBacktest()
{
  return true;
}

bool AllowDemo()
{
  return true;
}

bool AllowLive()
{
  return true;
}
#endif

#endif // _SERVICES_SECURITY_LICENSE_MQH_
