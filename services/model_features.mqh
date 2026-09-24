#ifndef MODEL_FEATURES_MQH
#define MODEL_FEATURES_MQH

// Core enums are supplied by the entrypoint; this closure has no engine inputs.
#include "indicators/pivot_points_calculator.mqh"
#include "model_features/schema.mqh"
#include "model_features/clock.mqh"
#include "model_features/types.mqh"
#include "model_features/export.mqh"
#include "model_features/indicators.mqh"
#include "model_features/pivot_context.mqh"
#include "model_features/stochastic_structure.mqh"

bool g_model_last_capture_complete = false;

bool ModelInitialize(const ModelCaptureConfig &config)
{
  if(!ModelOpen(config)) return false;
  ModelOpenIndicators();
  return !g_model_failed;
}

void ModelObserve(const MqlTick &tick, const long sequence)
{
  if(g_model_first_time == 0) g_model_first_time = tick.time_msc;
  g_model_last_time = tick.time_msc;
  g_model_sequence = sequence;
  if(!ModelReady()) return;
  ModelRefreshContext(tick, sequence);
  ModelUpdateStructure(tick);
}

void ModelInvalidateLiveFeatures(ModelRow &row)
{
  for(int i = 0; i < ArraySize(row.cells); i++)
  {
    string name = g_model_layout[row.file].names[i];
    bool series = StringFind(name, "macro_source_") == 0 || StringFind(name, "micro_source_") == 0;
    string families[] = {"macro_stochastic_", "micro_stochastic_", "macro_percent_b_", "micro_percent_b_", "macro_atr_", "micro_atr_"};
    for(int f = 0; f < ArraySize(families); f++) if(StringFind(name, families[f]) == 0) series = true;
    if(series) row.cells[i] = StringGetCharacter(g_model_layout[row.file].nullable, i) == '1' ? MODEL_NULL : "0";
    if(StringFind(name, "forming_") == 0) row.cells[i] = name == "forming_status" ? "UNAVAILABLE" : MODEL_NULL;
  }
  row.Flag("macro_complete", false);
  row.Flag("micro_complete", false);
  row.Flag("structure_complete", false);
  row.Set("macro_reason", "QUOTE_CHANGED");
  row.Set("micro_reason", "QUOTE_CHANGED");
  row.Set("structure_reason", "QUOTE_CHANGED");
}

bool ModelCapture(const string signal_id, const string snapshot_id, const string stage,
                   const long sequence, const MqlTick &tick)
{
  g_model_last_capture_complete = false;
  if(!ModelReady() || !ModelCheckSpecification()) return false;
  ModelRow row;
  row.Init(MODEL_FEATURE_SNAPSHOTS);
  row.Set("snapshot_id", snapshot_id);
  row.Set("signal_id", signal_id);
  row.Integer("sequence", sequence);
  row.Set("capture_stage", stage);
  row.Clock("observed_time_msc", tick.time_msc);
  row.Set("macro_window_id", ModelNullable(g_model_window_id));
  row.Number("bid", tick.bid);
  row.Number("ask", tick.ask);
  row.Number("point", g_model_point);
  row.Number("tick_size", g_model_tick_size);
  row.Integer("macro_seconds", PeriodSeconds(g_model_config.macro));
  row.Integer("micro_seconds", PeriodSeconds(g_model_config.micro));
  bool macro = ModelCaptureIndicators(row, 0, tick, snapshot_id);
  bool micro = ModelCaptureIndicators(row, 1, tick, snapshot_id);
  bool pivot = ModelCaptureContext(row, tick);
  bool structure = ModelCaptureStructure(row, tick, snapshot_id);
  MqlTick after;
  bool consistent = SymbolInfoTick(g_model_config.symbol, after) && after.time_msc == tick.time_msc &&
                    after.bid == tick.bid && after.ask == tick.ask;
  if(!consistent) ModelInvalidateLiveFeatures(row);
  bool complete = consistent && macro && micro && pivot && structure;
  g_model_last_capture_complete = complete;
  row.Flag("complete", complete);
  if(!complete) g_model_feature_gaps++;
  g_model_audit_count++;
  return ModelWrite(row);
}

void ModelSeal(const int broker_peak, const int virtual_peak, const string completion = "NATURAL")
{
  if(!g_model_config.enabled || !g_model_open || g_model_sealed) return;
  ModelCloseWindow(g_model_last_time, "RUN_END");
  if(g_model_first_time <= 0 || g_model_last_time < g_model_first_time) ModelFail("RUN_CLOCK");
  for(int file = 0; file < MODEL_FILE_COUNT; file++)
    if(file != MODEL_RUN_SUMMARY && ModelEngineFile(file, g_model_config.engine))
      if(!ModelFlush(file, true) && !g_model_failed) ModelFail("FINAL_FLUSH");
  ModelMetadata(MODEL_RUN_SUMMARY, "export_status", g_model_failed ? "FAILED" : "OK", true);
  ModelMetadata(MODEL_RUN_SUMMARY, "completion_status", g_model_failed ? "CENSORED" : completion, true);
  ModelMetadata(MODEL_RUN_SUMMARY, "failure", g_model_failed ? g_model_failure : "NONE", true);
  ModelMetadata(MODEL_RUN_SUMMARY, "broker_peak", ModelInteger(broker_peak), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "virtual_peak", ModelInteger(virtual_peak), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "handle_peak", ModelInteger(g_model_handle_peak), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "buffer_peak", ModelInteger(g_model_buffer_peak), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "feature_gap_count", ModelInteger(g_model_feature_gaps), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "warmup_count", ModelInteger(g_model_warmup_count), true);
  ModelMetadata(MODEL_RUN_SUMMARY, "warmup_fingerprint", g_model_warmup_count > 0 ? ModelFingerprintText(g_model_warmup_fingerprint) : "NONE", true);
  ModelMetadata(MODEL_RUN_SUMMARY, "warmup_status", g_model_warmup_status, true);
  ModelSummaryClock("warmup_first_time_msc", (long)g_model_warmup_first * 1000, true);
  ModelSummaryClock("warmup_last_time_msc", (long)g_model_warmup_last * 1000, true);
  ModelSummaryClock("first_time_msc", g_model_first_time, false);
  ModelSummaryClock("last_time_msc", g_model_last_time, false);
  for(int file = 0; file < MODEL_FILE_COUNT; file++)
    if(file != MODEL_RUN_SUMMARY && ModelEngineFile(file, g_model_config.engine))
      ModelMetadata(MODEL_RUN_SUMMARY, "rows_" + ModelFileName(file), ModelInteger(g_model_rows[file]), true);
  if(!ModelFlush(MODEL_RUN_SUMMARY, true) && !g_model_failed) ModelFail("SUMMARY_FLUSH");
  g_model_sealed = true;
  for(int file = 0; file < MODEL_FILE_COUNT; file++) ArrayFree(g_model_buffers[file].rows);
}

void ModelBoundary()
{
  if(g_model_failed) ModelCloseIndicators();
  ModelStopTesterIfFailed();
}

#endif
