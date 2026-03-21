#ifndef _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_LAYOUT_MQH_
#define _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_LAYOUT_MQH_

enum LightweightUiProfiles
{
  LIGHTWEIGHT_UI_PROFILE_FULL = 0,
  LIGHTWEIGHT_UI_PROFILE_COMPACT = 1
};

enum LightweightUiFitReasons
{
  LIGHTWEIGHT_UI_FIT_REASON_DIMENSION_COMPACT = 0,
  LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE = 1,
  LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_DENSITY = 2,
  LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_TEXT_FIT = 3,
  LIGHTWEIGHT_UI_FIT_REASON_COMPACT_MIN_WIDTH_DENSE = 4,
  LIGHTWEIGHT_UI_FIT_REASON_COMPACT_WIDTH_OVERFLOW = 5,
  LIGHTWEIGHT_UI_FIT_REASON_COMPACT_SIGNAL_DENSITY = 6
};

const string LIGHTWEIGHT_UI_FONT_NAME = "Tahoma";

const int LIGHTWEIGHT_UI_DEFAULT_PANEL_X = 8;
const int LIGHTWEIGHT_UI_DEFAULT_PANEL_Y = 24;
const int LIGHTWEIGHT_UI_COMPACT_PANEL_X = 6;
const int LIGHTWEIGHT_UI_COMPACT_PANEL_Y = 18;
const int LIGHTWEIGHT_UI_EXTREME_PANEL_X = 4;
const int LIGHTWEIGHT_UI_EXTREME_PANEL_Y = 12;

const int LIGHTWEIGHT_UI_DEFAULT_PADDING_X = 10;
const int LIGHTWEIGHT_UI_DEFAULT_PADDING_Y = 6;
const int LIGHTWEIGHT_UI_COMPACT_PADDING_X = 8;
const int LIGHTWEIGHT_UI_COMPACT_PADDING_Y = 5;

const int LIGHTWEIGHT_UI_PANEL_MIN_WIDTH = 260;
const int LIGHTWEIGHT_UI_PANEL_MAX_WIDTH = 520;
const int LIGHTWEIGHT_UI_PANEL_MIN_WIDTH_COMPACT = 180;
const int LIGHTWEIGHT_UI_PANEL_MAX_WIDTH_COMPACT = 360;

