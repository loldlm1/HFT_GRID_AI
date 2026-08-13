//+------------------------------------------------------------------+
//|              trading_signals/pivot_fractal_statistics_export   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_

const int PIVOT_V12_SCHEMA_VERSION = 12;
const string PIVOT_V12_ENGINE_LABEL = "PIVOT_FRACTAL_V2";
const string PIVOT_V12_FEATURE_SET_ID =
  "schema_v12_pivot_signal_features";
const string PIVOT_V12_STORAGE_ROOT = "PivotFractalV12";
const string PIVOT_V12_RUNS_FOLDER = "runs";
const string PIVOT_V12_NULL = "\\N";
const int PIVOT_V12_FLUSH_ROWS = 256;
const int PIVOT_V12_ORIGIN_STATE_RESERVE = 64;
const int PIVOT_V12_PARITY_LINK_RESERVE = 16;

const string PIVOT_V12_MANIFEST_FILE = "run_manifest.tsv";
const string PIVOT_V12_WINDOWS_FILE = "pivot_windows.tsv";
const string PIVOT_V12_ORIGINS_FILE = "signal_origins.tsv";
const string PIVOT_V12_TRIALS_FILE = "virtual_trials.tsv";
const string PIVOT_V12_VIRTUAL_OUTCOMES_FILE = "virtual_outcomes.tsv";
const string PIVOT_V12_CHECKS_FILE = "execution_checks.tsv";
const string PIVOT_V12_BROKER_OUTCOMES_FILE = "broker_outcomes.tsv";
const string PIVOT_V12_SUMMARY_FILE = "run_summary.tsv";

const string PIVOT_V12_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string PIVOT_V12_WINDOWS_HEADER =
  "schema_version\trun_id\tconfig_id\twindow_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tactive_bar_open_analysis_time\tactive_bar_open_offset_minutes\tsource_bar_open_broker_time\tsource_bar_open_analysis_time\tsource_bar_open_offset_minutes\tsource_close_boundary_broker_time\tsource_close_boundary_analysis_time\tsource_close_boundary_offset_minutes\tsource_open\tsource_high\tsource_low\tsource_close\tsource_range\traw_s3_price\traw_s2_price\traw_s1_price\traw_pp_price\traw_r1_price\traw_r2_price\traw_r3_price\ttrade_s3_price\ttrade_s2_price\ttrade_s1_price\ttrade_pp_price\ttrade_r1_price\ttrade_r2_price\ttrade_r3_price\tfirst_observed_broker_time\tfirst_observed_analysis_time\tfirst_observed_offset_minutes\tfirst_observed_bid\tpp_initial_relation\tpp_role\tpp_arm_broker_time\tpp_arm_analysis_time\tpp_arm_offset_minutes\tpp_arm_bid\twindow_state\tinvalid_reason\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status";
const string PIVOT_V12_ORIGINS_HEADER =
  "schema_version\trun_id\tconfig_id\torigin_id\twindow_id\tbroker_signal_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\ttrigger_bid\ttrigger_ask\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\traw_s3_price\traw_s2_price\traw_s1_price\traw_pp_price\traw_r1_price\traw_r2_price\traw_r3_price\ttrade_s3_price\ttrade_s2_price\ttrade_s1_price\ttrade_pp_price\ttrade_r1_price\ttrade_r2_price\ttrade_r3_price\tpivot_raw_price\tpivot_trade_price\tnext_outward_pivot_price\tstructural_entry_price\tstructural_sl_price\tstructural_take_profit\torigin_micro_band_width_0\torigin_micro_band_width_points_0\torigin_micro_b_percent_0\torigin_micro_b_percent_sma_5_0\torigin_micro_b_percent_sma_slope_0\torigin_micro_b_percent_state_0\torigin_micro_b_percent_1\torigin_micro_b_percent_sma_5_1\torigin_micro_b_percent_sma_slope_1\torigin_micro_b_percent_state_1\torigin_micro_b_percent_2\torigin_micro_b_percent_sma_5_2\torigin_micro_b_percent_sma_slope_2\torigin_micro_b_percent_state_2\torigin_micro_b_percent_3\torigin_micro_b_percent_sma_5_3\torigin_micro_b_percent_sma_slope_3\torigin_micro_b_percent_state_3\torigin_micro_b_percent_4\torigin_micro_b_percent_sma_5_4\torigin_micro_b_percent_sma_slope_4\torigin_micro_b_percent_state_4\torigin_micro_b_percent_5\torigin_micro_b_percent_sma_5_5\torigin_micro_b_percent_sma_slope_5\torigin_micro_b_percent_state_5\torigin_micro_stochastic_main_line_0\torigin_micro_stochastic_main_line_sma_5_0\torigin_micro_stochastic_main_line_sma_slope_0\torigin_micro_stochastic_main_line_state_0\torigin_micro_stochastic_main_line_1\torigin_micro_stochastic_main_line_sma_5_1\torigin_micro_stochastic_main_line_sma_slope_1\torigin_micro_stochastic_main_line_state_1\torigin_micro_stochastic_main_line_2\torigin_micro_stochastic_main_line_sma_5_2\torigin_micro_stochastic_main_line_sma_slope_2\torigin_micro_stochastic_main_line_state_2\torigin_micro_stochastic_main_line_3\torigin_micro_stochastic_main_line_sma_5_3\torigin_micro_stochastic_main_line_sma_slope_3\torigin_micro_stochastic_main_line_state_3\torigin_micro_stochastic_main_line_4\torigin_micro_stochastic_main_line_sma_5_4\torigin_micro_stochastic_main_line_sma_slope_4\torigin_micro_stochastic_main_line_state_4\torigin_micro_stochastic_main_line_5\torigin_micro_stochastic_main_line_sma_5_5\torigin_micro_stochastic_main_line_sma_slope_5\torigin_micro_stochastic_main_line_state_5\torigin_micro_stochastic_signal_line_0\torigin_micro_stochastic_signal_line_sma_5_0\torigin_micro_stochastic_signal_line_sma_slope_0\torigin_micro_stochastic_signal_line_state_0\torigin_micro_stochastic_signal_line_1\torigin_micro_stochastic_signal_line_sma_5_1\torigin_micro_stochastic_signal_line_sma_slope_1\torigin_micro_stochastic_signal_line_state_1\torigin_micro_stochastic_signal_line_2\torigin_micro_stochastic_signal_line_sma_5_2\torigin_micro_stochastic_signal_line_sma_slope_2\torigin_micro_stochastic_signal_line_state_2\torigin_micro_stochastic_signal_line_3\torigin_micro_stochastic_signal_line_sma_5_3\torigin_micro_stochastic_signal_line_sma_slope_3\torigin_micro_stochastic_signal_line_state_3\torigin_micro_stochastic_signal_line_4\torigin_micro_stochastic_signal_line_sma_5_4\torigin_micro_stochastic_signal_line_sma_slope_4\torigin_micro_stochastic_signal_line_state_4\torigin_micro_stochastic_signal_line_5\torigin_micro_stochastic_signal_line_sma_5_5\torigin_micro_stochastic_signal_line_sma_slope_5\torigin_micro_stochastic_signal_line_state_5\torigin_micro_band_base_line_0\torigin_micro_band_base_line_slope_points_0\torigin_micro_band_base_line_1\torigin_micro_band_base_line_slope_points_1\torigin_micro_band_base_line_2\torigin_micro_band_base_line_slope_points_2\torigin_micro_band_base_line_3\torigin_micro_band_base_line_slope_points_3\torigin_micro_band_base_line_4\torigin_micro_band_base_line_slope_points_4\torigin_micro_band_base_line_5\torigin_micro_band_base_line_slope_points_5\torigin_macro_band_width_points_0\torigin_macro_b_percent_0\torigin_macro_b_percent_sma_5_0\torigin_macro_b_percent_sma_slope_0\torigin_macro_b_percent_state_0\torigin_macro_b_percent_1\torigin_macro_b_percent_sma_5_1\torigin_macro_b_percent_sma_slope_1\torigin_macro_b_percent_state_1\torigin_macro_b_percent_2\torigin_macro_b_percent_sma_5_2\torigin_macro_b_percent_sma_slope_2\torigin_macro_b_percent_state_2\torigin_macro_b_percent_3\torigin_macro_b_percent_sma_5_3\torigin_macro_b_percent_sma_slope_3\torigin_macro_b_percent_state_3\torigin_macro_b_percent_4\torigin_macro_b_percent_sma_5_4\torigin_macro_b_percent_sma_slope_4\torigin_macro_b_percent_state_4\torigin_macro_b_percent_5\torigin_macro_b_percent_sma_5_5\torigin_macro_b_percent_sma_slope_5\torigin_macro_b_percent_state_5\torigin_macro_stochastic_main_line_0\torigin_macro_stochastic_main_line_sma_5_0\torigin_macro_stochastic_main_line_sma_slope_0\torigin_macro_stochastic_main_line_state_0\torigin_macro_stochastic_main_line_1\torigin_macro_stochastic_main_line_sma_5_1\torigin_macro_stochastic_main_line_sma_slope_1\torigin_macro_stochastic_main_line_state_1\torigin_macro_stochastic_main_line_2\torigin_macro_stochastic_main_line_sma_5_2\torigin_macro_stochastic_main_line_sma_slope_2\torigin_macro_stochastic_main_line_state_2\torigin_macro_stochastic_main_line_3\torigin_macro_stochastic_main_line_sma_5_3\torigin_macro_stochastic_main_line_sma_slope_3\torigin_macro_stochastic_main_line_state_3\torigin_macro_stochastic_main_line_4\torigin_macro_stochastic_main_line_sma_5_4\torigin_macro_stochastic_main_line_sma_slope_4\torigin_macro_stochastic_main_line_state_4\torigin_macro_stochastic_main_line_5\torigin_macro_stochastic_main_line_sma_5_5\torigin_macro_stochastic_main_line_sma_slope_5\torigin_macro_stochastic_main_line_state_5\torigin_macro_stochastic_signal_line_0\torigin_macro_stochastic_signal_line_sma_5_0\torigin_macro_stochastic_signal_line_sma_slope_0\torigin_macro_stochastic_signal_line_state_0\torigin_macro_stochastic_signal_line_1\torigin_macro_stochastic_signal_line_sma_5_1\torigin_macro_stochastic_signal_line_sma_slope_1\torigin_macro_stochastic_signal_line_state_1\torigin_macro_stochastic_signal_line_2\torigin_macro_stochastic_signal_line_sma_5_2\torigin_macro_stochastic_signal_line_sma_slope_2\torigin_macro_stochastic_signal_line_state_2\torigin_macro_stochastic_signal_line_3\torigin_macro_stochastic_signal_line_sma_5_3\torigin_macro_stochastic_signal_line_sma_slope_3\torigin_macro_stochastic_signal_line_state_3\torigin_macro_stochastic_signal_line_4\torigin_macro_stochastic_signal_line_sma_5_4\torigin_macro_stochastic_signal_line_sma_slope_4\torigin_macro_stochastic_signal_line_state_4\torigin_macro_stochastic_signal_line_5\torigin_macro_stochastic_signal_line_sma_5_5\torigin_macro_stochastic_signal_line_sma_slope_5\torigin_macro_stochastic_signal_line_state_5\torigin_macro_band_base_line_0\torigin_macro_band_base_line_slope_points_0\torigin_macro_band_base_line_1\torigin_macro_band_base_line_slope_points_1\torigin_macro_band_base_line_2\torigin_macro_band_base_line_slope_points_2\torigin_macro_band_base_line_3\torigin_macro_band_base_line_slope_points_3\torigin_macro_band_base_line_4\torigin_macro_band_base_line_slope_points_4\torigin_macro_band_base_line_5\torigin_macro_band_base_line_slope_points_5\torigin_micro_features_complete\torigin_macro_features_complete\torigin_feature_snapshot_complete\torigin_feature_invalid_reason\tidentity_consumed\tmatrix_declared\tbroker_attempt_status\torigin_expiry_broker_time\torigin_expiry_analysis_time\torigin_expiry_offset_minutes\torigin_terminal_status";
const string PIVOT_V12_TRIALS_HEADER =
  "schema_version\trun_id\tconfig_id\ttrial_id\tparity_trial_id\tpolicy_id\torigin_id\twindow_id\tbroker_signal_id\ttrial_role\tsl_policy\ttp_r_multiple\treentry_index\tpreceding_loss_count\tlevel_id\tdirection\tdeclared_broker_time\tdeclared_analysis_time\tdeclared_offset_minutes\tentry_bid\tentry_ask\tentry_price\tentry_quote_side\texit_quote_side\torigin_micro_band_width_0\trequested_risk_distance_price\trequested_risk_distance_points\tnormalized_risk_ticks\tnormalized_risk_distance_price\tnormalized_risk_distance_points\tstop_loss_price\ttake_profit_price\tgeometry_equivalence_id\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\tminimum_risk_distance_points\tdistance_eligible\tboundary_price\tboundary_eligible\tlot_mode\tlot_strategy_size\treference_balance\taccount_currency\trisk_budget_amount\trequested_volume\tnormalized_volume\tvirtual_expected_stop_loss\tvirtual_expected_take_profit\tvirtual_expected_reward_risk_ratio\tvirtual_money_plan_complete\teligibility_status\tineligible_reason\tparent_trial_id\tcontinuation_source_outcome_id\torigin_window_active_at_entry";
