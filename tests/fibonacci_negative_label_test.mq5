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
  string label = FormatFibNextLabel("NEXT", -23.6, 1, 0.01);
  if(StringFind(label, "-23.6%") < 0)
    Print("FAIL: negative label missing");
  else
    Print("PASS");
}
