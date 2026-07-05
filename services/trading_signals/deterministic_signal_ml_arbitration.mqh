//+------------------------------------------------------------------+
//|             trading_signals/deterministic_signal_ml_arbitration  |
//+------------------------------------------------------------------+
#ifndef _TS_DETERMINISTIC_SIGNAL_ML_ARBITRATION_MQH_
#define _TS_DETERMINISTIC_SIGNAL_ML_ARBITRATION_MQH_

const int    ML_ARBITRATION_SCHEMA_VERSION = 1;
const int    ML_ARBITRATION_ARRAY_BULLISH  = 0;
const int    ML_ARBITRATION_ARRAY_BEARISH  = 1;
const double ML_ARBITRATION_SCORE_EPSILON  = 0.0000000001;
const string ML_ARBITRATION_ACTION_SELECTED = "SELECTED";
const string ML_ARBITRATION_ACTION_BLOCKED  = "BLOCKED";
const string ML_ARBITRATION_REASON_SINGLE   = "single_candidate";
const string ML_ARBITRATION_REASON_CLASSIFIER = "highest_classifier_score";
const string ML_ARBITRATION_REASON_REGRESSOR  = "classifier_tie_regressor_score";
const string ML_ARBITRATION_REASON_STRATEGY   = "score_tie_strategy_priority";
const string ML_ARBITRATION_REASON_FALLBACK   = "deterministic_fallback";
const string ML_ARBITRATION_REASON_SELECTED_APPLY_FAILED = "selected_apply_failed";

struct MLArbitrationCandidate
{
  bool     valid;
  int      direction_array;
  int      signal_index;
  int      leg_index;
  SignalTypes direction;
  string   group_id;
  string   signal_id;
  string   source_key;
  int      source_attempt_index;
  string   symbol;
  int      strategy_id;
  string   strategy_label;
  string   source_type;
  int      source_extremum_slot;
  datetime source_extremum_time;
  bool     source_extremum_is_peak;
  double   source_extremum_price;
  datetime activation_time;
  bool     classifier_score_valid;
  bool     regressor_score_valid;
  double   classifier_score;
  double   regressor_score;
  double   threshold_probability;
  int      rank_position;
  string   rank_reason;
  ExecutionLegState leg_state;
  ExecutionLegTradeAdmissionContext admission_context;

  MLArbitrationCandidate()
  {
    valid                  = false;
    direction_array        = -1;
    signal_index           = -1;
    leg_index              = -1;
    direction              = NO_SIGNAL;
    group_id               = "";
    signal_id              = "";
    source_key             = "";
    source_attempt_index   = 0;
    symbol                 = "";
    strategy_id            = DETERMINISTIC_STRATEGY_NONE;
    strategy_label         = "";
    source_type            = "";
    source_extremum_slot   = -1;
    source_extremum_time   = 0;
    source_extremum_is_peak = false;
    source_extremum_price  = 0.0;
    activation_time        = 0;
    classifier_score_valid = false;
    regressor_score_valid  = false;
    classifier_score       = 0.0;
    regressor_score        = 0.0;
    threshold_probability  = 0.0;
    rank_position          = 0;
    rank_reason            = "";
    leg_state              = ExecutionLegState();
    admission_context      = ExecutionLegTradeAdmissionContext();
  }

  MLArbitrationCandidate(const MLArbitrationCandidate &candidate)
  {
    valid                  = candidate.valid;
    direction_array        = candidate.direction_array;
    signal_index           = candidate.signal_index;
    leg_index              = candidate.leg_index;
    direction              = candidate.direction;
    group_id               = candidate.group_id;
    signal_id              = candidate.signal_id;
    source_key             = candidate.source_key;
    source_attempt_index   = candidate.source_attempt_index;
    symbol                 = candidate.symbol;
    strategy_id            = candidate.strategy_id;
    strategy_label         = candidate.strategy_label;
    source_type            = candidate.source_type;
    source_extremum_slot   = candidate.source_extremum_slot;
    source_extremum_time   = candidate.source_extremum_time;
    source_extremum_is_peak = candidate.source_extremum_is_peak;
    source_extremum_price  = candidate.source_extremum_price;
    activation_time        = candidate.activation_time;
    classifier_score_valid = candidate.classifier_score_valid;
    regressor_score_valid  = candidate.regressor_score_valid;
    classifier_score       = candidate.classifier_score;
    regressor_score        = candidate.regressor_score;
    threshold_probability  = candidate.threshold_probability;
    rank_position          = candidate.rank_position;
    rank_reason            = candidate.rank_reason;
    leg_state              = candidate.leg_state;
    admission_context      = candidate.admission_context;
  }
};

