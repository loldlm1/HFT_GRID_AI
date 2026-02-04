#property script_show_inputs
#include "../services/core/enums.mqh"
#include "../services/core/base_structures.mqh"
#include "../services/utils/array_functions.mqh"
#include "../services/utils/miscellaneous.mqh"
#include "../services/indicators/stochastic_market_indicator.mqh"
#include "../services/trading_signals/signal_params_struct.mqh"
#include "../services/frontend/grid_visual_utils.mqh"

double g_bid = 1.0;
double g_ask = 1.0;

void OnStart()
{
  string errors = "";
  string entry = FormatFibEntryLabel("BULLISH ENTRY", 61.8, true, 59.32);
  if(entry != "BULLISH ENTRY 61.8% (59.32%)")
    errors += "entry label mismatch\n";

  string next = FormatFibNextLabel("BULLISH NEXT", 78.6, 1, 0.12);
  if(next != "BULLISH NEXT 78.6% L1 lot=0.12")
    errors += "next label mismatch\n";

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
