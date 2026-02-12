#property script_show_inputs
#include "harness/cases/structure_filter_mode_behavior_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_structure_filter_mode_behavior_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
