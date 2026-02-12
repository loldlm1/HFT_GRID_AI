#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FILTER_MODE_BEHAVIOR_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FILTER_MODE_BEHAVIOR_MQH

#include "../framework.mqh"

bool StructureFilter_AssertMatch(const string label,
                                 const TrendStructureFilterModes filter_mode,
                                 const OscillatorStructureTypes structure_type,
                                 const SignalTypes signal_type,
                                 const bool latest_is_peak,
                                 const bool expected_match,
                                 string &errors)
{
  OscillatorMarketStructure latest_extremum;
  latest_extremum.is_peak = latest_is_peak;

  bool actual_match = TrendStructureFilterMatches(filter_mode,
                                                  structure_type,
                                                  signal_type,
                                                  latest_extremum);
  if(actual_match == expected_match)
    return true;

  errors += StringFormat("%s expected=%s actual=%s filter=%d structure=%s signal=%s latest_is_peak=%s\n",
                         label,
                         expected_match ? "true" : "false",
                         actual_match ? "true" : "false",
                         (int)filter_mode,
                         IntegerToString((int)structure_type),
                         IntegerToString((int)signal_type),
                         latest_is_peak ? "true" : "false");
  return false;
}

bool RunTest_structure_filter_mode_behavior_test(string &errors)
{
  errors = "";

  // OFF mode always passes.
  StructureFilter_AssertMatch("off allows any state",
                              STRUCT_FILTER_OFF,
                              OSCILLATOR_STRUCTURE_EQ,
                              NO_SIGNAL,
                              true,
                              true,
                              errors);

  // Bullish accepts only bottom-family filters (LL/HL) on bottom-side extrema.
  StructureFilter_AssertMatch("bullish bottom LL exact",
                              STRUCT_FILTER_LL,
                              OSCILLATOR_STRUCTURE_LL,
                              BULLISH,
                              false,
                              true,
                              errors);
  StructureFilter_AssertMatch("bullish bottom HL exact",
                              STRUCT_FILTER_HL,
                              OSCILLATOR_STRUCTURE_HL,
                              BULLISH,
                              false,
                              true,
                              errors);
  StructureFilter_AssertMatch("bullish rejects peak-family HH",
                              STRUCT_FILTER_HH,
                              OSCILLATOR_STRUCTURE_HH,
                              BULLISH,
                              false,
                              false,
                              errors);
  StructureFilter_AssertMatch("bullish rejects peak-family LH",
                              STRUCT_FILTER_LH,
                              OSCILLATOR_STRUCTURE_LH,
                              BULLISH,
                              false,
                              false,
                              errors);
  StructureFilter_AssertMatch("bullish rejects peak-side latest extremum",
                              STRUCT_FILTER_LL,
                              OSCILLATOR_STRUCTURE_LL,
                              BULLISH,
                              true,
                              false,
                              errors);

  // Bearish accepts only peak-family filters (HH/LH) on peak-side extrema.
  StructureFilter_AssertMatch("bearish peak HH exact",
                              STRUCT_FILTER_HH,
                              OSCILLATOR_STRUCTURE_HH,
                              BEARISH,
                              true,
                              true,
                              errors);
  StructureFilter_AssertMatch("bearish peak LH exact",
                              STRUCT_FILTER_LH,
                              OSCILLATOR_STRUCTURE_LH,
                              BEARISH,
                              true,
                              true,
                              errors);
  StructureFilter_AssertMatch("bearish rejects bottom-family LL",
                              STRUCT_FILTER_LL,
                              OSCILLATOR_STRUCTURE_LL,
                              BEARISH,
                              true,
                              false,
                              errors);
  StructureFilter_AssertMatch("bearish rejects bottom-side latest extremum",
                              STRUCT_FILTER_HH,
                              OSCILLATOR_STRUCTURE_HH,
                              BEARISH,
                              false,
                              false,
                              errors);

  // EQ tolerance follows side-family rules only.
  StructureFilter_AssertMatch("bullish EQ tolerated for bottom family LL",
                              STRUCT_FILTER_LL,
                              OSCILLATOR_STRUCTURE_EQ,
                              BULLISH,
                              false,
                              true,
                              errors);
  StructureFilter_AssertMatch("bullish EQ tolerated for bottom family HL",
                              STRUCT_FILTER_HL,
                              OSCILLATOR_STRUCTURE_EQ,
                              BULLISH,
                              false,
                              true,
                              errors);
  StructureFilter_AssertMatch("bullish EQ rejects peak family HH",
                              STRUCT_FILTER_HH,
                              OSCILLATOR_STRUCTURE_EQ,
                              BULLISH,
                              false,
                              false,
                              errors);
  StructureFilter_AssertMatch("bearish EQ tolerated for peak family HH",
                              STRUCT_FILTER_HH,
                              OSCILLATOR_STRUCTURE_EQ,
                              BEARISH,
                              true,
                              true,
                              errors);
  StructureFilter_AssertMatch("bearish EQ tolerated for peak family LH",
                              STRUCT_FILTER_LH,
                              OSCILLATOR_STRUCTURE_EQ,
                              BEARISH,
                              true,
                              true,
                              errors);
  StructureFilter_AssertMatch("bearish EQ rejects bottom family HL",
                              STRUCT_FILTER_HL,
                              OSCILLATOR_STRUCTURE_EQ,
                              BEARISH,
                              true,
                              false,
                              errors);

  return (errors == "");
}

#endif
