#property script_show_inputs
#include "harness/cases/structure_entry_trigger_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_structure_entry_trigger_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
