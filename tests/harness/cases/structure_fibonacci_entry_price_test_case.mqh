#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ENTRY_PRICE_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ENTRY_PRICE_MQH

#include "../framework.mqh"

bool EntryPrice_AssertClose(const string label,
                            const double actual,
                            const double expected,
                            const double tol,
                            string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.5f got %.5f\n", label, expected, actual);
    return false;
  }
  return true;
}

bool RunTest_structure_fibonacci_entry_price_test(string &errors)
{
  double peak = 1.2000;
  double bottom = 1.1000;
  double price_38 = GetFiboTrendBottomPrice(peak, bottom, 38.2);

  errors = "";
  EntryPrice_AssertClose("price_38", price_38, 1.16180, 0.0002, errors);

  return (errors == "");
}

#endif
