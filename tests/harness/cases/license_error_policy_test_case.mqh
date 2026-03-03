#ifndef HFT_GRID_AI_TEST_CASE_LICENSE_ERROR_POLICY_MQH
#define HFT_GRID_AI_TEST_CASE_LICENSE_ERROR_POLICY_MQH

#include "../framework.mqh"

bool RunTest_license_error_policy_test(string &errors)
{
  errors = "";

  if(!LicenseErrorIsHardAuth("invalid_key"))
    errors += "invalid_key must be classified as hard auth\n";
  if(!LicenseErrorIsHardAuth("expired"))
    errors += "expired must be classified as hard auth\n";
  if(!LicenseErrorIsHardAuth("missing_magic_number"))
    errors += "missing_magic_number must be classified as hard auth\n";
  if(!LicenseErrorIsHardAuth("invalid_magic_number"))
    errors += "invalid_magic_number must be classified as hard auth\n";
  if(LicenseErrorIsHardAuth("online_limit_reached"))
    errors += "online_limit_reached must not be hard auth\n";

  if(!LicenseErrorIsRetryable("request_failed", 0))
    errors += "request_failed must be retryable\n";
  if(!LicenseErrorIsRetryable("online_limit_reached", 429))
    errors += "online_limit_reached must be retryable\n";
  if(!LicenseErrorIsRetryable("", 500))
    errors += "http 500 must be retryable\n";
  if(LicenseErrorIsRetryable("invalid_key", 401))
    errors += "invalid_key must not be retryable\n";
  if(LicenseErrorIsRetryable("missing_magic_number", 422))
    errors += "missing_magic_number must not be retryable\n";
  if(LicenseErrorIsRetryable("invalid_magic_number", 422))
    errors += "invalid_magic_number must not be retryable\n";

  if(!LicenseErrorIsOnlineLimitReached("online_limit_reached"))
    errors += "online_limit_reached detector failed\n";
  if(LicenseErrorIsOnlineLimitReached("rate_limited"))
    errors += "online_limit detector false positive\n";

  if(!LicenseShouldRemoveForOnlineLimit(true, 0))
    errors += "startup online_limit must remove immediately\n";
  if(LicenseShouldRemoveForOnlineLimit(false, 1))
    errors += "runtime single online_limit confirmation must not remove\n";
  if(!LicenseShouldRemoveForOnlineLimit(false, 2))
    errors += "runtime two online_limit confirmations must remove\n";

  string friendly_message = LicenseFriendlyOnlineLimitMessage();
  if(friendly_message == "")
    errors += "friendly online_limit message must not be empty\n";
  if(StringFind(friendly_message, "online_limit_reached") >= 0)
    errors += "friendly message must stay non-technical\n";

  string previous_error = license_last_error;
  license_last_error = "online_limit_reached";
  string removal_message = LicenseServiceBuildRemovalMessage("");
  if(removal_message != friendly_message)
    errors += "removal message for online_limit must use friendly copy\n";
  license_last_error = previous_error;

  if(LicenseLastFailureWasStartupOnlineLimit())
    errors += "startup online_limit failure flag should default false in unit context\n";

  return (errors == "");
}

#endif