const string PIVOT_V12_VIRTUAL_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\toutcome_id\ttrial_id\tparity_trial_id\tpolicy_id\torigin_id\twindow_id\ttrial_role\tsl_policy\ttp_r_multiple\treentry_index\tdirection\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status\tterminal_reason\tthreshold_price\tobserved_exit_bid\tobserved_exit_ask\tobserved_exit_price\texit_quote_side\tgap_points\tduration_seconds\tvirtual_nominal_r\tvirtual_quote_gross_profit\tvirtual_quote_gross_r\tvirtual_binary_eligible\tvirtual_binary_target\tvirtual_exclusion_reason\tfirst_touch_consistent\tchain_terminal\tchain_terminal_reason\tcontinuation_allowed\tcontinuation_reason\tnext_reentry_index\tnext_trial_id";
const string PIVOT_V12_CHECKS_HEADER =
  "schema_version\trun_id\tconfig_id\tcheck_id\torigin_id\tbroker_signal_id\tparity_trial_id\twindow_id\tcheck_sequence\tcheck_phase\tbroker_time\tanalysis_time\toffset_minutes\tsymbol\tdirection\taccount_margin_mode\taccount_margin_mode_supported\tsymbol_trade_mode\tsymbol_trade_mode_allowed\tmarket_session_open\taccount_trade_allowed\taccount_expert_trade_allowed\tterminal_trade_allowed\tmql_trade_allowed\tbid\task\tspread_points\tpoint_size\ttrade_tick_size\tstops_distance_points\tfreeze_distance_points\tentry_price\tstop_loss_price\ttake_profit_price\trisk_distance_points\treward_distance_points\trisk_budget_amount\trequested_volume\tnormalized_volume\tvolume_min\tvolume_max\tvolume_step\tvolume_valid\tfok_supported\tfill_policy\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\taccount_balance\tfree_margin\trequired_margin\tmargin_valid\tgeometry_valid\tstop_distance_valid\tfreeze_distance_valid\torder_check_performed\torder_check_allowed\torder_check_retcode\torder_check_comment\tallowed\tblock_source\tblock_reason\tsend_performed\tsend_succeeded\ttrade_action\tsend_retcode\tsend_comment\torder_ticket\tdeal_ticket\tposition_ticket\tposition_identifier\tbroker_entry_confirmed\tbroker_close_confirmed\tbroker_entry_price\tbroker_volume\tbroker_stop_loss\tbroker_take_profit\tclose_price\tclosed_volume\tterminal_reason\tprotection_modified";
const string PIVOT_V12_BROKER_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tbroker_outcome_id\torigin_id\tbroker_signal_id\tparity_trial_id\twindow_id\tsymbol\tmacro_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\tentry_broker_time\tentry_analysis_time\tentry_offset_minutes\tclose_broker_time\tclose_analysis_time\tclose_offset_minutes\torder_ticket\tentry_deal_ticket\tlast_close_deal_ticket\tclose_deal_count\tposition_ticket\tposition_identifier\tsubmitted_request_price\tbroker_entry_price\tbroker_volume\timmutable_stop_loss\timmutable_take_profit\tbroker_close_price\tbroker_closed_volume\trequest_risk_distance_points\trequest_reward_distance_points\trequest_price_reward_risk_ratio\trisk_budget_amount\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\tentry_slippage_points\texit_slippage_points\tbroker_gross_profit\tbroker_commission\tbroker_swap\tbroker_fee\tbroker_net_profit\tbroker_gross_budget_r\tbroker_net_budget_r\tbroker_gross_execution_r\tbroker_net_execution_r\tbroker_terminal_reason\tclose_reason_consistent\tbroker_binary_eligible\tbroker_binary_target\tbroker_exclusion_reason\tduration_seconds\tbroker_entry_confirmed\tbroker_close_confirmed";
const string PIVOT_V12_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_broker_time\tstarted_analysis_time\tstarted_offset_minutes\tfinished_broker_time\tfinished_analysis_time\tfinished_offset_minutes\tpivot_window_rows\tsignal_origin_rows\tvirtual_trial_rows\tmatrix_trial_rows\treentry_trial_rows\tparity_trial_rows\tvirtual_active_trial_rows\tvirtual_ineligible_feature_rows\tvirtual_ineligible_geometry_rows\tvirtual_ineligible_distance_rows\tvirtual_ineligible_money_rows\tvirtual_outcome_rows\tmatrix_tp_rows\tmatrix_sl_rows\tmatrix_censored_rows\tparity_outcome_rows\texecution_check_rows\tbroker_outcome_rows\tbroker_binary_eligible_rows\tbroker_binary_tp_rows\tbroker_binary_sl_rows\tbroker_excluded_rows\tparity_pair_rows\tparity_terminal_match_rows\tparity_terminal_mismatch_rows\tparity_excluded_rows\tchain_tp_complete_rows\tchain_structural_sl_rows\tchain_reentry_cap_rows\tchain_next_pivot_boundary_rows\tchain_origin_expired_rows\tchain_run_end_censored_rows\tchain_ineligible_rows\tactive_state_peak\tactive_state_cap\tstate_capacity_failed\tduplicate_identity_count\treferential_integrity_error_count\trow_integrity_error_count\texport_status\tcompletion_status";

struct PivotV12PendingOrigin
{
  PivotTrialOriginSnapshot origin;
  string broker_attempt_status;
  bool matrix_declared;

  PivotV12PendingOrigin()
  {
    Reset();
  }

  PivotV12PendingOrigin(const PivotV12PendingOrigin &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin.Reset();
    broker_attempt_status = "NOT_EVALUATED";
    matrix_declared = false;
  }

  void CopyFrom(const PivotV12PendingOrigin &other)
  {
    origin.CopyFrom(other.origin);
    broker_attempt_status = other.broker_attempt_status;
    matrix_declared = other.matrix_declared;
  }
};

string g_pivot_v12_run_id = "";
string g_pivot_v12_config_id = "";
string g_pivot_v12_folder = "";
datetime g_pivot_v12_started_at = 0;
bool g_pivot_v12_initialized = false;
bool g_pivot_v12_failed = false;
bool g_pivot_v12_error_logged = false;
bool g_pivot_v12_summary_written = false;
int g_pivot_v12_window_rows = 0;
int g_pivot_v12_origin_rows = 0;
int g_pivot_v12_virtual_trial_rows = 0;
int g_pivot_v12_matrix_trial_rows = 0;
int g_pivot_v12_reentry_trial_rows = 0;
int g_pivot_v12_parity_trial_rows = 0;
int g_pivot_v12_virtual_active_rows = 0;
int g_pivot_v12_ineligible_feature_rows = 0;
int g_pivot_v12_ineligible_geometry_rows = 0;
int g_pivot_v12_ineligible_distance_rows = 0;
int g_pivot_v12_ineligible_money_rows = 0;
int g_pivot_v12_virtual_outcome_rows = 0;
int g_pivot_v12_matrix_tp_rows = 0;
int g_pivot_v12_matrix_sl_rows = 0;
int g_pivot_v12_matrix_censored_rows = 0;
int g_pivot_v12_parity_outcome_rows = 0;
int g_pivot_v12_check_rows = 0;
int g_pivot_v12_broker_outcome_rows = 0;
int g_pivot_v12_broker_binary_eligible_rows = 0;
int g_pivot_v12_broker_binary_tp_rows = 0;
int g_pivot_v12_broker_binary_sl_rows = 0;
int g_pivot_v12_broker_excluded_rows = 0;
int g_pivot_v12_parity_pair_rows = 0;
int g_pivot_v12_parity_terminal_match_rows = 0;
int g_pivot_v12_parity_terminal_mismatch_rows = 0;
int g_pivot_v12_parity_excluded_rows = 0;
int g_pivot_v12_chain_tp_complete_rows = 0;
int g_pivot_v12_chain_structural_sl_rows = 0;
int g_pivot_v12_chain_reentry_cap_rows = 0;
int g_pivot_v12_chain_boundary_rows = 0;
int g_pivot_v12_chain_origin_expired_rows = 0;
int g_pivot_v12_chain_run_end_censored_rows = 0;
int g_pivot_v12_chain_ineligible_rows = 0;
int g_pivot_v12_duplicate_identity_count = 0;
int g_pivot_v12_referential_integrity_error_count = 0;
int g_pivot_v12_row_integrity_error_count = 0;
string g_pivot_v12_window_buffer[];
string g_pivot_v12_origin_buffer[];
string g_pivot_v12_trial_buffer[];
string g_pivot_v12_virtual_outcome_buffer[];
string g_pivot_v12_check_buffer[];
string g_pivot_v12_broker_outcome_buffer[];
PivotV12PendingOrigin g_pivot_v12_pending_origins[];
PivotTrialParityLink g_pivot_v12_parity_links[];

bool PivotV12Enabled()
{
  return Enable_Signal_Feature_Export;
}

bool PivotV12Ready()
{
  return PivotV12Enabled() && g_pivot_v12_initialized &&
         !g_pivot_v12_failed;
}

void PivotV12MarkFailed(const string operation,
                        const string filename = "",
                        const int error_code = 0)
{
  g_pivot_v12_failed = true;
  if(g_pivot_v12_error_logged)
    return;
  string message = StringFormat("operation=%s|file=%s|error=%d",
                                operation,
                                filename,
                                error_code);
  if(Enable_File_Logs)
    ExecutionAppendQueryDebugLog("PIVOT_V12_EXPORT_FAILED", message);
  if(Enable_Logs)
    Print("PIVOT_V12_EXPORT_FAILED | ", message);
  g_pivot_v12_error_logged = true;
}

bool PivotV12RejectReference(const string operation)
{
  g_pivot_v12_referential_integrity_error_count++;
  PivotV12MarkFailed(operation);
  return false;
}

int FindPivotV12ParityLink(const string parity_trial_id)
{
  if(parity_trial_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_v12_parity_links); i++)
  {
    if(g_pivot_v12_parity_links[i].parity_trial_id == parity_trial_id)
      return i;
  }
  return -1;
}

bool RemovePivotV12ParityLinkAt(const int index)
{
  int total = ArraySize(g_pivot_v12_parity_links);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_v12_parity_links[i].CopyFrom(
      g_pivot_v12_parity_links[i + 1]);
  int reserve = total - 1 > 0 ? PIVOT_V12_PARITY_LINK_RESERVE : 0;
  return ArrayResize(g_pivot_v12_parity_links,
                     total - 1,
                     reserve) == total - 1;
}

bool PivotV12FinalizeParityLink(const int index)
{
  if(index < 0 || index >= ArraySize(g_pivot_v12_parity_links))
    return false;
  PivotTrialParityLink link(g_pivot_v12_parity_links[index]);
  if(!link.virtual_outcome_recorded || !link.broker_outcome_linked)
    return true;
  if(link.summary_counted)
    return PivotV12RejectReference("PARITY_SUMMARY_DUPLICATE");

  g_pivot_v12_parity_pair_rows++;
  bool virtual_binary =
    link.virtual_first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST ||
    link.virtual_first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  if(!link.broker_binary_eligible || !virtual_binary)
  {
    g_pivot_v12_parity_excluded_rows++;
  }
  else
  {
    int virtual_target =
      link.virtual_first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST ? 1 : 0;
    if(virtual_target == link.broker_binary_target)
      g_pivot_v12_parity_terminal_match_rows++;
    else
    {
      g_pivot_v12_parity_terminal_mismatch_rows++;
    }
  }
  g_pivot_v12_parity_links[index].summary_counted = true;
  if(!RemovePivotV12ParityLinkAt(index))
    return PivotV12RejectReference("PARITY_LINK_REMOVE_FAILED");
  return true;
}

bool PivotV12RegisterParityLink(const PivotTrialEntry &trial)
{
  if(trial.identity.role != PIVOT_TRIAL_ROLE_BROKER_PARITY ||
     trial.identity.parity_trial_id == "" ||
     trial.identity.trial_id != trial.identity.parity_trial_id ||
     trial.identity.origin_id == "" ||
     trial.identity.broker_signal_id == "" ||
     FindPivotV12ParityLink(trial.identity.parity_trial_id) >= 0)
    return PivotV12RejectReference("PARITY_LINK_REGISTER_INVALID");
  int total = ArraySize(g_pivot_v12_parity_links);
  if(total >= PIVOT_TRIAL_ACTIVE_STATE_CAP)
    return PivotV12RejectReference("PARITY_LINK_CAP_REACHED");
  if(ArrayResize(g_pivot_v12_parity_links,
                 total + 1,
                 PIVOT_V12_PARITY_LINK_RESERVE) != total + 1)
    return PivotV12RejectReference("PARITY_LINK_RESIZE_FAILED");
  g_pivot_v12_parity_links[total].Reset();
  g_pivot_v12_parity_links[total].origin_id = trial.identity.origin_id;
  g_pivot_v12_parity_links[total].broker_signal_id =
    trial.identity.broker_signal_id;
  g_pivot_v12_parity_links[total].parity_trial_id =
    trial.identity.parity_trial_id;
  g_pivot_v12_parity_links[total].accepted_request_copied = true;
  return true;
}

