#ifndef HFT_GRID_AI_TEST_CASE_LICENSE_SERVICE_FACADE_MQH
#define HFT_GRID_AI_TEST_CASE_LICENSE_SERVICE_FACADE_MQH

#include "../framework.mqh"
#include "../../../services/Bcrypt.mqh"
#include "../../../services/SecurityLicense.mqh"

bool RunTest_license_service_facade_test(string &errors)
{
  errors = "";

  if(LicenseServiceTimerSeconds() <= 0)
    errors += "timer seconds must be > 0\n";
  if(LicenseServiceTimerSeconds() != LICENSE_SERVICE_TIMER_SECONDS)
    errors += "timer seconds must match compile-time constant\n";

  LicenseSetRequestedAddonsCsv("addon_session_time_filter,addon_candle_structure");
  if(LicenseGetRequestedAddonsCsv() == "")
    errors += "requested addons csv should be settable\n";

#ifndef LICENSE_ENFORCEMENT_ENABLED
  if(!LicenseHasAddon("addon_session_time_filter"))
    errors += "LicenseHasAddon should return true in compile-time-off mode\n";
  if(LicenseGrantedAddonCount() != 0)
    errors += "granted addon count should default to 0 in compile-time-off mode\n";
#ifdef LICENSE_DAILY_RESULTS_ENABLED
  errors += "daily results must be forced off when enforcement is off\n";
#endif
  if(!LicenseServiceInit())
    errors += "init should pass when enforcement is compile-time off\n";
  if(!VerifyLicense())
    errors += "VerifyLicense should pass when enforcement is compile-time off\n";
  if(!VerifyLicenseType())
    errors += "VerifyLicenseType should pass when enforcement is compile-time off\n";
  if(!VerifyValidLicenseTime())
    errors += "VerifyValidLicenseTime should pass when enforcement is compile-time off\n";
  if(LicenseIsTestingMode())
    errors += "LicenseIsTestingMode should be false for script runtime context\n";
  string granted_addons[];
  LicenseCopyGrantedAddons(granted_addons);
  if(ArraySize(granted_addons) != 0)
    errors += "granted addon array should default empty in compile-time-off mode\n";
  LicenseServiceOnTimer();
  LicenseServiceOnDeinit();
#else
  // In enforcement mode, addon availability depends on online verification state.
  // Keep this facade check mode-safe and ensure count remains valid.
  if(LicenseGrantedAddonCount() < 0)
    errors += "granted addon count should never be negative\n";
#ifdef LICENSE_DAILY_RESULTS_ENABLED
  if(LicenseServiceTimerSeconds() < 1)
    errors += "timer should remain valid when online flags are enabled\n";
#endif
#endif

  return (errors == "");
}

#endif
