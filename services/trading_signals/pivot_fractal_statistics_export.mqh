//+------------------------------------------------------------------+
//|              trading_signals/pivot_fractal_statistics_export   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_

const int PIVOT_V13_SCHEMA_VERSION = 13;
const string PIVOT_V13_ENGINE_LABEL = "PIVOT_FRACTAL_V2";
const string PIVOT_V13_FEATURE_SET_ID =
  "schema_v13_hft_deep_pivot_features";
const string PIVOT_V13_STORAGE_ROOT = "PivotFractalV13";
const string PIVOT_V13_RUNS_FOLDER = "runs";
const string PIVOT_V13_NULL = "\\N";
const int PIVOT_V13_FLUSH_ROWS = 256;
const int PIVOT_V13_ORIGIN_STATE_RESERVE = 64;
const int PIVOT_V13_PARITY_LINK_RESERVE = 16;

const string PIVOT_V13_MANIFEST_FILE = "run_manifest.tsv";
const string PIVOT_V13_WINDOWS_FILE = "pivot_windows.tsv";
const string PIVOT_V13_ORIGINS_FILE = "signal_origins.tsv";
const string PIVOT_V13_VIRTUAL_TRIALS_FILE = "virtual_trials.tsv";
const string PIVOT_V13_VIRTUAL_OUTCOMES_FILE = "virtual_outcomes.tsv";
const string PIVOT_V13_DEEP_EVENTS_FILE = "deep_pivot_events.tsv";
const string PIVOT_V13_DEEP_LINKS_FILE = "deep_pivot_parent_links.tsv";
const string PIVOT_V13_DEEP_TRIALS_FILE = "deep_virtual_trials.tsv";
const string PIVOT_V13_DEEP_OUTCOMES_FILE = "deep_virtual_outcomes.tsv";
const string PIVOT_V13_CHECKS_FILE = "execution_checks.tsv";
const string PIVOT_V13_BROKER_OUTCOMES_FILE = "broker_outcomes.tsv";
const string PIVOT_V13_SUMMARY_FILE = "run_summary.tsv";

const string PIVOT_V13_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string PIVOT_V13_WINDOWS_HEADER =
  "schema_version\trun_id\tconfig_id\twindow_id\twindow_scope\tsymbol\ttimeframe\tactive_bar_open_broker_time\tactive_bar_open_analysis_time\tactive_bar_open_offset_minutes\tsource_bar_open_broker_time\tsource_bar_open_analysis_time\tsource_bar_open_offset_minutes\tsource_close_boundary_broker_time\tsource_close_boundary_analysis_time\tsource_close_boundary_offset_minutes\tsource_open\tsource_high\tsource_low\tsource_close\tsource_range\traw_s3_price\traw_s2_price\traw_s1_price\traw_pp_price\traw_r1_price\traw_r2_price\traw_r3_price\ttrade_s3_price\ttrade_s2_price\ttrade_s1_price\ttrade_pp_price\ttrade_r1_price\ttrade_r2_price\ttrade_r3_price\tfirst_observed_broker_time\tfirst_observed_analysis_time\tfirst_observed_offset_minutes\tfirst_observed_bid\tpp_initial_relation\tpp_role\tpp_arm_broker_time\tpp_arm_analysis_time\tpp_arm_offset_minutes\tpp_arm_bid\twindow_state\tinvalid_reason\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status";
const string PIVOT_V13_ORIGINS_HEADER =
  "schema_version\trun_id\tconfig_id\torigin_id\twindow_id\tbroker_signal_id\tsymbol\tmacro_timeframe\tdeep_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\ttrigger_bid\ttrigger_ask\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\traw_s3_price\traw_s2_price\traw_s1_price\traw_pp_price\traw_r1_price\traw_r2_price\traw_r3_price\ttrade_s3_price\ttrade_s2_price\ttrade_s1_price\ttrade_pp_price\ttrade_r1_price\ttrade_r2_price\ttrade_r3_price\tpivot_raw_price\tpivot_trade_price\tnext_outward_pivot_price\tmidpoint_50_price\tstructural_entry_price\tstructural_sl_price\tstructural_take_profit\torigin_micro_band_width_points_0\torigin_micro_b_percent_0\torigin_micro_b_percent_sma_5_0\torigin_micro_b_percent_sma_slope_0\torigin_micro_b_percent_state_0\torigin_micro_b_percent_1\torigin_micro_b_percent_sma_5_1\torigin_micro_b_percent_sma_slope_1\torigin_micro_b_percent_state_1\torigin_micro_b_percent_2\torigin_micro_b_percent_sma_5_2\torigin_micro_b_percent_sma_slope_2\torigin_micro_b_percent_state_2\torigin_micro_b_percent_3\torigin_micro_b_percent_sma_5_3\torigin_micro_b_percent_sma_slope_3\torigin_micro_b_percent_state_3\torigin_micro_b_percent_4\torigin_micro_b_percent_sma_5_4\torigin_micro_b_percent_sma_slope_4\torigin_micro_b_percent_state_4\torigin_micro_b_percent_5\torigin_micro_b_percent_sma_5_5\torigin_micro_b_percent_sma_slope_5\torigin_micro_b_percent_state_5\torigin_micro_stochastic_main_line_0\torigin_micro_stochastic_main_line_sma_5_0\torigin_micro_stochastic_main_line_sma_slope_0\torigin_micro_stochastic_main_line_state_0\torigin_micro_stochastic_main_line_1\torigin_micro_stochastic_main_line_sma_5_1\torigin_micro_stochastic_main_line_sma_slope_1\torigin_micro_stochastic_main_line_state_1\torigin_micro_stochastic_main_line_2\torigin_micro_stochastic_main_line_sma_5_2\torigin_micro_stochastic_main_line_sma_slope_2\torigin_micro_stochastic_main_line_state_2\torigin_micro_stochastic_main_line_3\torigin_micro_stochastic_main_line_sma_5_3\torigin_micro_stochastic_main_line_sma_slope_3\torigin_micro_stochastic_main_line_state_3\torigin_micro_stochastic_main_line_4\torigin_micro_stochastic_main_line_sma_5_4\torigin_micro_stochastic_main_line_sma_slope_4\torigin_micro_stochastic_main_line_state_4\torigin_micro_stochastic_main_line_5\torigin_micro_stochastic_main_line_sma_5_5\torigin_micro_stochastic_main_line_sma_slope_5\torigin_micro_stochastic_main_line_state_5\torigin_micro_stochastic_signal_line_0\torigin_micro_stochastic_signal_line_sma_5_0\torigin_micro_stochastic_signal_line_sma_slope_0\torigin_micro_stochastic_signal_line_state_0\torigin_micro_stochastic_signal_line_1\torigin_micro_stochastic_signal_line_sma_5_1\torigin_micro_stochastic_signal_line_sma_slope_1\torigin_micro_stochastic_signal_line_state_1\torigin_micro_stochastic_signal_line_2\torigin_micro_stochastic_signal_line_sma_5_2\torigin_micro_stochastic_signal_line_sma_slope_2\torigin_micro_stochastic_signal_line_state_2\torigin_micro_stochastic_signal_line_3\torigin_micro_stochastic_signal_line_sma_5_3\torigin_micro_stochastic_signal_line_sma_slope_3\torigin_micro_stochastic_signal_line_state_3\torigin_micro_stochastic_signal_line_4\torigin_micro_stochastic_signal_line_sma_5_4\torigin_micro_stochastic_signal_line_sma_slope_4\torigin_micro_stochastic_signal_line_state_4\torigin_micro_stochastic_signal_line_5\torigin_micro_stochastic_signal_line_sma_5_5\torigin_micro_stochastic_signal_line_sma_slope_5\torigin_micro_stochastic_signal_line_state_5\torigin_micro_band_base_line_0\torigin_micro_band_base_line_slope_points_0\torigin_micro_band_base_line_1\torigin_micro_band_base_line_slope_points_1\torigin_micro_band_base_line_2\torigin_micro_band_base_line_slope_points_2\torigin_micro_band_base_line_3\torigin_micro_band_base_line_slope_points_3\torigin_micro_band_base_line_4\torigin_micro_band_base_line_slope_points_4\torigin_micro_band_base_line_5\torigin_micro_band_base_line_slope_points_5\torigin_macro_band_width_points_0\torigin_macro_b_percent_0\torigin_macro_b_percent_sma_5_0\torigin_macro_b_percent_sma_slope_0\torigin_macro_b_percent_state_0\torigin_macro_b_percent_1\torigin_macro_b_percent_sma_5_1\torigin_macro_b_percent_sma_slope_1\torigin_macro_b_percent_state_1\torigin_macro_b_percent_2\torigin_macro_b_percent_sma_5_2\torigin_macro_b_percent_sma_slope_2\torigin_macro_b_percent_state_2\torigin_macro_b_percent_3\torigin_macro_b_percent_sma_5_3\torigin_macro_b_percent_sma_slope_3\torigin_macro_b_percent_state_3\torigin_macro_b_percent_4\torigin_macro_b_percent_sma_5_4\torigin_macro_b_percent_sma_slope_4\torigin_macro_b_percent_state_4\torigin_macro_b_percent_5\torigin_macro_b_percent_sma_5_5\torigin_macro_b_percent_sma_slope_5\torigin_macro_b_percent_state_5\torigin_macro_stochastic_main_line_0\torigin_macro_stochastic_main_line_sma_5_0\torigin_macro_stochastic_main_line_sma_slope_0\torigin_macro_stochastic_main_line_state_0\torigin_macro_stochastic_main_line_1\torigin_macro_stochastic_main_line_sma_5_1\torigin_macro_stochastic_main_line_sma_slope_1\torigin_macro_stochastic_main_line_state_1\torigin_macro_stochastic_main_line_2\torigin_macro_stochastic_main_line_sma_5_2\torigin_macro_stochastic_main_line_sma_slope_2\torigin_macro_stochastic_main_line_state_2\torigin_macro_stochastic_main_line_3\torigin_macro_stochastic_main_line_sma_5_3\torigin_macro_stochastic_main_line_sma_slope_3\torigin_macro_stochastic_main_line_state_3\torigin_macro_stochastic_main_line_4\torigin_macro_stochastic_main_line_sma_5_4\torigin_macro_stochastic_main_line_sma_slope_4\torigin_macro_stochastic_main_line_state_4\torigin_macro_stochastic_main_line_5\torigin_macro_stochastic_main_line_sma_5_5\torigin_macro_stochastic_main_line_sma_slope_5\torigin_macro_stochastic_main_line_state_5\torigin_macro_stochastic_signal_line_0\torigin_macro_stochastic_signal_line_sma_5_0\torigin_macro_stochastic_signal_line_sma_slope_0\torigin_macro_stochastic_signal_line_state_0\torigin_macro_stochastic_signal_line_1\torigin_macro_stochastic_signal_line_sma_5_1\torigin_macro_stochastic_signal_line_sma_slope_1\torigin_macro_stochastic_signal_line_state_1\torigin_macro_stochastic_signal_line_2\torigin_macro_stochastic_signal_line_sma_5_2\torigin_macro_stochastic_signal_line_sma_slope_2\torigin_macro_stochastic_signal_line_state_2\torigin_macro_stochastic_signal_line_3\torigin_macro_stochastic_signal_line_sma_5_3\torigin_macro_stochastic_signal_line_sma_slope_3\torigin_macro_stochastic_signal_line_state_3\torigin_macro_stochastic_signal_line_4\torigin_macro_stochastic_signal_line_sma_5_4\torigin_macro_stochastic_signal_line_sma_slope_4\torigin_macro_stochastic_signal_line_state_4\torigin_macro_stochastic_signal_line_5\torigin_macro_stochastic_signal_line_sma_5_5\torigin_macro_stochastic_signal_line_sma_slope_5\torigin_macro_stochastic_signal_line_state_5\torigin_macro_band_base_line_0\torigin_macro_band_base_line_slope_points_0\torigin_macro_band_base_line_1\torigin_macro_band_base_line_slope_points_1\torigin_macro_band_base_line_2\torigin_macro_band_base_line_slope_points_2\torigin_macro_band_base_line_3\torigin_macro_band_base_line_slope_points_3\torigin_macro_band_base_line_4\torigin_macro_band_base_line_slope_points_4\torigin_macro_band_base_line_5\torigin_macro_band_base_line_slope_points_5\torigin_micro_features_complete\torigin_macro_features_complete\torigin_feature_snapshot_complete\torigin_feature_invalid_reason\tidentity_consumed\th1_lanes_declared\tbroker_attempt_status\torigin_terminal_status";
const string PIVOT_V13_TRIALS_HEADER =
  "schema_version\trun_id\tconfig_id\ttrial_id\tparity_trial_id\torigin_id\twindow_id\tbroker_signal_id\ttrial_role\tentry_policy\ttp_r_multiple\tlevel_id\tdirection\tdeclared_broker_time\tdeclared_analysis_time\tdeclared_offset_minutes\tentry_broker_time\tentry_analysis_time\tentry_offset_minutes\tentry_bid\tentry_ask\tentry_price\tentry_quote_side\texit_quote_side\tmidpoint_50_price\tmidpoint_touched\trequested_risk_distance_price\trequested_risk_distance_points\tnormalized_risk_ticks\tnormalized_risk_distance_price\tnormalized_risk_distance_points\tstop_loss_price\ttake_profit_price\tgeometry_equivalence_id\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\tminimum_risk_distance_points\tdistance_eligible\tlot_mode\tlot_strategy_size\treference_balance\taccount_currency\trisk_budget_amount\trequested_volume\tnormalized_volume\tvirtual_expected_stop_loss\tvirtual_expected_take_profit\tvirtual_expected_reward_risk_ratio\tvirtual_money_plan_complete\teligibility_status\tineligible_reason\torigin_window_active_at_entry";
