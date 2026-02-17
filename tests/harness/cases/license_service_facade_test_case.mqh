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

#ifndef LICENSE_ENFORCEMENT_ENABLED
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
  LicenseServiceOnTimer();
  LicenseServiceOnDeinit();
#else
#ifdef LICENSE_DAILY_RESULTS_ENABLED
  if(LicenseServiceTimerSeconds() < 1)
    errors += "timer should remain valid when online flags are enabled\n";
#endif
#endif

  return (errors == "");
}

#endif
