#ifndef HFT_GRID_AI_TEST_CASE_SUPPORT_RESISTANCE_SIGNAL_GATE_MQH
#define HFT_GRID_AI_TEST_CASE_SUPPORT_RESISTANCE_SIGNAL_GATE_MQH

#include "../framework.mqh"
#include "support_resistance_retest_chain_test_case.mqh"

bool SupportResistanceGate_ResolveEntry(const StochasticMarketStructure &structure,
                                        const double close_price,
                                        const SignalTypes direction,
                                        const StructureTriggerEntryModes trigger_mode,
                                        double &entry_price_out,
                                        bool &in_zone_out,
                                        bool &entry_is_limit_out,
                                        string &errors)
{
  bool ok = ResolveStructureFibonacciEntryForPrices(structure,
                                                    close_price,
                                                    close_price,
                                                    close_price,
                                                    direction,
                                                    trigger_mode,
                                                    entry_price_out,
                                                    in_zone_out,
                                                    entry_is_limit_out,
                                                    CONTEXT_SLOT_BASE,
                                                    0);
  if(!ok)
  {
    errors += "resolve structure entry failed\n";
    return false;
  }

  return true;
}

bool RunTest_support_resistance_signal_gate_test(string &errors)
{
  errors = "";
  ClearSupportResistanceRetestChainRuntimeOverride();

  LoadStructureFibonacciLevels("0.0,50.0,100.0",
                               "0.0,50.0,100.0");

  StochasticMarketStructure bullish_structure;
  SupportResistanceChain_PrepareBullishStructure(bullish_structure);

  StrategyContextIndicators snapshot;
  snapshot.context = CONTEXT_SLOT_BASE;
  snapshot.timeframe = PERIOD_M1;
  snapshot.structure_valid = true;
  snapshot.structure_data = bullish_structure;

  SetSupportResistanceRetestChainRuntime(true, 3, 10.0);
  StrategyStructureLayerContext enabled_ctx = BuildBaseStructureLayerContext();

  double entry_price = 0.0;
  bool in_zone = false;
  bool entry_is_limit = false;

  if(!SupportResistanceGate_ResolveEntry(bullish_structure,
                                         205.0,
                                         BULLISH,
                                         LEVELS_AS_LIMITS,
                                         entry_price,
                                         in_zone,
                                         entry_is_limit,
                                         errors))
    return false;

  if(!in_zone || !entry_is_limit)
  {
    errors += "limit entry should resolve in zone\n";
    return false;
  }

  if(!EvaluateSupportResistanceRetestChainFilter(snapshot,
                                                 enabled_ctx,
                                                 BULLISH,
                                                 entry_price,
                                                 in_zone))
  {
    errors += "limit gate should pass\n";
  }

  if(!SupportResistanceGate_ResolveEntry(bullish_structure,
                                         205.0,
                                         BULLISH,
                                         LEVEL_AS_ZONE,
                                         entry_price,
                                         in_zone,
                                         entry_is_limit,
                                         errors))
    return false;

  if(!in_zone || entry_is_limit)
  {
    errors += "zone entry should resolve as market entry\n";
    return false;
  }

  if(!EvaluateSupportResistanceRetestChainFilter(snapshot,
                                                 enabled_ctx,
                                                 BULLISH,
                                                 entry_price,
                                                 in_zone))
  {
    errors += "zone gate should pass\n";
  }

  if(!SupportResistanceGate_ResolveEntry(bullish_structure,
                                         190.0,
                                         BULLISH,
                                         LEVEL_AS_ZONE,
                                         entry_price,
                                         in_zone,
                                         entry_is_limit,
                                         errors))
    return false;

  if(!in_zone)
  {
    errors += "outside candidate should still resolve a fibonacci zone\n";
    return false;
  }

  if(EvaluateSupportResistanceRetestChainFilter(snapshot,
                                                enabled_ctx,
                                                BULLISH,
                                                entry_price,
                                                in_zone))
  {
    errors += "zone gate should fail when chain is broken\n";
  }

  SetSupportResistanceRetestChainRuntime(false, 3, 10.0);
  StrategyStructureLayerContext disabled_ctx = BuildBaseStructureLayerContext();
  if(!EvaluateSupportResistanceRetestChainFilter(snapshot,
                                                 disabled_ctx,
                                                 BULLISH,
                                                 entry_price,
                                                 in_zone))
  {
    errors += "disabled gate should no-op\n";
  }

  ClearSupportResistanceRetestChainRuntimeOverride();
  return (errors == "");
}

#endif