const int LIGHTWEIGHT_UI_FULL_FONT_SIZE = 8;
const int LIGHTWEIGHT_UI_COMPACT_FONT_SIZE = 7;
const int LIGHTWEIGHT_UI_FULL_BUTTON_FONT_SIZE = 8;
const int LIGHTWEIGHT_UI_COMPACT_BUTTON_FONT_SIZE = 7;
const int LIGHTWEIGHT_UI_FULL_ROW_STEP = 15;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_ROW_STEP = 16;
const int LIGHTWEIGHT_UI_COMPACT_ROW_STEP = 14;
const int LIGHTWEIGHT_UI_FULL_BUTTON_H = 20;
const int LIGHTWEIGHT_UI_COMPACT_BUTTON_H = 18;
const int LIGHTWEIGHT_UI_DETAILS_BUTTON_H = 16;
const int LIGHTWEIGHT_UI_FULL_BUTTON_TOP_OFFSET = 6;
const int LIGHTWEIGHT_UI_COMPACT_BUTTON_TOP_OFFSET = 5;
const int LIGHTWEIGHT_UI_BUTTON_GAP_Y = 6;
const int LIGHTWEIGHT_UI_DETAILS_BUTTON_GAP_Y = 4;
const int LIGHTWEIGHT_UI_FULL_MAX_ROWS = 18;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_MAX_ROWS = 16;
const int LIGHTWEIGHT_UI_COMPACT_MAX_ROWS = 12;
const int LIGHTWEIGHT_UI_FULL_MAX_VALUE_CHARS = 64;
const int LIGHTWEIGHT_UI_COMPACT_MAX_VALUE_CHARS = 40;
const int LIGHTWEIGHT_UI_FULL_CHAR_WIDTH_EST = 6;
const int LIGHTWEIGHT_UI_COMPACT_CHAR_WIDTH_EST = 5;
const int LIGHTWEIGHT_UI_ROW_CHAR_PADDING = 8;
const int LIGHTWEIGHT_UI_ROW_VALUE_LABEL_RESERVE = 14;
const int LIGHTWEIGHT_UI_LAYOUT_CHANGE_DELTA = 12;
const int LIGHTWEIGHT_UI_MIN_ROWS_VISIBLE = 5;
const int LIGHTWEIGHT_UI_BOTTOM_MARGIN = 16;
const int LIGHTWEIGHT_UI_CHART_COMPACT_WIDTH_THRESHOLD = 520;
const int LIGHTWEIGHT_UI_CHART_COMPACT_HEIGHT_THRESHOLD = 340;
const int LIGHTWEIGHT_UI_CHART_EXTREME_WIDTH_THRESHOLD = 360;
const int LIGHTWEIGHT_UI_CHART_EXTREME_HEIGHT_THRESHOLD = 250;
const int LIGHTWEIGHT_UI_CHART_FALLBACK_WIDTH = 960;
const int LIGHTWEIGHT_UI_CHART_FALLBACK_HEIGHT = 640;
const int LIGHTWEIGHT_UI_FULL_PRESSURE_PANEL_WIDTH_THRESHOLD = 360;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_PANEL_WIDTH_THRESHOLD = 300;
const int LIGHTWEIGHT_UI_FULL_PRESSURE_ROW_CHARS_THRESHOLD = 46;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_ROW_CHARS_THRESHOLD = 34;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_ROW_COUNT = 11;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_ROW_COUNT = 13;
const int LIGHTWEIGHT_UI_MIN_WIDTH_FORCE_COMPACT_ROW_COUNT = 11;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_OVERFLOW_ROWS = 1;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_OVERFLOW_ROWS = 3;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_LONG_ROW_OVERAGE = 8;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_LONG_ROW_OVERAGE = 14;
const int LIGHTWEIGHT_UI_FULL_PRESSURED_SIGNAL_ROWS = 2;
const int LIGHTWEIGHT_UI_FORCE_COMPACT_SIGNAL_ROWS = 2;
const int LIGHTWEIGHT_UI_FULL_MIN_WIDTH_EPSILON = 4;

struct LightweightUiChartSnapshot
{
  int chart_width;
  int chart_height;
  bool valid;

  LightweightUiChartSnapshot()
    : chart_width(0),
      chart_height(0),
      valid(false)
  {
  }

  LightweightUiChartSnapshot(const LightweightUiChartSnapshot &other)
    : chart_width(other.chart_width),
      chart_height(other.chart_height),
      valid(other.valid)
  {
  }
};

struct LightweightUiFitInputs
{
  int total_candidate_rows;
  int longest_row_chars;
  int over_budget_rows;
  int signal_detail_rows;
  int full_panel_width;
  int full_row_max_chars;
  bool full_at_min_width;

  LightweightUiFitInputs()
    : total_candidate_rows(0),
      longest_row_chars(0),
      over_budget_rows(0),
      signal_detail_rows(0),
      full_panel_width(0),
      full_row_max_chars(0),
      full_at_min_width(false)
  {
  }

  LightweightUiFitInputs(const LightweightUiFitInputs &other)
    : total_candidate_rows(other.total_candidate_rows),
      longest_row_chars(other.longest_row_chars),
      over_budget_rows(other.over_budget_rows),
      signal_detail_rows(other.signal_detail_rows),
      full_panel_width(other.full_panel_width),
      full_row_max_chars(other.full_row_max_chars),
      full_at_min_width(other.full_at_min_width)
  {
  }
};

