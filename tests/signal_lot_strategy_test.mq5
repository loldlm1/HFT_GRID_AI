#property script_show_inputs
#include "harness/cases/signal_lot_strategy_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_signal_lot_strategy_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
