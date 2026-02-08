#property script_show_inputs
#include "harness/cases/grid_visual_label_format_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_grid_visual_label_format_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