const string PIVOT_V13_VIRTUAL_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\toutcome_id\ttrial_id\tparity_trial_id\torigin_id\twindow_id\ttrial_role\tentry_policy\ttp_r_multiple\tdirection\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status\tterminal_reason\tthreshold_price\tobserved_exit_bid\tobserved_exit_ask\tobserved_exit_price\texit_quote_side\tgap_points\th1_structural_lifecycle_seconds\tvirtual_nominal_r\tvirtual_quote_gross_profit\tvirtual_quote_gross_r\tvirtual_binary_eligible\tvirtual_binary_target\tvirtual_exclusion_reason\tfirst_touch_consistent";
const string PIVOT_V13_DEEP_EVENTS_HEADER =
  "schema_version\trun_id\tconfig_id\tdeep_event_id\tdeep_window_id\tsymbol\tdeep_timeframe\tmicro_timeframe\tactive_deep_bar_open_broker_time\tlevel_id\tdirection\ttrigger_broker_time\ttrigger_analysis_time\ttrigger_offset_minutes\ttrigger_bid\ttrigger_ask\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\tpivot_raw_price\tpivot_trade_price\tnext_outward_pivot_price\tdeep_micro_band_width_points_0\tdeep_micro_b_percent_0\tdeep_micro_b_percent_sma_5_0\tdeep_micro_b_percent_sma_slope_0\tdeep_micro_b_percent_state_0\tdeep_micro_b_percent_1\tdeep_micro_b_percent_sma_5_1\tdeep_micro_b_percent_sma_slope_1\tdeep_micro_b_percent_state_1\tdeep_micro_b_percent_2\tdeep_micro_b_percent_sma_5_2\tdeep_micro_b_percent_sma_slope_2\tdeep_micro_b_percent_state_2\tdeep_micro_b_percent_3\tdeep_micro_b_percent_sma_5_3\tdeep_micro_b_percent_sma_slope_3\tdeep_micro_b_percent_state_3\tdeep_micro_b_percent_4\tdeep_micro_b_percent_sma_5_4\tdeep_micro_b_percent_sma_slope_4\tdeep_micro_b_percent_state_4\tdeep_micro_b_percent_5\tdeep_micro_b_percent_sma_5_5\tdeep_micro_b_percent_sma_slope_5\tdeep_micro_b_percent_state_5\tdeep_micro_stochastic_main_line_0\tdeep_micro_stochastic_main_line_sma_5_0\tdeep_micro_stochastic_main_line_sma_slope_0\tdeep_micro_stochastic_main_line_state_0\tdeep_micro_stochastic_main_line_1\tdeep_micro_stochastic_main_line_sma_5_1\tdeep_micro_stochastic_main_line_sma_slope_1\tdeep_micro_stochastic_main_line_state_1\tdeep_micro_stochastic_main_line_2\tdeep_micro_stochastic_main_line_sma_5_2\tdeep_micro_stochastic_main_line_sma_slope_2\tdeep_micro_stochastic_main_line_state_2\tdeep_micro_stochastic_main_line_3\tdeep_micro_stochastic_main_line_sma_5_3\tdeep_micro_stochastic_main_line_sma_slope_3\tdeep_micro_stochastic_main_line_state_3\tdeep_micro_stochastic_main_line_4\tdeep_micro_stochastic_main_line_sma_5_4\tdeep_micro_stochastic_main_line_sma_slope_4\tdeep_micro_stochastic_main_line_state_4\tdeep_micro_stochastic_main_line_5\tdeep_micro_stochastic_main_line_sma_5_5\tdeep_micro_stochastic_main_line_sma_slope_5\tdeep_micro_stochastic_main_line_state_5\tdeep_micro_stochastic_signal_line_0\tdeep_micro_stochastic_signal_line_sma_5_0\tdeep_micro_stochastic_signal_line_sma_slope_0\tdeep_micro_stochastic_signal_line_state_0\tdeep_micro_stochastic_signal_line_1\tdeep_micro_stochastic_signal_line_sma_5_1\tdeep_micro_stochastic_signal_line_sma_slope_1\tdeep_micro_stochastic_signal_line_state_1\tdeep_micro_stochastic_signal_line_2\tdeep_micro_stochastic_signal_line_sma_5_2\tdeep_micro_stochastic_signal_line_sma_slope_2\tdeep_micro_stochastic_signal_line_state_2\tdeep_micro_stochastic_signal_line_3\tdeep_micro_stochastic_signal_line_sma_5_3\tdeep_micro_stochastic_signal_line_sma_slope_3\tdeep_micro_stochastic_signal_line_state_3\tdeep_micro_stochastic_signal_line_4\tdeep_micro_stochastic_signal_line_sma_5_4\tdeep_micro_stochastic_signal_line_sma_slope_4\tdeep_micro_stochastic_signal_line_state_4\tdeep_micro_stochastic_signal_line_5\tdeep_micro_stochastic_signal_line_sma_5_5\tdeep_micro_stochastic_signal_line_sma_slope_5\tdeep_micro_stochastic_signal_line_state_5\tdeep_micro_band_base_line_0\tdeep_micro_band_base_line_slope_points_0\tdeep_micro_band_base_line_1\tdeep_micro_band_base_line_slope_points_1\tdeep_micro_band_base_line_2\tdeep_micro_band_base_line_slope_points_2\tdeep_micro_band_base_line_3\tdeep_micro_band_base_line_slope_points_3\tdeep_micro_band_base_line_4\tdeep_micro_band_base_line_slope_points_4\tdeep_micro_band_base_line_5\tdeep_micro_band_base_line_slope_points_5\tdeep_micro_features_complete\tdeep_feature_invalid_reason\tidentity_consumed\tadmission_status\tactive_parent_count\trequired_link_slots\trequired_trial_slots\trequired_outcome_slots\treserved_link_slots\treserved_trial_slots\treserved_outcome_slots\tcapacity_rejection_reason";
const string PIVOT_V13_DEEP_LINKS_HEADER =
  "schema_version\trun_id\tconfig_id\tparent_link_id\tdeep_event_id\torigin_id\tparent_kind\tparent_trial_id\tparent_broker_signal_id\tparent_entry_policy\tparent_tp_r_multiple\tdirection\tparent_entry_broker_time\tevent_trigger_broker_time\tm10_parent_age_seconds\tlink_status";
const string PIVOT_V13_DEEP_TRIALS_HEADER =
  "schema_version\trun_id\tconfig_id\tdeep_trial_id\tdeep_event_id\ttp_r_multiple\tlevel_id\tdirection\tdeclared_broker_time\tdeclared_analysis_time\tdeclared_offset_minutes\tentry_bid\tentry_ask\tentry_price\tentry_quote_side\texit_quote_side\trequested_risk_distance_price\trequested_risk_distance_points\tnormalized_risk_ticks\tnormalized_risk_distance_price\tnormalized_risk_distance_points\tstop_loss_price\ttake_profit_price\tgeometry_equivalence_id\tspread_points\tpoint_size\ttrade_tick_size\tstops_level_points\tfreeze_level_points\tminimum_risk_distance_points\tdistance_eligible\teligibility_status\tineligible_reason";
const string PIVOT_V13_DEEP_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tdeep_outcome_id\tparent_link_id\tdeep_trial_id\tdeep_event_id\torigin_id\ttp_r_multiple\tdirection\tterminal_broker_time\tterminal_analysis_time\tterminal_offset_minutes\tterminal_status\tterminal_reason\tthreshold_price\tobserved_exit_bid\tobserved_exit_ask\tobserved_exit_price\texit_quote_side\tgap_points\tdeep_lifecycle_seconds\tvirtual_nominal_r\tvirtual_quote_gross_profit\tvirtual_quote_gross_r\tvirtual_binary_eligible\tvirtual_binary_target\tvirtual_exclusion_reason\tfirst_touch_consistent";
const string PIVOT_V13_CHECKS_HEADER =
  "schema_version\trun_id\tconfig_id\tcheck_id\torigin_id\tbroker_signal_id\tparity_trial_id\twindow_id\tcheck_sequence\tcheck_phase\tbroker_time\tanalysis_time\toffset_minutes\tsymbol\tdirection\taccount_margin_mode\taccount_margin_mode_supported\tsymbol_trade_mode\tsymbol_trade_mode_allowed\tmarket_session_open\taccount_trade_allowed\taccount_expert_trade_allowed\tterminal_trade_allowed\tmql_trade_allowed\tbid\task\tspread_points\tpoint_size\ttrade_tick_size\tstops_distance_points\tfreeze_distance_points\tentry_price\tstop_loss_price\ttake_profit_price\trisk_distance_points\treward_distance_points\trisk_budget_amount\trequested_volume\tnormalized_volume\tvolume_min\tvolume_max\tvolume_step\tvolume_valid\tfok_supported\tfill_policy\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\taccount_balance\tfree_margin\trequired_margin\tmargin_valid\tgeometry_valid\tstop_distance_valid\tfreeze_distance_valid\torder_check_performed\torder_check_allowed\torder_check_retcode\torder_check_comment\tallowed\tblock_source\tblock_reason\tsend_performed\tsend_succeeded\ttrade_action\tsend_retcode\tsend_comment\torder_ticket\tdeal_ticket\tposition_ticket\tposition_identifier\tbroker_entry_confirmed\tbroker_close_confirmed\tbroker_entry_price\tbroker_volume\tbroker_stop_loss\tbroker_take_profit\tclose_price\tclosed_volume\tterminal_reason\tprotection_modified";
const string PIVOT_V13_BROKER_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tbroker_outcome_id\torigin_id\tbroker_signal_id\tparity_trial_id\twindow_id\tsymbol\tmacro_timeframe\tdeep_timeframe\tmicro_timeframe\tactive_bar_open_broker_time\tlevel_id\tdirection\tentry_broker_time\tentry_analysis_time\tentry_offset_minutes\tclose_broker_time\tclose_analysis_time\tclose_offset_minutes\torder_ticket\tentry_deal_ticket\tlast_close_deal_ticket\tclose_deal_count\tposition_ticket\tposition_identifier\tsubmitted_request_price\tbroker_entry_price\tbroker_volume\timmutable_stop_loss\timmutable_take_profit\tbroker_close_price\tbroker_closed_volume\trequest_risk_distance_points\trequest_reward_distance_points\trequest_price_reward_risk_ratio\trisk_budget_amount\tquote_expected_stop_loss\tquote_expected_take_profit\tquote_expected_reward_risk_ratio\trisk_budget_utilization_ratio\tentry_slippage_points\texit_slippage_points\tbroker_gross_profit\tbroker_commission\tbroker_swap\tbroker_fee\tbroker_net_profit\tbroker_gross_budget_r\tbroker_net_budget_r\tbroker_gross_execution_r\tbroker_net_execution_r\tbroker_terminal_reason\tclose_reason_consistent\tbroker_binary_eligible\tbroker_binary_target\tbroker_exclusion_reason\th1_structural_lifecycle_seconds\tbroker_entry_confirmed\tbroker_close_confirmed";
const string PIVOT_V13_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_broker_time\tstarted_analysis_time\tstarted_offset_minutes\tfinished_broker_time\tfinished_analysis_time\tfinished_offset_minutes\tpivot_window_rows\tmacro_window_rows\tdeep_window_rows\tsignal_origin_rows\th1_trial_rows\th1_structural_trial_rows\th1_midpoint_trial_rows\tparity_trial_rows\th1_outcome_rows\th1_tp_rows\th1_sl_rows\th1_not_triggered_rows\th1_ineligible_rows\th1_run_censored_rows\tdeep_event_rows\tdeep_event_admitted_rows\tdeep_event_capacity_rejected_rows\tdeep_parent_link_rows\tdeep_trial_rows\tdeep_outcome_rows\tdeep_tp_rows\tdeep_sl_rows\tdeep_parent_exit_censored_rows\tdeep_run_censored_rows\tdeep_ineligible_rows\texecution_check_rows\tbroker_outcome_rows\tparity_pair_rows\th1_active_state_peak\th1_active_state_cap\tdeep_event_active_peak\tdeep_event_active_cap\tdeep_link_active_peak\tdeep_link_active_cap\tdeep_trial_active_peak\tdeep_trial_active_cap\tdeep_outcome_active_peak\tdeep_outcome_active_cap\tduplicate_identity_count\treferential_integrity_error_count\trow_integrity_error_count\texport_status\tcompletion_status";

struct PivotV13PendingOrigin
{
  PivotTrialOriginSnapshot origin;
  string broker_attempt_status;
  bool h1_lanes_declared;

  PivotV13PendingOrigin()
  {
    Reset();
  }

  PivotV13PendingOrigin(const PivotV13PendingOrigin &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin.Reset();
    broker_attempt_status = "NOT_EVALUATED";
    h1_lanes_declared = false;
  }

  void CopyFrom(const PivotV13PendingOrigin &other)
  {
    origin.CopyFrom(other.origin);
    broker_attempt_status = other.broker_attempt_status;
    h1_lanes_declared = other.h1_lanes_declared;
  }
};

string g_pivot_v13_run_id = "";
string g_pivot_v13_config_id = "";
string g_pivot_v13_folder = "";
datetime g_pivot_v13_started_at = 0;
bool g_pivot_v13_initialized = false;
bool g_pivot_v13_failed = false;
bool g_pivot_v13_error_logged = false;
bool g_pivot_v13_summary_written = false;
int g_pivot_v13_window_rows = 0;
int g_pivot_v13_macro_window_rows = 0;
int g_pivot_v13_deep_window_rows = 0;
int g_pivot_v13_origin_rows = 0;
int g_pivot_v13_virtual_trial_rows = 0;
int g_pivot_v13_h1_structural_trial_rows = 0;
int g_pivot_v13_h1_midpoint_trial_rows = 0;
int g_pivot_v13_parity_trial_rows = 0;
int g_pivot_v13_virtual_outcome_rows = 0;
int g_pivot_v13_h1_tp_rows = 0;
int g_pivot_v13_h1_sl_rows = 0;
int g_pivot_v13_h1_not_triggered_rows = 0;
int g_pivot_v13_h1_ineligible_rows = 0;
int g_pivot_v13_h1_run_censored_rows = 0;
int g_pivot_v13_check_rows = 0;
int g_pivot_v13_broker_outcome_rows = 0;
int g_pivot_v13_parity_pair_rows = 0;
int g_pivot_v13_deep_event_rows = 0;
int g_pivot_v13_deep_event_admitted_rows = 0;
int g_pivot_v13_deep_event_capacity_rejected_rows = 0;
int g_pivot_v13_deep_parent_link_rows = 0;
int g_pivot_v13_deep_trial_rows = 0;
int g_pivot_v13_deep_outcome_rows = 0;
int g_pivot_v13_deep_tp_rows = 0;
int g_pivot_v13_deep_sl_rows = 0;
int g_pivot_v13_deep_parent_exit_censored_rows = 0;
int g_pivot_v13_deep_run_censored_rows = 0;
int g_pivot_v13_deep_ineligible_rows = 0;
int g_pivot_v13_duplicate_identity_count = 0;
int g_pivot_v13_referential_integrity_error_count = 0;
int g_pivot_v13_row_integrity_error_count = 0;
string g_pivot_v13_window_buffer[];
string g_pivot_v13_origin_buffer[];
string g_pivot_v13_trial_buffer[];
string g_pivot_v13_virtual_outcome_buffer[];
string g_pivot_v13_deep_event_buffer[];
string g_pivot_v13_deep_link_buffer[];
string g_pivot_v13_deep_trial_buffer[];
string g_pivot_v13_deep_outcome_buffer[];
string g_pivot_v13_check_buffer[];
string g_pivot_v13_broker_outcome_buffer[];
PivotV13PendingOrigin g_pivot_v13_pending_origins[];
PivotTrialParityLink g_pivot_v13_parity_links[];

int DeepPivotEventPeak();
int DeepPivotParentLinkPeak();
int DeepPivotTrialPeak();
int DeepPivotOutcomePeak();
int DeepPivotDuplicateIdentityCount();
bool DeepPivotResearchIntegrityFailed();
bool DeepPivotHasOutstandingOutcomes();

bool PivotV13Enabled()
{
  return Enable_Signal_Feature_Export;
}

bool PivotV13Ready()
{
  return PivotV13Enabled() && g_pivot_v13_initialized &&
         !g_pivot_v13_failed;
}

void PivotV13MarkFailed(const string operation,
                        const string filename = "",
                        const int error_code = 0)
{
  g_pivot_v13_failed = true;
  if(g_pivot_v13_error_logged)
    return;
  string message = StringFormat("operation=%s|file=%s|error=%d",
                                operation,
                                filename,
                                error_code);
  if(Enable_File_Logs)
    ExecutionAppendQueryDebugLog("PIVOT_V13_EXPORT_FAILED", message);
  if(Enable_Logs)
    Print("PIVOT_V13_EXPORT_FAILED | ", message);
  g_pivot_v13_error_logged = true;
}

