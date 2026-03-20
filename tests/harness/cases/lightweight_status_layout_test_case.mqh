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
  ResolveLightweightUiLayoutMetrics(wide_snapshot, false, wide_layout);

  if(wide_layout.panel_width > LIGHTWEIGHT_UI_PANEL_MAX_WIDTH)
    errors += "full layout width should respect max bound\n";
  if(wide_layout.panel_x != LIGHTWEIGHT_UI_DEFAULT_PANEL_X)
    errors += "wide layout should keep default panel margin\n";
  if(ResolveLightweightUiRowBudget(wide_snapshot, wide_layout) < 10)
    errors += "wide layout should preserve a generous row budget\n";
  if(ShouldShowLightweightUiDetailsButton(wide_layout.profile, true))
    errors += "full profile should not show compact details button\n";

  LightweightUiChartSnapshot compact_snapshot;
  ResolveLightweightUiChartSnapshotFromDimensions(420, 320, compact_snapshot);

  if(ResolveLightweightUiProfile(compact_snapshot) != LIGHTWEIGHT_UI_PROFILE_COMPACT)
    errors += "narrow chart should use compact profile\n";

  LightweightUiLayoutMetrics compact_layout;
  ResolveLightweightUiLayoutMetrics(compact_snapshot, false, compact_layout);

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
  ResolveLightweightUiLayoutMetrics(extreme_snapshot, true, extreme_layout);

  if(!extreme_layout.reduced_margins)
    errors += "extreme chart should reduce panel margins\n";
  if(extreme_layout.panel_x != LIGHTWEIGHT_UI_EXTREME_PANEL_X)
    errors += "extreme chart should use emergency x margin\n";
  if(extreme_layout.panel_width > extreme_snapshot.chart_width - extreme_layout.panel_x * 2)
    errors += "extreme layout width should fit inside the chart bounds\n";
  if(extreme_layout.first_row_offset <= compact_layout.first_row_offset)
    errors += "details button should move compact content lower\n";

  if(!HasLightweightUiMajorChartChange(compact_snapshot, extreme_snapshot))
    errors += "material chart resize should invalidate layout\n";
  if(HasLightweightUiMajorChartChange(compact_snapshot, compact_snapshot))
    errors += "identical chart snapshot should not trigger layout invalidation\n";

  return (errors == "");
}

#endif
