//+------------------------------------------------------------------+
//|                                        services/SecurityLicense  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_SECURITY_LICENSE_MQH_
#define _SERVICES_SECURITY_LICENSE_MQH_

// Compile-time switches
// Keep both OFF in repository for local/manual testing.
// Production build: uncomment both lines below.
//#define LICENSE_ENFORCEMENT_ENABLED
//#define LICENSE_DAILY_RESULTS_ENABLED

#ifdef LICENSE_DAILY_RESULTS_ENABLED
#ifndef LICENSE_ENFORCEMENT_ENABLED
#undef LICENSE_DAILY_RESULTS_ENABLED
#endif
#endif

#ifndef LICENSE_SERVICE_TIMER_SECONDS
#define LICENSE_SERVICE_TIMER_SECONDS 60
#endif

#ifdef LICENSE_ENFORCEMENT_ENABLED
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
    if(license_last_http_status > 0)
      PrintFormat("[License] Startup verification failed (HTTP %d, error=%s).",
                  license_last_http_status,
                  (license_last_error == "" ? "unknown" : license_last_error));
    else
      PrintFormat("[License] Startup verification failed (error=%s).",
                  (license_last_error == "" ? "request_failed" : license_last_error));
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
