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
  if(next != "BULLISH NEXT 78.6% L2 lot=0.12")
    errors += "next label mismatch\n";

  if(ResolveGridNextDisplayLevel(0) != 2)
    errors += "next display level from L1 should be L2\n";
  if(ResolveGridNextDisplayLevel(1) != 3)
    errors += "next display level from L2 should be L3\n";

  return (errors == "");
}

#endif
