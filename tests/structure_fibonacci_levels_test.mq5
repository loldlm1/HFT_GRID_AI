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
  double levels[];
  string err = "";
  bool ok = ParseStructureFibonacciLevels("23.6,38.2,50.0,61.8,78.6,100.0",
                                          levels,
                                          err);
  string errors = "";

  if(!ok)
  {
    Print("FAIL parse: ", err);
    return;
  }

  AssertClose("levels[0]", levels[0], 23.6, 0.01, errors);
  AssertClose("levels[5]", levels[5], 100.0, 0.01, errors);

  double lower = 0.0;
  double upper = 0.0;
  bool range_ok = ResolveFibonacciRangeForPercent(levels,
                                                  ArraySize(levels),
                                                  110.0,
                                                  lower,
                                                  upper);
  if(!range_ok)
    errors += "range not resolved\n";
  AssertClose("lower", lower, 100.0, 0.01, errors);
  AssertClose("upper", upper, 121.4, 0.01, errors); // 100 + (100-78.6)

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
