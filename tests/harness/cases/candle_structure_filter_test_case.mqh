#ifndef HFT_GRID_AI_TEST_CASE_CANDLE_STRUCTURE_FILTER_MQH
#define HFT_GRID_AI_TEST_CASE_CANDLE_STRUCTURE_FILTER_MQH

#include "../framework.mqh"

bool RunTest_candle_structure_filter_test(string &errors)
{
  errors = "";

  double highs[];
  double lows[];

  // OFF mode must pass even without data.
  ArrayResize(highs, 0);
  ArrayResize(lows, 0);
  if(!EvaluateCandleStructureChain(OFF_CANDLE_STRUCTURE, highs, lows, 0, 1))
    errors += "off mode should always pass\n";

  // SHRINKED mode accepts inside/equal bars.
  ArrayResize(highs, 2);
  ArrayResize(lows, 2);
  highs[0] = 10.0; lows[0] = 5.0;
  highs[1] = 10.0; lows[1] = 5.0;
  if(!EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 1))
    errors += "shrinked inside/equal should pass\n";

  // EXPANDED mode is strict and must reject equal ranges.
  if(EvaluateCandleStructureChain(EXPANDED_CANDLE_STRUCTURE, highs, lows, 0, 1))
    errors += "expanded strict should reject equal range\n";

  // BULLISH mode supports chain validation on shift/depth windows.
  ArrayResize(highs, 4);
  ArrayResize(lows, 4);
  highs[0] = 120.0; lows[0] = 95.0;
  highs[1] = 115.0; lows[1] = 90.0;
  highs[2] = 110.0; lows[2] = 85.0;
  highs[3] = 105.0; lows[3] = 80.0;
  if(!EvaluateCandleStructureChain(BULLISH_CANDLE_STRUCTURE, highs, lows, 1, 2))
    errors += "bullish chain shift=1 depth=2 should pass\n";

  // BEARISH mode requires lower highs and lower lows vs past bars.
  highs[0] = 80.0; lows[0] = 40.0;
  highs[1] = 85.0; lows[1] = 45.0;
  highs[2] = 90.0; lows[2] = 50.0;
  highs[3] = 95.0; lows[3] = 55.0;
  if(!EvaluateCandleStructureChain(BEARISH_CANDLE_STRUCTURE, highs, lows, 1, 2))
    errors += "bearish chain shift=1 depth=2 should pass\n";

  // Depth <= 0 falls back to one pairwise comparison.
  highs[0] = 11.0; lows[0] = 9.0;
  highs[1] = 10.0; lows[1] = 8.0;
  if(!EvaluateCandleStructureChain(BULLISH_CANDLE_STRUCTURE, highs, lows, 0, 0))
    errors += "depth fallback to 1 should pass\n";

  if(ResolveCandleStructureDepth(0) != 1)
    errors += "depth resolver should clamp 0 to 1\n";
  if(ResolveCandleStructureShift(-2) != 0)
    errors += "shift resolver should clamp negatives to 0\n";
  if(ResolveCandleStructureRequiredBars(1, 2) != 4)
    errors += "required bars should be shift + depth + 1\n";

  // Fail-closed: insufficient bars must fail when filter is active.
  ArrayResize(highs, 3);
  ArrayResize(lows, 3);
  highs[0] = 120.0; lows[0] = 95.0;
  highs[1] = 115.0; lows[1] = 90.0;
  highs[2] = 110.0; lows[2] = 85.0;
  if(EvaluateCandleStructureChain(BULLISH_CANDLE_STRUCTURE, highs, lows, 1, 2))
    errors += "insufficient bars should fail-closed\n";

  return (errors == "");
}

#endif
