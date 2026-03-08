//+------------------------------------------------------------------+
//|                                frontend/chart_style_guide.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_CHART_STYLE_GUIDE_MQH_
#define _SERVICES_FRONTEND_CHART_STYLE_GUIDE_MQH_

// Toggle for optional stop overlays in tester builds.
const bool SHOW_STOPS_LINES = false;

// Base palette for chart objects rendered by the EA.
const color COLOR_CHART_BACKGROUND = C'44,45,50';
const color COLOR_CHART_FOREGROUND = clrDarkTurquoise;
const color COLOR_CHART_BULL       = clrLightSeaGreen;
const color COLOR_CHART_BEAR       = C'239,83,80';
const color COLOR_CANDLE_BULL      = clrLightSeaGreen;
const color COLOR_CANDLE_BEAR      = C'239,83,80';
const color COLOR_CHART_LINE       = C'38,166,154';
const color COLOR_CHART_VOLUME     = C'38,166,154';
const color COLOR_CHART_BID        = C'38,166,154';
const color COLOR_CHART_ASK        = C'239,83,80';
const color COLOR_CHART_LAST       = C'156,186,240';
const color COLOR_CHART_STOP_LEVEL = C'239,83,80';

const color COLOR_PANEL_BACKGROUND = C'31,33,38';
const color COLOR_PANEL_BORDER     = C'38,166,154';
const color COLOR_PANEL_TEXT       = clrDarkTurquoise;
const color COLOR_PANEL_TITLE      = clrDarkTurquoise;
const color COLOR_HISTORY_FILL     = DimGray;
const color COLOR_HISTORY_LABEL    = C'239,83,80';

const color COLOR_PROFIT_POSITIVE  = clrLightSeaGreen;
const color COLOR_PROFIT_NEGATIVE  = C'239,83,80';
const color COLOR_PROFIT_NEUTRAL   = clrDarkTurquoise;

const string FRONTEND_PANEL_FONT         = "Trebuchet MS";
const int    FRONTEND_PANEL_CORNER       = CORNER_LEFT_UPPER;
const int    FRONTEND_PANEL_MARGIN_LEFT  = 14;
const int    FRONTEND_PANEL_MARGIN_TOP   = 46;
const int    FRONTEND_PANEL_PADDING_X    = 12;
const int    FRONTEND_PANEL_PADDING_Y    = 10;
const int    FRONTEND_PANEL_LINE_HEIGHT  = 17;
const int    FRONTEND_PANEL_TITLE_SIZE   = 10;
const int    FRONTEND_PANEL_TEXT_SIZE    = 9;
const int    FRONTEND_PANEL_MIN_WIDTH    = 320;
const int    FRONTEND_PANEL_MAX_WIDTH    = 520;

// Applies the default layout configuration for the chart hosting the EA.
void ApplyDefaultChartStyle(const long chart_id)
{
  ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true);
  ChartSetInteger(chart_id, CHART_QUICK_NAVIGATION, false);
  ChartSetInteger(chart_id, CHART_SHOW_GRID, 0, false);
  ChartSetInteger(chart_id, CHART_SHOW_VOLUMES, 0, false);
  ChartSetInteger(chart_id, CHART_AUTOSCROLL, 0, true);
  ChartSetInteger(chart_id, CHART_SHIFT, 0, true);

  ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, COLOR_CHART_BACKGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, COLOR_CHART_FOREGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, COLOR_CHART_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, COLOR_CHART_BEAR);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, COLOR_CANDLE_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, COLOR_CANDLE_BEAR);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, COLOR_CHART_LINE);
  ChartSetInteger(chart_id, CHART_COLOR_VOLUME, COLOR_CHART_VOLUME);
  ChartSetInteger(chart_id, CHART_COLOR_BID, COLOR_CHART_BID);
  ChartSetInteger(chart_id, CHART_COLOR_ASK, COLOR_CHART_ASK);
  ChartSetInteger(chart_id, CHART_COLOR_LAST, COLOR_CHART_LAST);
  ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL, COLOR_CHART_STOP_LEVEL);
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
