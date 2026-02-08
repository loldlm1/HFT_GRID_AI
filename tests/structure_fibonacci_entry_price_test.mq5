#property script_show_inputs
#include "../services/indicators/fibonacci_calculator.mqh"

bool AssertClose(const string label,
                 const double actual,
                 const double expected,
                 const double tol,
                 string &errors)
{
  if(MathAbs(actual - expected) > tol)
  {
    errors += StringFormat("%s expected %.5f got %.5f\n", label, expected, actual);
    return false;
  }
  return true;
}

void OnStart()
{
  double peak = 1.2000;
  double bottom = 1.1000;
  double price_38 = GetFiboTrendBottomPrice(peak, bottom, 38.2);
  string errors = "";

  AssertClose("price_38", price_38, 1.19618, 0.0002, errors);

  if(errors != "")
    Print("FAIL:\n", errors);
  else
    Print("PASS");
}
