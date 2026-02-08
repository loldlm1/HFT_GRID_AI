#ifndef HFT_GRID_AI_TEST_CASE_CONTEXT_BASE_ONLY_MQH
#define HFT_GRID_AI_TEST_CASE_CONTEXT_BASE_ONLY_MQH

#include "../framework.mqh"

bool RunTest_context_base_only_test(string &errors)
{
  errors = "";

  if(!StrategyContextEnabled(CONTEXT_SLOT_BASE))
    errors += "base context disabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_TREND))
    errors += "trend context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_MACRO))
    errors += "macro context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_SESSION))
    errors += "session context enabled\n";

  return (errors == "");
}

#endif
