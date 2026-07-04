//+------------------------------------------------------------------+
//|       trading_signals/deterministic_signal_statistics_export.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_DETERMINISTIC_SIGNAL_STATISTICS_EXPORT_MQH_
#define _SERVICES_TRADING_SIGNALS_DETERMINISTIC_SIGNAL_STATISTICS_EXPORT_MQH_

const int    DETERMINISTIC_SIGNAL_STATS_SCHEMA_VERSION = 1;
const string DETERMINISTIC_SIGNAL_STATS_STORAGE_ROOT   = "DeterministicSignalML";
const string DETERMINISTIC_SIGNAL_STATS_RUNS_FOLDER    = "runs";
const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_FILE  = "run_manifest.tsv";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_FILE  = "signal_features.tsv";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_FILE  = "signal_outcomes.tsv";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_FILE   = "run_summary.tsv";
const string DETERMINISTIC_SIGNAL_STATS_NULL           = "\\N";
const ushort DETERMINISTIC_SIGNAL_STATS_DELIMITER      = '\t';

const string DETERMINISTIC_SIGNAL_STATS_MANIFEST_HEADER =
  "schema_version\tkey\tvalue";
const string DETERMINISTIC_SIGNAL_STATS_FEATURES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tsymbol\tstrategy_id\tstrategy_label\tdirection\tentry_time\tsource_time\tsource_type\tmacro_h1_live_dir\tmacro_h4_live_dir\tmacro_d1_live_dir\tsl_fib_raw\tsl_fib_band\tentry_fib_raw\tentry_fib_band\tlow_chain_score_3\tlow_chain_score_5\tlow_chain_score_10\thigh_chain_score_3\thigh_chain_score_5\thigh_chain_score_10";
const string DETERMINISTIC_SIGNAL_STATS_OUTCOMES_HEADER =
  "schema_version\trun_id\tconfig_id\tsignal_id\tsource_key\tsource_attempt_index\tterminal_time\tterminal_reason\tprofit_r\tduration_seconds\tduration_m1_bars\tentry_price\tclose_price\tnet_profit";
const string DETERMINISTIC_SIGNAL_STATS_SUMMARY_HEADER =
  "schema_version\trun_id\tconfig_id\tstarted_at\tfinished_at\tfeature_rows\toutcome_rows\tfeature_invalid_rows\toutcome_invalid_rows\texport_status";

bool DeterministicSignalStatsEnabled()
{
  return Enable_Signal_Feature_Export;
}

#endif // _SERVICES_TRADING_SIGNALS_DETERMINISTIC_SIGNAL_STATISTICS_EXPORT_MQH_