bool PivotV12LinkParityVirtualOutcome(const PivotTrialOutcome &outcome)
{
  int index = FindPivotV12ParityLink(outcome.identity.parity_trial_id);
  if(index < 0 ||
     g_pivot_v12_parity_links[index].origin_id !=
       outcome.identity.origin_id ||
     g_pivot_v12_parity_links[index].broker_signal_id !=
       outcome.identity.broker_signal_id ||
     g_pivot_v12_parity_links[index].virtual_outcome_recorded)
    return PivotV12RejectReference("PARITY_VIRTUAL_LINK_INVALID");
  g_pivot_v12_parity_links[index].virtual_outcome_recorded = true;
  g_pivot_v12_parity_links[index].virtual_first_touch = outcome.first_touch;
  return PivotV12FinalizeParityLink(index);
}

bool PivotV12ParityHasVirtualOutcome(const string parity_trial_id)
{
  int index = FindPivotV12ParityLink(parity_trial_id);
  return index >= 0 &&
         g_pivot_v12_parity_links[index].virtual_outcome_recorded;
}

bool PivotV12LinkParityBrokerOutcome(const PivotSignal &signal)
{
  int index = FindPivotV12ParityLink(signal.parity_trial_id);
  if(index < 0 ||
     g_pivot_v12_parity_links[index].origin_id != signal.origin_id ||
     g_pivot_v12_parity_links[index].broker_signal_id !=
       signal.broker_signal_id ||
     g_pivot_v12_parity_links[index].broker_outcome_linked)
    return PivotV12RejectReference("PARITY_BROKER_LINK_INVALID");
  g_pivot_v12_parity_links[index].broker_outcome_linked = true;
  g_pivot_v12_parity_links[index].broker_binary_eligible =
    signal.execution.binary_eligible;
  g_pivot_v12_parity_links[index].broker_binary_target =
    signal.execution.binary_target;
  return PivotV12FinalizeParityLink(index);
}

string PivotV12BoolToken(const bool value)
{
  return value ? "1" : "0";
}

string PivotV12Cell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  return value == "" ? PIVOT_V12_NULL : value;
}

string PivotV12TimeToken(const datetime value)
{
  return value > 0
         ? TimeToString(value, TIME_DATE | TIME_SECONDS)
         : PIVOT_V12_NULL;
}

string PivotV12DoubleToken(const double value,
                           const bool allow_zero = false)
{
  if(!MathIsValidNumber(value) || (!allow_zero && value == 0.0))
    return PIVOT_V12_NULL;
  return DoubleToString(value, 10);
}

string PivotV12UlongToken(const ulong value)
{
  return value > 0 ? StringFormat("%I64u", value) : PIVOT_V12_NULL;
}

string PivotV12DirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BUY";
  if(direction == BEARISH)
    return "SELL";
  return "NONE";
}

string PivotV12WindowStateToken(const PivotWindowStates state)
{
  switch(state)
  {
    case PIVOT_WINDOW_EMPTY:   return "EMPTY";
    case PIVOT_WINDOW_PENDING: return "PENDING";
    case PIVOT_WINDOW_VALID:   return "VALID";
    case PIVOT_WINDOW_INVALID: return "INVALID";
  }
  return "UNKNOWN";
}

string PivotV12PriceSideToken(const PivotPriceSideStates side)
{
  switch(side)
  {
    case PIVOT_PRICE_SIDE_UNAVAILABLE: return "UNAVAILABLE";
    case PIVOT_PRICE_SIDE_BELOW:       return "BELOW";
    case PIVOT_PRICE_SIDE_EQUAL:       return "EQUAL";
    case PIVOT_PRICE_SIDE_ABOVE:       return "ABOVE";
  }
  return "UNKNOWN";
}

string PivotV12PpRoleToken(const PivotPpArmStates state)
{
  if(state == PIVOT_PP_BUY_ARMED)
    return "BUY";
  if(state == PIVOT_PP_SELL_ARMED)
    return "SELL";
  return "UNARMED";
}

void PivotV12AppendColumn(string &row,
                          const string value)
{
  if(row != "")
    row += "\t";
  row += value;
}

void PivotV12AppendTimestamp(string &row,
                             const datetime broker_time)
{
  datetime analysis_time = 0;
  int offset_minutes = 0;
  if(broker_time > 0)
    analysis_time = MarketDataNormalizeAnalysisTime(broker_time,
                                                    Broker_Session,
                                                    _Symbol,
                                                    offset_minutes);
  PivotV12AppendColumn(row, PivotV12TimeToken(broker_time));
  PivotV12AppendColumn(row, PivotV12TimeToken(analysis_time));
  PivotV12AppendColumn(row,
                       broker_time > 0
                       ? IntegerToString(offset_minutes)
                       : PIVOT_V12_NULL);
}

string PivotV12SanitizePart(const string raw_value)
{
  string value = raw_value;
  StringTrimLeft(value);
  StringTrimRight(value);
  string invalid = "\\/:*?\"<>|\t\r\n ";
  for(int i = 0; i < StringLen(invalid); i++)
  {
    string character = StringSubstr(invalid, i, 1);
    StringReplace(value, character, "_");
  }
  while(StringFind(value, "__") >= 0)
    StringReplace(value, "__", "_");
  return value;
}

string PivotV12HashToken(const string value)
{
  return StringFormat("%I64u", PivotTrialStableHash(value));
}

string PivotV12WindowId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open)
{
  string identity = symbol + "|" + EnumToString(timeframe) + "|" +
                    IntegerToString((long)active_bar_open);
  return "win_" + PivotV12HashToken(identity);
}

string PivotV12OriginId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open,
                        const PivotLevelIds level)
{
  string identity = symbol + "|" + EnumToString(timeframe) + "|" +
                    IntegerToString((long)active_bar_open) + "|" +
                    PivotLevelLabel(level);
  return "origin_" + PivotV12HashToken(identity);
}

string PivotV12BrokerSignalId(const string origin_id)
{
  if(origin_id == "")
    return "";
  return "broker_" + PivotV12HashToken(origin_id + "|STRUCTURAL_1R");
}

string PivotV12CheckId(const string broker_signal_id,
                       const int sequence,
                       const string phase)
{
  string payload = broker_signal_id + "|" + IntegerToString(sequence) +
                   "|" + phase;
  return "check_" + PivotV12HashToken(payload);
}

string PivotV12BrokerOutcomeId(const string broker_signal_id)
{
  return "broker_outcome_" +
         PivotV12HashToken(broker_signal_id + "|CLOSED");
}

string PivotV12BuildConfigPayload()
{
  string payload = IntegerToString(PIVOT_V12_SCHEMA_VERSION);
  payload += "|" + PIVOT_V12_ENGINE_LABEL;
  payload += "|" + EnumToString(Macro_Timeframe);
  payload += "|" + EnumToString(Micro_Timeframe);
  payload += "|" + IntegerToString(PIVOT_CONTEXT_BANDS_PERIOD);
  payload += "|" + DoubleToString(PIVOT_CONTEXT_B_PERCENT_DEVIATION, 4);
  payload += "|MODE_SMA|PRICE_WEIGHTED";
  payload += "|" + IntegerToString(PIVOT_CONTEXT_STOCHASTIC_K_PERIOD);
  payload += "|" + IntegerToString(PIVOT_CONTEXT_STOCHASTIC_D_PERIOD);
  payload += "|" + IntegerToString(PIVOT_CONTEXT_STOCHASTIC_SLOWING);
  payload += "|MODE_SMA|STO_CLOSECLOSE|MAIN_LINE|SIGNAL_LINE";
  payload += "|" + IntegerToString(PIVOT_FEATURE_EXPORT_SHIFT_COUNT);
  payload += "|" + IntegerToString(PIVOT_FEATURE_RAW_SHIFT_COUNT - 1);
  payload += "|" + IntegerToString(PIVOT_FEATURE_SMA_PERIOD);
  payload += "|" + DoubleToString(PIVOT_FEATURE_STATE_TOLERANCE, 7);
  payload += "|STRUCTURAL,MICRO_BW_13,MICRO_BW_21,MICRO_BW_34";
  payload += "|0.13,0.21,0.34|1,2,3,5";
  payload += "|" + IntegerToString(PIVOT_TRIAL_MAX_REENTRY_INDEX);
  payload +=
    "|risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick";
  payload += "|" + IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP);
  payload += "|" + EnumToString(Lot_Type);
  payload += "|" + DoubleToString(Lot_Strategy_Size, 8);
  payload += "|" + DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE, 8);
  payload += "|" + AccountInfoString(ACCOUNT_CURRENCY);
  payload +=
    "|order_calc_profit_counterfactual_gross_only_no_costs_or_net";
  payload +=
    "|deal_history_authoritative_gross_commission_swap_fee_net";
  payload +=
    "|accepted_request_geometry_shadow_trade_session_observed_broker_terminal_censored_calibration_only_not_matrix_or_ml";
  payload += "|" + PIVOT_V12_FEATURE_SET_ID;
  return payload;
}

string PivotV12BuildRunId()
{
  if(Signal_Feature_Run_Id != "")
    return PivotV12SanitizePart(Signal_Feature_Run_Id);
  string time_token = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
  return PivotV12SanitizePart(time_token + "_" + _Symbol + "_pivot_v12");
}

string PivotV12Path(const string filename)
{
  return g_pivot_v12_folder + "\\" + filename;
}

bool PivotV12EnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_pivot_v12_folder, delimiter, parts);
  if(total <= 0)
    return false;

  string current = "";
  for(int i = 0; i < total; i++)
  {
    if(parts[i] == "")
      continue;
    current = current == "" ? parts[i] : current + "\\" + parts[i];
    ResetLastError();
    bool created = FolderCreate(current, FILE_COMMON);
    int error = GetLastError();
    if(i == total - 1 && !created && error == 5019)
    {
      PivotV12MarkFailed("RUN_FOLDER_ALREADY_EXISTS", current, error);
      return false;
    }
    if(error != 0 && error != 5019)
    {
      PivotV12MarkFailed("CREATE_FOLDER", current, error);
      return false;
    }
  }
  return true;
}

int PivotV12ColumnCount(const string row)
{
  if(row == "")
    return 0;
  int columns = 1;
  for(int i = 0; i < StringLen(row); i++)
  {
    if(StringGetCharacter(row, i) == '\t')
      columns++;
  }
  return columns;
}

bool PivotV12RowMatchesHeader(const string header,
                              const string row)
{
  if(PivotV12ColumnCount(header) == PivotV12ColumnCount(row))
    return true;
  g_pivot_v12_row_integrity_error_count++;
  PivotV12MarkFailed("ROW_COLUMN_COUNT");
  return false;
}

bool PivotV12FileHeaderMatches(const string filename,
                               const string expected_header)
{
  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    PivotV12MarkFailed("OPEN_HEADER", filename, GetLastError());
    return false;
  }
  string actual_header = FileReadString(handle);
  FileClose(handle);
  if(actual_header == expected_header)
    return true;
  PivotV12MarkFailed("HEADER_MISMATCH", filename);
  return false;
}

bool PivotV12WriteLine(const string filename,
                       const string line,
                       const bool append)
{
  int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON;
  if(append)
    flags |= FILE_READ;
  ResetLastError();
  int handle = FileOpen(filename, flags);
  if(handle == INVALID_HANDLE)
  {
    PivotV12MarkFailed("OPEN_WRITE", filename, GetLastError());
    return false;
  }
  if(append && !FileSeek(handle, 0, SEEK_END))
  {
    PivotV12MarkFailed("SEEK_END", filename, GetLastError());
    FileClose(handle);
    return false;
  }
  bool written = FileWrite(handle, line) > 0;
  FileClose(handle);
  if(!written)
    PivotV12MarkFailed("WRITE_LINE", filename, GetLastError());
  return written;
}

bool PivotV12AppendRows(const string filename,
                        const string header,
                        string &buffer[])
{
  int total = ArraySize(buffer);
  if(total <= 0)
    return true;
  if(!FileIsExist(filename, FILE_COMMON) ||
     !PivotV12FileHeaderMatches(filename, header))
    return false;

  int handle = FileOpen(filename,
                        FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI |
                        FILE_COMMON);
  if(handle == INVALID_HANDLE || !FileSeek(handle, 0, SEEK_END))
  {
    PivotV12MarkFailed("OPEN_APPEND", filename, GetLastError());
    if(handle != INVALID_HANDLE)
      FileClose(handle);
    return false;
  }

  bool success = true;
  for(int i = 0; i < total; i++)
  {
    if(!PivotV12RowMatchesHeader(header, buffer[i]) ||
       FileWrite(handle, buffer[i]) == 0)
    {
      success = false;
      break;
    }
  }
  FileClose(handle);
  if(!success)
    PivotV12MarkFailed("WRITE_BATCH", filename, GetLastError());
  return success;
}

