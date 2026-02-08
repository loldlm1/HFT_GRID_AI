#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_LEVELS_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_LEVELS_MQH

#include "../framework.mqh"

bool FibLevels_AssertClose(const string label,
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

bool RunTest_structure_fibonacci_levels_test(string &errors)
{
  double levels[];
  string err = "";
  bool ok = ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                                          levels,
                                          err);
  errors = "";

  if(!ok)
  {
    errors += StringFormat("parse failed: %s\n", err);
    return false;
  }

  FibLevels_AssertClose("levels[0]", levels[0], 23.6, 0.01, errors);
  FibLevels_AssertClose("levels[5]", levels[5], 100.0, 0.01, errors);

  double lower = 0.0;
  double upper = 0.0;
  bool range_ok = ResolveFibonacciRangeForPercent(levels,
                                                  ArraySize(levels),
                                                  110.0,
                                                  lower,
                                                  upper);
  if(!range_ok)
    errors += "range not resolved\n";
  FibLevels_AssertClose("lower", lower, 100.0, 0.01, errors);
  FibLevels_AssertClose("upper", upper, 121.4, 0.01, errors);

  return (errors == "");
}

#endif