bool PivotV13RejectReference(const string operation)
{
  g_pivot_v13_referential_integrity_error_count++;
  PivotV13MarkFailed(operation);
  return false;
}

int FindPivotV13ParityLink(const string parity_trial_id)
{
  if(parity_trial_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_v13_parity_links); i++)
  {
    if(g_pivot_v13_parity_links[i].parity_trial_id == parity_trial_id)
      return i;
  }
  return -1;
}

bool RemovePivotV13ParityLinkAt(const int index)
{
  int total = ArraySize(g_pivot_v13_parity_links);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_v13_parity_links[i].CopyFrom(
      g_pivot_v13_parity_links[i + 1]);
  int reserve = total - 1 > 0 ? PIVOT_V13_PARITY_LINK_RESERVE : 0;
  return ArrayResize(g_pivot_v13_parity_links,
                     total - 1,
                     reserve) == total - 1;
}

bool PivotV13FinalizeParityLink(const int index)
{
  if(index < 0 || index >= ArraySize(g_pivot_v13_parity_links))
    return false;
  PivotTrialParityLink link(g_pivot_v13_parity_links[index]);
  if(!link.virtual_outcome_recorded || !link.broker_outcome_linked)
    return true;
  if(link.summary_counted)
    return PivotV13RejectReference("PARITY_SUMMARY_DUPLICATE");

  g_pivot_v13_parity_pair_rows++;
  g_pivot_v13_parity_links[index].summary_counted = true;
  if(!RemovePivotV13ParityLinkAt(index))
    return PivotV13RejectReference("PARITY_LINK_REMOVE_FAILED");
  return true;
}

bool PivotV13RegisterParityLink(const PivotTrialEntry &trial)
{
  if(trial.identity.role != PIVOT_TRIAL_ROLE_BROKER_PARITY ||
     trial.identity.parity_trial_id == "" ||
     trial.identity.trial_id != trial.identity.parity_trial_id ||
     trial.identity.origin_id == "" ||
     trial.identity.broker_signal_id == "" ||
     FindPivotV13ParityLink(trial.identity.parity_trial_id) >= 0)
    return PivotV13RejectReference("PARITY_LINK_REGISTER_INVALID");
  int total = ArraySize(g_pivot_v13_parity_links);
  if(total >= PIVOT_TRIAL_ACTIVE_STATE_CAP)
    return PivotV13RejectReference("PARITY_LINK_CAP_REACHED");
  if(ArrayResize(g_pivot_v13_parity_links,
                 total + 1,
                 PIVOT_V13_PARITY_LINK_RESERVE) != total + 1)
    return PivotV13RejectReference("PARITY_LINK_RESIZE_FAILED");
  g_pivot_v13_parity_links[total].Reset();
  g_pivot_v13_parity_links[total].origin_id = trial.identity.origin_id;
  g_pivot_v13_parity_links[total].broker_signal_id =
    trial.identity.broker_signal_id;
  g_pivot_v13_parity_links[total].parity_trial_id =
    trial.identity.parity_trial_id;
  g_pivot_v13_parity_links[total].accepted_request_copied = true;
  return true;
}

bool PivotV13LinkParityVirtualOutcome(const PivotTrialOutcome &outcome)
{
  int index = FindPivotV13ParityLink(outcome.identity.parity_trial_id);
  if(index < 0 ||
     g_pivot_v13_parity_links[index].origin_id !=
       outcome.identity.origin_id ||
     g_pivot_v13_parity_links[index].broker_signal_id !=
       outcome.identity.broker_signal_id ||
     g_pivot_v13_parity_links[index].virtual_outcome_recorded)
    return PivotV13RejectReference("PARITY_VIRTUAL_LINK_INVALID");
  g_pivot_v13_parity_links[index].virtual_outcome_recorded = true;
  g_pivot_v13_parity_links[index].virtual_first_touch = outcome.first_touch;
  return PivotV13FinalizeParityLink(index);
}

bool PivotV13ParityHasVirtualOutcome(const string parity_trial_id)
{
  int index = FindPivotV13ParityLink(parity_trial_id);
  return index >= 0 &&
         g_pivot_v13_parity_links[index].virtual_outcome_recorded;
}

bool PivotV13LinkParityBrokerOutcome(const PivotSignal &signal)
{
  int index = FindPivotV13ParityLink(signal.parity_trial_id);
  if(index < 0 ||
     g_pivot_v13_parity_links[index].origin_id != signal.origin_id ||
     g_pivot_v13_parity_links[index].broker_signal_id !=
       signal.broker_signal_id ||
     g_pivot_v13_parity_links[index].broker_outcome_linked)
    return PivotV13RejectReference("PARITY_BROKER_LINK_INVALID");
  g_pivot_v13_parity_links[index].broker_outcome_linked = true;
  g_pivot_v13_parity_links[index].broker_binary_eligible =
    signal.execution.binary_eligible;
  g_pivot_v13_parity_links[index].broker_binary_target =
    signal.execution.binary_target;
  return PivotV13FinalizeParityLink(index);
}

string PivotV13BoolToken(const bool value)
{
  return value ? "1" : "0";
}

string PivotV13Cell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  return value == "" ? PIVOT_V13_NULL : value;
}

string PivotV13TimeToken(const datetime value)
{
  return value > 0
         ? TimeToString(value, TIME_DATE | TIME_SECONDS)
         : PIVOT_V13_NULL;
}

string PivotV13DoubleToken(const double value,
                           const bool allow_zero = false)
{
  if(!MathIsValidNumber(value) || (!allow_zero && value == 0.0))
    return PIVOT_V13_NULL;
  return DoubleToString(value, 10);
}

string PivotV13UlongToken(const ulong value)
{
  return value > 0 ? StringFormat("%I64u", value) : PIVOT_V13_NULL;
}

string PivotV13DirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BUY";
  if(direction == BEARISH)
    return "SELL";
  return "NONE";
}

string PivotV13WindowStateToken(const PivotWindowStates state)
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

string PivotV13PriceSideToken(const PivotPriceSideStates side)
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

string PivotV13PpRoleToken(const PivotPpArmStates state)
{
  if(state == PIVOT_PP_BUY_ARMED)
    return "BUY";
  if(state == PIVOT_PP_SELL_ARMED)
    return "SELL";
  return "UNARMED";
}

string PivotV13DeepAdmissionToken(const DeepPivotAdmissionStatuses status)
{
  if(status == DEEP_PIVOT_ADMISSION_ADMITTED)
    return "ADMITTED";
  if(status == DEEP_PIVOT_ADMISSION_CAPACITY_REJECTED)
    return "CAPACITY_REJECTED";
  return "UNKNOWN";
}

string PivotV13DeepParentKindToken(const DeepPivotParentKinds kind)
{
  if(kind == DEEP_PIVOT_PARENT_H1_VIRTUAL)
    return "VIRTUAL";
  if(kind == DEEP_PIVOT_PARENT_BROKER)
    return "BROKER";
  return "UNKNOWN";
}

string PivotV13DeepLinkStatusToken(const DeepPivotLinkStatuses status)
{
  switch(status)
  {
    case DEEP_PIVOT_LINK_ACTIVE:      return "ACTIVE";
    case DEEP_PIVOT_LINK_PARENT_EXIT: return "PARENT_EXIT";
    case DEEP_PIVOT_LINK_RUN_END:     return "RUN_END";
    case DEEP_PIVOT_LINK_COMPLETE:    return "COMPLETE";
  }
  return "UNKNOWN";
}

void PivotV13AppendColumn(string &row,
                          const string value)
{
  if(row != "")
    row += "\t";
  row += value;
}

void PivotV13AppendTimestamp(string &row,
                             const datetime broker_time)
{
  datetime analysis_time = 0;
  int offset_minutes = 0;
  if(broker_time > 0)
    analysis_time = MarketDataNormalizeAnalysisTime(broker_time,
                                                    Broker_Session,
                                                    _Symbol,
                                                    offset_minutes);
  PivotV13AppendColumn(row, PivotV13TimeToken(broker_time));
  PivotV13AppendColumn(row, PivotV13TimeToken(analysis_time));
  PivotV13AppendColumn(row,
                       broker_time > 0
                       ? IntegerToString(offset_minutes)
                       : PIVOT_V13_NULL);
}

string PivotV13SanitizePart(const string raw_value)
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

string PivotV13HashToken(const string value)
{
  return StringFormat("%I64u", PivotTrialStableHash(value));
}

string PivotV13WindowId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open)
{
  string identity = symbol + "|" + EnumToString(timeframe) + "|" +
                    IntegerToString((long)active_bar_open);
  return "win_" + PivotV13HashToken(identity);
}

string PivotV13OriginId(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime active_bar_open,
                        const PivotLevelIds level)
{
  string identity = symbol + "|" + EnumToString(timeframe) + "|" +
                    IntegerToString((long)active_bar_open) + "|" +
                    PivotLevelLabel(level);
  return "origin_" + PivotV13HashToken(identity);
}

string PivotV13BrokerSignalId(const string origin_id)
{
  if(origin_id == "")
    return "";
  return "broker_" + PivotV13HashToken(origin_id + "|STRUCTURAL_1R");
}

string PivotV13CheckId(const string broker_signal_id,
                       const int sequence,
                       const string phase)
{
  string payload = broker_signal_id + "|" + IntegerToString(sequence) +
                   "|" + phase;
  return "check_" + PivotV13HashToken(payload);
}

string PivotV13BrokerOutcomeId(const string broker_signal_id)
{
  return "broker_outcome_" +
         PivotV13HashToken(broker_signal_id + "|CLOSED");
}

string PivotV13BuildConfigPayload()
{
  string payload = IntegerToString(PIVOT_V13_SCHEMA_VERSION);
  payload += "|" + PIVOT_V13_ENGINE_LABEL;
  payload += "|" + EnumToString(Macro_Timeframe);
  payload += "|" + EnumToString(Deep_Timeframe);
  payload += "|" + EnumToString(Micro_Timeframe);
  payload += "|" + MarketDataTimePolicyToken(Broker_Session);
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
  payload += "|STRUCTURAL,MIDPOINT_50|1,2,3,5|1,2,3";
  payload +=
    "|risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick";
  payload += "|" + IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP);
  payload += "|" + IntegerToString(PIVOT_DEEP_EVENT_ACTIVE_CAP);
  payload += "|" + IntegerToString(PIVOT_DEEP_LINK_ACTIVE_CAP);
  payload += "|" + IntegerToString(PIVOT_DEEP_TRIAL_ACTIVE_CAP);
  payload += "|" + IntegerToString(PIVOT_DEEP_OUTCOME_ACTIVE_CAP);
  payload += "|" + EnumToString(Lot_Type);
  payload += "|" + DoubleToString(Lot_Strategy_Size, 8);
  payload += "|" + DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE, 8);
  payload += "|" + AccountInfoString(ACCOUNT_CURRENCY);
  payload +=
    "|order_calc_profit_counterfactual_gross_only_no_costs_or_net";
  payload +=
    "|deal_history_authoritative_gross_commission_swap_fee_net";
  payload += "|one_exact_accepted_request_shadow_calibration_only";
  payload += "|" + PIVOT_V13_FEATURE_SET_ID;
  return payload;
}

string PivotV13BuildRunId()
{
  if(Signal_Feature_Run_Id != "")
    return PivotV13SanitizePart(Signal_Feature_Run_Id);
  string time_token = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
  return PivotV13SanitizePart(time_token + "_" + _Symbol + "_pivot_v13");
}

string PivotV13Path(const string filename)
{
  return g_pivot_v13_folder + "\\" + filename;
}

bool PivotV13EnsureFolder()
{
  string parts[];
  ushort delimiter = StringGetCharacter("\\", 0);
  int total = StringSplit(g_pivot_v13_folder, delimiter, parts);
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
      PivotV13MarkFailed("RUN_FOLDER_ALREADY_EXISTS", current, error);
      return false;
    }
    if(error != 0 && error != 5019)
    {
      PivotV13MarkFailed("CREATE_FOLDER", current, error);
      return false;
    }
  }
  return true;
}

int PivotV13ColumnCount(const string row)
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

bool PivotV13RowMatchesHeader(const string header,
                              const string row)
{
  if(PivotV13ColumnCount(header) == PivotV13ColumnCount(row))
    return true;
  g_pivot_v13_row_integrity_error_count++;
  PivotV13MarkFailed("ROW_COLUMN_COUNT");
  return false;
}

bool PivotV13FileHeaderMatches(const string filename,
                               const string expected_header)
{
  ResetLastError();
  int handle = FileOpen(filename,
                        FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
  if(handle == INVALID_HANDLE)
  {
    PivotV13MarkFailed("OPEN_HEADER", filename, GetLastError());
    return false;
  }
  string actual_header = FileReadString(handle);
  FileClose(handle);
  if(actual_header == expected_header)
    return true;
  PivotV13MarkFailed("HEADER_MISMATCH", filename);
  return false;
}

bool PivotV13WriteLine(const string filename,
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
    PivotV13MarkFailed("OPEN_WRITE", filename, GetLastError());
    return false;
  }
  if(append && !FileSeek(handle, 0, SEEK_END))
  {
    PivotV13MarkFailed("SEEK_END", filename, GetLastError());
    FileClose(handle);
    return false;
  }
  bool written = FileWrite(handle, line) > 0;
  FileClose(handle);
  if(!written)
    PivotV13MarkFailed("WRITE_LINE", filename, GetLastError());
  return written;
}

bool PivotV13AppendRows(const string filename,
                        const string header,
                        string &buffer[])
{
  int total = ArraySize(buffer);
  if(total <= 0)
    return true;
  if(!FileIsExist(filename, FILE_COMMON) ||
     !PivotV13FileHeaderMatches(filename, header))
    return false;

  int handle = FileOpen(filename,
                        FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI |
                        FILE_COMMON);
  if(handle == INVALID_HANDLE || !FileSeek(handle, 0, SEEK_END))
  {
    PivotV13MarkFailed("OPEN_APPEND", filename, GetLastError());
    if(handle != INVALID_HANDLE)
      FileClose(handle);
    return false;
  }

  bool success = true;
  for(int i = 0; i < total; i++)
  {
    if(!PivotV13RowMatchesHeader(header, buffer[i]) ||
       FileWrite(handle, buffer[i]) == 0)
    {
      success = false;
      break;
    }
  }
  FileClose(handle);
  if(!success)
    PivotV13MarkFailed("WRITE_BATCH", filename, GetLastError());
  return success;
}

bool PivotV13FlushBuffer(const string filename,
                         const string header,
                         string &buffer[])
{
  if(ArraySize(buffer) <= 0)
    return true;
  if(!PivotV13AppendRows(filename, header, buffer))
    return false;
  return ArrayResize(buffer, 0) == 0;
}

bool PivotV13QueueRow(const string filename,
                      const string header,
                      const string row,
                      string &buffer[])
{
  if(!PivotV13Ready() || !PivotV13RowMatchesHeader(header, row))
    return false;
  int total = ArraySize(buffer);
  if(ArrayResize(buffer, total + 1, PIVOT_V13_FLUSH_ROWS) != total + 1)
  {
    PivotV13MarkFailed("BUFFER_RESIZE", filename);
    return false;
  }
  buffer[total] = row;
  if(ArraySize(buffer) >= PIVOT_V13_FLUSH_ROWS)
    return PivotV13FlushBuffer(filename, header, buffer);
  return true;
}

