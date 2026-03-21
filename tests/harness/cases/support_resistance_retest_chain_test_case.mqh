#ifndef HFT_GRID_AI_TEST_CASE_SUPPORT_RESISTANCE_RETEST_CHAIN_MQH
#define HFT_GRID_AI_TEST_CASE_SUPPORT_RESISTANCE_RETEST_CHAIN_MQH

#include "../framework.mqh"

void SupportResistanceChain_PrepareBullishStructure(StochasticMarketStructure &structure_out)
{
  structure_out = StochasticMarketStructure();
  ArrayResize(structure_out.os_market_structures, 7);

  structure_out.os_market_structures[0].is_peak = false;
  structure_out.os_market_structures[0].extremum_low = 175.0;
  structure_out.os_market_structures[1].is_peak = true;
  structure_out.os_market_structures[1].extremum_high = 230.0;
  structure_out.os_market_structures[2].is_peak = false;
  structure_out.os_market_structures[2].extremum_low = 180.0;
  structure_out.os_market_structures[3].is_peak = true;
  structure_out.os_market_structures[3].extremum_high = 205.0;
  structure_out.os_market_structures[4].is_peak = false;
  structure_out.os_market_structures[4].extremum_low = 150.0;
  structure_out.os_market_structures[5].is_peak = true;
  structure_out.os_market_structures[5].extremum_high = 200.0;
  structure_out.os_market_structures[6].is_peak = false;
  structure_out.os_market_structures[6].extremum_low = 100.0;
}

void SupportResistanceChain_PrepareBearishStructure(StochasticMarketStructure &structure_out)
{
  structure_out = StochasticMarketStructure();
  ArrayResize(structure_out.os_market_structures, 7);

  structure_out.os_market_structures[0].is_peak = true;
  structure_out.os_market_structures[0].extremum_high = 115.0;
  structure_out.os_market_structures[1].is_peak = false;
  structure_out.os_market_structures[1].extremum_low = 80.0;
  structure_out.os_market_structures[2].is_peak = true;
  structure_out.os_market_structures[2].extremum_high = 130.0;
  structure_out.os_market_structures[3].is_peak = false;
  structure_out.os_market_structures[3].extremum_low = 105.0;
  structure_out.os_market_structures[4].is_peak = true;
  structure_out.os_market_structures[4].extremum_high = 160.0;
  structure_out.os_market_structures[5].is_peak = false;
  structure_out.os_market_structures[5].extremum_low = 100.0;
  structure_out.os_market_structures[6].is_peak = true;
  structure_out.os_market_structures[6].extremum_high = 200.0;
}

bool SupportResistanceChain_AssertClose(const string label,
                                        const double actual,
                                        const double expected,
                                        const double tolerance,
                                        string &errors)
{
  if(MathAbs(actual - expected) > tolerance)
  {
    errors += StringFormat("%s expected %.2f got %.2f\n", label, expected, actual);
    return false;
  }
  return true;
}

bool RunTest_support_resistance_retest_chain_test(string &errors)
{
  errors = "";

  StochasticMarketStructure bullish_structure;
  SupportResistanceChain_PrepareBullishStructure(bullish_structure);
  double zone_tolerance = GridResolvePointSizeSafe() * 2.0;
  if(zone_tolerance <= 0.0)
    zone_tolerance = 0.1;

  SupportResistanceRetestZone zone;
  if(!ResolveSupportResistanceRetestZone(bullish_structure, 3, 10.0, zone))
  {
    errors += "bullish anchor zone failed\n";
    return false;
  }

  if(!zone.anchor_is_peak)
    errors += "bullish anchor should be peak\n";
  SupportResistanceChain_AssertClose("bullish zone low", zone.lower_price, 202.25, zone_tolerance, errors);
  SupportResistanceChain_AssertClose("bullish zone high", zone.upper_price, 207.75, zone_tolerance, errors);

  double bullish_candidate = 205.0;
  if(!PriceMatchesSupportResistanceRetestZone(zone, bullish_candidate))
    errors += "bullish candidate should match first zone\n";

  SupportResistanceRetestChainResult result;
  if(!EvaluateSupportResistanceRetestChain(bullish_structure,
                                           bullish_candidate,
                                           1,
                                           10.0,
                                           result) ||
     !result.passed)
  {
    errors += "bullish chain count 1 should pass\n";
  }

  if(!EvaluateSupportResistanceRetestChain(bullish_structure,
                                           bullish_candidate,
                                           3,
                                           10.0,
                                           result) ||
     !result.passed)
  {
    errors += "bullish chain count 3 should pass\n";
  }
  else if(result.last_match_index != 5)
  {
    errors += "bullish chain should recurse into older peak\n";
  }

  if(EvaluateSupportResistanceRetestChain(bullish_structure,
                                          bullish_candidate,
                                          4,
                                          10.0,
                                          result))
  {
    errors += "bullish chain count 4 should fail on insufficient depth\n";
  }

  if(EvaluateSupportResistanceRetestChain(bullish_structure,
                                          190.0,
                                          1,
                                          10.0,
                                          result))
  {
    errors += "bullish candidate outside first zone should fail\n";
  }

  StochasticMarketStructure bearish_structure;
  SupportResistanceChain_PrepareBearishStructure(bearish_structure);

  if(!EvaluateSupportResistanceRetestChain(bearish_structure,
                                           105.0,
                                           3,
                                           10.0,
                                           result) ||
     !result.passed)
  {
    errors += "bearish chain count 3 should pass\n";
  }

  if(ResolveSupportResistanceRetestChainCount(0) != 1)
    errors += "count sanitizer should clamp to 1\n";

  if(MathAbs(ResolveSupportResistanceRetestChainRangePercent(0.0) - 10.0) > 0.0001)
    errors += "range sanitizer should fallback to 10\n";

  return (errors == "");
}

#endif
