#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_CLASSIFIER_TYPES_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_CLASSIFIER_TYPES_MQH

#include "../framework.mqh"

bool StructureClassifier_AssertType(const string label,
                                    const OscillatorStructureTypes actual,
                                    const OscillatorStructureTypes expected,
                                    string &errors)
{
  if(actual == expected)
    return true;

  errors += StringFormat("%s expected=%s actual=%s\n",
                         label,
                         IntegerToString((int)expected),
                         IntegerToString((int)actual));
  return false;
}

bool RunTest_structure_classifier_types_test(string &errors)
{
  errors = "";

  StructureClassifier_AssertType("high increasing -> HH",
                                 GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, 1.2100, 1.2000),
                                 OSCILLATOR_STRUCTURE_HH,
                                 errors);

  StructureClassifier_AssertType("high decreasing -> LH",
                                 GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, 1.1900, 1.2000),
                                 OSCILLATOR_STRUCTURE_LH,
                                 errors);

  StructureClassifier_AssertType("high equal -> EQ",
                                 GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, 1.2000, 1.2000),
                                 OSCILLATOR_STRUCTURE_EQ,
                                 errors);

  StructureClassifier_AssertType("low increasing -> HL",
                                 GetOscillatorStructureType(OSCILLATOR_LOW_PRICES, 1.1100, 1.1000),
                                 OSCILLATOR_STRUCTURE_HL,
                                 errors);

  StructureClassifier_AssertType("low decreasing -> LL",
                                 GetOscillatorStructureType(OSCILLATOR_LOW_PRICES, 1.0900, 1.1000),
                                 OSCILLATOR_STRUCTURE_LL,
                                 errors);

  StructureClassifier_AssertType("low equal -> EQ",
                                 GetOscillatorStructureType(OSCILLATOR_LOW_PRICES, 1.1000, 1.1000),
                                 OSCILLATOR_STRUCTURE_EQ,
                                 errors);

  return (errors == "");
}

#endif
