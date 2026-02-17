#property script_show_inputs
#include "harness/cases/addon_runtime_policy_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_addon_runtime_policy_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