bool PivotV12FlushBuffer(const string filename,
                         const string header,
                         string &buffer[])
{
  if(ArraySize(buffer) <= 0)
    return true;
  if(!PivotV12AppendRows(filename, header, buffer))
    return false;
  return ArrayResize(buffer, 0) == 0;
}

bool PivotV12QueueRow(const string filename,
                      const string header,
                      const string row,
                      string &buffer[])
{
  if(!PivotV12Ready() || !PivotV12RowMatchesHeader(header, row))
    return false;
  int total = ArraySize(buffer);
  if(ArrayResize(buffer, total + 1, PIVOT_V12_FLUSH_ROWS) != total + 1)
  {
    PivotV12MarkFailed("BUFFER_RESIZE", filename);
    return false;
  }
  buffer[total] = row;
  if(ArraySize(buffer) >= PIVOT_V12_FLUSH_ROWS)
    return PivotV12FlushBuffer(filename, header, buffer);
  return true;
}

bool PivotV12FlushAll()
{
  bool windows_ok = PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_WINDOWS_FILE),
                                        PIVOT_V12_WINDOWS_HEADER,
                                        g_pivot_v12_window_buffer);
  bool origins_ok = PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_ORIGINS_FILE),
                                        PIVOT_V12_ORIGINS_HEADER,
                                        g_pivot_v12_origin_buffer);
  bool trials_ok = PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_TRIALS_FILE),
                                       PIVOT_V12_TRIALS_HEADER,
                                       g_pivot_v12_trial_buffer);
  bool virtual_outcomes_ok =
    PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_VIRTUAL_OUTCOMES_FILE),
                        PIVOT_V12_VIRTUAL_OUTCOMES_HEADER,
                        g_pivot_v12_virtual_outcome_buffer);
  bool checks_ok = PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_CHECKS_FILE),
                                       PIVOT_V12_CHECKS_HEADER,
                                       g_pivot_v12_check_buffer);
  bool broker_outcomes_ok =
    PivotV12FlushBuffer(PivotV12Path(PIVOT_V12_BROKER_OUTCOMES_FILE),
                        PIVOT_V12_BROKER_OUTCOMES_HEADER,
                        g_pivot_v12_broker_outcome_buffer);
  return windows_ok && origins_ok && trials_ok && virtual_outcomes_ok &&
         checks_ok && broker_outcomes_ok;
}

string PivotV12ManifestRow(const string key,
                           const string value)
{
  return IntegerToString(PIVOT_V12_SCHEMA_VERSION) + "\t" +
         PivotV12Cell(key) + "\t" + PivotV12Cell(value);
}

bool PivotV12WriteManifest()
{
  string filename = PivotV12Path(PIVOT_V12_MANIFEST_FILE);
  if(FileIsExist(filename, FILE_COMMON) ||
     !PivotV12WriteLine(filename, PIVOT_V12_MANIFEST_HEADER, false))
    return false;

  string rows[];
  if(ArrayResize(rows, 70) != 70)
  {
    PivotV12MarkFailed("MANIFEST_RESIZE", filename);
    return false;
  }
  rows[0] = PivotV12ManifestRow("run_id", g_pivot_v12_run_id);
  rows[1] = PivotV12ManifestRow("config_id", g_pivot_v12_config_id);
  rows[2] = PivotV12ManifestRow("started_broker_time",
                               PivotV12TimeToken(g_pivot_v12_started_at));
  rows[3] = PivotV12ManifestRow("symbol", _Symbol);
  rows[4] = PivotV12ManifestRow("chart_period", EnumToString(_Period));
  rows[5] = PivotV12ManifestRow("engine_id", "2");
  rows[6] = PivotV12ManifestRow("engine_label", PIVOT_V12_ENGINE_LABEL);
  rows[7] = PivotV12ManifestRow("macro_timeframe",
                               EnumToString(Macro_Timeframe));
  rows[8] = PivotV12ManifestRow("micro_timeframe",
                               EnumToString(Micro_Timeframe));
  rows[9] = PivotV12ManifestRow("pivot_formula",
                               "CLASSIC_PP_S1_S3_R1_R3");
  rows[10] = PivotV12ManifestRow(
    "source_policy",
    "macro_immediately_previous_completed_broker_candle_shift_1");
  rows[11] = PivotV12ManifestRow(
    "origin_identity_policy",
    "symbol,macro_timeframe,active_bar_open,level_first_trigger_once");
  rows[12] = PivotV12ManifestRow(
    "trigger_policy",
    "live_bid_virtual_limit_support_buy_resistance_sell");
  rows[13] = PivotV12ManifestRow(
    "pp_policy",
    "first_causal_bid_side_then_return_touch");
  rows[14] = PivotV12ManifestRow(
    "real_execution_policy",
    "single_structural_sl_fresh_quote_1r_fok_immutable");
  rows[15] = PivotV12ManifestRow("matrix_mode",
                                "export_enabled_virtual_trials_only");
  rows[16] = PivotV12ManifestRow(
    "matrix_sl_policies",
    "STRUCTURAL,MICRO_BW_13,MICRO_BW_21,MICRO_BW_34");
  rows[17] = PivotV12ManifestRow("matrix_sl_ratios", "0.13,0.21,0.34");
  rows[18] = PivotV12ManifestRow("matrix_tp_multiples", "1,2,3,5");
  rows[19] = PivotV12ManifestRow(
    "origin_width_policy",
    "micro_bands_shift_0_price_width_frozen_per_origin_virtual_geometry");
  rows[20] = PivotV12ManifestRow(
    "reentry_policy",
    "sl_first_same_policy_fresh_quote_frozen_width_one_generation_per_tick");
  rows[21] = PivotV12ManifestRow("reentry_max_index",
                                IntegerToString(PIVOT_TRIAL_MAX_REENTRY_INDEX));
  rows[22] = PivotV12ManifestRow(
    "boundary_policy",
    "entry_and_sl_strictly_inside_next_outward_pivot_by_one_trade_tick");
  rows[23] = PivotV12ManifestRow("entry_quote_policy",
                                "buy_ask_sell_bid");
  rows[24] = PivotV12ManifestRow("exit_quote_policy",
                                "buy_bid_sell_ask");
  rows[25] = PivotV12ManifestRow(
    "minimum_distance_policy",
    "risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick");
  rows[26] = PivotV12ManifestRow("active_state_cap",
                                IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP));
  rows[27] = PivotV12ManifestRow(
    "capacity_failure_policy",
    "invalidate_research_stop_new_declarations_keep_active_and_broker_lanes");
  rows[28] = PivotV12ManifestRow(
    "bands_period",
    IntegerToString(PIVOT_CONTEXT_BANDS_PERIOD));
  rows[29] = PivotV12ManifestRow(
    "bands_deviation",
    DoubleToString(PIVOT_CONTEXT_B_PERCENT_DEVIATION, 4));
  rows[30] = PivotV12ManifestRow("bands_shift", "0");
  rows[31] = PivotV12ManifestRow("bands_ma_method", "MODE_SMA");
  rows[32] = PivotV12ManifestRow("bands_applied_price", "PRICE_WEIGHTED");
  rows[33] = PivotV12ManifestRow(
    "feature_capture_policy",
    "one_immutable_origin_snapshot_shift_0_developing_shift_1_5_completed");
  rows[34] = PivotV12ManifestRow(
    "feature_price_policy",
    "immutable_touched_pivot_for_micro_and_macro_b_percent_all_shifts");
  rows[35] = PivotV12ManifestRow("feature_export_shifts", "0,1,2,3,4,5");
  rows[36] = PivotV12ManifestRow(
    "feature_internal_history_max_shift",
    IntegerToString(PIVOT_FEATURE_RAW_SHIFT_COUNT - 1));
  rows[37] = PivotV12ManifestRow(
    "feature_sma_period",
    IntegerToString(PIVOT_FEATURE_SMA_PERIOD));
  rows[38] = PivotV12ManifestRow(
    "feature_sma_policy",
    "arithmetic_mean_series_shift_through_shift_plus_4");
  rows[39] = PivotV12ManifestRow(
    "feature_sma_slope_policy",
    "sma_5_shift_minus_sma_5_shift_plus_1");
  rows[40] = PivotV12ManifestRow(
    "feature_state_policy",
    "raw_vs_sma_5_above_below_equal_absolute_tolerance");
  rows[41] = PivotV12ManifestRow(
    "feature_state_tolerance",
    DoubleToString(PIVOT_FEATURE_STATE_TOLERANCE, 7));
  rows[42] = PivotV12ManifestRow(
    "bands_b_percent_policy",
    "100_times_pivot_minus_lower_divided_by_upper_minus_lower_unclipped");
  rows[43] = PivotV12ManifestRow(
    "bands_width_policy",
    "upper_minus_lower_divided_by_point_shift_0");
  rows[44] = PivotV12ManifestRow(
    "bands_base_line_slope_policy",
    "base_line_shift_minus_next_shift_divided_by_point");
  rows[45] = PivotV12ManifestRow("bands_base_line_buffer", "0:BASE_LINE");
  rows[46] = PivotV12ManifestRow("bands_upper_band_buffer", "1:UPPER_BAND");
  rows[47] = PivotV12ManifestRow("bands_lower_band_buffer", "2:LOWER_BAND");
  rows[48] = PivotV12ManifestRow(
    "stochastic_k_period",
    IntegerToString(PIVOT_CONTEXT_STOCHASTIC_K_PERIOD));
  rows[49] = PivotV12ManifestRow(
    "stochastic_d_period",
    IntegerToString(PIVOT_CONTEXT_STOCHASTIC_D_PERIOD));
  rows[50] = PivotV12ManifestRow(
    "stochastic_slowing",
    IntegerToString(PIVOT_CONTEXT_STOCHASTIC_SLOWING));
  rows[51] = PivotV12ManifestRow("stochastic_ma_method", "MODE_SMA");
  rows[52] = PivotV12ManifestRow("stochastic_price_field", "STO_CLOSECLOSE");
  rows[53] = PivotV12ManifestRow(
    "stochastic_main_line_buffer",
    "0:MAIN_LINE");
  rows[54] = PivotV12ManifestRow(
    "stochastic_signal_line_buffer",
    "1:SIGNAL_LINE");
  rows[55] = PivotV12ManifestRow("lot_mode", EnumToString(Lot_Type));
  rows[56] = PivotV12ManifestRow("lot_strategy_size",
                                DoubleToString(Lot_Strategy_Size, 8));
  rows[57] = PivotV12ManifestRow(
    "reference_balance",
    DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE, 8));
  rows[58] = PivotV12ManifestRow("account_currency",
                                AccountInfoString(ACCOUNT_CURRENCY));
  rows[59] = PivotV12ManifestRow(
    "volume_normalization_policy",
    "normalize_down_block_below_minimum");
  rows[60] = PivotV12ManifestRow(
    "virtual_money_policy",
    "order_calc_profit_counterfactual_gross_only_no_costs_or_net");
  rows[61] = PivotV12ManifestRow(
    "broker_money_policy",
    "deal_history_authoritative_gross_commission_swap_fee_net");
  rows[62] = PivotV12ManifestRow(
    "virtual_outcome_policy",
    "tp_first_sl_first_or_censored_from_causal_executable_quote");
  rows[63] = PivotV12ManifestRow(
    "virtual_binary_cohort_policy",
    "origin_feature_complete_eligible_tp_or_sl_only");
  rows[64] = PivotV12ManifestRow(
    "broker_binary_cohort_policy",
    "feature_complete_consistent_broker_tp_or_sl_only");
  rows[65] = PivotV12ManifestRow(
    "parity_policy",
    "accepted_request_geometry_shadow_trade_session_observed_broker_terminal_censored_calibration_only_not_matrix_or_ml");
  rows[66] = PivotV12ManifestRow(
    "time_policy",
    "broker_time_causal_analysis_time_export_only");
  rows[67] = PivotV12ManifestRow(
    "broker_session",
    MarketDataTimePolicyToken(Broker_Session));
  rows[68] = PivotV12ManifestRow("feature_set_id",
                                PIVOT_V12_FEATURE_SET_ID);
  rows[69] = PivotV12ManifestRow("research_approval_state",
                                "OFFLINE_RESEARCH_ONLY");

  for(int i = 0; i < ArraySize(rows); i++)
  {
    if(!PivotV12RowMatchesHeader(PIVOT_V12_MANIFEST_HEADER, rows[i]) ||
       !PivotV12WriteLine(filename, rows[i], true))
      return false;
  }
  return true;
}

bool PivotV12CreateDataFiles()
{
  return PivotV12WriteLine(PivotV12Path(PIVOT_V12_WINDOWS_FILE),
                           PIVOT_V12_WINDOWS_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_ORIGINS_FILE),
                           PIVOT_V12_ORIGINS_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_TRIALS_FILE),
                           PIVOT_V12_TRIALS_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_VIRTUAL_OUTCOMES_FILE),
                           PIVOT_V12_VIRTUAL_OUTCOMES_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_CHECKS_FILE),
                           PIVOT_V12_CHECKS_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_BROKER_OUTCOMES_FILE),
                           PIVOT_V12_BROKER_OUTCOMES_HEADER,
                           false) &&
         PivotV12WriteLine(PivotV12Path(PIVOT_V12_SUMMARY_FILE),
                           PIVOT_V12_SUMMARY_HEADER,
                           false);
}

