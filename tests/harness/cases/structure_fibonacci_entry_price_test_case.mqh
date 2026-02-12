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
  // Use wide synthetic prices so _Digits normalization remains stable across
  // symbols with very different precision (FX, metals, indices, crypto).
  double peak = 11000.0;
  double bottom = 10000.0;
  double price_38 = GetFiboTrendBottomPrice(peak, bottom, 38.2);

  errors = "";
  EntryPrice_AssertClose("price_38", price_38, 10618.0, 0.1, errors);

  return (errors == "");
}

#endif
