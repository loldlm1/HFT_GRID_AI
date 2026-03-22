#property script_show_inputs
#include "harness/cases/structure_trailing_logic_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_structure_trailing_logic_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