bool PivotV12RunFilesExist()
{
  return FileIsExist(PivotV12Path(PIVOT_V12_MANIFEST_FILE), FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_WINDOWS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_ORIGINS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_TRIALS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_VIRTUAL_OUTCOMES_FILE),
                     FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_CHECKS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_BROKER_OUTCOMES_FILE),
                     FILE_COMMON) ||
         FileIsExist(PivotV12Path(PIVOT_V12_SUMMARY_FILE), FILE_COMMON);
}

void PivotV12StatsReset()
{
  g_pivot_v12_run_id = "";
  g_pivot_v12_config_id = "";
  g_pivot_v12_folder = "";
  g_pivot_v12_started_at = 0;
  g_pivot_v12_initialized = false;
  g_pivot_v12_failed = false;
  g_pivot_v12_error_logged = false;
  g_pivot_v12_summary_written = false;
  g_pivot_v12_window_rows = 0;
  g_pivot_v12_origin_rows = 0;
  g_pivot_v12_virtual_trial_rows = 0;
  g_pivot_v12_matrix_trial_rows = 0;
  g_pivot_v12_reentry_trial_rows = 0;
  g_pivot_v12_parity_trial_rows = 0;
  g_pivot_v12_virtual_active_rows = 0;
  g_pivot_v12_ineligible_feature_rows = 0;
  g_pivot_v12_ineligible_geometry_rows = 0;
  g_pivot_v12_ineligible_distance_rows = 0;
  g_pivot_v12_ineligible_money_rows = 0;
  g_pivot_v12_virtual_outcome_rows = 0;
  g_pivot_v12_matrix_tp_rows = 0;
  g_pivot_v12_matrix_sl_rows = 0;
  g_pivot_v12_matrix_censored_rows = 0;
  g_pivot_v12_parity_outcome_rows = 0;
  g_pivot_v12_check_rows = 0;
  g_pivot_v12_broker_outcome_rows = 0;
  g_pivot_v12_broker_binary_eligible_rows = 0;
  g_pivot_v12_broker_binary_tp_rows = 0;
  g_pivot_v12_broker_binary_sl_rows = 0;
  g_pivot_v12_broker_excluded_rows = 0;
  g_pivot_v12_parity_pair_rows = 0;
  g_pivot_v12_parity_terminal_match_rows = 0;
  g_pivot_v12_parity_terminal_mismatch_rows = 0;
  g_pivot_v12_parity_excluded_rows = 0;
  g_pivot_v12_chain_tp_complete_rows = 0;
  g_pivot_v12_chain_structural_sl_rows = 0;
  g_pivot_v12_chain_reentry_cap_rows = 0;
  g_pivot_v12_chain_boundary_rows = 0;
  g_pivot_v12_chain_origin_expired_rows = 0;
  g_pivot_v12_chain_run_end_censored_rows = 0;
  g_pivot_v12_chain_ineligible_rows = 0;
  g_pivot_v12_duplicate_identity_count = 0;
  g_pivot_v12_referential_integrity_error_count = 0;
  g_pivot_v12_row_integrity_error_count = 0;
  ArrayResize(g_pivot_v12_window_buffer, 0);
  ArrayResize(g_pivot_v12_origin_buffer, 0);
  ArrayResize(g_pivot_v12_trial_buffer, 0);
  ArrayResize(g_pivot_v12_virtual_outcome_buffer, 0);
  ArrayResize(g_pivot_v12_check_buffer, 0);
  ArrayResize(g_pivot_v12_broker_outcome_buffer, 0);
  ArrayResize(g_pivot_v12_pending_origins, 0,
              PIVOT_V12_ORIGIN_STATE_RESERVE);
  ArrayResize(g_pivot_v12_parity_links, 0,
              PIVOT_V12_PARITY_LINK_RESERVE);
  ResetPivotTrialMatrixState();
}

bool PivotV12StatsInit()
{
  PivotV12StatsReset();
  if(!PivotV12Enabled())
    return true;

  g_pivot_v12_started_at = TimeCurrent();
  g_pivot_v12_run_id = PivotV12BuildRunId();
  g_pivot_v12_config_id =
    "cfg_" + PivotV12HashToken(PivotV12BuildConfigPayload());
  g_pivot_v12_folder = PIVOT_V12_STORAGE_ROOT + "\\" +
                       PIVOT_V12_RUNS_FOLDER + "\\" +
                       g_pivot_v12_run_id;
  if(!PivotV12EnsureFolder())
    return false;
  if(PivotV12RunFilesExist())
  {
    PivotV12MarkFailed("RUN_FOLDER_ALREADY_INITIALIZED", g_pivot_v12_folder);
    return false;
  }

  g_pivot_v12_initialized = true;
  if(!PivotV12WriteManifest() || !PivotV12CreateDataFiles())
  {
    PivotV12MarkFailed("INITIALIZE_RUN_FILES", g_pivot_v12_folder);
    return false;
  }
  return true;
}

string PivotV12FeatureToken(const bool available,
                            const double value)
{
  return available ? PivotV12DoubleToken(value, true) : PIVOT_V12_NULL;
}

void PivotV12AppendDerivedSeries(
  string &row,
  const PivotDerivedFeatureSeries &series,
  const bool timeframe_complete)
{
  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    bool available = timeframe_complete && series.complete &&
                     series.available[shift];
    PivotV12AppendColumn(
      row,
      PivotV12FeatureToken(available, series.raw_values[shift]));
    PivotV12AppendColumn(
      row,
      PivotV12FeatureToken(available, series.sma_5_values[shift]));
    PivotV12AppendColumn(
      row,
      PivotV12FeatureToken(available, series.sma_slopes[shift]));
    PivotV12AppendColumn(
      row,
      available
      ? PivotV12PriceSideToken(series.states[shift])
      : PIVOT_V12_NULL);
  }
}

void PivotV12AppendTimeframeFeatures(
  string &row,
  const bool timeframe_complete,
  const PivotBandTrendSnapshot &band_trend,
  const PivotDerivedFeatureSeries &b_percent,
  const PivotDerivedFeatureSeries &stochastic_main_line,
  const PivotDerivedFeatureSeries &stochastic_signal_line)
{
  PivotV12AppendColumn(
    row,
    PivotV12FeatureToken(timeframe_complete && band_trend.width_available,
                         band_trend.width_points_0));
  PivotV12AppendDerivedSeries(row, b_percent, timeframe_complete);
  PivotV12AppendDerivedSeries(row,
                              stochastic_main_line,
                              timeframe_complete);
  PivotV12AppendDerivedSeries(row,
                              stochastic_signal_line,
                              timeframe_complete);
  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    bool available = timeframe_complete && band_trend.complete &&
                     band_trend.base_line_available[shift];
    PivotV12AppendColumn(
      row,
      PivotV12FeatureToken(available, band_trend.base_line[shift]));
    PivotV12AppendColumn(
      row,
      PivotV12FeatureToken(
        available,
        band_trend.base_line_slope_points[shift]));
  }
}

int FindPivotV12PendingOrigin(const string origin_id)
{
  if(origin_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_v12_pending_origins); i++)
  {
    if(g_pivot_v12_pending_origins[i].origin.origin_id == origin_id)
      return i;
  }
  return -1;
}

bool RemovePivotV12PendingOriginAt(const int index)
{
  int total = ArraySize(g_pivot_v12_pending_origins);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_v12_pending_origins[i].CopyFrom(
      g_pivot_v12_pending_origins[i + 1]);
  int reserve = total > 1 ? PIVOT_V12_ORIGIN_STATE_RESERVE : 0;
  return ArrayResize(g_pivot_v12_pending_origins,
                     total - 1,
                     reserve) == total - 1;
}

string PivotV12BrokerAttemptStatus(const PivotSignal &signal)
{
  if(signal.attempt_status == "CENSORED")
    return "CENSORED";
  if(signal.execution.broker_close_confirmed)
    return "CLOSED";
  if(signal.execution.broker_entry_confirmed)
    return "FILLED";
  if(signal.admission_status == EXECUTION_ADMISSION_SEND_FAILED ||
     signal.attempt_status == "SEND_FAILED")
    return "SEND_FAILED";
  if(signal.execution.send_attempted || signal.attempt_status == "SENT")
    return "SENT";
  if(signal.admission_status == EXECUTION_ADMISSION_BLOCKED ||
     signal.attempt_status == "DENIED")
    return "BLOCKED";
  return "NOT_EVALUATED";
}

bool PivotV12RegisterOrigin(const PivotSignal &signal)
{
  if(!PivotV12Ready())
    return false;
  if(signal.origin_id == "" || signal.window_id == "" ||
     signal.broker_signal_id == "" ||
     signal.active_bar_open <= 0 || signal.trigger_time <= 0 ||
     signal.trigger_bid <= 0.0 || signal.trigger_ask < signal.trigger_bid ||
     !signal.levels.valid ||
     !MathIsValidNumber(signal.route.structural_stop_loss) ||
     signal.route.structural_stop_loss <= 0.0)
    return PivotV12RejectReference("REGISTER_ORIGIN_INVALID");
  if(FindPivotV12PendingOrigin(signal.origin_id) >= 0)
  {
    PivotV12RegisterDuplicateIdentity();
    return false;
  }

  PivotV12PendingOrigin pending;
  PivotTrialOriginSnapshot origin;
  origin.origin_id = signal.origin_id;
  origin.window_id = signal.window_id;
  origin.broker_signal_id = signal.broker_signal_id;
  origin.symbol = _Symbol;
  origin.macro_timeframe = signal.pivot_timeframe;
  origin.micro_timeframe = Micro_Timeframe;
  origin.active_bar_open = signal.active_bar_open;
  origin.trigger_time = signal.trigger_time;
  origin.level_id = signal.level_id;
  origin.direction = signal.direction;
  origin.trigger_bid = signal.trigger_bid;
  origin.trigger_ask = signal.trigger_ask;
  origin.spread_points = signal.trigger_spread_points;
  origin.point_size = signal.execution.observation_check.point_size;
  origin.trade_tick_size = signal.execution.observation_check.trade_tick_size;
  origin.stops_level_points =
    signal.execution.observation_check.stops_distance_points;
  origin.freeze_level_points =
    signal.execution.observation_check.freeze_distance_points;
  int level_index = (int)signal.level_id;
  if(level_index < 0 || level_index >= PIVOT_LEVEL_COUNT)
    return PivotV12RejectReference("REGISTER_ORIGIN_LEVEL_INVALID");
  origin.pivot_raw_price = signal.levels.raw_prices[level_index];
  origin.pivot_trade_price = signal.levels.trade_prices[level_index];
  origin.structural_entry_price = signal.direction == BULLISH
                                  ? signal.trigger_ask
                                  : signal.trigger_bid;
  origin.structural_stop_loss = signal.route.structural_stop_loss;
  double signed_structural_risk = signal.direction == BULLISH
                                  ? origin.structural_entry_price -
                                    origin.structural_stop_loss
                                  : origin.structural_stop_loss -
                                    origin.structural_entry_price;
  origin.structural_take_profit = signal.direction == BULLISH
                                  ? origin.structural_entry_price +
                                    signed_structural_risk
                                  : origin.structural_entry_price -
                                    signed_structural_risk;
  if(!MathIsValidNumber(origin.structural_take_profit) ||
     origin.structural_take_profit <= 0.0 ||
     origin.point_size <= 0.0 || origin.trade_tick_size <= 0.0 ||
     origin.stops_level_points < 0.0 ||
     origin.freeze_level_points < 0.0 ||
     !PivotTrialNextOutwardBoundary(signal.direction,
                                    signal.level_id,
                                    signal.levels,
                                    origin.boundary_available,
                                    origin.next_outward_pivot_price))
    return PivotV12RejectReference("REGISTER_ORIGIN_GEOMETRY_INVALID");

  origin.origin_micro_band_width_available =
    signal.features.micro_band_trend.width_available &&
    signal.features.micro_band_width_0 > 0.0;
  origin.origin_micro_band_width_0 =
    origin.origin_micro_band_width_available
    ? signal.features.micro_band_width_0
    : 0.0;
  origin.levels.CopyFrom(signal.levels);
  origin.features.CopyFrom(signal.features);
  pending.origin.CopyFrom(origin);
  pending.broker_attempt_status = PivotV12BrokerAttemptStatus(signal);
  pending.matrix_declared = signal.matrix_declared;

  int total = ArraySize(g_pivot_v12_pending_origins);
  if(ArrayResize(g_pivot_v12_pending_origins,
                 total + 1,
                 PIVOT_V12_ORIGIN_STATE_RESERVE) != total + 1)
  {
    PivotV12MarkFailed("ORIGIN_STATE_RESIZE");
    return false;
  }
  g_pivot_v12_pending_origins[total].CopyFrom(pending);
  return true;
}

