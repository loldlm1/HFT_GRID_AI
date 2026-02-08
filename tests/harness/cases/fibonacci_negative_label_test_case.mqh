#ifndef HFT_GRID_AI_TEST_CASE_FIBONACCI_NEGATIVE_LABEL_MQH
#define HFT_GRID_AI_TEST_CASE_FIBONACCI_NEGATIVE_LABEL_MQH

#include "../framework.mqh"

bool RunTest_fibonacci_negative_label_test(string &errors)
{
  errors = "";

  g_bid = 1.0;
  g_ask = 1.0;

  string label = FormatFibNextLabel("NEXT", -23.6, 1, 0.01);
  if(StringFind(label, "-23.6%") < 0)
    errors += "negative label missing\n";

  return (errors == "");
}

#endif