bool PivotV13FlushAll()
{
  bool windows_ok = PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_WINDOWS_FILE),
                                        PIVOT_V13_WINDOWS_HEADER,
                                        g_pivot_v13_window_buffer);
  bool origins_ok = PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_ORIGINS_FILE),
                                        PIVOT_V13_ORIGINS_HEADER,
                                        g_pivot_v13_origin_buffer);
  bool trials_ok = PivotV13FlushBuffer(
                                       PivotV13Path(PIVOT_V13_VIRTUAL_TRIALS_FILE),
                                       PIVOT_V13_TRIALS_HEADER,
                                       g_pivot_v13_trial_buffer);
  bool virtual_outcomes_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_VIRTUAL_OUTCOMES_FILE),
                        PIVOT_V13_VIRTUAL_OUTCOMES_HEADER,
                        g_pivot_v13_virtual_outcome_buffer);
  bool deep_events_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_DEEP_EVENTS_FILE),
                        PIVOT_V13_DEEP_EVENTS_HEADER,
                        g_pivot_v13_deep_event_buffer);
  bool deep_links_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_DEEP_LINKS_FILE),
                        PIVOT_V13_DEEP_LINKS_HEADER,
                        g_pivot_v13_deep_link_buffer);
  bool deep_trials_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_DEEP_TRIALS_FILE),
                        PIVOT_V13_DEEP_TRIALS_HEADER,
                        g_pivot_v13_deep_trial_buffer);
  bool deep_outcomes_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_DEEP_OUTCOMES_FILE),
                        PIVOT_V13_DEEP_OUTCOMES_HEADER,
                        g_pivot_v13_deep_outcome_buffer);
  bool checks_ok = PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_CHECKS_FILE),
                                       PIVOT_V13_CHECKS_HEADER,
                                       g_pivot_v13_check_buffer);
  bool broker_outcomes_ok =
    PivotV13FlushBuffer(PivotV13Path(PIVOT_V13_BROKER_OUTCOMES_FILE),
                        PIVOT_V13_BROKER_OUTCOMES_HEADER,
                        g_pivot_v13_broker_outcome_buffer);
  return windows_ok && origins_ok && trials_ok && virtual_outcomes_ok &&
         deep_events_ok && deep_links_ok && deep_trials_ok &&
         deep_outcomes_ok && checks_ok && broker_outcomes_ok;
}

string PivotV13ManifestRow(const string key,
                           const string value)
{
  return IntegerToString(PIVOT_V13_SCHEMA_VERSION) + "\t" +
         PivotV13Cell(key) + "\t" + PivotV13Cell(value);
}

string PivotV13ManifestValue(const string key)
{
  if(key == "run_id") return g_pivot_v13_run_id;
  if(key == "config_id") return g_pivot_v13_config_id;
  if(key == "started_broker_time") return PivotV13TimeToken(g_pivot_v13_started_at);
  if(key == "symbol") return _Symbol;
  if(key == "chart_period") return EnumToString(_Period);
  if(key == "engine_id") return "2";
  if(key == "engine_label") return PIVOT_V13_ENGINE_LABEL;
  if(key == "magic_namespace") return "HFT_GRID_AI_PIVOT_FRACTAL_V13";
  if(key == "storage_root") return "Common\\Files\\PivotFractalV13\\runs";
  if(key == "macro_timeframe") return EnumToString(Macro_Timeframe);
  if(key == "deep_timeframe") return EnumToString(Deep_Timeframe);
  if(key == "micro_timeframe") return EnumToString(Micro_Timeframe);
  if(key == "pivot_formula") return "CLASSIC_PP_S1_S3_R1_R3";
  if(key == "source_policy") return "previous_completed_broker_candle_shift_1_per_macro_or_deep_window";
  if(key == "origin_identity_policy") return "symbol,macro_timeframe,active_bar_open,level_first_trigger_once";
  if(key == "trigger_policy") return "live_bid_virtual_limit_support_buy_resistance_sell";
  if(key == "pp_policy") return "first_causal_bid_side_then_return_touch";
  if(key == "real_execution_policy") return "single_structural_1r_fresh_quote_fok_immutable";
  if(key == "h1_entry_policies") return "STRUCTURAL,MIDPOINT_50";
  if(key == "h1_tp_multiples") return "1,2,3,5";
  if(key == "midpoint_policy") return "exact_halfway_toward_next_outward_pivot_actual_entry_clock";
  if(key == "reentry_policy") return "NONE";
  if(key == "deep_capture_policy") return "active_same_direction_h1_parents_only_h1_terminal_before_deep_discovery";
  if(key == "deep_event_identity_policy") return "symbol,deep_timeframe,active_bar_open,level_first_trigger_once_direction_outcome";
  if(key == "deep_parent_policy") return "freeze_active_parent_set_no_retroactive_links";
  if(key == "deep_tp_multiples") return "1,2,3";
  if(key == "deep_geometry_policy") return "shared_event_next_outward_pivot_exact_integer_r";
  if(key == "deep_censor_policy") return "parent_exit_or_run_end_never_binary_loss";
  if(key == "deep_capacity_policy") return "atomic_event_links_three_trials_three_outcomes_per_link_or_capacity_rejected";
  if(key == "entry_quote_policy") return "buy_ask_sell_bid";
  if(key == "exit_quote_policy") return "buy_bid_sell_ask";
  if(key == "minimum_distance_policy") return "risk_points_gte_spread_plus_max_stops_freeze_plus_trade_tick";
  if(key == "h1_active_state_cap") return IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP);
  if(key == "deep_event_active_cap") return IntegerToString(PIVOT_DEEP_EVENT_ACTIVE_CAP);
  if(key == "deep_link_active_cap") return IntegerToString(PIVOT_DEEP_LINK_ACTIVE_CAP);
  if(key == "deep_trial_active_cap") return IntegerToString(PIVOT_DEEP_TRIAL_ACTIVE_CAP);
  if(key == "deep_outcome_active_cap") return IntegerToString(PIVOT_DEEP_OUTCOME_ACTIVE_CAP);
  if(key == "bands_period") return IntegerToString(PIVOT_CONTEXT_BANDS_PERIOD);
  if(key == "bands_deviation") return DoubleToString(PIVOT_CONTEXT_B_PERCENT_DEVIATION, 4);
  if(key == "bands_shift") return "0";
  if(key == "bands_ma_method") return "MODE_SMA";
  if(key == "bands_applied_price") return "PRICE_WEIGHTED";
  if(key == "feature_capture_policy") return "one_origin_macro_micro_snapshot_and_one_configured_micro_snapshot_per_deep_event";
  if(key == "feature_price_policy") return "immutable_touched_pivot_for_b_percent_all_shifts";
  if(key == "feature_export_shifts") return "0,1,2,3,4,5";
  if(key == "feature_sma_period") return IntegerToString(PIVOT_FEATURE_SMA_PERIOD);
  if(key == "feature_state_tolerance") return DoubleToString(PIVOT_FEATURE_STATE_TOLERANCE, 7);
  if(key == "stochastic_k_period") return IntegerToString(PIVOT_CONTEXT_STOCHASTIC_K_PERIOD);
  if(key == "stochastic_d_period") return IntegerToString(PIVOT_CONTEXT_STOCHASTIC_D_PERIOD);
  if(key == "stochastic_slowing") return IntegerToString(PIVOT_CONTEXT_STOCHASTIC_SLOWING);
  if(key == "stochastic_ma_method") return "MODE_SMA";
  if(key == "stochastic_price_field") return "STO_CLOSECLOSE";
  if(key == "lot_mode") return EnumToString(Lot_Type);
  if(key == "lot_strategy_size") return DoubleToString(Lot_Strategy_Size, 8);
  if(key == "reference_balance") return DoubleToString(PIVOT_EXECUTION_REFERENCE_BALANCE, 8);
  if(key == "account_currency") return AccountInfoString(ACCOUNT_CURRENCY);
  if(key == "virtual_money_policy") return "order_calc_profit_counterfactual_gross_only";
  if(key == "broker_money_policy") return "deal_history_authoritative_gross_commission_swap_fee_net";
  if(key == "duration_policy") return "exact_nonnegative_broker_seconds_completed_h1_only_no_cap_no_rounding";
  if(key == "parity_policy") return "one_exact_accepted_request_shadow_calibration_only";
  if(key == "time_policy") return "broker_time_causal_analysis_time_export_only";
  if(key == "broker_session") return MarketDataTimePolicyToken(Broker_Session);
  if(key == "feature_set_id") return PIVOT_V13_FEATURE_SET_ID;
  if(key == "research_approval_state") return "OFFLINE_RESEARCH_ONLY";
  return "";
}

bool PivotV13WriteManifest()
{
  string filename = PivotV13Path(PIVOT_V13_MANIFEST_FILE);
  if(FileIsExist(filename, FILE_COMMON) ||
     !PivotV13WriteLine(filename, PIVOT_V13_MANIFEST_HEADER, false))
    return false;

  string keys[];
  ushort delimiter = StringGetCharacter("|", 0);
  string key_spec =
    "account_currency|bands_applied_price|bands_deviation|bands_ma_method|"
    "bands_period|bands_shift|broker_money_policy|broker_session|chart_period|"
    "config_id|deep_capacity_policy|deep_capture_policy|deep_censor_policy|"
    "deep_event_active_cap|deep_event_identity_policy|deep_geometry_policy|"
    "deep_link_active_cap|deep_outcome_active_cap|deep_parent_policy|"
    "deep_timeframe|deep_tp_multiples|deep_trial_active_cap|duration_policy|"
    "engine_id|engine_label|entry_quote_policy|exit_quote_policy|"
    "feature_capture_policy|feature_export_shifts|feature_price_policy|"
    "feature_set_id|feature_sma_period|feature_state_tolerance|"
    "h1_active_state_cap|h1_entry_policies|h1_tp_multiples|lot_mode|"
    "lot_strategy_size|macro_timeframe|magic_namespace|micro_timeframe|"
    "midpoint_policy|minimum_distance_policy|origin_identity_policy|"
    "parity_policy|pivot_formula|pp_policy|real_execution_policy|"
    "reentry_policy|reference_balance|research_approval_state|run_id|"
    "source_policy|started_broker_time|stochastic_d_period|stochastic_k_period|"
    "stochastic_ma_method|stochastic_price_field|stochastic_slowing|"
    "storage_root|symbol|time_policy|trigger_policy|virtual_money_policy";
  int key_count = StringSplit(key_spec, delimiter, keys);
  if(key_count != 64)
  {
    PivotV13MarkFailed("MANIFEST_KEY_SPEC", filename);
    return false;
  }
  for(int i = 0; i < key_count; i++)
  {
    string row = PivotV13ManifestRow(keys[i],
                                     PivotV13ManifestValue(keys[i]));
    if(!PivotV13RowMatchesHeader(PIVOT_V13_MANIFEST_HEADER, row) ||
       !PivotV13WriteLine(filename, row, true))
      return false;
  }
  return true;
}

bool PivotV13CreateDataFiles()
{
  return PivotV13WriteLine(PivotV13Path(PIVOT_V13_WINDOWS_FILE),
                           PIVOT_V13_WINDOWS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_ORIGINS_FILE),
                           PIVOT_V13_ORIGINS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_VIRTUAL_TRIALS_FILE),
                           PIVOT_V13_TRIALS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_VIRTUAL_OUTCOMES_FILE),
                           PIVOT_V13_VIRTUAL_OUTCOMES_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_DEEP_EVENTS_FILE),
                           PIVOT_V13_DEEP_EVENTS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_DEEP_LINKS_FILE),
                           PIVOT_V13_DEEP_LINKS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_DEEP_TRIALS_FILE),
                           PIVOT_V13_DEEP_TRIALS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_DEEP_OUTCOMES_FILE),
                           PIVOT_V13_DEEP_OUTCOMES_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_CHECKS_FILE),
                           PIVOT_V13_CHECKS_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_BROKER_OUTCOMES_FILE),
                           PIVOT_V13_BROKER_OUTCOMES_HEADER,
                           false) &&
         PivotV13WriteLine(PivotV13Path(PIVOT_V13_SUMMARY_FILE),
                           PIVOT_V13_SUMMARY_HEADER,
                           false);
}

bool PivotV13RunFilesExist()
{
  return FileIsExist(PivotV13Path(PIVOT_V13_MANIFEST_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_WINDOWS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_ORIGINS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_VIRTUAL_TRIALS_FILE),
                     FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_VIRTUAL_OUTCOMES_FILE),
                     FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_DEEP_EVENTS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_DEEP_LINKS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_DEEP_TRIALS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_DEEP_OUTCOMES_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_CHECKS_FILE), FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_BROKER_OUTCOMES_FILE),
                     FILE_COMMON) ||
         FileIsExist(PivotV13Path(PIVOT_V13_SUMMARY_FILE), FILE_COMMON);
}

void PivotV13StatsReset()
{
  g_pivot_v13_run_id = "";
  g_pivot_v13_config_id = "";
  g_pivot_v13_folder = "";
  g_pivot_v13_started_at = 0;
  g_pivot_v13_initialized = false;
  g_pivot_v13_failed = false;
  g_pivot_v13_error_logged = false;
  g_pivot_v13_summary_written = false;
  g_pivot_v13_window_rows = 0;
  g_pivot_v13_macro_window_rows = 0;
  g_pivot_v13_deep_window_rows = 0;
  g_pivot_v13_origin_rows = 0;
  g_pivot_v13_virtual_trial_rows = 0;
  g_pivot_v13_h1_structural_trial_rows = 0;
  g_pivot_v13_h1_midpoint_trial_rows = 0;
  g_pivot_v13_parity_trial_rows = 0;
  g_pivot_v13_virtual_outcome_rows = 0;
  g_pivot_v13_h1_tp_rows = 0;
  g_pivot_v13_h1_sl_rows = 0;
  g_pivot_v13_h1_not_triggered_rows = 0;
  g_pivot_v13_h1_ineligible_rows = 0;
  g_pivot_v13_h1_run_censored_rows = 0;
  g_pivot_v13_check_rows = 0;
  g_pivot_v13_broker_outcome_rows = 0;
  g_pivot_v13_parity_pair_rows = 0;
  g_pivot_v13_deep_event_rows = 0;
  g_pivot_v13_deep_event_admitted_rows = 0;
  g_pivot_v13_deep_event_capacity_rejected_rows = 0;
  g_pivot_v13_deep_parent_link_rows = 0;
  g_pivot_v13_deep_trial_rows = 0;
  g_pivot_v13_deep_outcome_rows = 0;
  g_pivot_v13_deep_tp_rows = 0;
  g_pivot_v13_deep_sl_rows = 0;
  g_pivot_v13_deep_parent_exit_censored_rows = 0;
  g_pivot_v13_deep_run_censored_rows = 0;
  g_pivot_v13_deep_ineligible_rows = 0;
  g_pivot_v13_duplicate_identity_count = 0;
  g_pivot_v13_referential_integrity_error_count = 0;
  g_pivot_v13_row_integrity_error_count = 0;
  ArrayResize(g_pivot_v13_window_buffer, 0);
  ArrayResize(g_pivot_v13_origin_buffer, 0);
  ArrayResize(g_pivot_v13_trial_buffer, 0);
  ArrayResize(g_pivot_v13_virtual_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_deep_event_buffer, 0);
  ArrayResize(g_pivot_v13_deep_link_buffer, 0);
  ArrayResize(g_pivot_v13_deep_trial_buffer, 0);
  ArrayResize(g_pivot_v13_deep_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_check_buffer, 0);
  ArrayResize(g_pivot_v13_broker_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_pending_origins, 0,
              PIVOT_V13_ORIGIN_STATE_RESERVE);
  ArrayResize(g_pivot_v13_parity_links, 0,
              PIVOT_V13_PARITY_LINK_RESERVE);
  ResetPivotTrialLaneState();
}