struct MLArbitrationGroupSummary
{
  string group_id;
  int    candidate_count;
  int    selected_index;
  string selected_signal_id;
  string rank_reason;
  bool   classifier_tie;
  bool   regressor_tie;
  bool   strategy_tie_break;

  MLArbitrationGroupSummary()
  {
    group_id           = "";
    candidate_count    = 0;
    selected_index     = -1;
    selected_signal_id = "";
    rank_reason        = "";
    classifier_tie     = false;
    regressor_tie      = false;
    strategy_tie_break = false;
  }

  MLArbitrationGroupSummary(const MLArbitrationGroupSummary &summary)
  {
    group_id           = summary.group_id;
    candidate_count    = summary.candidate_count;
    selected_index     = summary.selected_index;
    selected_signal_id = summary.selected_signal_id;
    rank_reason        = summary.rank_reason;
    classifier_tie     = summary.classifier_tie;
    regressor_tie      = summary.regressor_tie;
    strategy_tie_break = summary.strategy_tie_break;
  }
};

struct MLArbitrationDecisionRow
{
  bool     valid;
  string   group_id;
  string   selected_signal_id;
  string   signal_id;
  int      source_attempt_index;
  string   action;
  string   reason;
  int      rank_position;
  string   rank_reason;
  MLArbitrationCandidate candidate;

  MLArbitrationDecisionRow()
  {
    valid                = false;
    group_id             = "";
    selected_signal_id   = "";
    signal_id            = "";
    source_attempt_index = 0;
    action               = "";
    reason               = "";
    rank_position        = 0;
    rank_reason          = "";
    candidate            = MLArbitrationCandidate();
  }

  MLArbitrationDecisionRow(const MLArbitrationDecisionRow &row)
  {
    valid                = row.valid;
    group_id             = row.group_id;
    selected_signal_id   = row.selected_signal_id;
    signal_id            = row.signal_id;
    source_attempt_index = row.source_attempt_index;
    action               = row.action;
    reason               = row.reason;
    rank_position        = row.rank_position;
    rank_reason          = row.rank_reason;
    candidate            = row.candidate;
  }
};

string MLArbitrationBoolToken(const bool value)
{
  return value ? "true" : "false";
}

string MLArbitrationDirectionToken(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "BULLISH";
  if(direction == BEARISH)
    return "BEARISH";
  return "NO_SIGNAL";
}

string MLArbitrationSourceTypeToken(const SignalParams &signal_params)
{
  return signal_params.source_extremum_is_peak ? "PEAK" : "BOTTOM";
}

string MLArbitrationCell(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "\r", " ");
  StringReplace(value, "\n", " ");
  StringReplace(value, "\t", " ");
  return value;
}

string MLArbitrationTimeKey(const datetime value)
{
  if(value <= 0)
    return "0";
  return IntegerToString((int)value);
}

string MLArbitrationPriceKey(const double value)
{
  int digits = Digits();
  if(digits <= 0)
    digits = 5;
  return DoubleToString(NormalizeDouble(value, digits), digits);
}

string MLArbitrationResolveSignalId(const SignalParams &signal_params)
{
  if(signal_params.ml_shadow_signal_id != "")
    return signal_params.ml_shadow_signal_id;
  if(signal_params.deterministic_stats_signal_id != "")
    return signal_params.deterministic_stats_signal_id;
  return signal_params.execution_sequence_id;
}

string MLArbitrationResolveSourceKey(const SignalParams &signal_params)
{
  if(signal_params.deterministic_source_key != "")
    return signal_params.deterministic_source_key;
  return BuildDeterministicSignalSourceKey(signal_params);
}

string MLArbitrationBuildGroupId(const SignalParams &signal_params,
                                 const datetime activation_time)
{
  string symbol = _Symbol;
  string source_type = MLArbitrationSourceTypeToken(signal_params);
  return MLArbitrationCell(StringFormat("%s|%s|slot=%d|%s|source_time=%s|source_price=%s|activation=%s",
                                        symbol,
                                        MLArbitrationDirectionToken(signal_params.signal_type),
                                        signal_params.source_extremum_slot,
                                        source_type,
                                        MLArbitrationTimeKey(signal_params.source_extremum_time),
                                        MLArbitrationPriceKey(signal_params.source_extremum_price),
                                        MLArbitrationTimeKey(activation_time)));
}