bool PivotV12UpdateOrigin(const PivotSignal &signal)
{
  if(!PivotV12Enabled())
    return true;
  if(!PivotV12Ready())
    return false;
  int index = FindPivotV12PendingOrigin(signal.origin_id);
  if(index < 0)
  {
    if(signal.origin_registered && signal.origin_export_finalized &&
       signal.origin_id != "" && signal.window_id != "")
      return true;
    return PivotV12RejectReference("UPDATE_ORIGIN_NOT_FOUND");
  }
  g_pivot_v12_pending_origins[index].broker_attempt_status =
    PivotV12BrokerAttemptStatus(signal);
  g_pivot_v12_pending_origins[index].matrix_declared = signal.matrix_declared;
  return true;
}

datetime PivotV12LatestOriginTriggerForWindow(const string window_id)
{
  datetime latest_trigger = 0;
  for(int i = 0; i < ArraySize(g_pivot_v12_pending_origins); i++)
  {
    if(g_pivot_v12_pending_origins[i].origin.window_id == window_id &&
       g_pivot_v12_pending_origins[i].origin.trigger_time > latest_trigger)
    {
      latest_trigger =
        g_pivot_v12_pending_origins[i].origin.trigger_time;
    }
  }
  return latest_trigger;
}

bool PivotV12RecordOrigin(const PivotV12PendingOrigin &pending,
                          const datetime terminal_time,
                          const string terminal_status)
{
  PivotTrialOriginSnapshot origin(pending.origin);
  if(!PivotV12Ready() || origin.origin_id == "" ||
     origin.window_id == "" || origin.broker_signal_id == "" ||
     terminal_time <= origin.trigger_time ||
     (terminal_status != "WINDOW_EXPIRED" &&
      terminal_status != "RUN_FINISHED") ||
     pending.broker_attempt_status == "NOT_EVALUATED")
    return PivotV12RejectReference("RECORD_ORIGIN_INVALID");

  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row, origin.origin_id);
  PivotV12AppendColumn(row, origin.window_id);
  PivotV12AppendColumn(row, origin.broker_signal_id);
  PivotV12AppendColumn(row, origin.symbol);
  PivotV12AppendColumn(row, EnumToString(origin.macro_timeframe));
  PivotV12AppendColumn(row, EnumToString(origin.micro_timeframe));
  PivotV12AppendColumn(row, PivotV12TimeToken(origin.active_bar_open));
  PivotV12AppendColumn(row, PivotLevelLabel(origin.level_id));
  PivotV12AppendColumn(row, PivotV12DirectionToken(origin.direction));
  PivotV12AppendTimestamp(row, origin.trigger_time);
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.trigger_bid));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.trigger_ask));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.spread_points, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.point_size));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.trade_tick_size));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(origin.stops_level_points, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(origin.freeze_level_points, true));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV12AppendColumn(row,
                         PivotV12DoubleToken(origin.levels.raw_prices[i]));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV12AppendColumn(row,
                         PivotV12DoubleToken(origin.levels.trade_prices[i]));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.pivot_raw_price));
  PivotV12AppendColumn(row, PivotV12DoubleToken(origin.pivot_trade_price));
  PivotV12AppendColumn(row,
                       origin.boundary_available
                       ? PivotV12DoubleToken(origin.next_outward_pivot_price)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(origin.structural_entry_price));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(origin.structural_stop_loss));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(origin.structural_take_profit));

  bool micro_complete = origin.features.micro_complete;
  bool macro_complete = origin.features.macro_complete;
  PivotV12AppendColumn(row,
                       origin.origin_micro_band_width_available
                       ? PivotV12DoubleToken(
                           origin.origin_micro_band_width_0)
                       : PIVOT_V12_NULL);
  PivotV12AppendTimeframeFeatures(
    row,
    micro_complete,
    origin.features.micro_band_trend,
    origin.features.micro_b_percent_features,
    origin.features.micro_stochastic_main_line_features,
    origin.features.micro_stochastic_signal_line_features);
  PivotV12AppendTimeframeFeatures(
    row,
    macro_complete,
    origin.features.macro_band_trend,
    origin.features.macro_b_percent_features,
    origin.features.macro_stochastic_main_line_features,
    origin.features.macro_stochastic_signal_line_features);
  PivotV12AppendColumn(row, PivotV12BoolToken(micro_complete));
  PivotV12AppendColumn(row, PivotV12BoolToken(macro_complete));
  PivotV12AppendColumn(row, PivotV12BoolToken(origin.features.complete));
  string feature_reason = origin.features.invalid_reason;
  if(feature_reason == "")
    feature_reason = "FEATURE_SNAPSHOT_INCOMPLETE";
  PivotV12AppendColumn(row,
                       origin.features.complete
                       ? PIVOT_V12_NULL
                       : PivotV12Cell(feature_reason));
  PivotV12AppendColumn(row, "1");
  PivotV12AppendColumn(row, PivotV12BoolToken(pending.matrix_declared));
  PivotV12AppendColumn(row, pending.broker_attempt_status);
  PivotV12AppendTimestamp(row, terminal_time);
  PivotV12AppendColumn(row, terminal_status);

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_ORIGINS_FILE),
                       PIVOT_V12_ORIGINS_HEADER,
                       row,
                       g_pivot_v12_origin_buffer))
    return false;
  g_pivot_v12_origin_rows++;
  return true;
}

bool PivotV12FinalizeOriginsForWindow(const string window_id,
                                      const datetime terminal_time,
                                      const string terminal_status)
{
  for(int i = ArraySize(g_pivot_v12_pending_origins) - 1; i >= 0; i--)
  {
    if(g_pivot_v12_pending_origins[i].origin.window_id != window_id)
      continue;
    if(!PivotV12RecordOrigin(g_pivot_v12_pending_origins[i],
                             terminal_time,
                             terminal_status) ||
       !RemovePivotV12PendingOriginAt(i))
      return false;
  }
  return true;
}

bool PivotV12RecordWindow(const PivotFractalWindowState &window,
                          const datetime requested_terminal_time,
                          const string terminal_status)
{
  if(!PivotV12Ready())
    return false;
  if(window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     window.active_bar_open <= 0 ||
     window.source_bar_open <= 0 ||
     window.first_observed_time <= 0 ||
     (terminal_status != "EXPIRED" && terminal_status != "RUN_FINISHED"))
    return PivotV12RejectReference("RECORD_WINDOW_INVALID");

  string window_id = PivotV12WindowId(_Symbol,
                                      window.timeframe,
                                      window.active_bar_open);
  datetime terminal_time = requested_terminal_time;
  datetime latest_window_fact = window.active_bar_open;
  if(window.first_observed_time > latest_window_fact)
    latest_window_fact = window.first_observed_time;
  if(window.pp_arm_time > latest_window_fact)
    latest_window_fact = window.pp_arm_time;
  datetime latest_origin_trigger =
    PivotV12LatestOriginTriggerForWindow(window_id);
  if(latest_origin_trigger > latest_window_fact)
    latest_window_fact = latest_origin_trigger;
  if(terminal_time <= latest_window_fact)
    terminal_time = latest_window_fact + 1;
  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row, window_id);
  PivotV12AppendColumn(row, _Symbol);
  PivotV12AppendColumn(row, EnumToString(window.timeframe));
  PivotV12AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV12AppendTimestamp(row, window.active_bar_open);
  PivotV12AppendTimestamp(row, window.source_bar_open);
  PivotV12AppendTimestamp(row, window.source_close_boundary);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.levels.source_open));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.levels.source_high));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.levels.source_low));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.levels.source_close));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.levels.source_range));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV12AppendColumn(row,
                         PivotV12DoubleToken(window.levels.raw_prices[i]));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV12AppendColumn(row,
                         PivotV12DoubleToken(window.levels.trade_prices[i]));
  PivotV12AppendTimestamp(row, window.first_observed_time);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(window.first_observed_bid));
  PivotV12AppendColumn(row,
                       PivotV12PriceSideToken(window.pp_initial_relation));
  PivotV12AppendColumn(row, PivotV12PpRoleToken(window.pp_arm_state));
  PivotV12AppendTimestamp(row, window.pp_arm_time);
  PivotV12AppendColumn(row,
                       window.pp_arm_time > 0
                       ? PivotV12DoubleToken(window.pp_arm_bid)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotV12WindowStateToken(window.state));
  PivotV12AppendColumn(row, PivotV12Cell(window.invalid_reason));
  PivotV12AppendTimestamp(row, terminal_time);
  PivotV12AppendColumn(row, terminal_status);

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_WINDOWS_FILE),
                       PIVOT_V12_WINDOWS_HEADER,
                       row,
                       g_pivot_v12_window_buffer))
    return false;
  g_pivot_v12_window_rows++;
  string origin_terminal_status = terminal_status == "EXPIRED"
                                  ? "WINDOW_EXPIRED"
                                  : "RUN_FINISHED";
  return PivotV12FinalizeOriginsForWindow(window_id,
                                          terminal_time,
                                          origin_terminal_status);
}

bool PivotV12RecordVirtualTrial(const PivotTrialEntry &trial)
{
  if(!PivotV12Ready())
    return false;
  bool matrix_trial = trial.identity.role == PIVOT_TRIAL_ROLE_MATRIX;
  bool parity_trial =
    trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  if((!matrix_trial && !parity_trial) ||
     trial.identity.trial_id == "" ||
     trial.identity.origin_id == "" || trial.identity.window_id == "" ||
     trial.declared_time <= 0 ||
     (matrix_trial && !trial.origin_window_active_at_entry) ||
     trial.geometry.entry_bid <= 0.0 ||
     trial.geometry.entry_ask < trial.geometry.entry_bid ||
     trial.geometry.entry_price <= 0.0 ||
     trial.geometry.point_size <= 0.0 ||
     trial.geometry.trade_tick_size <= 0.0)
    return PivotV12RejectReference("RECORD_VIRTUAL_TRIAL_INVALID");
  if(matrix_trial &&
     (trial.identity.policy_id == "" ||
      !PivotTrialTpMultipleSupported(trial.identity.tp_r_multiple) ||
      trial.identity.reentry_index < 0 ||
      trial.identity.reentry_index > PIVOT_TRIAL_MAX_REENTRY_INDEX ||
      trial.identity.parity_trial_id != "" ||
      trial.identity.broker_signal_id != ""))
    return PivotV12RejectReference("RECORD_MATRIX_TRIAL_IDENTITY_INVALID");
  if(parity_trial &&
     (trial.identity.parity_trial_id == "" ||
      trial.identity.parity_trial_id != trial.identity.trial_id ||
      trial.identity.broker_signal_id == "" ||
      trial.identity.policy_id != "" ||
      trial.identity.tp_r_multiple != 0 ||
      trial.identity.reentry_index != 0 ||
      trial.preceding_loss_count != 0 ||
      trial.parent_trial_id != "" ||
      trial.continuation_source_outcome_id != "" ||
      trial.origin_expiry_time <= 0 ||
      trial.origin_window_active_at_entry !=
        (trial.declared_time < trial.origin_expiry_time) ||
      trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE))
    return PivotV12RejectReference("RECORD_PARITY_TRIAL_IDENTITY_INVALID");

  bool geometry_available =
    trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_FEATURE &&
    trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY;
  bool active =
    trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  if((geometry_available && !trial.geometry.valid) ||
     (active && !trial.money_plan.complete) ||
     (!active && trial.ineligible_reason == ""))
    return PivotV12RejectReference("RECORD_VIRTUAL_TRIAL_STATE_INVALID");

  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row, trial.identity.trial_id);
  PivotV12AppendColumn(
    row,
    parity_trial
    ? trial.identity.parity_trial_id
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    matrix_trial ? trial.identity.policy_id : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, trial.identity.origin_id);
  PivotV12AppendColumn(row, trial.identity.window_id);
  PivotV12AppendColumn(
    row,
    parity_trial
    ? trial.identity.broker_signal_id
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotTrialRoleLabel(trial.identity.role));
  PivotV12AppendColumn(row,
                       matrix_trial
                       ? PivotTrialSlPolicyLabel(trial.identity.sl_policy)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       matrix_trial
                       ? IntegerToString(trial.identity.tp_r_multiple)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       IntegerToString(trial.identity.reentry_index));
  PivotV12AppendColumn(row,
                       IntegerToString(trial.preceding_loss_count));
  PivotV12AppendColumn(row, PivotLevelLabel(trial.level_id));
  PivotV12AppendColumn(row, PivotV12DirectionToken(trial.direction));
  PivotV12AppendTimestamp(row, trial.declared_time);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.entry_bid));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.entry_ask));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.entry_price));
  PivotV12AppendColumn(
    row,
    PivotTrialQuoteSideLabel(trial.geometry.entry_quote_side));
  PivotV12AppendColumn(
    row,
    PivotTrialQuoteSideLabel(trial.geometry.exit_quote_side));
  PivotV12AppendColumn(
    row,
    trial.origin_micro_band_width_available
    ? PivotV12DoubleToken(trial.origin_micro_band_width_0)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.requested_risk_distance_price)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.requested_risk_distance_points)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? StringFormat("%I64d", trial.geometry.normalized_risk_ticks)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.normalized_risk_distance_price)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.normalized_risk_distance_points)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.stop_loss_price)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.take_profit_price)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12Cell(trial.geometry.geometry_equivalence_id)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.spread_points,
                                           true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.point_size));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(trial.geometry.trade_tick_size));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         trial.geometry.stops_level_points,
                         true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         trial.geometry.freeze_level_points,
                         true));
  PivotV12AppendColumn(
    row,
    geometry_available
    ? PivotV12DoubleToken(trial.geometry.minimum_risk_distance_points)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(
                         geometry_available &&
                         trial.geometry.distance_eligible));
  PivotV12AppendColumn(
    row,
    trial.geometry.boundary_available
    ? PivotV12DoubleToken(trial.geometry.boundary_price)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(
                         geometry_available &&
                         trial.geometry.boundary_eligible));
  PivotV12AppendColumn(row, EnumToString(Lot_Type));
  PivotV12AppendColumn(row, DoubleToString(Lot_Strategy_Size, 8));
  PivotV12AppendColumn(
    row,
    reference_mode
    ? PivotV12DoubleToken(PIVOT_EXECUTION_REFERENCE_BALANCE)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, AccountInfoString(ACCOUNT_CURRENCY));
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(trial.money_plan.risk_budget_amount, true)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(trial.money_plan.requested_volume)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(trial.money_plan.normalized_volume)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(
        trial.money_plan.virtual_expected_stop_loss,
        true)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(
        trial.money_plan.virtual_expected_take_profit,
        true)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    trial.money_plan.complete
    ? PivotV12DoubleToken(
        trial.money_plan.virtual_expected_reward_risk_ratio,
        true)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(trial.money_plan.complete));
  PivotV12AppendColumn(
    row,
    PivotTrialEligibilityLabel(trial.eligibility_status));
  PivotV12AppendColumn(row,
                       active
                       ? PIVOT_V12_NULL
                       : PivotV12Cell(trial.ineligible_reason));
  PivotV12AppendColumn(row, PivotV12Cell(trial.parent_trial_id));
  PivotV12AppendColumn(
    row,
    PivotV12Cell(trial.continuation_source_outcome_id));
  PivotV12AppendColumn(
    row,
    PivotV12BoolToken(trial.origin_window_active_at_entry));

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_TRIALS_FILE),
                       PIVOT_V12_TRIALS_HEADER,
                       row,
                       g_pivot_v12_trial_buffer))
    return false;
  g_pivot_v12_virtual_trial_rows++;
  if(matrix_trial)
  {
    g_pivot_v12_matrix_trial_rows++;
    if(trial.identity.reentry_index > 0)
      g_pivot_v12_reentry_trial_rows++;
  }
  else
  {
    g_pivot_v12_parity_trial_rows++;
    if(!PivotV12RegisterParityLink(trial))
      return false;
  }
  if(active)
    g_pivot_v12_virtual_active_rows++;
  else if(matrix_trial)
  {
    g_pivot_v12_chain_ineligible_rows++;
    if(trial.eligibility_status ==
       PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_FEATURE)
      g_pivot_v12_ineligible_feature_rows++;
    else if(trial.eligibility_status ==
            PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_GEOMETRY)
      g_pivot_v12_ineligible_geometry_rows++;
    else if(trial.eligibility_status ==
            PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_DISTANCE)
      g_pivot_v12_ineligible_distance_rows++;
    else if(trial.eligibility_status ==
            PIVOT_TRIAL_ELIGIBILITY_INELIGIBLE_MONEY)
      g_pivot_v12_ineligible_money_rows++;
  }
  return true;
}