struct LightweightUiFitDecision
{
  LightweightUiProfiles profile;
  bool pressured;
  int fit_reason;
  int total_candidate_rows;
  int longest_row_chars;
  int over_budget_rows;
  int signal_detail_rows;
  int full_panel_width;
  int full_row_max_chars;
  bool full_at_min_width;

  LightweightUiFitDecision()
    : profile(LIGHTWEIGHT_UI_PROFILE_FULL),
      pressured(false),
      fit_reason(LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE),
      total_candidate_rows(0),
      longest_row_chars(0),
      over_budget_rows(0),
      signal_detail_rows(0),
      full_panel_width(0),
      full_row_max_chars(0),
      full_at_min_width(false)
  {
  }

  LightweightUiFitDecision(const LightweightUiFitDecision &other)
    : profile(other.profile),
      pressured(other.pressured),
      fit_reason(other.fit_reason),
      total_candidate_rows(other.total_candidate_rows),
      longest_row_chars(other.longest_row_chars),
      over_budget_rows(other.over_budget_rows),
      signal_detail_rows(other.signal_detail_rows),
      full_panel_width(other.full_panel_width),
      full_row_max_chars(other.full_row_max_chars),
      full_at_min_width(other.full_at_min_width)
  {
  }
};

struct LightweightUiLayoutMetrics
{
  LightweightUiProfiles profile;
  int panel_x;
  int panel_y;
  int panel_padding_x;
  int panel_padding_y;
  int panel_width;
  int button_h;
  int button_top_offset;
  int button_font_size;
  int details_button_h;
  int row_step;
  int font_size;
  int max_rows;
  int max_value_chars_limit;
  int max_value_chars;
  int max_row_chars;
  int char_width_est;
  int first_row_offset;
  bool pressured;
  bool reduced_margins;
  bool show_details_button;
  int fit_reason;
  string font_name;

  LightweightUiLayoutMetrics()
    : profile(LIGHTWEIGHT_UI_PROFILE_FULL),
      panel_x(LIGHTWEIGHT_UI_DEFAULT_PANEL_X),
      panel_y(LIGHTWEIGHT_UI_DEFAULT_PANEL_Y),
      panel_padding_x(LIGHTWEIGHT_UI_DEFAULT_PADDING_X),
      panel_padding_y(LIGHTWEIGHT_UI_DEFAULT_PADDING_Y),
      panel_width(LIGHTWEIGHT_UI_PANEL_MIN_WIDTH),
      button_h(LIGHTWEIGHT_UI_FULL_BUTTON_H),
      button_top_offset(LIGHTWEIGHT_UI_FULL_BUTTON_TOP_OFFSET),
      button_font_size(LIGHTWEIGHT_UI_FULL_BUTTON_FONT_SIZE),
      details_button_h(LIGHTWEIGHT_UI_DETAILS_BUTTON_H),
      row_step(LIGHTWEIGHT_UI_FULL_ROW_STEP),
      font_size(LIGHTWEIGHT_UI_FULL_FONT_SIZE),
      max_rows(LIGHTWEIGHT_UI_FULL_MAX_ROWS),
      max_value_chars_limit(LIGHTWEIGHT_UI_FULL_MAX_VALUE_CHARS),
      max_value_chars(LIGHTWEIGHT_UI_FULL_MAX_VALUE_CHARS),
      max_row_chars(0),
      char_width_est(LIGHTWEIGHT_UI_FULL_CHAR_WIDTH_EST),
      first_row_offset(0),
      pressured(false),
      reduced_margins(false),
      show_details_button(false),
      fit_reason(LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE),
      font_name(LIGHTWEIGHT_UI_FONT_NAME)
  {
  }