bool PivotV13StatsInit()
{
  PivotV13StatsReset();
  if(!PivotV13Enabled())
    return true;

  g_pivot_v13_started_at = TimeCurrent();
  g_pivot_v13_run_id = PivotV13BuildRunId();
  g_pivot_v13_config_id =
    "cfg_" + PivotV13HashToken(PivotV13BuildConfigPayload());
  g_pivot_v13_folder = PIVOT_V13_STORAGE_ROOT + "\\" +
                       PIVOT_V13_RUNS_FOLDER + "\\" +
                       g_pivot_v13_run_id;
  if(!PivotV13EnsureFolder())
    return false;
  if(PivotV13RunFilesExist())
  {
    PivotV13MarkFailed("RUN_FOLDER_ALREADY_INITIALIZED", g_pivot_v13_folder);
    return false;
  }

  g_pivot_v13_initialized = true;
  if(!PivotV13WriteManifest() || !PivotV13CreateDataFiles())
  {
    PivotV13MarkFailed("INITIALIZE_RUN_FILES", g_pivot_v13_folder);
    return false;
  }
  return true;
}

string PivotV13FeatureToken(const bool available,
                            const double value)
{
  return available ? PivotV13DoubleToken(value, true) : PIVOT_V13_NULL;
}

void PivotV13AppendDerivedSeries(
  string &row,
  const PivotDerivedFeatureSeries &series,
  const bool timeframe_complete)
{
  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    bool available = timeframe_complete && series.complete &&
                     series.available[shift];
    PivotV13AppendColumn(
      row,
      PivotV13FeatureToken(available, series.raw_values[shift]));
    PivotV13AppendColumn(
      row,
      PivotV13FeatureToken(available, series.sma_5_values[shift]));
    PivotV13AppendColumn(
      row,
      PivotV13FeatureToken(available, series.sma_slopes[shift]));
    PivotV13AppendColumn(
      row,
      available
      ? PivotV13PriceSideToken(series.states[shift])
      : PIVOT_V13_NULL);
  }
}

void PivotV13AppendTimeframeFeatures(
  string &row,
  const bool timeframe_complete,
  const PivotBandTrendSnapshot &band_trend,
  const PivotDerivedFeatureSeries &b_percent,
  const PivotDerivedFeatureSeries &stochastic_main_line,
  const PivotDerivedFeatureSeries &stochastic_signal_line)
{
  PivotV13AppendColumn(
    row,
    PivotV13FeatureToken(timeframe_complete && band_trend.width_available,
                         band_trend.width_points_0));
  PivotV13AppendDerivedSeries(row, b_percent, timeframe_complete);
  PivotV13AppendDerivedSeries(row,
                              stochastic_main_line,
                              timeframe_complete);
  PivotV13AppendDerivedSeries(row,
                              stochastic_signal_line,
                              timeframe_complete);
  for(int shift = 0; shift < PIVOT_FEATURE_EXPORT_SHIFT_COUNT; shift++)
  {
    bool available = timeframe_complete && band_trend.complete &&
                     band_trend.base_line_available[shift];
    PivotV13AppendColumn(
      row,
      PivotV13FeatureToken(available, band_trend.base_line[shift]));
    PivotV13AppendColumn(
      row,
      PivotV13FeatureToken(
        available,
        band_trend.base_line_slope_points[shift]));
  }
}

int FindPivotV13PendingOrigin(const string origin_id)
{
  if(origin_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_v13_pending_origins); i++)
  {
    if(g_pivot_v13_pending_origins[i].origin.origin_id == origin_id)
      return i;
  }
  return -1;
}

bool RemovePivotV13PendingOriginAt(const int index)
{
  int total = ArraySize(g_pivot_v13_pending_origins);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_v13_pending_origins[i].CopyFrom(
      g_pivot_v13_pending_origins[i + 1]);
  int reserve = total > 1 ? PIVOT_V13_ORIGIN_STATE_RESERVE : 0;
  return ArrayResize(g_pivot_v13_pending_origins,
                     total - 1,
                     reserve) == total - 1;
}

string PivotV13BrokerAttemptStatus(const PivotSignal &signal)
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

bool PivotV13RegisterOrigin(const PivotSignal &signal)
{
  if(!PivotV13Ready())
    return false;
  if(signal.origin_id == "" || signal.window_id == "" ||
     signal.broker_signal_id == "" ||
     signal.active_bar_open <= 0 || signal.trigger_time <= 0 ||
     signal.trigger_bid <= 0.0 || signal.trigger_ask < signal.trigger_bid ||
     !signal.levels.valid ||
     !MathIsValidNumber(signal.route.structural_stop_loss) ||
     signal.route.structural_stop_loss <= 0.0)
    return PivotV13RejectReference("REGISTER_ORIGIN_INVALID");
  if(FindPivotV13PendingOrigin(signal.origin_id) >= 0)
  {
    PivotV13RegisterDuplicateIdentity();
    return false;
  }

  PivotV13PendingOrigin pending;
  PivotTrialOriginSnapshot origin;
  origin.origin_id = signal.origin_id;
  origin.window_id = signal.window_id;
  origin.broker_signal_id = signal.broker_signal_id;
  origin.symbol = _Symbol;
  origin.macro_timeframe = signal.pivot_timeframe;
  origin.deep_timeframe = Deep_Timeframe;
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
    return PivotV13RejectReference("REGISTER_ORIGIN_LEVEL_INVALID");
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
  bool boundary_available = false;
  if(!MathIsValidNumber(origin.structural_take_profit) ||
     origin.structural_take_profit <= 0.0 ||
     origin.point_size <= 0.0 || origin.trade_tick_size <= 0.0 ||
     origin.stops_level_points < 0.0 ||
     origin.freeze_level_points < 0.0 ||
     !PivotTrialNextOutwardBoundary(signal.direction,
                                    signal.level_id,
                                    signal.levels,
                                    boundary_available,
                                    origin.next_outward_pivot_price) ||
     !boundary_available ||
     !PivotTrialMidpointPrice(signal.direction,
                              origin.pivot_trade_price,
                              origin.next_outward_pivot_price,
                              origin.midpoint_50_price))
    return PivotV13RejectReference("REGISTER_ORIGIN_GEOMETRY_INVALID");
  origin.levels.CopyFrom(signal.levels);
  origin.features.CopyFrom(signal.features);
  pending.origin.CopyFrom(origin);
  pending.broker_attempt_status = PivotV13BrokerAttemptStatus(signal);
  pending.h1_lanes_declared = signal.h1_lanes_declared;

  int total = ArraySize(g_pivot_v13_pending_origins);
  if(ArrayResize(g_pivot_v13_pending_origins,
                 total + 1,
                 PIVOT_V13_ORIGIN_STATE_RESERVE) != total + 1)
  {
    PivotV13MarkFailed("ORIGIN_STATE_RESIZE");
    return false;
  }
  g_pivot_v13_pending_origins[total].CopyFrom(pending);
  return true;
}

bool PivotV13UpdateOrigin(const PivotSignal &signal)
{
  if(!PivotV13Enabled())
    return true;
  if(!PivotV13Ready())
    return false;
  int index = FindPivotV13PendingOrigin(signal.origin_id);
  if(index < 0)
  {
    if(signal.origin_registered && signal.origin_export_finalized &&
       signal.origin_id != "" && signal.window_id != "")
      return true;
    return PivotV13RejectReference("UPDATE_ORIGIN_NOT_FOUND");
  }
  g_pivot_v13_pending_origins[index].broker_attempt_status =
    PivotV13BrokerAttemptStatus(signal);
  g_pivot_v13_pending_origins[index].h1_lanes_declared = signal.h1_lanes_declared;
  return true;
}

datetime PivotV13LatestOriginTriggerForWindow(const string window_id)
{
  datetime latest_trigger = 0;
  for(int i = 0; i < ArraySize(g_pivot_v13_pending_origins); i++)
  {
    if(g_pivot_v13_pending_origins[i].origin.window_id == window_id &&
       g_pivot_v13_pending_origins[i].origin.trigger_time > latest_trigger)
    {
      latest_trigger =
        g_pivot_v13_pending_origins[i].origin.trigger_time;
    }
  }
  return latest_trigger;
}

bool PivotV13RecordOrigin(const PivotV13PendingOrigin &pending,
                          const datetime terminal_time,
                          const string terminal_status)
{
  PivotTrialOriginSnapshot origin(pending.origin);
  if(!PivotV13Ready() || origin.origin_id == "" ||
     origin.window_id == "" || origin.broker_signal_id == "" ||
     terminal_time <= origin.trigger_time ||
     (terminal_status != "WINDOW_EXPIRED" &&
      terminal_status != "RUN_FINISHED") ||
     pending.broker_attempt_status == "NOT_EVALUATED")
    return PivotV13RejectReference("RECORD_ORIGIN_INVALID");

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, origin.origin_id);
  PivotV13AppendColumn(row, origin.window_id);
  PivotV13AppendColumn(row, origin.broker_signal_id);
  PivotV13AppendColumn(row, origin.symbol);
  PivotV13AppendColumn(row, EnumToString(origin.macro_timeframe));
  PivotV13AppendColumn(row, EnumToString(origin.deep_timeframe));
  PivotV13AppendColumn(row, EnumToString(origin.micro_timeframe));
  PivotV13AppendColumn(row, PivotV13TimeToken(origin.active_bar_open));
  PivotV13AppendColumn(row, PivotLevelLabel(origin.level_id));
  PivotV13AppendColumn(row, PivotV13DirectionToken(origin.direction));
  PivotV13AppendTimestamp(row, origin.trigger_time);
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.trigger_bid));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.trigger_ask));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.spread_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.point_size));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.trade_tick_size));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.stops_level_points, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.freeze_level_points, true));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV13AppendColumn(row,
                         PivotV13DoubleToken(origin.levels.raw_prices[i]));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV13AppendColumn(row,
                         PivotV13DoubleToken(origin.levels.trade_prices[i]));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.pivot_raw_price));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.pivot_trade_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.next_outward_pivot_price));
  PivotV13AppendColumn(row, PivotV13DoubleToken(origin.midpoint_50_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.structural_entry_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.structural_stop_loss));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(origin.structural_take_profit));

  bool micro_complete = origin.features.micro_complete;
  bool macro_complete = origin.features.macro_complete;
  PivotV13AppendTimeframeFeatures(
    row,
    micro_complete,
    origin.features.micro_band_trend,
    origin.features.micro_b_percent_features,
    origin.features.micro_stochastic_main_line_features,
    origin.features.micro_stochastic_signal_line_features);
  PivotV13AppendTimeframeFeatures(
    row,
    macro_complete,
    origin.features.macro_band_trend,
    origin.features.macro_b_percent_features,
    origin.features.macro_stochastic_main_line_features,
    origin.features.macro_stochastic_signal_line_features);
  PivotV13AppendColumn(row, PivotV13BoolToken(micro_complete));
  PivotV13AppendColumn(row, PivotV13BoolToken(macro_complete));
  PivotV13AppendColumn(row, PivotV13BoolToken(origin.features.complete));
  string feature_reason = origin.features.invalid_reason;
  if(feature_reason == "")
    feature_reason = "FEATURE_SNAPSHOT_INCOMPLETE";
  PivotV13AppendColumn(row,
                       origin.features.complete
                       ? PIVOT_V13_NULL
                       : PivotV13Cell(feature_reason));
  PivotV13AppendColumn(row, "1");
  PivotV13AppendColumn(row, PivotV13BoolToken(pending.h1_lanes_declared));
  PivotV13AppendColumn(row, pending.broker_attempt_status);
  PivotV13AppendColumn(row, terminal_status);

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_ORIGINS_FILE),
                       PIVOT_V13_ORIGINS_HEADER,
                       row,
                       g_pivot_v13_origin_buffer))
    return false;
  g_pivot_v13_origin_rows++;
  return true;
}

bool PivotV13FinalizeOriginsForWindow(const string window_id,
                                      const datetime terminal_time,
                                      const string terminal_status)
{
  for(int i = ArraySize(g_pivot_v13_pending_origins) - 1; i >= 0; i--)
  {
    if(g_pivot_v13_pending_origins[i].origin.window_id != window_id)
      continue;
    if(!PivotV13RecordOrigin(g_pivot_v13_pending_origins[i],
                             terminal_time,
                             terminal_status) ||
       !RemovePivotV13PendingOriginAt(i))
      return false;
  }
  return true;
}

bool PivotV13RecordWindow(const PivotFractalWindowState &window,
                          const datetime requested_terminal_time,
                          const string terminal_status)
{
  if(!PivotV13Ready())
    return false;
  if(window.state != PIVOT_WINDOW_VALID ||
     !window.levels.valid ||
     (window.timeframe != Macro_Timeframe &&
      window.timeframe != Deep_Timeframe) ||
     window.active_bar_open <= 0 ||
     window.source_bar_open <= 0 ||
     window.first_observed_time <= 0 ||
     (terminal_status != "EXPIRED" && terminal_status != "RUN_FINISHED"))
    return PivotV13RejectReference("RECORD_WINDOW_INVALID");

  string window_id = PivotV13WindowId(_Symbol,
                                      window.timeframe,
                                      window.active_bar_open);
  datetime terminal_time = requested_terminal_time;
  datetime latest_window_fact = window.active_bar_open;
  if(window.first_observed_time > latest_window_fact)
    latest_window_fact = window.first_observed_time;
  if(window.pp_arm_time > latest_window_fact)
    latest_window_fact = window.pp_arm_time;
  datetime latest_origin_trigger =
    PivotV13LatestOriginTriggerForWindow(window_id);
  if(latest_origin_trigger > latest_window_fact)
    latest_window_fact = latest_origin_trigger;
  if(terminal_time <= latest_window_fact)
    terminal_time = latest_window_fact + 1;
  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, window_id);
  PivotV13AppendColumn(row,
                       window.timeframe == Macro_Timeframe ? "MACRO" : "DEEP");
  PivotV13AppendColumn(row, _Symbol);
  PivotV13AppendColumn(row, EnumToString(window.timeframe));
  PivotV13AppendTimestamp(row, window.active_bar_open);
  PivotV13AppendTimestamp(row, window.source_bar_open);
  PivotV13AppendTimestamp(row, window.source_close_boundary);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.levels.source_open));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.levels.source_high));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.levels.source_low));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.levels.source_close));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.levels.source_range));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV13AppendColumn(row,
                         PivotV13DoubleToken(window.levels.raw_prices[i]));
  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    PivotV13AppendColumn(row,
                         PivotV13DoubleToken(window.levels.trade_prices[i]));
  PivotV13AppendTimestamp(row, window.first_observed_time);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(window.first_observed_bid));
  PivotV13AppendColumn(row,
                       PivotV13PriceSideToken(window.pp_initial_relation));
  PivotV13AppendColumn(row, PivotV13PpRoleToken(window.pp_arm_state));
  PivotV13AppendTimestamp(row, window.pp_arm_time);
  PivotV13AppendColumn(row,
                       window.pp_arm_time > 0
                       ? PivotV13DoubleToken(window.pp_arm_bid)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13WindowStateToken(window.state));
  PivotV13AppendColumn(row, PivotV13Cell(window.invalid_reason));
  PivotV13AppendTimestamp(row, terminal_time);
  PivotV13AppendColumn(row, terminal_status);

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_WINDOWS_FILE),
                       PIVOT_V13_WINDOWS_HEADER,
                       row,
                       g_pivot_v13_window_buffer))
    return false;
  g_pivot_v13_window_rows++;
  if(window.timeframe == Macro_Timeframe)
    g_pivot_v13_macro_window_rows++;
  else
    g_pivot_v13_deep_window_rows++;
  string origin_terminal_status = terminal_status == "EXPIRED"
                                  ? "WINDOW_EXPIRED"
                                  : "RUN_FINISHED";
  return PivotV13FinalizeOriginsForWindow(window_id,
                                          terminal_time,
                                          origin_terminal_status);
}

