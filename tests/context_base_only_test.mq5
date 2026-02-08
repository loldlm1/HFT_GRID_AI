#property script_show_inputs
#include "harness/cases/context_base_only_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_context_base_only_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