  LightweightUiLayoutMetrics(const LightweightUiLayoutMetrics &other)
    : profile(other.profile),
      panel_x(other.panel_x),
      panel_y(other.panel_y),
      panel_padding_x(other.panel_padding_x),
      panel_padding_y(other.panel_padding_y),
      panel_width(other.panel_width),
      button_h(other.button_h),
      button_top_offset(other.button_top_offset),
      button_font_size(other.button_font_size),
      details_button_h(other.details_button_h),
      row_step(other.row_step),
      font_size(other.font_size),
      max_rows(other.max_rows),
      max_value_chars_limit(other.max_value_chars_limit),
      max_value_chars(other.max_value_chars),
      max_row_chars(other.max_row_chars),
      char_width_est(other.char_width_est),
      first_row_offset(other.first_row_offset),
      pressured(other.pressured),
      reduced_margins(other.reduced_margins),
      show_details_button(other.show_details_button),
      fit_reason(other.fit_reason),
      font_name(other.font_name)
  {
  }
};

string ClampLightweightUiText(const string text,
                              const int max_chars)
{
  if(max_chars < 4)
    return text;

  int len = StringLen(text);
  if(len <= max_chars)
    return text;

  return StringSubstr(text, 0, max_chars - 3) + "...";
}

string BuildLightweightUiRowText(const string label,
                                 const string value,
                                 const int max_row_chars)
{
  string prefix = label + ": ";
  string full_text = prefix + value;

  if(max_row_chars < 4)
    return full_text;
  if(StringLen(full_text) <= max_row_chars)
    return full_text;

  int value_budget = max_row_chars - StringLen(prefix);
  if(value_budget >= 8)
    return prefix + ClampLightweightUiText(value, value_budget);

  return ClampLightweightUiText(full_text, max_row_chars);
}

void ResolveLightweightUiChartSnapshotFromDimensions(const int chart_width,
                                                     const int chart_height,
                                                     LightweightUiChartSnapshot &snapshot)
{
  snapshot.chart_width = chart_width;
  snapshot.chart_height = chart_height;
  snapshot.valid = (chart_width > 0 && chart_height > 0);

  if(snapshot.chart_width <= 0)
    snapshot.chart_width = LIGHTWEIGHT_UI_CHART_FALLBACK_WIDTH;
  if(snapshot.chart_height <= 0)
    snapshot.chart_height = LIGHTWEIGHT_UI_CHART_FALLBACK_HEIGHT;
}

void ResolveLightweightUiChartSnapshot(const long chart_id,
                                       LightweightUiChartSnapshot &snapshot)
{
  long chart_width = 0;
  long chart_height = 0;

  bool width_ok = ChartGetInteger(chart_id, CHART_WIDTH_IN_PIXELS, 0, chart_width);
  bool height_ok = ChartGetInteger(chart_id, CHART_HEIGHT_IN_PIXELS, 0, chart_height);

  ResolveLightweightUiChartSnapshotFromDimensions((width_ok ? (int)chart_width : 0),
                                                  (height_ok ? (int)chart_height : 0),
                                                  snapshot);
}

LightweightUiProfiles ResolveLightweightUiDimensionProfile(const LightweightUiChartSnapshot &snapshot)
{
  if(snapshot.chart_width < LIGHTWEIGHT_UI_CHART_COMPACT_WIDTH_THRESHOLD)
    return LIGHTWEIGHT_UI_PROFILE_COMPACT;
  if(snapshot.chart_height < LIGHTWEIGHT_UI_CHART_COMPACT_HEIGHT_THRESHOLD)
    return LIGHTWEIGHT_UI_PROFILE_COMPACT;
  return LIGHTWEIGHT_UI_PROFILE_FULL;
}

LightweightUiProfiles ResolveLightweightUiProfile(const LightweightUiChartSnapshot &snapshot)
{
  return ResolveLightweightUiDimensionProfile(snapshot);
}

bool IsLightweightUiCompactProfile(const LightweightUiProfiles profile)
{
  return (profile == LIGHTWEIGHT_UI_PROFILE_COMPACT);
}

bool IsLightweightUiExtremeChart(const LightweightUiChartSnapshot &snapshot)
{
  if(snapshot.chart_width < LIGHTWEIGHT_UI_CHART_EXTREME_WIDTH_THRESHOLD)
    return true;
  if(snapshot.chart_height < LIGHTWEIGHT_UI_CHART_EXTREME_HEIGHT_THRESHOLD)
    return true;
  return false;
}