int MLArbitrationStrategyPriority(const int strategy_id)
{
  if(strategy_id == DETERMINISTIC_STRATEGY_1)
    return 3;
  if(strategy_id == DETERMINISTIC_STRATEGY_2)
    return 2;
  if(strategy_id == DETERMINISTIC_STRATEGY_3)
    return 1;
  return 0;
}

bool MLArbitrationScoresEqual(const double left,
                              const double right)
{
  return (MathAbs(left - right) <= ML_ARBITRATION_SCORE_EPSILON);
}

int MLArbitrationCompareCandidates(const MLArbitrationCandidate &left,
                                   const MLArbitrationCandidate &right,
                                   string &rank_reason_out)
{
  rank_reason_out = ML_ARBITRATION_REASON_FALLBACK;

  if(left.valid && !right.valid)
    return 1;
  if(!left.valid && right.valid)
    return -1;
  if(!left.valid && !right.valid)
    return 0;

  if(left.classifier_score_valid && !right.classifier_score_valid)
  {
    rank_reason_out = ML_ARBITRATION_REASON_CLASSIFIER;
    return 1;
  }
  if(!left.classifier_score_valid && right.classifier_score_valid)
  {
    rank_reason_out = ML_ARBITRATION_REASON_CLASSIFIER;
    return -1;
  }
  if(left.classifier_score_valid && right.classifier_score_valid &&
     !MLArbitrationScoresEqual(left.classifier_score, right.classifier_score))
  {
    rank_reason_out = ML_ARBITRATION_REASON_CLASSIFIER;
    return (left.classifier_score > right.classifier_score) ? 1 : -1;
  }

  if(left.regressor_score_valid && !right.regressor_score_valid)
  {
    rank_reason_out = ML_ARBITRATION_REASON_REGRESSOR;
    return 1;
  }
  if(!left.regressor_score_valid && right.regressor_score_valid)
  {
    rank_reason_out = ML_ARBITRATION_REASON_REGRESSOR;
    return -1;
  }
  if(left.regressor_score_valid && right.regressor_score_valid &&
     !MLArbitrationScoresEqual(left.regressor_score, right.regressor_score))
  {
    rank_reason_out = ML_ARBITRATION_REASON_REGRESSOR;
    return (left.regressor_score > right.regressor_score) ? 1 : -1;
  }

  int left_priority = MLArbitrationStrategyPriority(left.strategy_id);
  int right_priority = MLArbitrationStrategyPriority(right.strategy_id);
  if(left_priority != right_priority)
  {
    rank_reason_out = ML_ARBITRATION_REASON_STRATEGY;
    return (left_priority > right_priority) ? 1 : -1;
  }

  int signal_compare = StringCompare(left.signal_id, right.signal_id);
  if(signal_compare != 0)
  {
    rank_reason_out = ML_ARBITRATION_REASON_FALLBACK;
    return (signal_compare < 0) ? 1 : -1;
  }

  if(left.signal_index != right.signal_index)
  {
    rank_reason_out = ML_ARBITRATION_REASON_FALLBACK;
    return (left.signal_index < right.signal_index) ? 1 : -1;
  }

  return 0;
}

bool MLArbitrationSameGroup(const MLArbitrationCandidate &left,
                            const MLArbitrationCandidate &right)
{
  if(!left.valid || !right.valid)
    return false;
  return (left.group_id != "" && left.group_id == right.group_id);
}

bool MLArbitrationSourceIdentityMatches(const MLArbitrationCandidate &candidate,
                                        const SignalParams &signal_params,
                                        const datetime activation_time)
{
  if(!candidate.valid)
    return false;
  if(signal_params.signal_type != candidate.direction)
    return false;
  if(signal_params.source_extremum_slot != candidate.source_extremum_slot)
    return false;
  if(signal_params.source_extremum_time != candidate.source_extremum_time)
    return false;
  if(signal_params.source_extremum_is_peak != candidate.source_extremum_is_peak)
    return false;
  if(activation_time != candidate.activation_time)
    return false;

  double tolerance = ExecutionResolvePointSize();
  if(tolerance <= 0.0)
    tolerance = 0.0000001;

  return (MathAbs(signal_params.source_extremum_price -
                  candidate.source_extremum_price) <= tolerance);
}

