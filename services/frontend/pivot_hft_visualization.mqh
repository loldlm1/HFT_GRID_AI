//+------------------------------------------------------------------+
//|                    pivot_hft_visualization.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_

const string PIVOT_HFT_OBJECT_PREFIX = "PIVOT_HFT_";
bool g_pivot_hft_visualization_visible = false;
bool g_pivot_hft_visualization_initialized = false;
string g_pivot_hft_dynamic_visual_objects[];

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

string PivotHftVisualObjectName(const string suffix)
{
  return PIVOT_HFT_OBJECT_PREFIX + suffix;
}

void PivotHftDeleteVisualObject(const string suffix)
{
  string object_name = PivotHftVisualObjectName(suffix);
  if(ObjectFind(ChartID(), object_name) >= 0)
    ObjectDelete(ChartID(), object_name);
}

bool PivotHftVisualListContains(string &objects[],
                                const string object_name)
{
  int total = ArraySize(objects);
  for(int i = 0; i < total; i++)
  {
    if(objects[i] == object_name)
      return true;
  }
  return false;
}

void PivotHftTrackDynamicVisual(string &objects[],
                                const string object_name)
{
  if(object_name == "" || PivotHftVisualListContains(objects, object_name))
    return;

  int total = ArraySize(objects);
  if(ArrayResize(objects, total + 1, 32) != total + 1)
    return;
  objects[total] = object_name;
}

void PivotHftSyncDynamicVisuals(string &current_objects[])
{
  long chart_id = ChartID();
  int previous_total = ArraySize(g_pivot_hft_dynamic_visual_objects);
  for(int i = 0; i < previous_total; i++)
  {
    string object_name = g_pivot_hft_dynamic_visual_objects[i];
    if(!PivotHftVisualListContains(current_objects, object_name) &&
       ObjectFind(chart_id, object_name) >= 0)
      ObjectDelete(chart_id, object_name);
  }

  ArrayResize(g_pivot_hft_dynamic_visual_objects, 0);
  if(ArraySize(current_objects) > 0)
    ArrayCopy(g_pivot_hft_dynamic_visual_objects, current_objects);
}

bool PivotHftUpdateHorizontalLine(const string suffix,
                                  const double price,
                                  const color line_color,
                                  const ENUM_LINE_STYLE line_style,
                                  const int line_width,
                                  const string label,
                                  const bool draw_in_background)
{
  string object_name = PivotHftVisualObjectName(suffix);
  if(price <= 0.0)
  {
    PivotHftDeleteVisualObject(suffix);
    return false;
  }

  long chart_id = ChartID();
  bool created = false;
  if(ObjectFind(chart_id, object_name) < 0)
  {
    ResetLastError();
    if(!ObjectCreate(chart_id, object_name, OBJ_HLINE, 0, 0, price))
      return false;
    created = true;
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_HIDDEN, true);
  }

  double tolerance = PivotHftTickSize() * 0.5;
  if(created || MathAbs(ObjectGetDouble(chart_id,
                                        object_name,
                                        OBJPROP_PRICE) - price) > tolerance)
    ObjectSetDouble(chart_id, object_name, OBJPROP_PRICE, price);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_COLOR) !=
     (long)line_color)
    ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, line_color);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_STYLE) !=
     (long)line_style)
    ObjectSetInteger(chart_id, object_name, OBJPROP_STYLE, line_style);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_WIDTH) !=
     (long)line_width)
    ObjectSetInteger(chart_id, object_name, OBJPROP_WIDTH, line_width);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_BACK) !=
     (long)draw_in_background)
    ObjectSetInteger(chart_id,
                     object_name,
                     OBJPROP_BACK,
                     draw_in_background);
  if(created || ObjectGetString(chart_id, object_name, OBJPROP_TEXT) != label)
    ObjectSetString(chart_id, object_name, OBJPROP_TEXT, label);
  return true;
}

