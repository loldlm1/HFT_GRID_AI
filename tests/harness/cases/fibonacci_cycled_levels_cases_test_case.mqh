#ifndef HFT_GRID_AI_TEST_CASE_FIBONACCI_CYCLED_LEVELS_MQH
#define HFT_GRID_AI_TEST_CASE_FIBONACCI_CYCLED_LEVELS_MQH

#include "../framework.mqh"

bool FibonacciCycled_AssertClose(const string label,
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

void FibonacciCycled_RunCase(const string label,
                             const string csv,
                             const double start_percent,
                             const int steps,
                             const int direction,
                             const double expected,
                             string &errors)
{
  double levels[];
  string err = "";
  if(!ParseStructureFibonacciLevels(csv, levels, err))
  {
    errors += StringFormat("%s parse failed: %s\n", label, err);
    return;
  }

  double next = 0.0;
  if(!ResolveFibonacciNextPercentCycled(levels,
                                        ArraySize(levels),
                                        start_percent,
                                        steps,
                                        direction,
                                        next))
  {
    errors += StringFormat("%s cycle failed\n", label);
    return;
  }

  FibonacciCycled_AssertClose(label, next, expected, 0.1, errors);
}

bool RunTest_fibonacci_cycled_levels_cases_test(string &errors)
{
  errors = "";

  FibonacciCycled_RunCase("std up from 100",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          100.0, 1, 1, 123.6, errors);
  FibonacciCycled_RunCase("std up step6 from 100",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          100.0, 6, 1, 200.0, errors);
  FibonacciCycled_RunCase("std down from 23.6",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          23.6, 1, -1, 0.0, errors);
  FibonacciCycled_RunCase("std down step2 from 23.6",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          23.6, 2, -1, -23.6, errors);
  FibonacciCycled_RunCase("std up from -23.6",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          -23.6, 1, 1, 0.0, errors);
  FibonacciCycled_RunCase("std up step2 from -23.6",
                          "23.6,38.2,50.0,61.8,78.6,100.0",
                          -23.6, 2, 1, 23.6, errors);

  FibonacciCycled_RunCase("implicit 100 up from 78.6",
                          "0.0,23.6,38.2,78.6",
                          78.6, 1, 1, 100.0, errors);
  FibonacciCycled_RunCase("implicit 100 up from 100",
                          "0.0,23.6,38.2,78.6",
                          100.0, 1, 1, 123.6, errors);
  FibonacciCycled_RunCase("implicit 100 down from 0",
                          "0.0,23.6,38.2,78.6",
                          0.0, 1, -1, -23.6, errors);
  FibonacciCycled_RunCase("negative extension down from 0",
                          "-61.8,0.0,100.0,161.8",
                          0.0, 1, -1, -61.8, errors);

  FibonacciCycled_RunCase("implicit 0 down from 23.6",
                          "23.6,50.0,100.0",
                          23.6, 1, -1, 0.0, errors);

  FibonacciCycled_RunCase("custom up from 250",
                          "48.5,161.8,250.0",
                          250.0, 1, 1, 298.5, errors);
  FibonacciCycled_RunCase("custom down from 48.5 skip 0",
                          "48.5,161.8,250.0",
                          48.5, 1, -1, -48.5, errors);
  FibonacciCycled_RunCase("custom down step2",
                          "48.5,161.8,250.0",
                          48.5, 2, -1, -161.8, errors);
  FibonacciCycled_RunCase("custom down step3",
                          "48.5,161.8,250.0",
                          48.5, 3, -1, -250.0, errors);
  FibonacciCycled_RunCase("custom up from -48.5",
                          "48.5,161.8,250.0",
                          -48.5, 1, 1, 48.5, errors);

  FibonacciCycled_RunCase("unsorted duplicate up",
                          "100.0,38.2,23.6,38.2",
                          100.0, 1, 1, 123.6, errors);

  return (errors == "");
}

#endif