bool PivotV13RecordVirtualTrial(const PivotTrialEntry &trial)
{
  if(!PivotV13Ready())
    return false;
  bool h1_trial = trial.identity.role == PIVOT_TRIAL_ROLE_H1;
  bool parity_trial = trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  bool pending_midpoint = h1_trial &&
                          trial.identity.entry_policy ==
                            PIVOT_TRIAL_ENTRY_MIDPOINT_50 &&
                          !trial.midpoint_touched;
  if((!h1_trial && !parity_trial) || trial.identity.trial_id == "" ||
     trial.identity.origin_id == "" || trial.identity.window_id == "" ||
     trial.declared_time <= 0 ||
     (h1_trial &&
      (trial.identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL &&
       trial.identity.entry_policy != PIVOT_TRIAL_ENTRY_MIDPOINT_50)) ||
     (h1_trial && !PivotTrialTpMultipleSupported(trial.identity.tp_r_multiple)) ||
     (h1_trial && (trial.identity.parity_trial_id != "" ||
                   trial.identity.broker_signal_id != "")) ||
     (parity_trial &&
      (trial.identity.parity_trial_id == "" ||
       trial.identity.parity_trial_id != trial.identity.trial_id ||
       trial.identity.broker_signal_id == "" ||
       trial.identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL ||
       trial.identity.tp_r_multiple != 1 ||
       trial.eligibility_status != PIVOT_TRIAL_ELIGIBILITY_ACTIVE)))
    return PivotV13RejectReference("RECORD_VIRTUAL_TRIAL_IDENTITY_INVALID");

  bool active = trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  bool geometry_available = active && trial.geometry.valid;
  if(pending_midpoint &&
     (trial.entry_time != 0 || trial.geometry.valid ||
      trial.geometry.entry_price > 0.0))
    return PivotV13RejectReference("RECORD_PENDING_MIDPOINT_GEOMETRY");
  if(active && (!geometry_available || !trial.money_plan.complete ||
                trial.entry_time <= 0))
    return PivotV13RejectReference("RECORD_ACTIVE_TRIAL_STATE_INVALID");
  if(!active && !pending_midpoint && trial.ineligible_reason == "")
    return PivotV13RejectReference("RECORD_INELIGIBLE_TRIAL_REASON");

  bool reference_mode = Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, trial.identity.trial_id);
  PivotV13AppendColumn(row, parity_trial ? trial.identity.parity_trial_id : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.identity.origin_id);
  PivotV13AppendColumn(row, trial.identity.window_id);
  PivotV13AppendColumn(row, parity_trial ? trial.identity.broker_signal_id : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotTrialRoleLabel(trial.identity.role));
  PivotV13AppendColumn(row, PivotTrialEntryPolicyLabel(trial.identity.entry_policy));
  PivotV13AppendColumn(row, IntegerToString(trial.identity.tp_r_multiple));
  PivotV13AppendColumn(row, PivotLevelLabel(trial.level_id));
  PivotV13AppendColumn(row, PivotV13DirectionToken(trial.direction));
  PivotV13AppendTimestamp(row, trial.declared_time);
  PivotV13AppendTimestamp(row, trial.entry_time);
  PivotV13AppendColumn(row, pending_midpoint ? PIVOT_V13_NULL : PivotV13DoubleToken(trial.geometry.entry_bid));
  PivotV13AppendColumn(row, pending_midpoint ? PIVOT_V13_NULL : PivotV13DoubleToken(trial.geometry.entry_ask));
  PivotV13AppendColumn(row, pending_midpoint ? PIVOT_V13_NULL : PivotV13DoubleToken(trial.geometry.entry_price));
  PivotV13AppendColumn(row, pending_midpoint ? PIVOT_V13_NULL : PivotTrialQuoteSideLabel(trial.geometry.entry_quote_side));
  PivotV13AppendColumn(row, pending_midpoint ? PIVOT_V13_NULL : PivotTrialQuoteSideLabel(trial.geometry.exit_quote_side));
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.midpoint_50_price));
  PivotV13AppendColumn(row, PivotV13BoolToken(trial.midpoint_touched));
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.requested_risk_distance_price) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.requested_risk_distance_points) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? StringFormat("%I64d", trial.geometry.normalized_risk_ticks) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.normalized_risk_distance_price) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.normalized_risk_distance_points) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.stop_loss_price) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.take_profit_price) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, geometry_available ? PivotV13Cell(trial.geometry.geometry_equivalence_id) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.geometry.spread_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.geometry.point_size, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.geometry.trade_tick_size, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.geometry.stops_level_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(trial.geometry.freeze_level_points, true));
  PivotV13AppendColumn(row, geometry_available ? PivotV13DoubleToken(trial.geometry.minimum_risk_distance_points, true) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13BoolToken(geometry_available && trial.geometry.distance_eligible));
  PivotV13AppendColumn(row, EnumToString(Lot_Type));
  PivotV13AppendColumn(row, DoubleToString(Lot_Strategy_Size, 8));
  PivotV13AppendColumn(row, reference_mode ? PivotV13DoubleToken(PIVOT_EXECUTION_REFERENCE_BALANCE) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, AccountInfoString(ACCOUNT_CURRENCY));
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.risk_budget_amount, true) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.requested_volume) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.normalized_volume) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.virtual_expected_stop_loss, true) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.virtual_expected_take_profit, true) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, trial.money_plan.complete ? PivotV13DoubleToken(trial.money_plan.virtual_expected_reward_risk_ratio, true) : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(trial.money_plan.complete));
  PivotV13AppendColumn(row, PivotTrialEligibilityLabel(trial.eligibility_status));
  PivotV13AppendColumn(row, active ? PIVOT_V13_NULL : PivotV13Cell(trial.ineligible_reason));
  PivotV13AppendColumn(
    row,
    PivotV13BoolToken(trial.origin_window_active_at_entry));

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_VIRTUAL_TRIALS_FILE),
                       PIVOT_V13_TRIALS_HEADER,
                       row,
                       g_pivot_v13_trial_buffer))
    return false;
  g_pivot_v13_virtual_trial_rows++;
  if(h1_trial && trial.identity.entry_policy == PIVOT_TRIAL_ENTRY_STRUCTURAL)
    g_pivot_v13_h1_structural_trial_rows++;
  else if(h1_trial)
    g_pivot_v13_h1_midpoint_trial_rows++;
  else
  {
    g_pivot_v13_parity_trial_rows++;
    if(!PivotV13RegisterParityLink(trial))
      return false;
  }
  return true;
}

bool PivotV13RecordVirtualOutcome(const PivotTrialOutcome &outcome)
{
  if(!PivotV13Ready())
    return false;

  bool h1_outcome = outcome.identity.role == PIVOT_TRIAL_ROLE_H1;
  bool parity_outcome =
    outcome.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  bool terminal_touch =
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST ||
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  bool censored = outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_CENSORED;
  bool not_triggered =
    outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_NOT_TRIGGERED;
  bool ineligible = outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_INELIGIBLE;
  if(outcome.outcome_id == "" || outcome.identity.trial_id == "" ||
     outcome.identity.origin_id == "" || outcome.identity.window_id == "" ||
     (!h1_outcome && !parity_outcome) ||
     (outcome.direction != BULLISH && outcome.direction != BEARISH) ||
     outcome.terminal_time <= 0 || outcome.observed_exit_bid <= 0.0 ||
     outcome.observed_exit_ask < outcome.observed_exit_bid ||
     outcome.exit_quote_side != PivotTrialExitQuoteSide(outcome.direction) ||
     outcome.observed_exit_price !=
       (outcome.direction == BULLISH
        ? outcome.observed_exit_bid
        : outcome.observed_exit_ask) ||
     (!terminal_touch && !censored && !not_triggered && !ineligible) ||
     !outcome.first_touch_consistent)
    return PivotV13RejectReference("RECORD_VIRTUAL_OUTCOME_INVALID");
  if((h1_outcome &&
      (outcome.identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL &&
       outcome.identity.entry_policy != PIVOT_TRIAL_ENTRY_MIDPOINT_50)) ||
     (h1_outcome &&
      !PivotTrialTpMultipleSupported(outcome.identity.tp_r_multiple)) ||
     (h1_outcome && outcome.identity.parity_trial_id != "") ||
     (parity_outcome &&
      (outcome.identity.parity_trial_id == "" ||
       outcome.identity.parity_trial_id != outcome.identity.trial_id ||
       outcome.identity.broker_signal_id == "" ||
       outcome.identity.entry_policy != PIVOT_TRIAL_ENTRY_STRUCTURAL ||
       outcome.identity.tp_r_multiple != 1)))
    return PivotV13RejectReference("RECORD_VIRTUAL_OUTCOME_IDENTITY_INVALID");
  if(terminal_touch &&
     (!outcome.lifecycle_seconds_available || outcome.duration_seconds < 0 ||
      outcome.threshold_price <= 0.0 ||
      !outcome.virtual_quote_gross_available))
    return PivotV13RejectReference("RECORD_COMPLETED_OUTCOME_FACTS_INVALID");
  if(!terminal_touch && outcome.lifecycle_seconds_available)
    return PivotV13RejectReference("RECORD_NONTERMINAL_DURATION_INVALID");

  string terminal_status = "CENSORED_RUN_END";
  if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST)
    terminal_status = "TP_FIRST";
  else if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST)
    terminal_status = "SL_FIRST";
  else if(not_triggered)
    terminal_status = "NOT_TRIGGERED";
  else if(ineligible)
    terminal_status = "INELIGIBLE";

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, outcome.outcome_id);
  PivotV13AppendColumn(row, outcome.identity.trial_id);
  PivotV13AppendColumn(row,
                       parity_outcome
                       ? outcome.identity.parity_trial_id
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, outcome.identity.origin_id);
  PivotV13AppendColumn(row, outcome.identity.window_id);
  PivotV13AppendColumn(row, PivotTrialRoleLabel(outcome.identity.role));
  PivotV13AppendColumn(row,
                       PivotTrialEntryPolicyLabel(
                         outcome.identity.entry_policy));
  PivotV13AppendColumn(row, IntegerToString(outcome.identity.tp_r_multiple));
  PivotV13AppendColumn(row, PivotV13DirectionToken(outcome.direction));
  PivotV13AppendTimestamp(row, outcome.terminal_time);
  PivotV13AppendColumn(row, terminal_status);
  PivotV13AppendColumn(row, PivotV13Cell(outcome.terminal_reason));
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? PivotV13DoubleToken(outcome.threshold_price)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_bid));
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_ask));
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_price));
  PivotV13AppendColumn(row,
                       PivotTrialQuoteSideLabel(outcome.exit_quote_side));
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? PivotV13DoubleToken(outcome.gap_points, true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? StringFormat("%I64d", outcome.duration_seconds)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? PivotV13DoubleToken(outcome.virtual_nominal_r, true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? PivotV13DoubleToken(
                           outcome.virtual_quote_gross_profit, true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       terminal_touch
                       ? PivotV13DoubleToken(outcome.virtual_quote_gross_r,
                                             true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(terminal_touch &&
                                         outcome.virtual_binary_eligible));
  PivotV13AppendColumn(row,
                       terminal_touch && outcome.virtual_binary_eligible
                       ? IntegerToString(outcome.virtual_binary_target)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       terminal_touch && outcome.virtual_binary_eligible
                       ? PIVOT_V13_NULL
                       : PivotV13Cell(outcome.virtual_exclusion_reason == ""
                                      ? terminal_status
                                      : outcome.virtual_exclusion_reason));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(outcome.first_touch_consistent));

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_VIRTUAL_OUTCOMES_FILE),
                       PIVOT_V13_VIRTUAL_OUTCOMES_HEADER,
                       row,
                       g_pivot_v13_virtual_outcome_buffer))
    return false;
  g_pivot_v13_virtual_outcome_rows++;
  if(terminal_status == "TP_FIRST")
    g_pivot_v13_h1_tp_rows++;
  else if(terminal_status == "SL_FIRST")
    g_pivot_v13_h1_sl_rows++;
  else if(terminal_status == "NOT_TRIGGERED")
    g_pivot_v13_h1_not_triggered_rows++;
  else if(terminal_status == "INELIGIBLE")
    g_pivot_v13_h1_ineligible_rows++;
  else if(terminal_status == "CENSORED_RUN_END")
    g_pivot_v13_h1_run_censored_rows++;
  if(parity_outcome)
  {
    if(!PivotV13LinkParityVirtualOutcome(outcome))
      return false;
  }
  return true;
}