int MLArbitrationFindBestCandidateIndex(const MLArbitrationCandidate &candidates[])
{
  int total = ArraySize(candidates);
  int best_index = -1;
  for(int i = 0; i < total; i++)
  {
    if(!candidates[i].valid)
      continue;
    if(best_index < 0)
    {
      best_index = i;
      continue;
    }

    string rank_reason = "";
    if(MLArbitrationCompareCandidates(candidates[i],
                                      candidates[best_index],
                                      rank_reason) > 0)
      best_index = i;
  }

  return best_index;
}

bool MLArbitrationBuildCandidate(SignalParams &signal_params,
                                 const ExecutionLegState &leg_state,
                                 const ExecutionLegTradeAdmissionContext &admission_context,
                                 const int direction_array,
                                 const int signal_index,
                                 const int leg_index,
                                 const datetime activation_time,
                                 MLArbitrationCandidate &candidate_out)
{
  candidate_out = MLArbitrationCandidate();

  if(!signal_params.deterministic_strategy)
    return false;
  if(signal_params.signal_type != BULLISH &&
     signal_params.signal_type != BEARISH)
    return false;
  if(signal_params.source_extremum_time <= 0 ||
     signal_params.source_extremum_slot < 0 ||
     signal_params.source_extremum_price <= 0.0)
    return false;

  candidate_out.valid                  = true;
  candidate_out.direction_array        = direction_array;
  candidate_out.signal_index           = signal_index;
  candidate_out.leg_index              = leg_index;
  candidate_out.direction              = signal_params.signal_type;
  candidate_out.group_id               = MLArbitrationBuildGroupId(signal_params,
                                                                   activation_time);
  candidate_out.signal_id              = MLArbitrationResolveSignalId(signal_params);
  candidate_out.source_key             = MLArbitrationResolveSourceKey(signal_params);
  candidate_out.source_attempt_index   = signal_params.deterministic_source_attempt_index;
  candidate_out.symbol                 = _Symbol;
  candidate_out.strategy_id            = signal_params.strategy_id;
  candidate_out.strategy_label         = signal_params.strategy_label;
  candidate_out.source_type            = MLArbitrationSourceTypeToken(signal_params);
  candidate_out.source_extremum_slot   = signal_params.source_extremum_slot;
  candidate_out.source_extremum_time   = signal_params.source_extremum_time;
  candidate_out.source_extremum_is_peak = signal_params.source_extremum_is_peak;
  candidate_out.source_extremum_price  = signal_params.source_extremum_price;
  candidate_out.activation_time        = activation_time;
  candidate_out.classifier_score_valid = (signal_params.ml_shadow_evaluated &&
                                          signal_params.ml_shadow_available &&
                                          signal_params.ml_shadow_feature_valid &&
                                          signal_params.ml_shadow_classifier_scored &&
                                          MathIsValidNumber(signal_params.ml_shadow_classifier_score));
  candidate_out.regressor_score_valid  = (signal_params.ml_shadow_evaluated &&
                                          signal_params.ml_shadow_available &&
                                          signal_params.ml_shadow_feature_valid &&
                                          signal_params.ml_shadow_regressor_scored &&
                                          MathIsValidNumber(signal_params.ml_shadow_regressor_score));
  candidate_out.classifier_score       = signal_params.ml_shadow_classifier_score;
  candidate_out.regressor_score        = signal_params.ml_shadow_regressor_score;
  candidate_out.threshold_probability  = signal_params.ml_shadow_threshold;
  candidate_out.rank_position          = 0;
  candidate_out.rank_reason            = "";
  candidate_out.leg_state              = leg_state;
  candidate_out.admission_context      = admission_context;

  return (candidate_out.group_id != "" && candidate_out.signal_id != "");
}

void MLArbitrationRegisterGroupCounters(const int candidate_count,
                                        const string rank_reason)
{
  if(!g_ml_shadow_state.enabled || !DeterministicSignalMLFilterMode())
    return;

  g_ml_shadow_state.arbitration_group_rows++;
  if(candidate_count <= 1)
    g_ml_shadow_state.arbitration_single_candidate_groups++;
  else
    g_ml_shadow_state.arbitration_multi_candidate_groups++;

  if(rank_reason == ML_ARBITRATION_REASON_REGRESSOR)
    g_ml_shadow_state.arbitration_classifier_tie_rows++;
  else if(rank_reason == ML_ARBITRATION_REASON_STRATEGY)
  {
    g_ml_shadow_state.arbitration_classifier_tie_rows++;
    g_ml_shadow_state.arbitration_regressor_tie_rows++;
    g_ml_shadow_state.arbitration_strategy_tie_break_rows++;
  }
  else if(rank_reason == ML_ARBITRATION_REASON_FALLBACK)
  {
    g_ml_shadow_state.arbitration_classifier_tie_rows++;
    g_ml_shadow_state.arbitration_regressor_tie_rows++;
  }
}

