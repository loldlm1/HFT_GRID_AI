#property script_show_inputs
#include "harness/cases/lightweight_status_layout_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_lightweight_status_layout_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