bool PivotHftUpdateTestSegment(const string suffix,
                               const datetime time_start,
                               const datetime time_end,
                               const double price,
                               const color line_color,
                               const string label)
{
  string object_name = PivotHftVisualObjectName(suffix);
  if(time_start <= 0 || time_end <= time_start || price <= 0.0)
  {
    PivotHftDeleteVisualObject(suffix);
    return false;
  }

  long chart_id = ChartID();
  bool created = false;
  if(ObjectFind(chart_id, object_name) < 0)
  {
    ResetLastError();
    if(!ObjectCreate(chart_id,
                     object_name,
                     OBJ_TREND,
                     0,
                     time_start,
                     price,
                     time_end,
                     price))
      return false;
    created = true;
    ObjectSetInteger(chart_id, object_name, OBJPROP_RAY_LEFT, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, object_name, OBJPROP_HIDDEN, true);
  }

  double tolerance = PivotHftTickSize() * 0.5;
  datetime current_start =
    (datetime)ObjectGetInteger(chart_id, object_name, OBJPROP_TIME, 0);
  datetime current_end =
    (datetime)ObjectGetInteger(chart_id, object_name, OBJPROP_TIME, 1);
  double current_price = ObjectGetDouble(chart_id,
                                         object_name,
                                         OBJPROP_PRICE,
                                         0);
  if(created || current_start != time_start || current_end != time_end ||
     MathAbs(current_price - price) > tolerance)
  {
    ObjectMove(chart_id, object_name, 0, time_start, price);
    ObjectMove(chart_id, object_name, 1, time_end, price);
  }
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_COLOR) !=
     (long)line_color)
    ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, line_color);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_STYLE) !=
     (long)STYLE_SOLID)
    ObjectSetInteger(chart_id, object_name, OBJPROP_STYLE, STYLE_SOLID);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_WIDTH) != 3)
    ObjectSetInteger(chart_id, object_name, OBJPROP_WIDTH, 3);
  if(created || ObjectGetInteger(chart_id, object_name, OBJPROP_BACK) != 0)
    ObjectSetInteger(chart_id, object_name, OBJPROP_BACK, false);
  if(created || ObjectGetString(chart_id, object_name, OBJPROP_TEXT) != label)
    ObjectSetString(chart_id, object_name, OBJPROP_TEXT, label);
  return true;
}

void PivotHftDrawLevelLine(const PivotHftPivotLevels level,
                           const string suffix,
                           const double price,
                           const color base_color,
                           const ENUM_LINE_STYLE base_style)
{
  color line_color = base_color;
  ENUM_LINE_STYLE line_style = base_style;
  int line_width = 1;
  string state_label = "UNTESTED";
  PivotHftLevelTestStatuses level_status = PivotHftGetLevelTestStatus(level);

  if(level_status == PIVOT_HFT_LEVEL_BURNED)
  {
    line_color = clrDimGray;
    line_style = STYLE_DOT;
    state_label = "BURNED";
  }
  else if(level_status == PIVOT_HFT_LEVEL_TOUCHED_OPEN)
  {
    line_color = clrOrange;
    line_style = STYLE_DASHDOT;
    line_width = 2;
    state_label = "TEST OPEN";
  }

  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE &&
     g_pivot_hft_campaign.pivot_level == level)
  {
    line_color = clrGold;
    line_style = STYLE_SOLID;
    line_width = 2;
    state_label = PivotHftCampaignDisplayStatus(g_pivot_hft_campaign);
  }

  if(g_pivot_hft_supersession_candidate.valid &&
     g_pivot_hft_supersession_candidate.pivot_level == level)
  {
    line_color = clrDeepSkyBlue;
    line_style = STYLE_DASHDOT;
    line_width = 3;
    state_label = StringFormat("CANDIDATE FOR %s",
                               PivotHftLevelLabel(
                                 g_pivot_hft_supersession_candidate.owner_pivot_level));
  }

  PivotHftUpdateHorizontalLine(suffix,
                               price,
                               line_color,
                               line_style,
                               line_width,
                               suffix + " " + state_label,
                               true);
}

void PivotHftDrawBurnedLevelTests(string &current_objects[])
{
  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
    micro_seconds = 60;

  for(int i = (int)PIVOT_HFT_LEVEL_P;
      i < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      i++)
  {
    PivotHftPivotLevels level = (PivotHftPivotLevels)i;
    if(PivotHftGetLevelTestStatus(level) != PIVOT_HFT_LEVEL_BURNED)
      continue;

    datetime touch_time = PivotHftLevelFirstTouchBar(level);
    double level_price = PivotHftResolveLevelPrice(level,
                                                   g_pivot_hft_pivots);
    string level_label = PivotHftLevelLabel(level);
    string suffix = "TEST_" + level_label;
    if(PivotHftUpdateTestSegment(suffix,
                                 touch_time,
                                 touch_time + micro_seconds,
                                 level_price,
                                 clrSilver,
                                 level_label + " FIRST TEST"))
      PivotHftTrackDynamicVisual(current_objects,
                                 PivotHftVisualObjectName(suffix));
  }
}

