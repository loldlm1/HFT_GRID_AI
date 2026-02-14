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

bool RunTest_structure_compound_modes_test(string &errors)
{
  errors = "";

  // Exact match and parity twin match.
  StructureCompound_AssertModeMatch("trend ride buy canonical",
                                    COMPOUND_MODE_TREND_RIDE_BUY,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    4,
                                    true,
                                    errors);
  StructureCompound_AssertModeMatch("trend ride buy parity twin",
                                    COMPOUND_MODE_TREND_RIDE_BUY,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    4,
                                    true,
                                    errors);

  // One-slot mismatch must fail.
  StructureCompound_AssertModeMatch("trend ride buy mismatch",
                                    COMPOUND_MODE_TREND_RIDE_BUY,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_LL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    4,
                                    false,
                                    errors);

  // EQ semantics: required where expected, forbidden otherwise.
  StructureCompound_AssertModeMatch("breakout ready buy requires eq",
                                    COMPOUND_MODE_BREAKOUT_READY_BUY,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_EQ,
                                    4,
                                    false,
                                    errors);
  StructureCompound_AssertModeMatch("trend ride buy rejects eq on non-eq slot",
                                    COMPOUND_MODE_TREND_RIDE_BUY,
                                    OSCILLATOR_STRUCTURE_EQ,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    4,
                                    false,
                                    errors);

  // Active mode fails closed on insufficient depth.
  StructureCompound_AssertModeMatch("compound active insufficient depth",
                                    COMPOUND_MODE_TREND_RIDE_BUY,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    OSCILLATOR_STRUCTURE_HL,
                                    OSCILLATOR_STRUCTURE_HH,
                                    3,
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

  // Mode matching is direction-agnostic: sell templates still resolve as a pure
  // structure gate and do not encode position direction by themselves.
  StructureCompound_AssertTypeFilter("direction agnostic compound filter",
                                     COMPOUND_MODE_TREND_RIDE_SELL,
                                     true,
                                     true,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     OSCILLATOR_STRUCTURE_LL,
                                     OSCILLATOR_STRUCTURE_LH,
                                     4,
                                     true,
                                     errors);
  return (errors == "");
}

#endif
