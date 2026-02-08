#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_STRICT_RANGE_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_FIBONACCI_STRICT_RANGE_MQH

#include "../framework.mqh"

bool StrictRange_AssertClose(const string label,
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

bool RunTest_structure_fibonacci_strict_range_test(string &errors)
{
  errors = "";
  double levels[];
  string err = "";
  if(!ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0", levels, err))
  {
    errors += StringFormat("parse failed: %s\n", err);
    return false;
  }

  double lower = 0.0;
  double upper = 0.0;

  if(ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 150.0, lower, upper))
    errors += "strict range should fail above max\n";

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 23.6, lower, upper))
    errors += "strict range failed at min\n";
  else
  {
    StrictRange_AssertClose("lower@min", lower, 23.6, 0.01, errors);
    StrictRange_AssertClose("upper@min", upper, 38.2, 0.01, errors);
  }

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 100.0, lower, upper))
    errors += "strict range failed at max\n";
  else
  {
    StrictRange_AssertClose("lower@max", lower, 78.6, 0.01, errors);
    StrictRange_AssertClose("upper@max", upper, 100.0, 0.01, errors);
  }

  return (errors == "");
}

#endif
