#property script_show_inputs
#include "harness/cases/frontend_runtime_guard_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_frontend_runtime_guard_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
