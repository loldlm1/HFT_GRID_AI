#property script_show_inputs
#include "harness/cases/session_time_filter_dst_test_case.mqh"

void OnStart()
{
  string errors = "";
  if(!RunTest_session_time_filter_dst_test(errors))
  {
    if(errors != "")
      Print("FAIL:\n", errors);
    else
      Print("FAIL");
    return;
  }

  Print("PASS");
}
