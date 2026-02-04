#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/strategy_structure_context.mqh"

void OnStart()
{
  string errors = "";

  if(!StrategyContextEnabled(CONTEXT_SLOT_BASE))
    errors += "base context disabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_TREND))
    errors += "trend context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_MACRO))
    errors += "macro context enabled\n";
  if(StrategyContextEnabled(CONTEXT_SLOT_SESSION))
    errors += "session context enabled\n";

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