bool PivotV13RecordDeepPivotEvent(const DeepPivotEvent &event)
{
  if(!PivotV13Ready() || event.identity.deep_event_id == "" ||
     event.identity.deep_window_id == "" || event.identity.symbol == "" ||
     event.identity.deep_timeframe == PERIOD_CURRENT ||
     event.identity.active_deep_bar_open <= 0 ||
     (event.direction != BULLISH && event.direction != BEARISH) ||
     event.trigger_time <= 0 || event.trigger_bid <= 0.0 ||
     event.trigger_ask < event.trigger_bid || event.point_size <= 0.0 ||
     event.trade_tick_size <= 0.0 || !event.identity_consumed)
    return PivotV13RejectReference("RECORD_DEEP_EVENT_INVALID");

  bool rejected = event.admission_status ==
                  DEEP_PIVOT_ADMISSION_CAPACITY_REJECTED;
  bool admitted = event.admission_status == DEEP_PIVOT_ADMISSION_ADMITTED;
  if(!rejected && !admitted)
    return PivotV13RejectReference("RECORD_DEEP_EVENT_ADMISSION_INVALID");
  if(rejected)
  {
    if(event.active_parent_count <= 0 ||
       event.required_link_slots != event.active_parent_count ||
       event.required_trial_slots != 3 ||
       event.required_outcome_slots != event.active_parent_count * 3 ||
       event.reserved_link_slots != 0 || event.reserved_trial_slots != 0 ||
       event.reserved_outcome_slots != 0 ||
       event.capacity_rejection_reason == "")
      return PivotV13RejectReference("RECORD_DEEP_EVENT_REJECTION_INVALID");
  }
  else if(event.active_parent_count <= 0 ||
          event.required_link_slots != event.active_parent_count ||
          event.required_trial_slots != 3 ||
          event.required_outcome_slots != event.active_parent_count * 3 ||
          event.reserved_link_slots != event.required_link_slots ||
          event.reserved_trial_slots != event.required_trial_slots ||
          event.reserved_outcome_slots != event.required_outcome_slots)
  {
    return PivotV13RejectReference("RECORD_DEEP_EVENT_RESERVATION_INVALID");
  }

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, event.identity.deep_event_id);
  PivotV13AppendColumn(row, event.identity.deep_window_id);
  PivotV13AppendColumn(row, event.identity.symbol);
  PivotV13AppendColumn(row, EnumToString(event.identity.deep_timeframe));
  PivotV13AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV13AppendColumn(row,
                       PivotV13TimeToken(event.identity.active_deep_bar_open));
  PivotV13AppendColumn(row, PivotLevelLabel(event.identity.level_id));
  PivotV13AppendColumn(row, PivotV13DirectionToken(event.direction));
  PivotV13AppendTimestamp(row, event.trigger_time);
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.trigger_bid));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.trigger_ask));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.spread_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.point_size));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.trade_tick_size));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(event.stops_level_points, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(event.freeze_level_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.pivot_raw_price));
  PivotV13AppendColumn(row, PivotV13DoubleToken(event.pivot_trade_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(event.next_outward_pivot_price));
  PivotV13AppendTimeframeFeatures(
    row,
    event.deep_micro_features_complete,
    event.features.micro_band_trend,
    event.features.micro_b_percent_features,
    event.features.micro_stochastic_main_line_features,
    event.features.micro_stochastic_signal_line_features);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(event.deep_micro_features_complete));
  PivotV13AppendColumn(row,
                       event.deep_micro_features_complete
                       ? PIVOT_V13_NULL
                       : PivotV13Cell(event.deep_feature_invalid_reason == ""
                                      ? "FEATURE_SNAPSHOT_INCOMPLETE"
                                      : event.deep_feature_invalid_reason));
  PivotV13AppendColumn(row, PivotV13BoolToken(event.identity_consumed));
  PivotV13AppendColumn(row, PivotV13DeepAdmissionToken(event.admission_status));
  PivotV13AppendColumn(row, IntegerToString(event.active_parent_count));
  PivotV13AppendColumn(row, IntegerToString(event.required_link_slots));
  PivotV13AppendColumn(row, IntegerToString(event.required_trial_slots));
  PivotV13AppendColumn(row, IntegerToString(event.required_outcome_slots));
  PivotV13AppendColumn(row, IntegerToString(event.reserved_link_slots));
  PivotV13AppendColumn(row, IntegerToString(event.reserved_trial_slots));
  PivotV13AppendColumn(row, IntegerToString(event.reserved_outcome_slots));
  PivotV13AppendColumn(row,
                       rejected ? PivotV13Cell(event.capacity_rejection_reason)
                                : PIVOT_V13_NULL);

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_DEEP_EVENTS_FILE),
                       PIVOT_V13_DEEP_EVENTS_HEADER,
                       row,
                       g_pivot_v13_deep_event_buffer))
    return false;
  g_pivot_v13_deep_event_rows++;
  if(admitted)
    g_pivot_v13_deep_event_admitted_rows++;
  else
    g_pivot_v13_deep_event_capacity_rejected_rows++;
  return true;
}

bool PivotV13RecordDeepPivotParentLink(const DeepPivotParentLink &link)
{
  if(!PivotV13Ready() || link.parent_link_id == "" ||
     link.deep_event_id == "" || link.origin_id == "" ||
     link.parent_trial_id == "" || link.parent_entry_time <= 0 ||
     link.event_trigger_time <= 0 || link.parent_entry_time >
       link.event_trigger_time || link.parent_age_seconds < 0 ||
     link.parent_age_seconds !=
       (long)(link.event_trigger_time - link.parent_entry_time) ||
     (link.direction != BULLISH && link.direction != BEARISH))
    return PivotV13RejectReference("RECORD_DEEP_LINK_INVALID");

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, link.parent_link_id);
  PivotV13AppendColumn(row, link.deep_event_id);
  PivotV13AppendColumn(row, link.origin_id);
  PivotV13AppendColumn(row, PivotV13DeepParentKindToken(link.parent_kind));
  PivotV13AppendColumn(row, link.parent_trial_id);
  PivotV13AppendColumn(row, PivotV13Cell(link.parent_broker_signal_id));
  PivotV13AppendColumn(row,
                       PivotTrialEntryPolicyLabel(link.parent_entry_policy));
  PivotV13AppendColumn(row, IntegerToString(link.parent_tp_r_multiple));
  PivotV13AppendColumn(row, PivotV13DirectionToken(link.direction));
  PivotV13AppendColumn(row, PivotV13TimeToken(link.parent_entry_time));
  PivotV13AppendColumn(row, PivotV13TimeToken(link.event_trigger_time));
  PivotV13AppendColumn(row, StringFormat("%I64d", link.parent_age_seconds));
  PivotV13AppendColumn(row, PivotV13DeepLinkStatusToken(link.link_status));

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_DEEP_LINKS_FILE),
                       PIVOT_V13_DEEP_LINKS_HEADER,
                       row,
                       g_pivot_v13_deep_link_buffer))
    return false;
  g_pivot_v13_deep_parent_link_rows++;
  return true;
}

bool PivotV13RecordDeepPivotTrial(const DeepPivotTrial &trial)
{
  if(!PivotV13Ready() || trial.deep_trial_id == "" ||
     trial.deep_event_id == "" || trial.declared_time <= 0 ||
     (trial.direction != BULLISH && trial.direction != BEARISH) ||
     (trial.tp_r_multiple != 1 && trial.tp_r_multiple != 2 &&
      trial.tp_r_multiple != 3))
    return PivotV13RejectReference("RECORD_DEEP_TRIAL_INVALID");

  bool active = trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE;
  if(active && (!trial.geometry.valid || !trial.geometry.distance_eligible))
    return PivotV13RejectReference("RECORD_DEEP_TRIAL_GEOMETRY_INVALID");
  if(!active && trial.ineligible_reason == "")
    return PivotV13RejectReference("RECORD_DEEP_TRIAL_REASON_INVALID");

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, trial.deep_trial_id);
  PivotV13AppendColumn(row, trial.deep_event_id);
  PivotV13AppendColumn(row, IntegerToString(trial.tp_r_multiple));
  PivotV13AppendColumn(row, PivotLevelLabel(trial.level_id));
  PivotV13AppendColumn(row, PivotV13DirectionToken(trial.direction));
  PivotV13AppendTimestamp(row, trial.declared_time);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(trial.geometry.entry_bid)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(trial.geometry.entry_ask)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(trial.geometry.entry_price)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotTrialQuoteSideLabel(
                                  trial.geometry.entry_quote_side)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotTrialQuoteSideLabel(
                                  trial.geometry.exit_quote_side)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.requested_risk_distance_price)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.requested_risk_distance_points)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? StringFormat("%I64d",
                                             trial.geometry.normalized_risk_ticks)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.normalized_risk_distance_price)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.normalized_risk_distance_points)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.stop_loss_price)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.take_profit_price)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13Cell(
                                  trial.geometry.geometry_equivalence_id)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.spread_points, true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.point_size, true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.trade_tick_size, true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.stops_level_points, true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.freeze_level_points, true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       active ? PivotV13DoubleToken(
                                  trial.geometry.minimum_risk_distance_points,
                                  true)
                              : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(active && trial.geometry.distance_eligible));
  PivotV13AppendColumn(row,
                       PivotTrialEligibilityLabel(trial.eligibility_status));
  PivotV13AppendColumn(row,
                       active ? PIVOT_V13_NULL
                              : PivotV13Cell(trial.ineligible_reason));

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_DEEP_TRIALS_FILE),
                       PIVOT_V13_DEEP_TRIALS_HEADER,
                       row,
                       g_pivot_v13_deep_trial_buffer))
    return false;
  g_pivot_v13_deep_trial_rows++;
  return true;
}

bool PivotV13RecordDeepPivotOutcome(const DeepPivotOutcome &outcome)
{
  if(!PivotV13Ready() || outcome.deep_outcome_id == "" || outcome.parent_link_id == "" ||
     outcome.deep_trial_id == "" || outcome.deep_event_id == "" ||
     outcome.origin_id == "" || outcome.terminal_time <= 0 ||
     outcome.observed_exit_bid <= 0.0 ||
     outcome.observed_exit_ask < outcome.observed_exit_bid ||
     (outcome.direction != BULLISH && outcome.direction != BEARISH) ||
     outcome.exit_quote_side != PivotTrialExitQuoteSide(outcome.direction) ||
     !MathIsValidNumber(outcome.observed_exit_price) ||
     outcome.observed_exit_price <= 0.0 ||
     outcome.observed_exit_price != (outcome.direction == BULLISH
                                     ? outcome.observed_exit_bid
                                     : outcome.observed_exit_ask) ||
     !outcome.first_touch_consistent)
    return PivotV13RejectReference("RECORD_DEEP_OUTCOME_INVALID");

  bool completed = outcome.terminal_status == "TP_FIRST" ||
                   outcome.terminal_status == "SL_FIRST";
  bool allowed_terminal = completed ||
                          outcome.terminal_status == "CENSORED_PARENT_EXIT" ||
                          outcome.terminal_status == "CENSORED_RUN_END" ||
                          outcome.terminal_status == "INELIGIBLE";
  if(!allowed_terminal || (completed &&
     (!outcome.lifecycle_seconds_available || outcome.lifecycle_seconds < 0 ||
      outcome.threshold_price <= 0.0 || !outcome.virtual_quote_gross_available)) ||
     (!completed && outcome.lifecycle_seconds_available) ||
     (!completed && outcome.virtual_binary_target != -1) ||
     (completed && outcome.virtual_binary_eligible &&
      (outcome.virtual_binary_target != 0 &&
       outcome.virtual_binary_target != 1)) ||
     (completed && !outcome.virtual_binary_eligible &&
      outcome.virtual_binary_target != -1))
    return PivotV13RejectReference("RECORD_DEEP_OUTCOME_FACTS_INVALID");

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row, outcome.deep_outcome_id);
  PivotV13AppendColumn(row, outcome.parent_link_id);
  PivotV13AppendColumn(row, outcome.deep_trial_id);
  PivotV13AppendColumn(row, outcome.deep_event_id);
  PivotV13AppendColumn(row, outcome.origin_id);
  PivotV13AppendColumn(row, IntegerToString(outcome.tp_r_multiple));
  PivotV13AppendColumn(row, PivotV13DirectionToken(outcome.direction));
  PivotV13AppendTimestamp(row, outcome.terminal_time);
  PivotV13AppendColumn(row, outcome.terminal_status);
  PivotV13AppendColumn(row, PivotV13Cell(outcome.terminal_reason));
  PivotV13AppendColumn(row,
                       completed ? PivotV13DoubleToken(outcome.threshold_price)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_bid));
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_ask));
  PivotV13AppendColumn(row, PivotV13DoubleToken(outcome.observed_exit_price));
  PivotV13AppendColumn(row,
                       PivotTrialQuoteSideLabel(outcome.exit_quote_side));
  PivotV13AppendColumn(row,
                       completed ? PivotV13DoubleToken(outcome.gap_points, true)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       completed ? StringFormat("%I64d",
                                                outcome.lifecycle_seconds)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       completed ? PivotV13DoubleToken(
                                     outcome.virtual_nominal_r, true)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       completed ? PivotV13DoubleToken(
                                     outcome.virtual_quote_gross_profit, true)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       completed ? PivotV13DoubleToken(
                                     outcome.virtual_quote_gross_r, true)
                                 : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(completed &&
                                         outcome.virtual_binary_eligible));
  PivotV13AppendColumn(row,
                       completed && outcome.virtual_binary_eligible
                       ? IntegerToString(outcome.virtual_binary_target)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       completed && outcome.virtual_binary_eligible
                       ? PIVOT_V13_NULL
                       : PivotV13Cell(outcome.virtual_exclusion_reason == ""
                                      ? outcome.terminal_status
                                      : outcome.virtual_exclusion_reason));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(outcome.first_touch_consistent));

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_DEEP_OUTCOMES_FILE),
                       PIVOT_V13_DEEP_OUTCOMES_HEADER,
                       row,
                       g_pivot_v13_deep_outcome_buffer))
    return false;
  g_pivot_v13_deep_outcome_rows++;
  if(outcome.terminal_status == "TP_FIRST")
    g_pivot_v13_deep_tp_rows++;
  else if(outcome.terminal_status == "SL_FIRST")
    g_pivot_v13_deep_sl_rows++;
  else if(outcome.terminal_status == "CENSORED_PARENT_EXIT")
    g_pivot_v13_deep_parent_exit_censored_rows++;
  else if(outcome.terminal_status == "CENSORED_RUN_END")
    g_pivot_v13_deep_run_censored_rows++;
  else if(outcome.terminal_status == "INELIGIBLE")
    g_pivot_v13_deep_ineligible_rows++;
  return true;
}

bool PivotV13RecordExecutionCheck(const PivotSignal &signal,
                                  const BrokerExecutionCheck &check)
{
  if(!PivotV13Ready())
    return false;
  if(signal.origin_id == "" || signal.broker_signal_id == "" ||
     signal.window_id == "" || check.sequence <= 0 ||
     check.broker_time <= 0)
    return PivotV13RejectReference("RECORD_EXECUTION_CHECK_INVALID");

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
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row,
                       PivotV13CheckId(signal.broker_signal_id,
                                       check.sequence,
                                       check.phase));
  PivotV13AppendColumn(row, signal.origin_id);
  PivotV13AppendColumn(row, signal.broker_signal_id);
  PivotV13AppendColumn(row, PivotV13Cell(signal.parity_trial_id));
  PivotV13AppendColumn(row, signal.window_id);
  PivotV13AppendColumn(row, IntegerToString(check.sequence));
  PivotV13AppendColumn(row, check.phase);
  PivotV13AppendTimestamp(row, check.broker_time);
  PivotV13AppendColumn(row, _Symbol);
  PivotV13AppendColumn(row, PivotV13DirectionToken(signal.direction));
  PivotV13AppendColumn(row, StringFormat("%I64d", check.account_margin_mode));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(check.account_margin_mode_supported));
  PivotV13AppendColumn(row, StringFormat("%I64d", check.symbol_trade_mode));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(check.symbol_trade_mode_allowed));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.market_session_open));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.account_trade_allowed));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(check.account_expert_trade_allowed));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.terminal_trade_allowed));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.mql_trade_allowed));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.bid, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.ask, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.spread_points, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.point_size, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.trade_tick_size, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.stops_distance_points, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.freeze_distance_points, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.planned_entry_price, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.stop_loss_price, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.take_profit_price, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.risk_distance_points, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.reward_distance_points, true));
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(check.risk_budget_amount, true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.requested_volume, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.normalized_volume, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.volume_min, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.volume_max, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.volume_step, true));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.volume_valid));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.fok_supported));
  PivotV13AppendColumn(row, "ORDER_FILLING_FOK");
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.quote_expected_stop_loss,
                                           true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.quote_expected_take_profit,
                                           true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         check.quote_expected_reward_risk_ratio,
                         true));
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(
                           check.risk_budget_utilization_ratio,
                           true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.account_balance, true));
  PivotV13AppendColumn(row, PivotV13DoubleToken(check.free_margin, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(check.required_margin, true));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.margin_valid));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.geometry_valid));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.stop_distance_valid));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.freeze_distance_valid));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(check.order_check_performed));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.order_check_allowed));
  PivotV13AppendColumn(row,
                       check.order_check_performed
                       ? StringFormat("%I64u", check.order_check_retcode)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13Cell(check.order_check_comment));
  PivotV13AppendColumn(row, PivotV13BoolToken(check.allowed));
  PivotV13AppendColumn(row, PivotV13Cell(check.block_source));
  PivotV13AppendColumn(row, PivotV13Cell(check.block_reason));
  PivotV13AppendColumn(row, PivotV13BoolToken(send_performed));
  PivotV13AppendColumn(row, PivotV13BoolToken(send_succeeded));
  PivotV13AppendColumn(row,
                       send_performed
                       ? "TRADE_ACTION_DEAL"
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       send_performed
                       ? StringFormat("%I64u", check.send_retcode)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, PivotV13Cell(check.send_comment));
  PivotV13AppendColumn(row, PivotV13UlongToken(order_ticket));
  PivotV13AppendColumn(row, PivotV13UlongToken(deal_ticket));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(signal.execution.position_ticket));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(
                         signal.execution.position_identifier));
  PivotV13AppendColumn(row, PivotV13BoolToken(entry_confirmed));
  PivotV13AppendColumn(row, PivotV13BoolToken(close_confirmed));
  PivotV13AppendColumn(row,
                       entry_confirmed
                       ? PivotV13DoubleToken(
                           signal.execution.broker_entry_price)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       entry_confirmed
                       ? PivotV13DoubleToken(signal.execution.broker_volume)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       entry_confirmed
                       ? PivotV13DoubleToken(
                           signal.execution.broker_stop_loss)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       entry_confirmed
                       ? PivotV13DoubleToken(
                           signal.execution.broker_take_profit)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       close_confirmed
                       ? PivotV13DoubleToken(signal.execution.close_price)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       close_confirmed
                       ? PivotV13DoubleToken(signal.execution.closed_volume)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       close_confirmed
                       ? signal.execution.terminal_reason
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row, "0");

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_CHECKS_FILE),
                       PIVOT_V13_CHECKS_HEADER,
                       row,
                       g_pivot_v13_check_buffer))
    return false;
  g_pivot_v13_check_rows++;
  return true;
}