int ResolveLightweightUiPanelWidth(const LightweightUiChartSnapshot &snapshot,
                                   const LightweightUiProfiles profile,
                                   const int panel_x)
{
  int available_width = snapshot.chart_width - panel_x * 2;
  if(available_width < 140)
    available_width = 140;

  int target_width = available_width;
  if(IsLightweightUiCompactProfile(profile))
  {
    target_width = (snapshot.chart_width * 44) / 100;
    if(target_width < LIGHTWEIGHT_UI_PANEL_MIN_WIDTH_COMPACT)
      target_width = LIGHTWEIGHT_UI_PANEL_MIN_WIDTH_COMPACT;
    if(target_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH_COMPACT)
      target_width = LIGHTWEIGHT_UI_PANEL_MAX_WIDTH_COMPACT;
  }
  else
  {
    target_width = (snapshot.chart_width * 32) / 100;
    if(target_width < LIGHTWEIGHT_UI_PANEL_MIN_WIDTH)
      target_width = LIGHTWEIGHT_UI_PANEL_MIN_WIDTH;
    if(target_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH)
      target_width = LIGHTWEIGHT_UI_PANEL_MAX_WIDTH;
  }

  if(target_width > available_width)
    target_width = available_width;
  if(target_width < 140)
    target_width = 140;

  return target_width;
}

int ResolveLightweightUiRowMaxChars(const LightweightUiLayoutMetrics &metrics)
{
  int content_width = metrics.panel_width - metrics.panel_padding_x * 2;
  if(content_width < 72)
    content_width = 72;

  int max_chars = (content_width / metrics.char_width_est) - LIGHTWEIGHT_UI_ROW_CHAR_PADDING;
  if(max_chars < 18)
    max_chars = 18;

  int row_cap = metrics.max_value_chars_limit + LIGHTWEIGHT_UI_ROW_VALUE_LABEL_RESERVE;
  if(max_chars > row_cap)
    max_chars = row_cap;

  return max_chars;
}

int ResolveLightweightUiValueMaxChars(const LightweightUiLayoutMetrics &metrics)
{
  int max_chars = metrics.max_row_chars - LIGHTWEIGHT_UI_ROW_VALUE_LABEL_RESERVE;
  if(max_chars < 12)
    max_chars = 12;
  if(max_chars > metrics.max_value_chars_limit)
    max_chars = metrics.max_value_chars_limit;
  return max_chars;
}

bool IsLightweightUiPanelAtMinWidth(const LightweightUiLayoutMetrics &metrics)
{
  if(IsLightweightUiCompactProfile(metrics.profile))
    return (metrics.panel_width <= LIGHTWEIGHT_UI_PANEL_MIN_WIDTH_COMPACT + LIGHTWEIGHT_UI_FULL_MIN_WIDTH_EPSILON);

  return (metrics.panel_width <= LIGHTWEIGHT_UI_PANEL_MIN_WIDTH + LIGHTWEIGHT_UI_FULL_MIN_WIDTH_EPSILON);
}

