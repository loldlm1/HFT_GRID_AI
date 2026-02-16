#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_COMPOUND_MODES_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_COMPOUND_MODES_MQH

#include "../framework.mqh"

void StructureCompound_PrepareStructure(const OscillatorStructureTypes first,
                                        const OscillatorStructureTypes second,
                                        const OscillatorStructureTypes third,
                                        const OscillatorStructureTypes fourth,
                                        const int extrema_total,
                                        StochasticMarketStructure &structure_out)
{
  structure_out = StochasticMarketStructure();
  structure_out.first_structure_type  = first;
  structure_out.second_structure_type = second;
  structure_out.third_structure_type  = third;
  structure_out.fourth_structure_type = fourth;
  structure_out.first_structure_time  = D'2026.02.10 10:00';
  structure_out.second_structure_time = D'2026.02.10 11:00';
  structure_out.third_structure_time  = D'2026.02.10 12:00';
  structure_out.fourth_structure_time = D'2026.02.10 13:00';
  ArrayResize(structure_out.os_market_structures, extrema_total);
}

bool StructureCompound_AssertModeMatch(const string label,
                                       const TrendStructureCompoundModes mode,
                                       const OscillatorStructureTypes first,
                                       const OscillatorStructureTypes second,
                                       const OscillatorStructureTypes third,
                                       const OscillatorStructureTypes fourth,
                                       const int extrema_total,
                                       const bool expected_match,
                                       string &errors)
{
  StochasticMarketStructure structure;
  StructureCompound_PrepareStructure(first,
                                     second,
                                     third,
                                     fourth,
                                     extrema_total,
                                     structure);

  bool actual_match = EvaluateStructureCompoundMode(structure, mode);
  if(actual_match == expected_match)
    return true;

  errors += StringFormat("%s expected=%s actual=%s mode=%d slots=[%d,%d,%d,%d] extrema=%d\n",
                         label,
                         expected_match ? "true" : "false",
                         actual_match ? "true" : "false",
                         (int)mode,
                         (int)first,
                         (int)second,
                         (int)third,
                         (int)fourth,
                         extrema_total);
  return false;
}

bool StructureCompound_AssertTypeFilter(const string label,
                                        const TrendStructureCompoundModes mode,
                                        const bool context_enabled,
                                        const bool structure_valid,
                                        const OscillatorStructureTypes first,
                                        const OscillatorStructureTypes second,
                                        const OscillatorStructureTypes third,
                                        const OscillatorStructureTypes fourth,
                                        const int extrema_total,
                                        const bool expected_match,
                                        string &errors)
{
  StrategyStructureLayerContext ctx;
  ctx.structure_compound_filter = mode;
  ctx.enabled                   = context_enabled;
  ctx.uses_trend_dataset        = false;

  StrategyContextIndicators snapshot;
  snapshot.context         = CONTEXT_SLOT_BASE;
  snapshot.timeframe       = PERIOD_M1;
  snapshot.structure_valid = structure_valid;

  if(structure_valid)
  {
    StructureCompound_PrepareStructure(first,
                                       second,
                                       third,
                                       fourth,
                                       extrema_total,
                                       snapshot.structure_data);
  }

  bool actual_match = EvaluateStructureTypeFilters(snapshot, ctx);
  if(actual_match == expected_match)
    return true;

  errors += StringFormat("%s expected=%s actual=%s mode=%d structure_valid=%s\n",
                         label,
                         expected_match ? "true" : "false",
                         actual_match ? "true" : "false",
                         (int)mode,
                         structure_valid ? "true" : "false");
  return false;
}

OscillatorStructureTypes StructureCompound_ResolveParityTwin(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HL:
      return OSCILLATOR_STRUCTURE_HH;
    case OSCILLATOR_STRUCTURE_HH:
      return OSCILLATOR_STRUCTURE_HL;
    case OSCILLATOR_STRUCTURE_LH:
      return OSCILLATOR_STRUCTURE_LL;
    case OSCILLATOR_STRUCTURE_LL:
      return OSCILLATOR_STRUCTURE_LH;
    default:
      return OSCILLATOR_STRUCTURE_EQ;
  }
}