bool PivotV12RecordVirtualOutcome(const PivotTrialOutcome &outcome)
{
  if(!PivotV12Ready())
    return false;
  bool censored =
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_CENSORED;
  bool terminal_touch =
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST ||
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  bool matrix_outcome =
    outcome.identity.role == PIVOT_TRIAL_ROLE_MATRIX;
  bool parity_outcome =
    outcome.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  if(outcome.outcome_id == "" || outcome.identity.trial_id == "" ||
     outcome.identity.origin_id == "" || outcome.identity.window_id == "" ||
     (!matrix_outcome && !parity_outcome) ||
     (outcome.direction != BULLISH && outcome.direction != BEARISH) ||
     outcome.terminal_time <= 0 || outcome.duration_seconds <= 0 ||
     outcome.observed_exit_bid <= 0.0 ||
     outcome.observed_exit_ask < outcome.observed_exit_bid ||
     outcome.exit_quote_side != PivotTrialExitQuoteSide(outcome.direction) ||
     outcome.observed_exit_price !=
       (outcome.direction == BULLISH
        ? outcome.observed_exit_bid
        : outcome.observed_exit_ask) ||
     (!terminal_touch && !censored) || !outcome.first_touch_consistent ||
     (terminal_touch &&
      (outcome.threshold_price <= 0.0 ||
       !outcome.virtual_quote_gross_available)))
    return PivotV12RejectReference("RECORD_VIRTUAL_OUTCOME_INVALID");
  if(matrix_outcome &&
     (outcome.identity.policy_id == "" ||
      !PivotTrialTpMultipleSupported(outcome.identity.tp_r_multiple) ||
      outcome.identity.parity_trial_id != "" ||
      outcome.identity.broker_signal_id != ""))
    return PivotV12RejectReference("RECORD_MATRIX_OUTCOME_IDENTITY_INVALID");
  if(parity_outcome &&
     (outcome.identity.parity_trial_id == "" ||
      outcome.identity.parity_trial_id != outcome.identity.trial_id ||
      outcome.identity.broker_signal_id == "" ||
      outcome.identity.policy_id != "" ||
      outcome.identity.tp_r_multiple != 0 ||
      outcome.identity.reentry_index != 0 ||
      outcome.virtual_binary_eligible ||
      outcome.virtual_exclusion_reason == "" ||
      !outcome.chain_terminal ||
      outcome.chain_terminal_reason !=
        PIVOT_TRIAL_CHAIN_PARITY_COMPLETE ||
      outcome.continuation_allowed))
    return PivotV12RejectReference("RECORD_PARITY_OUTCOME_INVALID");

  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row, outcome.outcome_id);
  PivotV12AppendColumn(row, outcome.identity.trial_id);
  PivotV12AppendColumn(
    row,
    parity_outcome
    ? outcome.identity.parity_trial_id
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    matrix_outcome ? outcome.identity.policy_id : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, outcome.identity.origin_id);
  PivotV12AppendColumn(row, outcome.identity.window_id);
  PivotV12AppendColumn(row, PivotTrialRoleLabel(outcome.identity.role));
  PivotV12AppendColumn(
    row,
    matrix_outcome
    ? PivotTrialSlPolicyLabel(outcome.identity.sl_policy)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       matrix_outcome
                       ? IntegerToString(outcome.identity.tp_r_multiple)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       IntegerToString(outcome.identity.reentry_index));
  PivotV12AppendColumn(row,
                       PivotV12DirectionToken(outcome.direction));
  PivotV12AppendTimestamp(row, outcome.terminal_time);
  PivotV12AppendColumn(row,
                       PivotTrialFirstTouchLabel(outcome.first_touch));
  PivotV12AppendColumn(row, outcome.terminal_reason);
  PivotV12AppendColumn(row,
                       censored
                       ? PIVOT_V12_NULL
                       : PivotV12DoubleToken(outcome.threshold_price));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(outcome.observed_exit_bid));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(outcome.observed_exit_ask));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(outcome.observed_exit_price));
  PivotV12AppendColumn(
    row,
    PivotTrialQuoteSideLabel(outcome.exit_quote_side));
  PivotV12AppendColumn(row,
                       censored
                       ? PIVOT_V12_NULL
                       : PivotV12DoubleToken(outcome.gap_points, true));
  PivotV12AppendColumn(row,
                       StringFormat("%I64d", outcome.duration_seconds));
  PivotV12AppendColumn(row,
                       censored
                       ? PIVOT_V12_NULL
                       : PivotV12DoubleToken(outcome.virtual_nominal_r,
                                             true));
  PivotV12AppendColumn(
    row,
    censored
    ? PIVOT_V12_NULL
    : PivotV12DoubleToken(outcome.virtual_quote_gross_profit, true));
  PivotV12AppendColumn(row,
                       censored
                       ? PIVOT_V12_NULL
                       : PivotV12DoubleToken(outcome.virtual_quote_gross_r,
                                             true));
  PivotV12AppendColumn(
    row,
    PivotV12BoolToken(outcome.virtual_binary_eligible));
  PivotV12AppendColumn(
    row,
    outcome.virtual_binary_eligible
    ? IntegerToString(outcome.virtual_binary_target)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    outcome.virtual_binary_eligible
    ? PIVOT_V12_NULL
    : PivotV12Cell(outcome.virtual_exclusion_reason));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(outcome.first_touch_consistent));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(outcome.chain_terminal));
  PivotV12AppendColumn(
    row,
    outcome.chain_terminal
    ? PivotTrialChainTerminalLabel(outcome.chain_terminal_reason)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(
    row,
    PivotV12BoolToken(outcome.continuation_allowed));
  PivotV12AppendColumn(row,
                       PivotV12Cell(outcome.continuation_reason));
  PivotV12AppendColumn(
    row,
    outcome.next_reentry_index >= 0
    ? IntegerToString(outcome.next_reentry_index)
    : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotV12Cell(outcome.next_trial_id));

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_VIRTUAL_OUTCOMES_FILE),
                       PIVOT_V12_VIRTUAL_OUTCOMES_HEADER,
                       row,
                       g_pivot_v12_virtual_outcome_buffer))
    return false;
  g_pivot_v12_virtual_outcome_rows++;
  if(parity_outcome)
  {
    g_pivot_v12_parity_outcome_rows++;
    if(!PivotV12LinkParityVirtualOutcome(outcome))
      return false;
  }
  else
  {
    if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST)
      g_pivot_v12_matrix_tp_rows++;
    else if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST)
      g_pivot_v12_matrix_sl_rows++;
    else if(censored)
      g_pivot_v12_matrix_censored_rows++;

    if(outcome.chain_terminal_reason == PIVOT_TRIAL_CHAIN_TP_REACHED)
      g_pivot_v12_chain_tp_complete_rows++;
    else if(outcome.chain_terminal_reason ==
            PIVOT_TRIAL_CHAIN_STRUCTURAL_SL)
      g_pivot_v12_chain_structural_sl_rows++;
    else if(outcome.chain_terminal_reason ==
            PIVOT_TRIAL_CHAIN_REENTRY_CAP_REACHED)
      g_pivot_v12_chain_reentry_cap_rows++;
    else if(outcome.chain_terminal_reason ==
            PIVOT_TRIAL_CHAIN_NEXT_PIVOT_BOUNDARY)
      g_pivot_v12_chain_boundary_rows++;
    else if(outcome.chain_terminal_reason ==
            PIVOT_TRIAL_CHAIN_ORIGIN_EXPIRED)
      g_pivot_v12_chain_origin_expired_rows++;
    else if(outcome.chain_terminal_reason ==
            PIVOT_TRIAL_CHAIN_RUN_END_CENSORED)
      g_pivot_v12_chain_run_end_censored_rows++;
  }
  return true;
}

