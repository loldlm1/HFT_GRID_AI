#ifndef HFT_GRID_AI_TEST_CASE_LIGHTWEIGHT_STATUS_LAYOUT_MQH
#define HFT_GRID_AI_TEST_CASE_LIGHTWEIGHT_STATUS_LAYOUT_MQH

#include "../framework.mqh"

bool RunTest_lightweight_status_layout_test(string &errors)
{
  errors = "";

  LightweightUiChartSnapshot wide_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(1280, 720, wide_snapshot);

  if(ResolveLightweightUiProfile(wide_snapshot) != LIGHTWEIGHT_UI_PROFILE_FULL)
    errors += "wide chart should use full profile\n";

  LightweightUiLayoutMetrics wide_layout;
  ResolveLightweightUiLayoutMetricsForProfile(wide_snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_FULL,
                                              false,
                                              false,
                                              wide_layout);

  if(wide_layout.panel_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH)
    errors += "full layout width should respect max bound\n";
  if(wide_layout.panel_x != LIGHTWEIGHT_UI_DEFAULT_PANEL_X)
    errors += "wide layout should keep default panel margin\n";
  if(ResolveLightweightUiRowBudget(wide_snapshot, wide_layout) < 10)
    errors += "wide layout should preserve a generous row budget\n";
  if(ShouldShowLightweightUiDetailsButton(wide_layout.profile, true))
    errors += "full profile should not show compact details button\n";

  string clamped_row = BuildLightweightUiRowText("Purchased Addons",
                                                 "Candle Structure Filter, Compound Breakout Ready",
                                                 34);
  if(StringLen(clamped_row) > 34)
    errors += "row builder should clamp total row width, not only the value text\n";

  LightweightUiChartSnapshot compact_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(420, 320, compact_snapshot);

  if(ResolveLightweightUiProfile(compact_snapshot) != LIGHTWEIGHT_UI_PROFILE_COMPACT)
    errors += "narrow chart should use compact profile\n";

  LightweightUiLayoutMetrics compact_layout;
  ResolveLightweightUiLayoutMetricsForProfile(compact_snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_COMPACT,
                                              false,
                                              false,
                                              compact_layout);

  if(compact_layout.panel_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH_COMPACT)
    errors += "compact layout width should respect compact max bound\n";
  if(compact_layout.font_size != LIGHTWEIGHT_UI_COMPACT_FONT_SIZE)
    errors += "compact layout should reduce font size\n";
  if(compact_layout.button_h != LIGHTWEIGHT_UI_COMPACT_BUTTON_H)
    errors += "compact layout should reduce button height\n";
  if(!ShouldShowLightweightUiDetailsButton(compact_layout.profile, true))
    errors += "compact layout should allow details button when rows are hidden\n";
  if(ShouldShowLightweightUiDetailsButton(compact_layout.profile, false))
    errors += "details button should stay hidden without hidden rows\n";
  if(ResolveLightweightUiCompactSignalRowLimit(3, false) != 1)
    errors += "compact summary should keep one live signal row by default\n";
  if(ResolveLightweightUiCompactSignalRowLimit(3, true) != 3)
    errors += "details-expanded compact summary should expose all signal rows\n";

  LightweightUiChartSnapshot extreme_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(320, 220, extreme_snapshot);

  LightweightUiLayoutMetrics extreme_layout;
  ResolveLightweightUiLayoutMetricsForProfile(extreme_snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_COMPACT,
                                              false,
                                              true,
                                              extreme_layout);

  if(!extreme_layout.reduced_margins)
    errors += "extreme chart should reduce panel margins\n";
  if(extreme_layout.panel_x != LIGHTWEIGHT_UI_EXTREME_PANEL_X)
    errors += "extreme chart should use emergency x margin\n";
  if(extreme_layout.panel_width > extreme_snapshot.chart_width - extreme_layout.panel_x * 2)
    errors += "extreme layout width should fit inside the chart bounds\n";
  if(extreme_layout.first_row_offset <= compact_layout.first_row_offset)
    errors += "details button should move compact content lower\n";

  LightweightUiFitInputs safe_inputs;
  safe_inputs.total_candidate_rows = 10;
  safe_inputs.longest_row_chars = 46;
  safe_inputs.over_budget_rows = 0;
  safe_inputs.signal_detail_rows = 0;
  safe_inputs.full_panel_width = wide_layout.panel_width;
  safe_inputs.full_row_max_chars = wide_layout.max_row_chars;
  safe_inputs.full_at_min_width = IsLightweightUiPanelAtMinWidth(wide_layout);

  LightweightUiFitDecision safe_decision;
  ResolveLightweightUiFitDecision(wide_snapshot, safe_inputs, safe_decision);
  if(safe_decision.profile != LIGHTWEIGHT_UI_PROFILE_FULL || safe_decision.pressured)
    errors += "wide chart with safe content should remain relaxed full\n";

  LightweightUiChartSnapshot pressured_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(1115, 1196, pressured_snapshot);

  LightweightUiLayoutMetrics pressured_layout;
  ResolveLightweightUiLayoutMetricsForProfile(pressured_snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_FULL,
                                              false,
                                              false,
                                              pressured_layout);

  LightweightUiFitInputs pressured_inputs;
  pressured_inputs.total_candidate_rows = 14;
  pressured_inputs.longest_row_chars = 68;
  pressured_inputs.over_budget_rows = 2;
  pressured_inputs.signal_detail_rows = 2;
  pressured_inputs.full_panel_width = pressured_layout.panel_width;
  pressured_inputs.full_row_max_chars = pressured_layout.max_row_chars;
  pressured_inputs.full_at_min_width = IsLightweightUiPanelAtMinWidth(pressured_layout);

  LightweightUiFitDecision pressured_decision;
  ResolveLightweightUiFitDecision(pressured_snapshot, pressured_inputs, pressured_decision);
  if(pressured_decision.profile != LIGHTWEIGHT_UI_PROFILE_FULL || !pressured_decision.pressured)
    errors += "medium-width dense windows snapshot should enter pressured full mode\n";

  LightweightUiChartSnapshot windows_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(628, 1196, windows_snapshot);

  LightweightUiLayoutMetrics windows_layout;
  ResolveLightweightUiLayoutMetricsForProfile(windows_snapshot,
                                              LIGHTWEIGHT_UI_PROFILE_FULL,
                                              false,
                                              false,
                                              windows_layout);

  LightweightUiFitInputs windows_inputs;
  windows_inputs.total_candidate_rows = 14;
  windows_inputs.longest_row_chars = 90;
  windows_inputs.over_budget_rows = 4;
  windows_inputs.signal_detail_rows = 2;
  windows_inputs.full_panel_width = windows_layout.panel_width;
  windows_inputs.full_row_max_chars = windows_layout.max_row_chars;
  windows_inputs.full_at_min_width = IsLightweightUiPanelAtMinWidth(windows_layout);

  LightweightUiFitDecision windows_decision;
  ResolveLightweightUiFitDecision(windows_snapshot, windows_inputs, windows_decision);
  if(windows_decision.profile != LIGHTWEIGHT_UI_PROFILE_COMPACT)
    errors += "minimum-width dense windows snapshot should force compact mode\n";
  if(windows_decision.fit_reason != LIGHTWEIGHT_UI_FIT_REASON_COMPACT_MIN_WIDTH_DENSE &&
     windows_decision.fit_reason != LIGHTWEIGHT_UI_FIT_REASON_COMPACT_WIDTH_OVERFLOW)
    errors += "forced compact decision should expose a compact fit reason\n";

  LightweightUiChartSnapshot wine_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(444, 359, wine_snapshot);

  LightweightUiFitInputs wine_inputs;
  wine_inputs.total_candidate_rows = 9;
  wine_inputs.longest_row_chars = 43;
  wine_inputs.over_budget_rows = 1;
  wine_inputs.signal_detail_rows = 0;
  wine_inputs.full_panel_width = 0;
  wine_inputs.full_row_max_chars = 0;
  wine_inputs.full_at_min_width = false;

  LightweightUiFitDecision wine_decision;
  ResolveLightweightUiFitDecision(wine_snapshot, wine_inputs, wine_decision);
  if(wine_decision.profile != LIGHTWEIGHT_UI_PROFILE_COMPACT ||
     wine_decision.fit_reason != LIGHTWEIGHT_UI_FIT_REASON_DIMENSION_COMPACT)
    errors += "dimension-based compact snapshot should stay compact\n";

  if(!HasLightweightUiMajorChartChange(compact_snapshot, extreme_snapshot))
    errors += "material chart resize should invalidate layout\n";
  if(HasLightweightUiMajorChartChange(compact_snapshot, compact_snapshot))
    errors += "identical chart snapshot should not trigger layout invalidation\n";

  return (errors == "");
}

#endif
