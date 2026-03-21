#property script_show_inputs
#include "harness/cases/support_resistance_signal_gate_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_support_resistance_signal_gate_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