void ResolveLightweightUiLayoutMetricsForProfile(const LightweightUiChartSnapshot &snapshot,
                                                 const LightweightUiProfiles profile,
                                                 const bool pressured,
                                                 const bool show_details_button,
                                                 LightweightUiLayoutMetrics &metrics)
{
  metrics.profile = profile;
  metrics.pressured = pressured;
  metrics.show_details_button = (show_details_button && IsLightweightUiCompactProfile(metrics.profile));
  metrics.reduced_margins = false;
  metrics.font_name = LIGHTWEIGHT_UI_FONT_NAME;
  metrics.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE;

  if(IsLightweightUiCompactProfile(metrics.profile))
  {
    metrics.panel_x = LIGHTWEIGHT_UI_COMPACT_PANEL_X;
    metrics.panel_y = LIGHTWEIGHT_UI_COMPACT_PANEL_Y;
    metrics.panel_padding_x = LIGHTWEIGHT_UI_COMPACT_PADDING_X;
    metrics.panel_padding_y = LIGHTWEIGHT_UI_COMPACT_PADDING_Y;
    metrics.button_h = LIGHTWEIGHT_UI_COMPACT_BUTTON_H;
    metrics.button_top_offset = LIGHTWEIGHT_UI_COMPACT_BUTTON_TOP_OFFSET;
    metrics.button_font_size = LIGHTWEIGHT_UI_COMPACT_BUTTON_FONT_SIZE;
    metrics.row_step = LIGHTWEIGHT_UI_COMPACT_ROW_STEP;
    metrics.font_size = LIGHTWEIGHT_UI_COMPACT_FONT_SIZE;
    metrics.max_rows = LIGHTWEIGHT_UI_COMPACT_MAX_ROWS;
    metrics.max_value_chars_limit = LIGHTWEIGHT_UI_COMPACT_MAX_VALUE_CHARS;
    metrics.char_width_est = LIGHTWEIGHT_UI_COMPACT_CHAR_WIDTH_EST;
  }
  else
  {
    metrics.panel_x = LIGHTWEIGHT_UI_DEFAULT_PANEL_X;
    metrics.panel_y = LIGHTWEIGHT_UI_DEFAULT_PANEL_Y;
    metrics.panel_padding_x = LIGHTWEIGHT_UI_DEFAULT_PADDING_X;
    metrics.panel_padding_y = LIGHTWEIGHT_UI_DEFAULT_PADDING_Y;
    metrics.button_h = LIGHTWEIGHT_UI_FULL_BUTTON_H;
    metrics.button_top_offset = LIGHTWEIGHT_UI_FULL_BUTTON_TOP_OFFSET;
    metrics.button_font_size = LIGHTWEIGHT_UI_FULL_BUTTON_FONT_SIZE;
    metrics.row_step = (pressured ? LIGHTWEIGHT_UI_FULL_PRESSURED_ROW_STEP
                                  : LIGHTWEIGHT_UI_FULL_ROW_STEP);
    metrics.font_size = LIGHTWEIGHT_UI_FULL_FONT_SIZE;
    metrics.max_rows = (pressured ? LIGHTWEIGHT_UI_FULL_PRESSURED_MAX_ROWS
                                  : LIGHTWEIGHT_UI_FULL_MAX_ROWS);
    metrics.max_value_chars_limit = LIGHTWEIGHT_UI_FULL_MAX_VALUE_CHARS;
    metrics.char_width_est = LIGHTWEIGHT_UI_FULL_CHAR_WIDTH_EST;
  }

  if(IsLightweightUiExtremeChart(snapshot))
  {
    metrics.reduced_margins = true;
    metrics.panel_x = LIGHTWEIGHT_UI_EXTREME_PANEL_X;
    metrics.panel_y = LIGHTWEIGHT_UI_EXTREME_PANEL_Y;
  }

  metrics.panel_width = ResolveLightweightUiPanelWidth(snapshot,
                                                       metrics.profile,
                                                       metrics.panel_x);

  metrics.first_row_offset = metrics.button_top_offset +
                             metrics.button_h +
                             LIGHTWEIGHT_UI_BUTTON_GAP_Y;

  if(metrics.show_details_button)
  {
    metrics.first_row_offset += metrics.details_button_h +
                                LIGHTWEIGHT_UI_DETAILS_BUTTON_GAP_Y;
  }

  metrics.max_row_chars = ResolveLightweightUiRowMaxChars(metrics);
  metrics.max_value_chars = ResolveLightweightUiValueMaxChars(metrics);
}

