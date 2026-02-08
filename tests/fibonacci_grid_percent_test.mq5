#property script_show_inputs
#include "harness/cases/fibonacci_grid_percent_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_fibonacci_grid_percent_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
