#property script_show_inputs
#include "harness/cases/grid_target_profit_math_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_grid_target_profit_math_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
