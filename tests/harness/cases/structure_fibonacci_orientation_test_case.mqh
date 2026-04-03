#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ORIENTATION_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_ORIENTATION_MQH

#include "../framework.mqh"

bool Orientation_AssertClose(const string label,
                             const double actual,
                             const double expected,
                             const double tol,
                             string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.2f got %.2f\n", label, expected, actual);
    return false;
  }
  return true;
}

void Orientation_AssertMapping(const StochasticMarketStructure &s,
                               const double expected_bottom,
                               const double expected_peak,
                               string &errors)
{
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;

  if(!ResolveStructureReferenceRange(s, peak_price, bottom_price, current_is_bottom))
  {
    errors += "range failed\n";
    return;
  }

  double pct = 0.0;
  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, current_is_bottom, bottom_price, pct))
    errors += "bottom percent failed\n";
  else
    Orientation_AssertClose("bottom pct", pct, expected_bottom, 0.1, errors);

  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, current_is_bottom, peak_price, pct))
    errors += "peak percent failed\n";
  else
    Orientation_AssertClose("peak pct", pct, expected_peak, 0.1, errors);
}

void Orientation_AssertEligibility(const StochasticMarketStructure &s,
                                   const bool expect_bullish,
                                   const bool expect_bearish,
                                   string &errors)
{
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(s, peak_price, bottom_price, current_is_bottom))
  {
    errors += "eligibility range failed\n";
    return;
  }

  if(StructureDirectionMatchesOrientation(BULLISH, current_is_bottom) != expect_bullish)
    errors += "bullish orientation mismatch\n";
  if(StructureDirectionMatchesOrientation(BEARISH, current_is_bottom) != expect_bearish)
    errors += "bearish orientation mismatch\n";
}

bool RunTest_structure_fibonacci_orientation_test(string &errors)
{
  errors = "";

  StochasticMarketStructure s_bottom;
  ArrayResize(s_bottom.os_market_structures, 3);
  s_bottom.os_market_structures[0].is_peak = false;
  s_bottom.os_market_structures[0].extremum_low = 1.0900;
  s_bottom.os_market_structures[1].is_peak = true;
  s_bottom.os_market_structures[1].extremum_high = 1.2000;
  s_bottom.os_market_structures[2].is_peak = false;
  s_bottom.os_market_structures[2].extremum_low = 1.1000;
  Orientation_AssertMapping(s_bottom, 100.0, 0.0, errors);
  Orientation_AssertEligibility(s_bottom, true, false, errors);

  StochasticMarketStructure s_peak;
  ArrayResize(s_peak.os_market_structures, 3);
  s_peak.os_market_structures[0].is_peak = true;
  s_peak.os_market_structures[0].extremum_high = 1.2100;
  s_peak.os_market_structures[1].is_peak = false;
  s_peak.os_market_structures[1].extremum_low = 1.1000;
  s_peak.os_market_structures[2].is_peak = true;
  s_peak.os_market_structures[2].extremum_high = 1.2000;
  Orientation_AssertMapping(s_peak, 0.0, 100.0, errors);
  Orientation_AssertEligibility(s_peak, false, true, errors);

  return (errors == "");
}

#endif
