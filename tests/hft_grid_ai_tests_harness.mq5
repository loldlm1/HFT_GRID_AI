#property script_show_inputs

#include "harness/cases/context_base_only_test_case.mqh"
#include "harness/cases/candle_structure_filter_test_case.mqh"
#include "harness/cases/candle_structure_shrinked_edges_test_case.mqh"
#include "harness/cases/addon_runtime_policy_test_case.mqh"
#include "harness/cases/fibonacci_cycled_levels_cases_test_case.mqh"
#include "harness/cases/frontend_runtime_guard_test_case.mqh"
#include "harness/cases/fibonacci_grid_percent_test_case.mqh"
#include "harness/cases/fibonacci_negative_label_test_case.mqh"
#include "harness/cases/grid_order_lifecycle_level_stop_limit_test_case.mqh"
#include "harness/cases/grid_target_profit_math_test_case.mqh"
#include "harness/cases/grid_visual_label_format_test_case.mqh"
#include "harness/cases/lightweight_status_layout_test_case.mqh"
#include "harness/cases/license_service_facade_test_case.mqh"
#include "harness/cases/license_error_policy_test_case.mqh"
#include "harness/cases/signal_lot_strategy_test_case.mqh"
#include "harness/cases/support_resistance_retest_chain_test_case.mqh"
#include "harness/cases/support_resistance_signal_gate_test_case.mqh"
#include "harness/cases/structure_classifier_types_test_case.mqh"
#include "harness/cases/structure_context_requirements_test_case.mqh"
#include "harness/cases/structure_entry_trigger_test_case.mqh"
#include "harness/cases/structure_fibonacci_entry_levels_test_case.mqh"
#include "harness/cases/structure_fibonacci_entry_price_test_case.mqh"
#include "harness/cases/structure_compound_modes_test_case.mqh"
#include "harness/cases/structure_fibonacci_levels_test_case.mqh"
#include "harness/cases/structure_fibonacci_orientation_test_case.mqh"
#include "harness/cases/structure_fibonacci_strict_range_test_case.mqh"
#include "harness/cases/structure_snapshot_time_test_case.mqh"
#include "harness/cases/structure_trailing_logic_test_case.mqh"
#include "harness/cases/structure_touch_policy_test_case.mqh"

string HarnessCompactErrors(const string raw_errors)
{
  string compact = raw_errors;
  StringReplace(compact, "\r", "");
  StringReplace(compact, "\n", " | ");

  while(StringFind(compact, " |  | ") >= 0)
    StringReplace(compact, " |  | ", " | ");

  while(StringLen(compact) >= 3 && StringSubstr(compact, StringLen(compact) - 3, 3) == " | ")
    compact = StringSubstr(compact, 0, StringLen(compact) - 3);

  return compact;
}

void HarnessRecordResult(const string test_name,
                         const bool passed,
                         const string errors,
                         int &passed_count,
                         int &failed_count,
                         int &total_count)
{
  total_count++;
  Print("TEST_START: ", test_name);

  if(passed)
  {
    passed_count++;
    Print("TEST_PASS: ", test_name);
    return;
  }

  failed_count++;
  Print("TEST_FAIL: ", test_name);

  string compact = HarnessCompactErrors(errors);
  if(compact != "")
    Print("TEST_FAIL_DETAILS: ", test_name, " | ", compact);
}

void OnStart()
{
  int total_count = 0;
  int passed_count = 0;
  int failed_count = 0;
  string errors = "";

  HarnessRecordResult("context_base_only_test",
                      RunTest_context_base_only_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("candle_structure_filter_test",
                      RunTest_candle_structure_filter_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("candle_structure_shrinked_edges_test",
                      RunTest_candle_structure_shrinked_edges_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("addon_runtime_policy_test",
                      RunTest_addon_runtime_policy_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("fibonacci_cycled_levels_cases_test",
                      RunTest_fibonacci_cycled_levels_cases_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("frontend_runtime_guard_test",
                      RunTest_frontend_runtime_guard_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("fibonacci_grid_percent_test",
                      RunTest_fibonacci_grid_percent_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("fibonacci_negative_label_test",
                      RunTest_fibonacci_negative_label_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("grid_order_lifecycle_level_stop_limit_test",
                      RunTest_grid_order_lifecycle_level_stop_limit_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("grid_target_profit_math_test",
                      RunTest_grid_target_profit_math_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("grid_visual_label_format_test",
                      RunTest_grid_visual_label_format_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("lightweight_status_layout_test",
                      RunTest_lightweight_status_layout_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("license_service_facade_test",
                      RunTest_license_service_facade_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("license_error_policy_test",
                      RunTest_license_error_policy_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("signal_lot_strategy_test",
                      RunTest_signal_lot_strategy_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("support_resistance_retest_chain_test",
                      RunTest_support_resistance_retest_chain_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("support_resistance_signal_gate_test",
                      RunTest_support_resistance_signal_gate_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_classifier_types_test",
                      RunTest_structure_classifier_types_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_context_requirements_test",
                      RunTest_structure_context_requirements_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_entry_trigger_test",
                      RunTest_structure_entry_trigger_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_fibonacci_entry_levels_test",
                      RunTest_structure_fibonacci_entry_levels_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_fibonacci_entry_price_test",
                      RunTest_structure_fibonacci_entry_price_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_compound_modes_test",
                      RunTest_structure_compound_modes_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_fibonacci_levels_test",
                      RunTest_structure_fibonacci_levels_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_fibonacci_orientation_test",
                      RunTest_structure_fibonacci_orientation_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_fibonacci_strict_range_test",
                      RunTest_structure_fibonacci_strict_range_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_snapshot_time_test",
                      RunTest_structure_snapshot_time_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_trailing_logic_test",
                      RunTest_structure_trailing_logic_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  HarnessRecordResult("structure_touch_policy_test",
                      RunTest_structure_touch_policy_test(errors),
                      errors,
                      passed_count,
                      failed_count,
                      total_count);

  PrintFormat("HARNESS_SUMMARY: passed=%d failed=%d total=%d",
              passed_count,
              failed_count,
              total_count);

  if(failed_count == 0)
    Print("HARNESS_PASS");
  else
    Print("HARNESS_FAIL");
}