bool PivotV12RecordExecutionCheck(const PivotSignal &signal,
                                  const BrokerExecutionCheck &check)
{
  if(!PivotV12Ready())
    return false;
  if(signal.origin_id == "" || signal.broker_signal_id == "" ||
     signal.window_id == "" || check.sequence <= 0 ||
     check.broker_time <= 0)
    return PivotV12RejectReference("RECORD_EXECUTION_CHECK_INVALID");

  bool terminal_phase = check.phase == "TERMINAL";
  bool send_performed = check.phase == "SEND_RESULT" &&
                        signal.execution.send_attempted;
  bool send_succeeded = send_performed && check.allowed;
  bool entry_confirmed = signal.execution.broker_entry_confirmed;
  bool close_confirmed = terminal_phase &&
                         signal.execution.broker_close_confirmed;
  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  ulong order_ticket = signal.execution.order_ticket > 0
                       ? signal.execution.order_ticket
                       : check.order_ticket;
  ulong deal_ticket = check.deal_ticket;
  if(entry_confirmed)
    deal_ticket = signal.execution.entry_deal_ticket;
  if(close_confirmed)
    deal_ticket = signal.execution.last_close_deal_ticket;

  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row,
                       PivotV12CheckId(signal.broker_signal_id,
                                       check.sequence,
                                       check.phase));
  PivotV12AppendColumn(row, signal.origin_id);
  PivotV12AppendColumn(row, signal.broker_signal_id);
  PivotV12AppendColumn(row, PivotV12Cell(signal.parity_trial_id));
  PivotV12AppendColumn(row, signal.window_id);
  PivotV12AppendColumn(row, IntegerToString(check.sequence));
  PivotV12AppendColumn(row, check.phase);
  PivotV12AppendTimestamp(row, check.broker_time);
  PivotV12AppendColumn(row, _Symbol);
  PivotV12AppendColumn(row, PivotV12DirectionToken(signal.direction));
  PivotV12AppendColumn(row, StringFormat("%I64d", check.account_margin_mode));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(check.account_margin_mode_supported));
  PivotV12AppendColumn(row, StringFormat("%I64d", check.symbol_trade_mode));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(check.symbol_trade_mode_allowed));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.market_session_open));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.account_trade_allowed));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(check.account_expert_trade_allowed));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.terminal_trade_allowed));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.mql_trade_allowed));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.bid, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.ask, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.spread_points, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.point_size, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.trade_tick_size, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.stops_distance_points, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.freeze_distance_points, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.planned_entry_price, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.stop_loss_price, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.take_profit_price, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.risk_distance_points, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.reward_distance_points, true));
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(check.risk_budget_amount, true)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.requested_volume, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.normalized_volume, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.volume_min, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.volume_max, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.volume_step, true));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.volume_valid));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.fok_supported));
  PivotV12AppendColumn(row, "ORDER_FILLING_FOK");
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.quote_expected_stop_loss,
                                           true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.quote_expected_take_profit,
                                           true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         check.quote_expected_reward_risk_ratio,
                         true));
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(
                           check.risk_budget_utilization_ratio,
                           true)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.account_balance, true));
  PivotV12AppendColumn(row, PivotV12DoubleToken(check.free_margin, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(check.required_margin, true));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.margin_valid));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.geometry_valid));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.stop_distance_valid));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.freeze_distance_valid));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(check.order_check_performed));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.order_check_allowed));
  PivotV12AppendColumn(row,
                       check.order_check_performed
                       ? StringFormat("%I64u", check.order_check_retcode)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotV12Cell(check.order_check_comment));
  PivotV12AppendColumn(row, PivotV12BoolToken(check.allowed));
  PivotV12AppendColumn(row, PivotV12Cell(check.block_source));
  PivotV12AppendColumn(row, PivotV12Cell(check.block_reason));
  PivotV12AppendColumn(row, PivotV12BoolToken(send_performed));
  PivotV12AppendColumn(row, PivotV12BoolToken(send_succeeded));
  PivotV12AppendColumn(row,
                       send_performed
                       ? "TRADE_ACTION_DEAL"
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       send_performed
                       ? StringFormat("%I64u", check.send_retcode)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, PivotV12Cell(check.send_comment));
  PivotV12AppendColumn(row, PivotV12UlongToken(order_ticket));
  PivotV12AppendColumn(row, PivotV12UlongToken(deal_ticket));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(signal.execution.position_ticket));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(
                         signal.execution.position_identifier));
  PivotV12AppendColumn(row, PivotV12BoolToken(entry_confirmed));
  PivotV12AppendColumn(row, PivotV12BoolToken(close_confirmed));
  PivotV12AppendColumn(row,
                       entry_confirmed
                       ? PivotV12DoubleToken(
                           signal.execution.broker_entry_price)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       entry_confirmed
                       ? PivotV12DoubleToken(signal.execution.broker_volume)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       entry_confirmed
                       ? PivotV12DoubleToken(
                           signal.execution.broker_stop_loss)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       entry_confirmed
                       ? PivotV12DoubleToken(
                           signal.execution.broker_take_profit)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       close_confirmed
                       ? PivotV12DoubleToken(signal.execution.close_price)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       close_confirmed
                       ? PivotV12DoubleToken(signal.execution.closed_volume)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       close_confirmed
                       ? signal.execution.terminal_reason
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row, "0");

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_CHECKS_FILE),
                       PIVOT_V12_CHECKS_HEADER,
                       row,
                       g_pivot_v12_check_buffer))
    return false;
  g_pivot_v12_check_rows++;
  return true;
}

bool PivotV12RecordBrokerOutcome(const PivotSignal &signal)
{
  if(!PivotV12Ready())
    return false;
  if(signal.origin_id == "" || signal.broker_signal_id == "" ||
     signal.window_id == "" ||
     !signal.execution.broker_entry_confirmed ||
     !signal.execution.broker_close_confirmed ||
     signal.execution.close_deal_count <= 0)
    return PivotV12RejectReference("RECORD_BROKER_OUTCOME_INVALID");

  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  long duration_seconds = (long)(signal.execution.close_time -
                                 signal.execution.broker_entry_time);
  if(duration_seconds < 0)
    return PivotV12RejectReference("RECORD_BROKER_OUTCOME_TIME");

  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendColumn(row,
                       PivotV12BrokerOutcomeId(signal.broker_signal_id));
  PivotV12AppendColumn(row, signal.origin_id);
  PivotV12AppendColumn(row, signal.broker_signal_id);
  PivotV12AppendColumn(row, PivotV12Cell(signal.parity_trial_id));
  PivotV12AppendColumn(row, signal.window_id);
  PivotV12AppendColumn(row, _Symbol);
  PivotV12AppendColumn(row, EnumToString(signal.pivot_timeframe));
  PivotV12AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV12AppendColumn(row, PivotV12TimeToken(signal.active_bar_open));
  PivotV12AppendColumn(row, PivotLevelLabel(signal.level_id));
  PivotV12AppendColumn(row, PivotV12DirectionToken(signal.direction));
  PivotV12AppendTimestamp(row, signal.execution.broker_entry_time);
  PivotV12AppendTimestamp(row, signal.execution.close_time);
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(signal.execution.order_ticket));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(signal.execution.entry_deal_ticket));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(
                         signal.execution.last_close_deal_ticket));
  PivotV12AppendColumn(row,
                       IntegerToString(signal.execution.close_deal_count));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(signal.execution.position_ticket));
  PivotV12AppendColumn(row,
                       PivotV12UlongToken(
                         signal.execution.position_identifier));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.planned_entry_price));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.broker_entry_price));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.broker_volume));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.broker_stop_loss));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.broker_take_profit));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.close_price));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.closed_volume));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.risk_distance_points));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.reward_distance_points));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.price_reward_risk_ratio));
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(
                           signal.execution.risk_budget_amount)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.quote_expected_stop_loss));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.quote_expected_take_profit));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.quote_expected_reward_risk_ratio));
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(
                           signal.execution.risk_budget_utilization_ratio)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.entry_slippage_points,
                         true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.exit_slippage_points,
                         true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.gross_profit,
                                           true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.commission,
                                           true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.swap, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.fee, true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.net_profit, true));
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(signal.execution.gross_budget_r,
                                             true)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       reference_mode
                       ? PivotV12DoubleToken(signal.execution.net_budget_r,
                                             true)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(
                         signal.execution.gross_execution_r,
                         true));
  PivotV12AppendColumn(row,
                       PivotV12DoubleToken(signal.execution.net_execution_r,
                                           true));
  PivotV12AppendColumn(row, signal.execution.terminal_reason);
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(
                         signal.execution.close_reason_consistent));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(signal.execution.binary_eligible));
  PivotV12AppendColumn(row,
                       signal.execution.binary_eligible
                       ? IntegerToString(signal.execution.binary_target)
                       : PIVOT_V12_NULL);
  PivotV12AppendColumn(row,
                       PivotV12Cell(signal.execution.exclusion_reason));
  PivotV12AppendColumn(row, StringFormat("%I64d", duration_seconds));
  PivotV12AppendColumn(row, "1");
  PivotV12AppendColumn(row, "1");

  if(!PivotV12QueueRow(PivotV12Path(PIVOT_V12_BROKER_OUTCOMES_FILE),
                       PIVOT_V12_BROKER_OUTCOMES_HEADER,
                       row,
                       g_pivot_v12_broker_outcome_buffer))
    return false;
  g_pivot_v12_broker_outcome_rows++;
  if(signal.execution.binary_eligible)
  {
    g_pivot_v12_broker_binary_eligible_rows++;
    if(signal.execution.binary_target == 1)
      g_pivot_v12_broker_binary_tp_rows++;
    else if(signal.execution.binary_target == 0)
      g_pivot_v12_broker_binary_sl_rows++;
  }
  else
  {
    g_pivot_v12_broker_excluded_rows++;
  }
  if(signal.parity_trial_id != "")
  {
    if(!PivotV12LinkParityBrokerOutcome(signal))
      return false;
  }
  return true;
}

void PivotV12RegisterDuplicateIdentity()
{
  g_pivot_v12_duplicate_identity_count++;
}

bool PivotV12MarkOriginMatrixDeclared(const string origin_id)
{
  int index = FindPivotV12PendingOrigin(origin_id);
  if(index < 0)
    return false;
  g_pivot_v12_pending_origins[index].matrix_declared = true;
  return true;
}

bool PivotV12WriteSummary(const string completion_status)
{
  if(!PivotV12Enabled() || !g_pivot_v12_initialized ||
     g_pivot_v12_summary_written)
    return !g_pivot_v12_failed;

  if(PivotTrialResearchIntegrityFailed())
    PivotV12MarkFailed("VIRTUAL_STATE_INTEGRITY");
  if(g_pivot_v12_parity_terminal_mismatch_rows > 0)
    PivotV12MarkFailed("PARITY_TERMINAL_MISMATCH");
  for(int i = 0; i < ArraySize(g_pivot_v12_parity_links); i++)
  {
    if(!g_pivot_v12_parity_links[i].virtual_outcome_recorded)
    {
      PivotV12RejectReference("PARITY_OUTCOME_MISSING");
      break;
    }
  }
  if(ArraySize(g_pivot_v12_pending_origins) > 0)
    PivotV12RejectReference("SUMMARY_PENDING_ORIGINS");
  if(!PivotV12FlushAll())
    PivotV12MarkFailed("FLUSH_ALL");
  datetime finished_at = TimeCurrent();
  if(finished_at < g_pivot_v12_started_at)
    finished_at = g_pivot_v12_started_at;

  string row = "";
  PivotV12AppendColumn(row, IntegerToString(PIVOT_V12_SCHEMA_VERSION));
  PivotV12AppendColumn(row, g_pivot_v12_run_id);
  PivotV12AppendColumn(row, g_pivot_v12_config_id);
  PivotV12AppendTimestamp(row, g_pivot_v12_started_at);
  PivotV12AppendTimestamp(row, finished_at);
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_window_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_origin_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_virtual_trial_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_matrix_trial_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_reentry_trial_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_parity_trial_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_virtual_active_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_ineligible_feature_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_ineligible_geometry_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_ineligible_distance_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_ineligible_money_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_virtual_outcome_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_matrix_tp_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_matrix_sl_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_matrix_censored_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_parity_outcome_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_check_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_broker_outcome_rows));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_broker_binary_eligible_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_broker_binary_tp_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_broker_binary_sl_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_broker_excluded_rows));
  PivotV12AppendColumn(row, IntegerToString(g_pivot_v12_parity_pair_rows));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_parity_terminal_match_rows));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_parity_terminal_mismatch_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_parity_excluded_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_chain_tp_complete_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_chain_structural_sl_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_chain_reentry_cap_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_chain_boundary_rows));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_chain_origin_expired_rows));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_chain_run_end_censored_rows));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_chain_ineligible_rows));
  PivotV12AppendColumn(row, IntegerToString(PivotTrialActiveStatePeak()));
  PivotV12AppendColumn(row,
                       IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP));
  PivotV12AppendColumn(row,
                       PivotV12BoolToken(PivotTrialStateCapacityFailed()));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_duplicate_identity_count +
                    PivotTrialDuplicateIdentityCount()));
  PivotV12AppendColumn(
    row,
    IntegerToString(g_pivot_v12_referential_integrity_error_count));
  PivotV12AppendColumn(row,
                       IntegerToString(g_pivot_v12_row_integrity_error_count));
  PivotV12AppendColumn(row, g_pivot_v12_failed ? "FAILED" : "OK");
  PivotV12AppendColumn(row, completion_status);

  string filename = PivotV12Path(PIVOT_V12_SUMMARY_FILE);
  if(!PivotV12RowMatchesHeader(PIVOT_V12_SUMMARY_HEADER, row) ||
     !PivotV12FileHeaderMatches(filename, PIVOT_V12_SUMMARY_HEADER) ||
     !PivotV12WriteLine(filename, row, true))
    return false;
  g_pivot_v12_summary_written = true;
  return !g_pivot_v12_failed;
}

void PivotV12StatsDeinit(const string completion_status = "CENSORED")
{
  if(!PivotV12Enabled() || !g_pivot_v12_initialized)
    return;
  PivotV12WriteSummary(completion_status);
  ArrayResize(g_pivot_v12_window_buffer, 0);
  ArrayResize(g_pivot_v12_origin_buffer, 0);
  ArrayResize(g_pivot_v12_trial_buffer, 0);
  ArrayResize(g_pivot_v12_virtual_outcome_buffer, 0);
  ArrayResize(g_pivot_v12_check_buffer, 0);
  ArrayResize(g_pivot_v12_broker_outcome_buffer, 0);
  ArrayResize(g_pivot_v12_pending_origins, 0);
  ArrayResize(g_pivot_v12_parity_links, 0);
  ResetPivotTrialMatrixState();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
