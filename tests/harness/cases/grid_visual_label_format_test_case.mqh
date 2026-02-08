#ifndef HFT_GRID_AI_TEST_CASE_GRID_VISUAL_LABEL_FORMAT_MQH
#define HFT_GRID_AI_TEST_CASE_GRID_VISUAL_LABEL_FORMAT_MQH

#include "../framework.mqh"

bool RunTest_grid_visual_label_format_test(string &errors)
{
  errors = "";

  g_bid = 1.0;
  g_ask = 1.0;

  string entry = FormatFibEntryLabel("BULLISH ENTRY", 61.8, true, 59.32);
  if(entry != "BULLISH ENTRY 61.8% (59.32%)")
    errors += "entry label mismatch\n";

  string next = FormatFibNextLabel("BULLISH NEXT", 78.6, 1, 0.12);
  if(next != "BULLISH NEXT 78.6% L1 lot=0.12")
    errors += "next label mismatch\n";

  return (errors == "");
}

#endif
