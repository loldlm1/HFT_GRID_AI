#property script_show_inputs
#include "harness/cases/candle_structure_filter_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_candle_structure_filter_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
