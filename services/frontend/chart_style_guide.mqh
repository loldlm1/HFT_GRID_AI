//+------------------------------------------------------------------+
//|                                frontend/chart_style_guide.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_CHART_STYLE_GUIDE_MQH_
#define _SERVICES_FRONTEND_CHART_STYLE_GUIDE_MQH_

// Base palette for chart objects rendered by the EA.
const color COLOR_CHART_BACKGROUND = clrWhite;
const color COLOR_CHART_FOREGROUND = clrBlack;
const color COLOR_CHART_BULL       = DimGray;
const color COLOR_CHART_BEAR       = clrBlack;
const color COLOR_CANDLE_BULL      = LightGreen;
const color COLOR_CANDLE_BEAR      = clrBlack;

const color COLOR_PROFIT_POSITIVE  = clrGreen;
const color COLOR_PROFIT_NEGATIVE  = clrTomato;
const color COLOR_PROFIT_NEUTRAL   = clrSlateGray;

// Applies the default layout configuration for the chart hosting the EA.
void ApplyDefaultChartStyle(const long chart_id)
{
  ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true);
  ChartSetInteger(chart_id, CHART_QUICK_NAVIGATION, false);
  ChartSetInteger(chart_id, CHART_SHOW_GRID, 0, true);
  ChartSetInteger(chart_id, CHART_SHOW_VOLUMES, 0, false);
  ChartSetInteger(chart_id, CHART_AUTOSCROLL, 0, true);
  ChartSetInteger(chart_id, CHART_SHIFT, 0, true);

  ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, COLOR_CHART_BACKGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, COLOR_CHART_FOREGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, COLOR_CHART_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, COLOR_CHART_BEAR);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, COLOR_CANDLE_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, COLOR_CANDLE_BEAR);
}

// Provides a standard coloring rule for profit-sensitive lines.
color ResolveProfitColor(const double expected_profit_points)
{
  if(expected_profit_points > 0.0)
    return COLOR_PROFIT_POSITIVE;
  if(expected_profit_points < 0.0)
    return COLOR_PROFIT_NEGATIVE;
  return COLOR_PROFIT_NEUTRAL;
}

#endif // _SERVICES_FRONTEND_CHART_STYLE_GUIDE_MQH_