bool PivotV13RecordBrokerOutcome(const PivotSignal &signal)
{
  if(!PivotV13Ready())
    return false;
  if(signal.origin_id == "" || signal.broker_signal_id == "" ||
     signal.window_id == "" ||
     !signal.execution.broker_entry_confirmed ||
     !signal.execution.broker_close_confirmed ||
     signal.execution.close_deal_count <= 0)
    return PivotV13RejectReference("RECORD_BROKER_OUTCOME_INVALID");

  bool reference_mode =
    Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
  long duration_seconds = (long)(signal.execution.close_time -
                                 signal.execution.broker_entry_time);
  if(duration_seconds < 0)
    return PivotV13RejectReference("RECORD_BROKER_OUTCOME_TIME");

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendColumn(row,
                       PivotV13BrokerOutcomeId(signal.broker_signal_id));
  PivotV13AppendColumn(row, signal.origin_id);
  PivotV13AppendColumn(row, signal.broker_signal_id);
  PivotV13AppendColumn(row, PivotV13Cell(signal.parity_trial_id));
  PivotV13AppendColumn(row, signal.window_id);
  PivotV13AppendColumn(row, _Symbol);
  PivotV13AppendColumn(row, EnumToString(signal.pivot_timeframe));
  PivotV13AppendColumn(row, EnumToString(Deep_Timeframe));
  PivotV13AppendColumn(row, EnumToString(Micro_Timeframe));
  PivotV13AppendColumn(row, PivotV13TimeToken(signal.active_bar_open));
  PivotV13AppendColumn(row, PivotLevelLabel(signal.level_id));
  PivotV13AppendColumn(row, PivotV13DirectionToken(signal.direction));
  PivotV13AppendTimestamp(row, signal.execution.broker_entry_time);
  PivotV13AppendTimestamp(row, signal.execution.close_time);
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(signal.execution.order_ticket));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(signal.execution.entry_deal_ticket));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(
                         signal.execution.last_close_deal_ticket));
  PivotV13AppendColumn(row,
                       IntegerToString(signal.execution.close_deal_count));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(signal.execution.position_ticket));
  PivotV13AppendColumn(row,
                       PivotV13UlongToken(
                         signal.execution.position_identifier));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.planned_entry_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.broker_entry_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.broker_volume));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.broker_stop_loss));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.broker_take_profit));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.close_price));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.closed_volume));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.risk_distance_points));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.reward_distance_points));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.price_reward_risk_ratio));
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(
                           signal.execution.risk_budget_amount)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.quote_expected_stop_loss));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.quote_expected_take_profit));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.quote_expected_reward_risk_ratio));
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(
                           signal.execution.risk_budget_utilization_ratio)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.entry_slippage_points,
                         true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.exit_slippage_points,
                         true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.gross_profit,
                                           true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.commission,
                                           true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.swap, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.fee, true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.net_profit, true));
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(signal.execution.gross_budget_r,
                                             true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       reference_mode
                       ? PivotV13DoubleToken(signal.execution.net_budget_r,
                                             true)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(
                         signal.execution.gross_execution_r,
                         true));
  PivotV13AppendColumn(row,
                       PivotV13DoubleToken(signal.execution.net_execution_r,
                                           true));
  PivotV13AppendColumn(row, signal.execution.terminal_reason);
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(
                         signal.execution.close_reason_consistent));
  PivotV13AppendColumn(row,
                       PivotV13BoolToken(signal.execution.binary_eligible));
  PivotV13AppendColumn(row,
                       signal.execution.binary_eligible
                       ? IntegerToString(signal.execution.binary_target)
                       : PIVOT_V13_NULL);
  PivotV13AppendColumn(row,
                       PivotV13Cell(signal.execution.exclusion_reason));
  PivotV13AppendColumn(row, StringFormat("%I64d", duration_seconds));
  PivotV13AppendColumn(row, "1");
  PivotV13AppendColumn(row, "1");

  if(!PivotV13QueueRow(PivotV13Path(PIVOT_V13_BROKER_OUTCOMES_FILE),
                       PIVOT_V13_BROKER_OUTCOMES_HEADER,
                       row,
                       g_pivot_v13_broker_outcome_buffer))
    return false;
  g_pivot_v13_broker_outcome_rows++;
  if(signal.parity_trial_id != "")
  {
    if(!PivotV13LinkParityBrokerOutcome(signal))
      return false;
  }
  return true;
}

void PivotV13RegisterDuplicateIdentity()
{
  g_pivot_v13_duplicate_identity_count++;
}

bool PivotV13MarkOriginMatrixDeclared(const string origin_id)
{
  int index = FindPivotV13PendingOrigin(origin_id);
  if(index < 0)
    return false;
  g_pivot_v13_pending_origins[index].h1_lanes_declared = true;
  return true;
}

void PivotV13ValidateSummaryReconciliation()
{
  if(g_pivot_v13_window_rows !=
     g_pivot_v13_macro_window_rows + g_pivot_v13_deep_window_rows)
    PivotV13RejectReference("SUMMARY_WINDOW_COUNTS");
  if(g_pivot_v13_virtual_trial_rows !=
     g_pivot_v13_h1_structural_trial_rows +
     g_pivot_v13_h1_midpoint_trial_rows +
     g_pivot_v13_parity_trial_rows)
    PivotV13RejectReference("SUMMARY_H1_TRIAL_COUNTS");
  if(g_pivot_v13_h1_structural_trial_rows !=
       g_pivot_v13_origin_rows * PIVOT_TRIAL_TP_MULTIPLE_COUNT ||
     g_pivot_v13_h1_midpoint_trial_rows !=
       g_pivot_v13_origin_rows * PIVOT_TRIAL_TP_MULTIPLE_COUNT)
    PivotV13RejectReference("SUMMARY_H1_LANE_CARDINALITY");
  if(g_pivot_v13_virtual_outcome_rows !=
     g_pivot_v13_h1_tp_rows + g_pivot_v13_h1_sl_rows +
     g_pivot_v13_h1_not_triggered_rows +
     g_pivot_v13_h1_ineligible_rows +
     g_pivot_v13_h1_run_censored_rows)
    PivotV13RejectReference("SUMMARY_H1_OUTCOME_COUNTS");
  if(g_pivot_v13_virtual_outcome_rows != g_pivot_v13_virtual_trial_rows)
    PivotV13RejectReference("SUMMARY_H1_OUTCOME_CARDINALITY");
  if(g_pivot_v13_deep_event_rows !=
     g_pivot_v13_deep_event_admitted_rows +
     g_pivot_v13_deep_event_capacity_rejected_rows)
    PivotV13RejectReference("SUMMARY_DEEP_EVENT_COUNTS");
  if(g_pivot_v13_deep_trial_rows !=
     g_pivot_v13_deep_event_admitted_rows * 3)
    PivotV13RejectReference("SUMMARY_DEEP_TRIAL_CARDINALITY");
  if(g_pivot_v13_deep_outcome_rows !=
     g_pivot_v13_deep_parent_link_rows * 3)
    PivotV13RejectReference("SUMMARY_DEEP_OUTCOME_CARDINALITY");
  if(g_pivot_v13_deep_outcome_rows !=
     g_pivot_v13_deep_tp_rows + g_pivot_v13_deep_sl_rows +
     g_pivot_v13_deep_parent_exit_censored_rows +
     g_pivot_v13_deep_run_censored_rows +
     g_pivot_v13_deep_ineligible_rows)
    PivotV13RejectReference("SUMMARY_DEEP_OUTCOME_COUNTS");
  if(PivotTrialActiveStateCount() > 0)
    PivotV13RejectReference("SUMMARY_ACTIVE_H1_STATE");
  if(DeepPivotHasOutstandingOutcomes())
    PivotV13RejectReference("SUMMARY_ACTIVE_DEEP_STATE");
}

bool PivotV13WriteSummary(const string completion_status)
{
  if(!PivotV13Enabled() || !g_pivot_v13_initialized ||
     g_pivot_v13_summary_written)
    return !g_pivot_v13_failed;

  if(PivotTrialResearchIntegrityFailed())
    PivotV13MarkFailed("VIRTUAL_STATE_INTEGRITY");
  if(DeepPivotResearchIntegrityFailed())
    PivotV13MarkFailed("DEEP_STATE_INTEGRITY");
  for(int i = 0; i < ArraySize(g_pivot_v13_parity_links); i++)
  {
    if(!g_pivot_v13_parity_links[i].virtual_outcome_recorded)
    {
      PivotV13RejectReference("PARITY_OUTCOME_MISSING");
      break;
    }
  }
  if(ArraySize(g_pivot_v13_pending_origins) > 0)
    PivotV13RejectReference("SUMMARY_PENDING_ORIGINS");
  PivotV13ValidateSummaryReconciliation();
  if(!PivotV13FlushAll())
    PivotV13MarkFailed("FLUSH_ALL");
  datetime finished_at = TimeCurrent();
  if(finished_at < g_pivot_v13_started_at)
    finished_at = g_pivot_v13_started_at;

  string row = "";
  PivotV13AppendColumn(row, IntegerToString(PIVOT_V13_SCHEMA_VERSION));
  PivotV13AppendColumn(row, g_pivot_v13_run_id);
  PivotV13AppendColumn(row, g_pivot_v13_config_id);
  PivotV13AppendTimestamp(row, g_pivot_v13_started_at);
  PivotV13AppendTimestamp(row, finished_at);
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_window_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_macro_window_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_window_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_origin_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_virtual_trial_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(
                         g_pivot_v13_h1_structural_trial_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_h1_midpoint_trial_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_parity_trial_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_virtual_outcome_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_h1_tp_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_h1_sl_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_h1_not_triggered_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_h1_ineligible_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_h1_run_censored_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_event_rows));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_deep_event_admitted_rows));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_deep_event_capacity_rejected_rows));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_deep_parent_link_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_trial_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_outcome_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_tp_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_deep_sl_rows));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_deep_parent_exit_censored_rows));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_deep_run_censored_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_deep_ineligible_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_check_rows));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_broker_outcome_rows));
  PivotV13AppendColumn(row, IntegerToString(g_pivot_v13_parity_pair_rows));
  PivotV13AppendColumn(row, IntegerToString(PivotTrialActiveStatePeak()));
  PivotV13AppendColumn(row,
                       IntegerToString(PIVOT_TRIAL_ACTIVE_STATE_CAP));
  PivotV13AppendColumn(row, IntegerToString(DeepPivotEventPeak()));
  PivotV13AppendColumn(row,
                       IntegerToString(PIVOT_DEEP_EVENT_ACTIVE_CAP));
  PivotV13AppendColumn(row, IntegerToString(DeepPivotParentLinkPeak()));
  PivotV13AppendColumn(row,
                       IntegerToString(PIVOT_DEEP_LINK_ACTIVE_CAP));
  PivotV13AppendColumn(row, IntegerToString(DeepPivotTrialPeak()));
  PivotV13AppendColumn(row,
                       IntegerToString(PIVOT_DEEP_TRIAL_ACTIVE_CAP));
  PivotV13AppendColumn(row, IntegerToString(DeepPivotOutcomePeak()));
  PivotV13AppendColumn(row,
                       IntegerToString(PIVOT_DEEP_OUTCOME_ACTIVE_CAP));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_duplicate_identity_count +
                    PivotTrialDuplicateIdentityCount() +
                    DeepPivotDuplicateIdentityCount()));
  PivotV13AppendColumn(
    row,
    IntegerToString(g_pivot_v13_referential_integrity_error_count));
  PivotV13AppendColumn(row,
                       IntegerToString(g_pivot_v13_row_integrity_error_count));
  PivotV13AppendColumn(row, g_pivot_v13_failed ? "FAILED" : "OK");
  PivotV13AppendColumn(row, completion_status);

  string filename = PivotV13Path(PIVOT_V13_SUMMARY_FILE);
  if(!PivotV13RowMatchesHeader(PIVOT_V13_SUMMARY_HEADER, row) ||
     !PivotV13FileHeaderMatches(filename, PIVOT_V13_SUMMARY_HEADER) ||
     !PivotV13WriteLine(filename, row, true))
    return false;
  g_pivot_v13_summary_written = true;
  return !g_pivot_v13_failed;
}

void PivotV13StatsDeinit(const string completion_status = "CENSORED")
{
  if(!PivotV13Enabled() || !g_pivot_v13_initialized)
    return;
  PivotV13WriteSummary(completion_status);
  ArrayResize(g_pivot_v13_window_buffer, 0);
  ArrayResize(g_pivot_v13_origin_buffer, 0);
  ArrayResize(g_pivot_v13_trial_buffer, 0);
  ArrayResize(g_pivot_v13_virtual_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_deep_event_buffer, 0);
  ArrayResize(g_pivot_v13_deep_link_buffer, 0);
  ArrayResize(g_pivot_v13_deep_trial_buffer, 0);
  ArrayResize(g_pivot_v13_deep_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_check_buffer, 0);
  ArrayResize(g_pivot_v13_broker_outcome_buffer, 0);
  ArrayResize(g_pivot_v13_pending_origins, 0);
  ArrayResize(g_pivot_v13_parity_links, 0);
  ResetPivotTrialLaneState();
  ResetDeepPivotRuntimeState();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_FRACTAL_STATISTICS_EXPORT_MQH_
