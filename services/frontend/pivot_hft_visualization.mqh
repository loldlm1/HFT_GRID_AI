//+------------------------------------------------------------------+
//|                    pivot_hft_visualization.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_

const string PIVOT_HFT_OBJECT_PREFIX = "PIVOT_HFT_";
bool g_pivot_hft_visualization_visible = false;
const int PIVOT_HFT_VISUAL_SLOT_COUNT = 9;
double g_pivot_hft_visual_prices[9];
bool g_pivot_hft_visual_price_valid[9];

bool PivotHftVisualizationEnabledForRuntime()
{
  static int cached_enabled = -1;
  if(cached_enabled < 0)
  {
    bool tester_without_visuals =
      ((bool)MQLInfoInteger(MQL_TESTER) &&
       !(bool)MQLInfoInteger(MQL_VISUAL_MODE));
    cached_enabled = (Pivot_HFT_Enable_Visualization &&
                      !tester_without_visuals) ? 1 : 0;
  }
  return (cached_enabled == 1);
}

void PivotHftDeleteVisualObject(const string suffix)
{
  string object_name = PIVOT_HFT_OBJECT_PREFIX + suffix;
  if(ObjectFind(ChartID(), object_name) >= 0)
    ObjectDelete(ChartID(), object_name);
}

void PivotHftResetVisualPriceCache()
{
  for(int i = 0; i < PIVOT_HFT_VISUAL_SLOT_COUNT; i++)
  {
    g_pivot_hft_visual_prices[i] = 0.0;
    g_pivot_hft_visual_price_valid[i] = false;
  }
}

void PivotHftUpdateHorizontalLine(const int slot,
                                  const string suffix,
                                  const double price,
                                  const color line_color,
                                  const ENUM_LINE_STYLE line_style)
{
  if(slot < 0 || slot >= PIVOT_HFT_VISUAL_SLOT_COUNT)
    return;

  double tolerance = PivotHftTickSize() * 0.5;
  if(g_pivot_hft_visual_price_valid[slot] &&
     MathAbs(g_pivot_hft_visual_prices[slot] - price) <= tolerance)
    return;

  string object_name = PIVOT_HFT_OBJECT_PREFIX + suffix;
  if(price <= 0.0)
  {
    PivotHftDeleteVisualObject(suffix);
    g_pivot_hft_visual_prices[slot] = 0.0;
    g_pivot_hft_visual_price_valid[slot] = true;
    return;
  }

  if(ObjectFind(ChartID(), object_name) < 0)
  {
    ResetLastError();
    if(!ObjectCreate(ChartID(), object_name, OBJ_HLINE, 0, 0, price))
      return;
  }

  ObjectSetDouble(ChartID(), object_name, OBJPROP_PRICE, price);
  ObjectSetInteger(ChartID(), object_name, OBJPROP_COLOR, line_color);
  ObjectSetInteger(ChartID(), object_name, OBJPROP_STYLE, line_style);
  ObjectSetInteger(ChartID(), object_name, OBJPROP_WIDTH, 1);
  ObjectSetInteger(ChartID(), object_name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(ChartID(), object_name, OBJPROP_HIDDEN, true);
  ObjectSetString(ChartID(), object_name, OBJPROP_TEXT, suffix);
  g_pivot_hft_visual_prices[slot] = price;
  g_pivot_hft_visual_price_valid[slot] = true;
}

void ClearFrontendVisualization()
{
  string suffixes[9] = {"P", "R1", "R2", "R3", "S1", "S2", "S3",
                        "BAND_UPPER", "BAND_LOWER"};
  for(int i = 0; i < ArraySize(suffixes); i++)
    PivotHftDeleteVisualObject(suffixes[i]);

  ClearPivotHftPanel();
  PivotHftResetVisualPriceCache();
  g_pivot_hft_visualization_visible = false;
}

void RefreshPivotHftVisualization()
{
  if(!PivotHftVisualizationEnabledForRuntime())
  {
    if(g_pivot_hft_visualization_visible)
      ClearFrontendVisualization();
    return;
  }

  g_pivot_hft_visualization_visible = true;
  PivotHftUpdateHorizontalLine(0, "P", g_pivot_hft_pivots.pivot,
                               clrGold, STYLE_SOLID);
  PivotHftUpdateHorizontalLine(1, "R1", g_pivot_hft_pivots.resistance_1,
                               COLOR_CANDLE_BEAR, STYLE_DASH);
  PivotHftUpdateHorizontalLine(2, "R2", g_pivot_hft_pivots.resistance_2,
                               COLOR_CANDLE_BEAR, STYLE_DASH);
  PivotHftUpdateHorizontalLine(3, "R3", g_pivot_hft_pivots.resistance_3,
                               COLOR_CANDLE_BEAR, STYLE_DOT);
  PivotHftUpdateHorizontalLine(4, "S1", g_pivot_hft_pivots.support_1,
                               COLOR_CANDLE_BULL, STYLE_DASH);
  PivotHftUpdateHorizontalLine(5, "S2", g_pivot_hft_pivots.support_2,
                               COLOR_CANDLE_BULL, STYLE_DASH);
  PivotHftUpdateHorizontalLine(6, "S3", g_pivot_hft_pivots.support_3,
                               COLOR_CANDLE_BULL, STYLE_DOT);
  PivotHftUpdateHorizontalLine(7, "BAND_UPPER", g_pivot_hft_bands_upper,
                               clrSteelBlue, STYLE_DOT);
  PivotHftUpdateHorizontalLine(8, "BAND_LOWER", g_pivot_hft_bands_lower,
                               clrSteelBlue, STYLE_DOT);
  RefreshPivotHftPanel();
}

#endif // _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_
