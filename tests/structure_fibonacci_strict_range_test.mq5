#property script_show_inputs
#include "../services/trading_tools.mqh"
#include "../services/trading_management/structure_fibonacci_levels.mqh"

bool AssertClose(const string label,
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

void OnStart()
{
  string errors = "";
  double levels[];
  string err = "";
  if(!ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0", levels, err))
  {
    Print("FAIL parse: ", err);
    return;
  }

  double lower = 0.0;
  double upper = 0.0;

  if(ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 150.0, lower, upper))
    errors += "strict range should fail above max\n";

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 23.6, lower, upper))
    errors += "strict range failed at min\n";
  else
  {
    AssertClose("lower@min", lower, 23.6, 0.01, errors);
    AssertClose("upper@min", upper, 38.2, 0.01, errors);
  }

  if(!ResolveFibonacciRangeForPercentStrict(levels, ArraySize(levels), 100.0, lower, upper))
    errors += "strict range failed at max\n";
  else
  {
    AssertClose("lower@max", lower, 78.6, 0.01, errors);
    AssertClose("upper@max", upper, 100.0, 0.01, errors);
  }

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