void ResolveLightweightUiLayoutMetrics(const LightweightUiChartSnapshot &snapshot,
                                       const bool show_details_button,
                                       LightweightUiLayoutMetrics &metrics)
{
  ResolveLightweightUiLayoutMetricsForProfile(snapshot,
                                              ResolveLightweightUiDimensionProfile(snapshot),
                                              false,
                                              show_details_button,
                                              metrics);
}

void ResolveLightweightUiFitDecision(const LightweightUiChartSnapshot &snapshot,
                                     const LightweightUiFitInputs &inputs,
                                     LightweightUiFitDecision &decision)
{
  decision.profile = ResolveLightweightUiDimensionProfile(snapshot);
  decision.pressured = false;
  decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_SAFE;
  decision.total_candidate_rows = inputs.total_candidate_rows;
  decision.longest_row_chars = inputs.longest_row_chars;
  decision.over_budget_rows = inputs.over_budget_rows;
  decision.signal_detail_rows = inputs.signal_detail_rows;
  decision.full_panel_width = inputs.full_panel_width;
  decision.full_row_max_chars = inputs.full_row_max_chars;
  decision.full_at_min_width = inputs.full_at_min_width;

  if(IsLightweightUiCompactProfile(decision.profile))
  {
    decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_DIMENSION_COMPACT;
    return;
  }

  bool width_pressure = inputs.full_at_min_width ||
                        inputs.full_panel_width <= LIGHTWEIGHT_UI_FULL_PRESSURE_PANEL_WIDTH_THRESHOLD ||
                        inputs.full_row_max_chars <= LIGHTWEIGHT_UI_FULL_PRESSURE_ROW_CHARS_THRESHOLD;
  bool narrow_width_pressure = inputs.full_at_min_width ||
                               inputs.full_panel_width <= LIGHTWEIGHT_UI_FORCE_COMPACT_PANEL_WIDTH_THRESHOLD ||
                               inputs.full_row_max_chars <= LIGHTWEIGHT_UI_FORCE_COMPACT_ROW_CHARS_THRESHOLD;
  bool dense_rows = inputs.total_candidate_rows >= LIGHTWEIGHT_UI_FULL_PRESSURED_ROW_COUNT;
  bool overflow_pressure = inputs.over_budget_rows >= LIGHTWEIGHT_UI_FULL_PRESSURED_OVERFLOW_ROWS;
  bool long_row_pressure = inputs.longest_row_chars >
                           inputs.full_row_max_chars + LIGHTWEIGHT_UI_FULL_PRESSURED_LONG_ROW_OVERAGE;
  bool signal_pressure = inputs.signal_detail_rows >= LIGHTWEIGHT_UI_FULL_PRESSURED_SIGNAL_ROWS;
  bool density_pressure = (inputs.total_candidate_rows >= LIGHTWEIGHT_UI_FORCE_COMPACT_ROW_COUNT) ||
                          (dense_rows && (width_pressure || overflow_pressure || signal_pressure));

  bool force_compact_min_width = inputs.full_at_min_width &&
                                 (inputs.total_candidate_rows >= LIGHTWEIGHT_UI_MIN_WIDTH_FORCE_COMPACT_ROW_COUNT ||
                                  inputs.over_budget_rows >= LIGHTWEIGHT_UI_FULL_PRESSURED_OVERFLOW_ROWS);
  bool force_compact_overflow = narrow_width_pressure &&
                                (inputs.total_candidate_rows >= LIGHTWEIGHT_UI_FORCE_COMPACT_ROW_COUNT ||
                                 inputs.over_budget_rows >= LIGHTWEIGHT_UI_FORCE_COMPACT_OVERFLOW_ROWS ||
                                 inputs.longest_row_chars >
                                 inputs.full_row_max_chars + LIGHTWEIGHT_UI_FORCE_COMPACT_LONG_ROW_OVERAGE);
  bool force_compact_signals = narrow_width_pressure &&
                               inputs.signal_detail_rows >= LIGHTWEIGHT_UI_FORCE_COMPACT_SIGNAL_ROWS &&
                               inputs.total_candidate_rows >= LIGHTWEIGHT_UI_FULL_PRESSURED_ROW_COUNT;

  if(force_compact_min_width)
  {
    decision.profile = LIGHTWEIGHT_UI_PROFILE_COMPACT;
    decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_COMPACT_MIN_WIDTH_DENSE;
    return;
  }

  if(force_compact_overflow)
  {
    decision.profile = LIGHTWEIGHT_UI_PROFILE_COMPACT;
    decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_COMPACT_WIDTH_OVERFLOW;
    return;
  }

  if(force_compact_signals)
  {
    decision.profile = LIGHTWEIGHT_UI_PROFILE_COMPACT;
    decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_COMPACT_SIGNAL_DENSITY;
    return;
  }

  if(width_pressure || overflow_pressure || long_row_pressure || density_pressure || signal_pressure)
  {
    decision.pressured = true;
    if(density_pressure || signal_pressure)
      decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_DENSITY;
    else
      decision.fit_reason = LIGHTWEIGHT_UI_FIT_REASON_FULL_PRESSURED_TEXT_FIT;
  }
}