string MLArbitrationDecisionOutputRow(const MLArbitrationCandidate &candidate,
                                      const string selected_signal_id,
                                      const int rank_position,
                                      const string rank_reason,
                                      const string action,
                                      const string arbitration_reason)
{
  return IntegerToString(ML_ARBITRATION_SCHEMA_VERSION) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.shadow_run_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.export_id) + "\t" +
         MLShadowOutputCell(g_ml_shadow_state.model_id) + "\t" +
         MLShadowOutputCell(candidate.group_id) + "\t" +
         MLShadowOutputCell(selected_signal_id) + "\t" +
         MLShadowOutputCell(candidate.signal_id) + "\t" +
         MLShadowOutputCell(candidate.source_key) + "\t" +
         IntegerToString(candidate.source_attempt_index) + "\t" +
         MLShadowOutputCell(candidate.symbol) + "\t" +
         IntegerToString(candidate.strategy_id) + "\t" +
         MLShadowOutputCell(candidate.strategy_label) + "\t" +
         MLShadowOutputCell(MLArbitrationDirectionToken(candidate.direction)) + "\t" +
         MLShadowOutputCell(candidate.source_type) + "\t" +
         IntegerToString(candidate.source_extremum_slot) + "\t" +
         MLShadowTimeToken(candidate.source_extremum_time) + "\t" +
         MLShadowBoolToken(candidate.source_extremum_is_peak) + "\t" +
         MLShadowDoubleToken(candidate.source_extremum_price > 0.0,
                             candidate.source_extremum_price,
                             8) + "\t" +
         MLShadowTimeToken(candidate.activation_time) + "\t" +
         MLShadowDoubleToken(candidate.classifier_score_valid,
                             candidate.classifier_score,
                             8) + "\t" +
         MLShadowDoubleToken(candidate.regressor_score_valid,
                             candidate.regressor_score,
                             8) + "\t" +
         MLShadowDoubleToken(candidate.threshold_probability > 0.0,
                             candidate.threshold_probability,
                             8) + "\t" +
         IntegerToString(rank_position) + "\t" +
         MLShadowOutputCell(rank_reason) + "\t" +
         MLShadowOutputCell(action) + "\t" +
         MLShadowOutputCell(arbitration_reason);
}

bool MLArbitrationRecordDecision(const MLArbitrationCandidate &candidate,
                                 const string selected_signal_id,
                                 const int rank_position,
                                 const string rank_reason,
                                 const string action,
                                 const string arbitration_reason)
{
  if(!g_ml_shadow_state.enabled || !DeterministicSignalMLFilterMode())
    return false;
  if(!candidate.valid)
    return false;

  string row = MLArbitrationDecisionOutputRow(candidate,
                                             selected_signal_id,
                                             rank_position,
                                             rank_reason,
                                             action,
                                             arbitration_reason);
  if(!MLShadowQueueRow(MLShadowOutputPath(ML_SHADOW_ARBITRATION_DECISIONS_FILE),
                       ML_SHADOW_ARBITRATION_DECISIONS_HEADER,
                       row,
                       g_ml_shadow_arbitration_buffer))
    return false;

  if(action == ML_ARBITRATION_ACTION_SELECTED)
    g_ml_shadow_state.arbitration_selected_rows++;
  else if(action == ML_ARBITRATION_ACTION_BLOCKED)
    g_ml_shadow_state.arbitration_blocked_rows++;

  return true;
}

string MLArbitrationCandidateDebugToken(const MLArbitrationCandidate &candidate)
{
  return StringFormat("group=%s|signal_id=%s|strategy=%s|dir=%s|score=%s|regressor=%s|threshold=%s",
                      candidate.group_id,
                      candidate.signal_id,
                      candidate.strategy_label,
                      MLArbitrationDirectionToken(candidate.direction),
                      DoubleToString(candidate.classifier_score, 8),
                      DoubleToString(candidate.regressor_score, 8),
                      DoubleToString(candidate.threshold_probability, 8));
}

#endif // _TS_DETERMINISTIC_SIGNAL_ML_ARBITRATION_MQH_
