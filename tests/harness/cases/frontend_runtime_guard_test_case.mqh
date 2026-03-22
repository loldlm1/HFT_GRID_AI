#ifndef HFT_GRID_AI_TEST_CASE_FRONTEND_RUNTIME_GUARD_MQH
#define HFT_GRID_AI_TEST_CASE_FRONTEND_RUNTIME_GUARD_MQH

#include "../framework.mqh"

bool RunTest_frontend_runtime_guard_test(string &errors)
{
  errors = "";

  if(!FrontendChartWorkEnabledForRuntime(false, false))
    errors += "live non-visual should keep frontend enabled\n";

  if(!FrontendChartWorkEnabledForRuntime(false, true))
    errors += "live visual should keep frontend enabled\n";

  if(!FrontendChartWorkEnabledForRuntime(true, true))
    errors += "tester visual should keep frontend enabled\n";

  if(FrontendChartWorkEnabledForRuntime(true, false))
    errors += "tester non-visual should disable frontend chart work\n";

  if(!FrontendSkippingChartWorkForRuntime(true, false))
    errors += "tester non-visual skip helper should return true\n";

  return (errors == "");
}

#endif