int ResolveLightweightUiPanelHeight(const LightweightUiLayoutMetrics &metrics,
                                    const int rows_total)
{
  int safe_rows_total = rows_total;
  if(safe_rows_total < 0)
    safe_rows_total = 0;

  return metrics.first_row_offset +
         safe_rows_total * metrics.row_step +
         metrics.panel_padding_y;
}

int ResolveLightweightUiRowBudget(const LightweightUiChartSnapshot &snapshot,
                                  const LightweightUiLayoutMetrics &metrics)
{
  int available_height = snapshot.chart_height -
                         metrics.panel_y -
                         metrics.panel_padding_y -
                         LIGHTWEIGHT_UI_BOTTOM_MARGIN;
  int row_area = available_height - metrics.first_row_offset;

  int row_budget = LIGHTWEIGHT_UI_MIN_ROWS_VISIBLE;
  if(row_area > 0 && metrics.row_step > 0)
    row_budget = row_area / metrics.row_step;

  if(row_budget < LIGHTWEIGHT_UI_MIN_ROWS_VISIBLE)
    row_budget = LIGHTWEIGHT_UI_MIN_ROWS_VISIBLE;
  if(row_budget > metrics.max_rows)
    row_budget = metrics.max_rows;

  return row_budget;
}

bool ShouldShowLightweightUiDetailsButton(const LightweightUiProfiles profile,
                                          const bool has_hidden_rows)
{
  if(!has_hidden_rows)
    return false;
  return IsLightweightUiCompactProfile(profile);
}

int ResolveLightweightUiCompactSignalRowLimit(const int summary_total,
                                              const bool details_visible)
{
  if(summary_total <= 0)
    return 0;
  if(details_visible)
    return summary_total;
  return 1;
}

bool HasLightweightUiMajorChartChange(const LightweightUiChartSnapshot &previous_snapshot,
                                      const LightweightUiChartSnapshot &current_snapshot)
{
  if(!previous_snapshot.valid)
    return true;
  if(!current_snapshot.valid)
    return true;

  LightweightUiProfiles previous_profile = ResolveLightweightUiDimensionProfile(previous_snapshot);
  LightweightUiProfiles current_profile = ResolveLightweightUiDimensionProfile(current_snapshot);
  if(previous_profile != current_profile)
    return true;

  int width_delta = MathAbs(current_snapshot.chart_width - previous_snapshot.chart_width);
  int height_delta = MathAbs(current_snapshot.chart_height - previous_snapshot.chart_height);

  if(width_delta >= LIGHTWEIGHT_UI_LAYOUT_CHANGE_DELTA)
    return true;
  if(height_delta >= LIGHTWEIGHT_UI_LAYOUT_CHANGE_DELTA)
    return true;
  return false;
}

#endif // _SERVICES_FRONTEND_LIGHTWEIGHT_STATUS_LAYOUT_MQH_