bool StructureCompound_AssertStrictMode(const string label_prefix,
                                        const TrendStructureCompoundModes mode,
                                        const OscillatorStructureTypes first,
                                        const OscillatorStructureTypes second,
                                        const OscillatorStructureTypes third,
                                        const OscillatorStructureTypes fourth,
                                        string &errors)
{
  bool ok = true;

  ok = StructureCompound_AssertModeMatch(label_prefix + " canonical",
                                         mode,
                                         first,
                                         second,
                                         third,
                                         fourth,
                                         4,
                                         true,
                                         errors) && ok;

  ok = StructureCompound_AssertModeMatch(label_prefix + " parity twin rejected",
                                         mode,
                                         StructureCompound_ResolveParityTwin(first),
                                         StructureCompound_ResolveParityTwin(second),
                                         StructureCompound_ResolveParityTwin(third),
                                         StructureCompound_ResolveParityTwin(fourth),
                                         4,
                                         false,
                                         errors) && ok;

  ok = StructureCompound_AssertModeMatch(label_prefix + " rotated sequence rejected",
                                         mode,
                                         second,
                                         third,
                                         fourth,
                                         first,
                                         4,
                                         false,
                                         errors) && ok;

  ok = StructureCompound_AssertModeMatch(label_prefix + " eq slot rejected",
                                         mode,
                                         first,
                                         second,
                                         third,
                                         OSCILLATOR_STRUCTURE_EQ,
                                         4,
                                         false,
                                         errors) && ok;

  ok = StructureCompound_AssertModeMatch(label_prefix + " insufficient depth",
                                         mode,
                                         first,
                                         second,
                                         third,
                                         fourth,
                                         3,
                                         false,
                                         errors) && ok;
  return ok;
}

bool RunTest_structure_compound_modes_test(string &errors)
{
  errors = "";

  // Every active mode must be strict 1:1 positional matching.
  StructureCompound_AssertStrictMode("trend ride buy",
                                     COMPOUND_MODE_TREND_RIDE_BUY,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     errors);
  StructureCompound_AssertStrictMode("trend ride sell",
                                     COMPOUND_MODE_TREND_RIDE_SELL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     errors);
  StructureCompound_AssertStrictMode("pullback continue buy",
                                     COMPOUND_MODE_PULLBACK_CONTINUE_BUY,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     errors);
  StructureCompound_AssertStrictMode("pullback continue sell",
                                     COMPOUND_MODE_PULLBACK_CONTINUE_SELL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     errors);
  StructureCompound_AssertStrictMode("reversal early buy",
                                     COMPOUND_MODE_REVERSAL_EARLY_BUY,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     errors);
  StructureCompound_AssertStrictMode("reversal early sell",
                                     COMPOUND_MODE_REVERSAL_EARLY_SELL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     errors);
  StructureCompound_AssertStrictMode("breakout ready buy",
                                     COMPOUND_MODE_BREAKOUT_READY_BUY,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     errors);
  StructureCompound_AssertStrictMode("breakout ready sell",
                                     COMPOUND_MODE_BREAKOUT_READY_SELL,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_HL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     errors);
  StructureCompound_AssertStrictMode("volatility trap buy",
                                     COMPOUND_MODE_VOLATILITY_TRAP_BUY,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     errors);
  StructureCompound_AssertStrictMode("volatility trap sell",
                                     COMPOUND_MODE_VOLATILITY_TRAP_SELL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_HH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     errors);

  // Breakout family-only matches are no longer valid.
  StructureCompound_AssertModeMatch("breakout ready buy relaxed family rejected",
                                    COMPOUND_MODE_BREAKOUT_READY_BUY,
                                    OSCILLATOR_STRUCTURE_LH,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_LL,
                                    OSCILLATOR_STRUCTURE_HL,
                                    4,
                                    false,
                                    errors);
  StructureCompound_AssertModeMatch("breakout ready sell relaxed family rejected",
                                    COMPOUND_MODE_BREAKOUT_READY_SELL,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_LL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_LH,
                                    4,
                                    false,
                                    errors);

  // OFF mode force-passes structure type filtering even with invalid structure.
  StructureCompound_AssertTypeFilter("off force pass invalid structure",
                                     COMPOUND_MODE_OFF,
                                     true,
                                     false,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     0,
                                     true,
                                     errors);

  // Active mode fails when structure snapshot is missing.
  StructureCompound_AssertTypeFilter("active mode fails invalid structure",
                                     COMPOUND_MODE_TREND_RIDE_BUY,
                                     true,
                                     false,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     OSCILLATOR_STRUCTURE_EQ,
                                     0,
                                     false,
                                     errors);

  // Structure matching remains direction-agnostic (pure structure gate).
  StructureCompound_AssertTypeFilter("direction agnostic compound filter",
                                     COMPOUND_MODE_TREND_RIDE_SELL,
                                     true,
                                     true,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     4,
                                     true,
                                     errors);

  return (errors == "");
}

#endif
