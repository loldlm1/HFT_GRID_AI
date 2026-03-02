#property script_show_inputs
#include "harness/cases/license_error_policy_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_license_error_policy_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