bool PivotHftResolveVisualCampaign(PivotHftCampaignState &campaign,
                                   bool &expired)
{
  expired = false;
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
  {
    campaign = g_pivot_hft_campaign;
    return true;
  }

  if(PivotHftGetExpiredCampaignVisual(campaign))
  {
    expired = true;
    return true;
  }
  return false;
}

void PivotHftDrawCampaign(string &current_objects[])
{
  PivotHftCampaignState campaign;
  bool expired = false;
  if(!PivotHftResolveVisualCampaign(campaign, expired))
    return;

  string status_label = PivotHftCampaignDisplayStatus(campaign);
  string source_label = PivotHftCampaignSourceLabel(campaign);
  string direction_label = PivotHftDirectionToken(campaign.direction);
  color pivot_color = expired ? clrDimGray : clrGold;
  color extreme_color = expired ? clrDimGray : clrDeepSkyBlue;
  color trigger_color = expired ? clrDimGray : clrOrange;
  ENUM_LINE_STYLE line_style = expired ? STYLE_DOT : STYLE_DASHDOT;
  int trigger_width = 2;
  if(campaign.status == PIVOT_HFT_CAMPAIGN_ORDER_WAIT)
  {
    trigger_color = (campaign.direction == BULLISH)
                    ? COLOR_PROFIT_POSITIVE
                    : COLOR_PROFIT_NEGATIVE;
    line_style = STYLE_SOLID;
    trigger_width = 3;
  }

  string pivot_suffix = "CAMPAIGN_PIVOT";
  if(PivotHftUpdateHorizontalLine(pivot_suffix,
                                  campaign.pivot_price,
                                  pivot_color,
                                  line_style,
                                  2,
                                  StringFormat("%s %s %s PIVOT%s",
                                               status_label,
                                               direction_label,
                                               PivotHftLevelLabel(
                                                 campaign.pivot_level),
                                               source_label),
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(pivot_suffix));

  string extreme_suffix = "CAMPAIGN_EXTREME";
  if(PivotHftUpdateHorizontalLine(extreme_suffix,
                                  campaign.tracked_extreme,
                                  extreme_color,
                                  line_style,
                                  2,
                                  StringFormat("%s %s TRACKED EXTREME%s",
                                               status_label,
                                               direction_label,
                                               source_label),
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(extreme_suffix));

  string trigger_suffix = "CAMPAIGN_TRIGGER";
  double trigger_price =
    PivotHftCampaignRetracementThresholdForState(campaign);
  if(PivotHftUpdateHorizontalLine(trigger_suffix,
                                  trigger_price,
                                  trigger_color,
                                  line_style,
                                  trigger_width,
                                  StringFormat("%s %s ENTRY THRESHOLD%s",
                                               status_label,
                                               direction_label,
                                               source_label),
                                  false))
      PivotHftTrackDynamicVisual(current_objects,
                                 PivotHftVisualObjectName(trigger_suffix));
}

void PivotHftDrawConcurrentTerminalCampaign(string &current_objects[])
{
  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_IDLE)
    return;

  PivotHftCampaignState terminal_campaign;
  if(!PivotHftGetExpiredCampaignVisual(terminal_campaign) ||
     terminal_campaign.terminal_reason == "")
    return;

  string replacement_text = "";
  if(terminal_campaign.replacement_sequence_id != "")
  {
    replacement_text = StringFormat(" -> %s %.5f",
                                    PivotHftLevelLabel(
                                      terminal_campaign.replacement_level),
                                    terminal_campaign.replacement_price);
  }
  string suffix = "TERMINAL_CAMPAIGN_PIVOT";
  string label = StringFormat("TERMINAL %s %s %.5f%s reason=%s",
                              PivotHftCampaignDisplayStatus(
                                terminal_campaign),
                              PivotHftLevelLabel(
                                terminal_campaign.pivot_level),
                              terminal_campaign.pivot_price,
                              replacement_text,
                              terminal_campaign.terminal_reason);
  if(PivotHftUpdateHorizontalLine(suffix,
                                  terminal_campaign.pivot_price,
                                  clrDimGray,
                                  STYLE_DOT,
                                  2,
                                  label,
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(suffix));
}

string PivotHftPositionStopLabel(const PivotHftPositionState &state)
{
  string label = "LOCAL SL";
  if(state.status == PIVOT_HFT_POSITION_CLOSE_WAIT &&
     state.close_trigger == PIVOT_HFT_CLOSE_TRIGGER_ENTRY_SAFETY)
    label = "ENTRY SAFETY";
  else if(state.trailing_step_index == 1)
    label = "BE";
  else if(state.trailing_step_index > 1)
    label = StringFormat("TRAIL STEP %d", state.trailing_step_index);

  if(state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
    label += " CLOSE WAIT";
  return label;
}

color PivotHftPositionStopColor(const PivotHftPositionState &state)
{
  if(state.trailing_step_index > 1)
    return COLOR_PROFIT_POSITIVE;
  if(PivotHftPositionAtBreakEvenOrBetter(state))
    return COLOR_PROFIT_NEUTRAL;
  return COLOR_PROFIT_NEGATIVE;
}

void PivotHftDrawPosition(const PivotHftPositionState &state,
                          string &current_objects[])
{
  if((state.status != PIVOT_HFT_POSITION_ACTIVE &&
      state.status != PIVOT_HFT_POSITION_CLOSE_WAIT))
    return;

  string execution_token = PivotHftPositionExecutionId(state);
  if(execution_token == "" || execution_token == "-")
    return;
  string direction_label = PivotHftDirectionToken(state.direction);
  string source_label = PivotHftExecutionSourceLabel(state.execution_source);
  string retry_identity = PivotHftRetryIdentityLabelForOrdinal(
    state.campaign_retry_ordinal);
  string lifecycle_label = (state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
                           ? "CLOSE WAIT"
                           : "LIVE";
  color entry_color = (state.direction == BULLISH)
                      ? COLOR_CANDLE_BULL
                      : COLOR_CANDLE_BEAR;
  ENUM_LINE_STYLE entry_style = STYLE_DASH;
  if(state.execution_source == PIVOT_HFT_EXECUTION_VIRTUAL)
  {
    entry_color = clrDeepSkyBlue;
    entry_style = STYLE_DOT;
  }

  string entry_suffix = "POSITION_" + execution_token + "_ENTRY";
  if(PivotHftUpdateHorizontalLine(entry_suffix,
                                  state.entry_price,
                                  entry_color,
                                  entry_style,
                                  1,
                                  StringFormat("%s %s %s %s %s %s FILL",
                                               execution_token,
                                               direction_label,
                                               lifecycle_label,
                                               retry_identity,
                                               source_label,
                                               PivotHftLevelLabel(
                                                 state.pivot_level)),
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(entry_suffix));

  string stop_suffix = "POSITION_" + execution_token + "_STOP";
  if(PivotHftUpdateHorizontalLine(stop_suffix,
                                  state.local_sl_price,
                                  PivotHftPositionStopColor(state),
                                  STYLE_SOLID,
                                  2,
                                  StringFormat("%s %s %s %s %s @ %.5f",
                                               execution_token,
                                               direction_label,
                                               retry_identity,
                                               source_label,
                                               PivotHftPositionStopLabel(state),
                                               state.local_sl_price),
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(stop_suffix));

  if(state.local_tp_price > 0.0)
  {
    string target_suffix = "POSITION_" + execution_token + "_TP";
    string target_label = "FIXED TP";
    if(state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
      target_label += " CLOSE WAIT";

    if(PivotHftUpdateHorizontalLine(target_suffix,
                                    state.local_tp_price,
                                    COLOR_PROFIT_POSITIVE,
                                    STYLE_DASHDOT,
                                    2,
                                    StringFormat("%s %s %s %s %s @ %.5f",
                                                 execution_token,
                                                 direction_label,
                                                 retry_identity,
                                                 source_label,
                                                 target_label,
                                                 state.local_tp_price),
                                    false))
      PivotHftTrackDynamicVisual(current_objects,
                                 PivotHftVisualObjectName(target_suffix));
  }
}

void PivotHftDrawPendingRetry(const PivotHftPositionState &state,
                              string &current_objects[])
{
  if(state.status != PIVOT_HFT_POSITION_CLOSED ||
     !state.reattempt_pending ||
     (state.retry_state != PIVOT_HFT_RETRY_PENDING &&
      state.retry_state != PIVOT_HFT_RETRY_DEFERRED))
    return;

  string execution_token = PivotHftPositionExecutionId(state);
  if(execution_token == "" || execution_token == "-")
    return;

  string suffix = "RETRY_WAIT_" + execution_token;
  string label = StringFormat("RETRY %d %s %s | %s %s | reason=%s",
                              state.next_retry_number,
                              PivotHftExecutionSourceLabel(
                                state.next_retry_execution_source),
                              PivotHftRetryStateLabel(state.retry_state),
                              PivotHftDirectionToken(state.direction),
                              PivotHftLevelLabel(state.pivot_level),
                              state.retry_state_reason);
  color line_color = (state.retry_state == PIVOT_HFT_RETRY_DEFERRED)
                     ? clrOrangeRed
                     : clrOrange;
  if(PivotHftUpdateHorizontalLine(suffix,
                                  state.pivot_price,
                                  line_color,
                                  STYLE_DASHDOT,
                                  2,
                                  label,
                                  false))
    PivotHftTrackDynamicVisual(current_objects,
                               PivotHftVisualObjectName(suffix));
}

void PivotHftDrawPositions(string &current_objects[])
{
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftDrawPosition(g_pivot_hft_positions[i], current_objects);
    PivotHftDrawPendingRetry(g_pivot_hft_positions[i], current_objects);
  }
}

void PivotHftDeleteAllVisualObjects()
{
  ObjectsDeleteAll(ChartID(), PIVOT_HFT_OBJECT_PREFIX, 0, OBJ_HLINE);
  ObjectsDeleteAll(ChartID(), PIVOT_HFT_OBJECT_PREFIX, 0, OBJ_TREND);
}

void ClearFrontendVisualization()
{
  PivotHftDeleteAllVisualObjects();
  ClearPivotHftPanel();
  ArrayResize(g_pivot_hft_dynamic_visual_objects, 0);
  g_pivot_hft_visualization_visible = false;
  g_pivot_hft_visualization_initialized = false;
}

void RefreshPivotHftVisualization()
{
  if(!PivotHftVisualizationEnabledForRuntime())
  {
    if(g_pivot_hft_visualization_visible)
      ClearFrontendVisualization();
    return;
  }

  if(!g_pivot_hft_visualization_initialized)
  {
    PivotHftDeleteAllVisualObjects();
    g_pivot_hft_visualization_initialized = true;
  }

  g_pivot_hft_visualization_visible = true;
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_P,
                        "P",
                        g_pivot_hft_pivots.pivot,
                        clrGold,
                        STYLE_SOLID);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_R1,
                        "R1",
                        g_pivot_hft_pivots.resistance_1,
                        COLOR_CANDLE_BEAR,
                        STYLE_DASH);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_R2,
                        "R2",
                        g_pivot_hft_pivots.resistance_2,
                        COLOR_CANDLE_BEAR,
                        STYLE_DASH);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_R3,
                        "R3",
                        g_pivot_hft_pivots.resistance_3,
                        COLOR_CANDLE_BEAR,
                        STYLE_DOT);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_S1,
                        "S1",
                        g_pivot_hft_pivots.support_1,
                        COLOR_CANDLE_BULL,
                        STYLE_DASH);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_S2,
                        "S2",
                        g_pivot_hft_pivots.support_2,
                        COLOR_CANDLE_BULL,
                        STYLE_DASH);
  PivotHftDrawLevelLine(PIVOT_HFT_LEVEL_S3,
                        "S3",
                        g_pivot_hft_pivots.support_3,
                        COLOR_CANDLE_BULL,
                        STYLE_DOT);
  PivotHftUpdateHorizontalLine("BAND_UPPER",
                               g_pivot_hft_bands_upper,
                               clrSteelBlue,
                               STYLE_DOT,
                               1,
                               "BOLLINGER UPPER",
                               true);
  PivotHftUpdateHorizontalLine("BAND_LOWER",
                               g_pivot_hft_bands_lower,
                               clrSteelBlue,
                               STYLE_DOT,
                               1,
                               "BOLLINGER LOWER",
                               true);

  string current_objects[];
  PivotHftDrawBurnedLevelTests(current_objects);
  PivotHftDrawCampaign(current_objects);
  PivotHftDrawConcurrentTerminalCampaign(current_objects);
  PivotHftDrawPositions(current_objects);
  PivotHftSyncDynamicVisuals(current_objects);
  RefreshPivotHftPanel();
}

#endif // _SERVICES_FRONTEND_PIVOT_HFT_VISUALIZATION_MQH_
