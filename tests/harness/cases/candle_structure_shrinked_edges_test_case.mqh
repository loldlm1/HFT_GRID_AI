#ifndef HFT_GRID_AI_TEST_CASE_CANDLE_STRUCTURE_SHRINKED_EDGES_MQH
#define HFT_GRID_AI_TEST_CASE_CANDLE_STRUCTURE_SHRINKED_EDGES_MQH

#include "../framework.mqh"

bool RunTest_candle_structure_shrinked_edges_test(string &errors)
{
  errors = "";

  double highs[];
  double lows[];

  // Full equality chain across multiple depths must pass for SHRINKED.
  ArrayResize(highs, 5);
  ArrayResize(lows, 5);
  for(int i = 0; i < 5; i++)
  {
    highs[i] = 10.0;
    lows[i] = 5.0;
  }
  if(!EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 4))
    errors += "shrinked full equality depth=4 should pass\n";

  // Mixed inside/equal transitions across depth should also pass.
  highs[0] = 10.0; lows[0] = 8.0;
  highs[1] = 10.0; lows[1] = 8.0;
  highs[2] = 11.0; lows[2] = 7.0;
  highs[3] = 11.0; lows[3] = 7.0;
  highs[4] = 12.0; lows[4] = 6.0;
  if(!EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 4))
    errors += "shrinked inside/equal mixed depth=4 should pass\n";

  // Shifted window with equality must pass.
  if(!EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 1, 3))
    errors += "shrinked shifted window depth=3 should pass\n";

  // Equality belongs to SHRINKED only, not EXPANDED.
  if(EvaluateCandleStructureChain(EXPANDED_CANDLE_STRUCTURE, highs, lows, 1, 3))
    errors += "expanded should reject shrinked/equality window\n";

  // Single violating pair must fail the full chain.
  highs[2] = 9.0; // violates pair at index 1 -> 10 <= 9 is false
  if(EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 4))
    errors += "single violating high pair should fail\n";

  highs[2] = 11.0;
  lows[2] = 9.0; // violates pair at index 1 -> 8 >= 9 is false
  if(EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 4))
    errors += "single violating low pair should fail\n";

  // Multi-depth needs enough candles.
  ArrayResize(highs, 4);
  ArrayResize(lows, 4);
  highs[0] = 10.0; lows[0] = 8.0;
  highs[1] = 10.0; lows[1] = 8.0;
  highs[2] = 11.0; lows[2] = 7.0;
  highs[3] = 11.0; lows[3] = 7.0;
  if(EvaluateCandleStructureChain(SHRINKED_CANDLE_STRUCTURE, highs, lows, 0, 4))
    errors += "insufficient candles for depth=4 should fail\n";

  return (errors == "");
}

#endif
