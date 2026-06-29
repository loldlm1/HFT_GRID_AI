//+------------------------------------------------------------------+
//|                       pandora_xboost_state.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_

const int    PANDORA_XBOOST_SCHEMA_VERSION       = 5;
const int    PANDORA_XBOOST_MIN_DEPTH            = 0;
const int    PANDORA_XBOOST_MAX_DEPTH            = 5;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_1  = 30;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_2  = 20;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3  = 12;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_4  = 12;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_5  = 12;
const double PANDORA_XBOOST_MIN_EXPECTANCY_R     = 0.05;
const double PANDORA_XBOOST_MIN_EDGE_R           = 0.05;
const double PANDORA_XBOOST_DEPTH_PENALTY_R      = 0.03;
const int    PANDORA_XBOOST_TOP_CANDIDATE_LIMIT  = 3;
const int    PANDORA_XBOOST_ROLLING_DAYS_120     = 120;
const int    PANDORA_XBOOST_ROLLING_DAYS_60      = 60;
const int    PANDORA_XBOOST_SAMPLE_WINDOW_120    = 120;
const int    PANDORA_XBOOST_SAMPLE_WINDOW_60     = 60;
const int    PANDORA_XBOOST_SAMPLE_FRESHNESS_MAX_DAYS = 180;
const double PANDORA_XBOOST_SAMPLE_FRESHNESS_PENALTY_R = 0.02;
const int    PANDORA_XBOOST_BROKER_RECENT_TRADES = 30;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_1 = 30;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_2 = 20;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_3 = 12;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_4 = 12;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_5 = 12;
const double PANDORA_XBOOST_BAYES_UNCERTAINTY_Z = 1.0;
const double PANDORA_XBOOST_BAYES_UNCERTAINTY_FLOOR_R = 0.03;
const double PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R = 0.03;
const double PANDORA_XBOOST_BROKER_DEGRADATION_FLOOR_R = -0.05;
const double PANDORA_XBOOST_BROKER_DEGRADATION_WEIGHT = 1.0;
const int    PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES = 5;
const int    PANDORA_XBOOST_BROKER_MIN_RECENT_SAMPLES = 10;
const double PANDORA_XBOOST_ROBUST_MIN_SCORE_R = 0.02;
const double PANDORA_XBOOST_ROBUST_MEDIAN_PENALTY_WEIGHT = 0.35;
const double PANDORA_XBOOST_ROBUST_LOSS_RATE_PENALTY_WEIGHT = 0.10;
const double PANDORA_XBOOST_ROBUST_OUTLIER_PENALTY_WEIGHT = 0.08;
const double PANDORA_XBOOST_ROBUST_PAYOFF_CREDIT_CAP_R = 0.04;
const double PANDORA_XBOOST_ROBUST_FORWARD_PENALTY_WEIGHT = 0.50;
const double PANDORA_XBOOST_ROBUST_BROKER_NODE_WEIGHT = 0.70;
const double PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R = 0.05;
const int    PANDORA_XBOOST_ROBUST_OUTLIER_TOP_COUNT = 3;
const double PANDORA_XBOOST_ROBUST_LOSS_RATE_FLOOR = 0.55;
const double PANDORA_XBOOST_ROBUST_OUTLIER_FLOOR = 0.65;
const double PANDORA_XBOOST_ROBUST_PAYOFF_MIN_RATIO = 1.60;
const double PANDORA_XBOOST_ROBUST_PAYOFF_MIN_PROFIT_FACTOR = 1.05;
const double PANDORA_XBOOST_ROBUST_FRAGILITY_CAP_R = 0.16;
const double PANDORA_XBOOST_ROBUST_FORWARD_PENALTY_CAP_R = 0.12;
const double PANDORA_XBOOST_ROBUST_BROKER_PATH_WEIGHT = 0.35;
const double PANDORA_XBOOST_ROBUST_BROKER_DEGRADATION_CAP_R = 0.20;
const double PANDORA_XBOOST_V5_CALENDAR_RECENT_WEIGHT = 0.65;
const double PANDORA_XBOOST_V5_SAMPLE_RECENT_WEIGHT = 0.35;
const double PANDORA_XBOOST_V5_SHRINKAGE_WEIGHT = 0.25;
const double PANDORA_XBOOST_V5_FRAGILITY_WEIGHT = 0.60;
const double PANDORA_XBOOST_V5_FORWARD_WEIGHT = 0.50;
const double PANDORA_XBOOST_V5_BROKER_WEIGHT = 0.50;

void PandoraXBoostBuildRootCandidates(const SignalParams &root_signal);
void PandoraXBoostBuildNextCandidatesFromClosedSignal(const SignalParams &closed_signal,
                                                      const PandoraXBoostCloseEvents close_event,
                                                      const int next_depth);
bool PandoraXBoostApplyBrokerDecision(SignalParams &signal_params);
void PandoraXBoostReleaseBrokerAfterClose(const SignalParams &signal_params);
void PandoraXBoostResetRuntimeState();
void PandoraXBoostLogEvent(const string label, const string message);
string PandoraXBoostStorageShortLabel();
double PandoraXBoostClampDouble(const double value,
                                const double min_value,
                                const double max_value);
void PandoraXBoostResetSessionMask();
bool PandoraXBoostSessionMaskConfigured();
bool PandoraXBoostSessionMaskAllowsTraining(const datetime day_anchor,
                                            string &reason);
bool PandoraXBoostSessionMaskAllowsBroker(const datetime day_anchor,
                                          string &reason);

int PandoraXBoostClampDepth(const int configured_depth)
{
  if(configured_depth < PANDORA_XBOOST_MIN_DEPTH)
    return PANDORA_XBOOST_MIN_DEPTH;
  if(configured_depth > PANDORA_XBOOST_MAX_DEPTH)
    return PANDORA_XBOOST_MAX_DEPTH;
  return configured_depth;
}

bool PandoraXBoostEnabled()
{
  return (Pandora_XBoost_Mode != PANDORA_XBOOST_DISABLED);
}

bool PandoraXBoostTrainingMode()
{
  return (Pandora_XBoost_Mode == PANDORA_XBOOST_TRAINING);
}

bool PandoraXBoostInferenceMode()
{
  return (Pandora_XBoost_Mode == PANDORA_XBOOST_INFERENCE);
}

string PandoraXBoostModeLabel(const PandoraXBoostModes mode)
{
  switch(mode)
  {
    case PANDORA_XBOOST_TRAINING:
      return "TRAINING";
    case PANDORA_XBOOST_INFERENCE:
      return "INFERENCE";
    case PANDORA_XBOOST_DISABLED:
    default:
      return "DISABLED";
  }
}

string PandoraXBoostCandidateStatusLabel(const PandoraXBoostCandidateStatuses status)
{
  switch(status)
  {
    case PANDORA_XBOOST_CANDIDATE_WAIT:
      return "WAIT";
    case PANDORA_XBOOST_CANDIDATE_WATCH:
      return "WATCH";
    case PANDORA_XBOOST_CANDIDATE_READY:
      return "READY";
    case PANDORA_XBOOST_CANDIDATE_BLOCK:
      return "BLOCK";
    case PANDORA_XBOOST_CANDIDATE_NONE:
    default:
      return "NONE";
  }
}

string PandoraXBoostCloseEventLabel(const PandoraXBoostCloseEvents event_type,
                                    const int step_index = 0)
{
  switch(event_type)
  {
    case PANDORA_XBOOST_EVENT_ROOTL:
      return "ROOTL";
    case PANDORA_XBOOST_EVENT_ROOTS:
      return "ROOTS";
    case PANDORA_XBOOST_EVENT_SLL1:
      return "SLL1";
    case PANDORA_XBOOST_EVENT_SLS1:
      return "SLS1";
    case PANDORA_XBOOST_EVENT_TPL:
      return "TPL";
    case PANDORA_XBOOST_EVENT_TPS:
      return "TPS";
    case PANDORA_XBOOST_EVENT_TBE:
      return "TBE";
    case PANDORA_XBOOST_EVENT_TBEL:
      return "TBEL";
    case PANDORA_XBOOST_EVENT_TBES:
      return "TBES";
    case PANDORA_XBOOST_EVENT_TTPL:
    {
      int safe_step = step_index;
      if(safe_step < 1)
        safe_step = 1;
      return StringFormat("TTPL%d", safe_step);
    }
    case PANDORA_XBOOST_EVENT_TTPS:
    {
      int safe_step = step_index;
      if(safe_step < 1)
        safe_step = 1;
      return StringFormat("TTPS%d", safe_step);
    }
    case PANDORA_XBOOST_EVENT_FORCE_CLOSE:
      return "FORCE_CLOSE";
    case PANDORA_XBOOST_EVENT_NONE:
    default:
      return "NONE";
  }
}

string PandoraXBoostSafeKeyPart(const string raw_value)
{
  string value = raw_value;
  if(value == "")
    value = "none";

  string result = "";
  int total = StringLen(value);
  for(int i = 0; i < total; i++)
  {
    ushort ch = StringGetCharacter(value, i);
    bool is_digit = (ch >= '0' && ch <= '9');
    bool is_upper = (ch >= 'A' && ch <= 'Z');
    bool is_lower = (ch >= 'a' && ch <= 'z');
    bool is_safe = is_digit || is_upper || is_lower || ch == '_' || ch == '-' || ch == '.';
    if(is_safe)
      result = result + StringSubstr(value, i, 1);
    else
      result = result + "_";
  }

  if(result == "")
    result = "none";
  return result;
}

ulong PandoraXBoostHashKey(const string input_value)
{
  ulong hash = 1469598103934665603;
  int total = StringLen(input_value);
  for(int i = 0; i < total; i++)
  {
    hash ^= (ulong)StringGetCharacter(input_value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string PandoraXBoostDirectionLabel(const SignalTypes direction)
{
  if(direction == BULLISH)
    return "L";
  if(direction == BEARISH)
    return "S";
  return "N";
}

SignalTypes PandoraXBoostDirectionFromLabel(const string label)
{
  if(label == "L")
    return BULLISH;
  if(label == "S")
    return BEARISH;
  return NO_SIGNAL;
}

PandoraXBoostCloseEvents PandoraXBoostCloseEventFromLabel(const string label)
{
  if(label == "ROOTL")
    return PANDORA_XBOOST_EVENT_ROOTL;
  if(label == "ROOTS")
    return PANDORA_XBOOST_EVENT_ROOTS;
  if(label == "SLL1")
    return PANDORA_XBOOST_EVENT_SLL1;
  if(label == "SLS1")
    return PANDORA_XBOOST_EVENT_SLS1;
  if(label == "TPL")
    return PANDORA_XBOOST_EVENT_TPL;
  if(label == "TPS")
    return PANDORA_XBOOST_EVENT_TPS;
  if(label == "TBE")
    return PANDORA_XBOOST_EVENT_TBE;
  if(label == "TBEL")
    return PANDORA_XBOOST_EVENT_TBEL;
  if(label == "TBES")
    return PANDORA_XBOOST_EVENT_TBES;
  if(StringFind(label, "TTPL") == 0)
    return PANDORA_XBOOST_EVENT_TTPL;
  if(StringFind(label, "TTPS") == 0)
    return PANDORA_XBOOST_EVENT_TTPS;
  if(label == "FORCE_CLOSE")
    return PANDORA_XBOOST_EVENT_FORCE_CLOSE;
  return PANDORA_XBOOST_EVENT_NONE;
}

PandoraXBoostCloseEvents PandoraXBoostRootEventForDirection(const SignalTypes direction)
{
  if(direction == BULLISH)
    return PANDORA_XBOOST_EVENT_ROOTL;
  if(direction == BEARISH)
    return PANDORA_XBOOST_EVENT_ROOTS;
  return PANDORA_XBOOST_EVENT_NONE;
}

string PandoraXBoostDateKey(const datetime value)
{
  datetime safe_value = value;
  if(safe_value <= 0)
    safe_value = TimeCurrent();
  return PandoraXBoostSafeKeyPart(TimeToString(safe_value, TIME_DATE));
}

string PandoraXBoostBuildStrategyKey()
{
  int max_depth = PandoraXBoostClampDepth(Pandora_XBoost_Max_Depth);
  return StringFormat("v%d|%s|%s|%d|%d|%d|%d|%s|%d",
                      PANDORA_XBOOST_SCHEMA_VERSION,
                      PandoraXBoostSafeKeyPart(Pandora_XBoost_Strategy_Id),
                      PandoraXBoostSafeKeyPart(_Symbol),
                      (int)Strategy_Timeframe,
                      (int)Pandora_Box_Entry_Type,
                      (int)Pandora_Risk_Trailing_Mode,
                      (int)Pandora_Points_Value_Mode,
                      PandoraXBoostSafeKeyPart(Pandora_Box_Time_Range),
                      max_depth);
}

string PandoraXBoostBuildNodeKey(const string strategy_key,
                                 const SignalTypes root_side,
                                 const PandoraXBoostCloseEvents parent_event,
                                 const int depth,
                                 const SignalTypes candidate_side,
                                 const int event_step_index = 0,
                                 const string node_path = "")
{
  int safe_depth = depth;
  if(safe_depth < 1)
    safe_depth = 1;
  string safe_path = PandoraXBoostSafeKeyPart(node_path);
  return StringFormat("%s|%s|%s|%d|%s|%s",
                      strategy_key,
                      PandoraXBoostDirectionLabel(root_side),
                      PandoraXBoostCloseEventLabel(parent_event, event_step_index),
                      safe_depth,
                      PandoraXBoostDirectionLabel(candidate_side),
                      safe_path);
}

string PandoraXBoostBuildSampleId(const string strategy_key,
                                  const datetime root_date,
                                  const string node_path,
                                  const int depth,
                                  const SignalTypes candidate_side,
                                  const PandoraXBoostCloseEvents close_event,
                                  const int event_step_index = 0)
{
  int safe_depth = depth;
  if(safe_depth < 1)
    safe_depth = 1;
  return StringFormat("%s|%s|%s|%d|%s|%s",
                      strategy_key,
                      PandoraXBoostDateKey(root_date),
                      PandoraXBoostSafeKeyPart(node_path),
                      safe_depth,
                      PandoraXBoostDirectionLabel(candidate_side),
                      PandoraXBoostCloseEventLabel(close_event, event_step_index));
}

string PandoraXBoostBuildBrokerTradeId(const string strategy_key,
                                       const datetime root_date,
                                       const string node_path,
                                       const int depth,
                                       const int broker_trade_index,
                                       const SignalTypes side,
                                       const datetime entry_time)
{
  int safe_depth = depth;
  if(safe_depth < 1)
    safe_depth = 1;
  int safe_trade_index = broker_trade_index;
  if(safe_trade_index < 0)
    safe_trade_index = 0;

  return StringFormat("%s|%s|%s|%d|%d|%s|%I64d",
                      strategy_key,
                      PandoraXBoostDateKey(root_date),
                      PandoraXBoostSafeKeyPart(node_path),
                      safe_depth,
                      safe_trade_index,
                      PandoraXBoostDirectionLabel(side),
                      (long)entry_time);
}

string PandoraXBoostBuildDisplayId(const SignalTypes candidate_side,
                                   const PandoraXBoostCloseEvents parent_event,
                                   const int event_step_index = 0)
{
  return PandoraXBoostDirectionLabel(candidate_side) + "-" +
         PandoraXBoostCloseEventLabel(parent_event, event_step_index);
}

void PandoraXBoostPrepareSignalMetadata(SignalParams &signal_params,
                                        const string strategy_key,
                                        const string root_id,
                                        const SignalTypes root_side,
                                        const PandoraXBoostCloseEvents parent_event,
                                        const int depth,
                                        const bool local_only,
                                        const string parent_node_path = "")
{
  int safe_depth = depth;
  if(safe_depth < 1)
    safe_depth = 1;

  signal_params.pandora_xboost_enabled = true;
  signal_params.pandora_xboost_local_only = local_only;
  signal_params.pandora_xboost_broker_selected = false;
  signal_params.pandora_xboost_depth = safe_depth;
  signal_params.pandora_xboost_broker_trade_index = 0;
  signal_params.pandora_xboost_root_side = root_side;
  signal_params.pandora_xboost_parent_event = parent_event;
  signal_params.pandora_xboost_close_event = PANDORA_XBOOST_EVENT_NONE;
  signal_params.pandora_xboost_strategy_key = strategy_key;
  signal_params.pandora_xboost_root_id = root_id;
  signal_params.pandora_xboost_display_id =
    PandoraXBoostBuildDisplayId(signal_params.signal_type, parent_event);
  if(parent_node_path == "")
    signal_params.pandora_xboost_node_path = signal_params.pandora_xboost_display_id;
  else
    signal_params.pandora_xboost_node_path = parent_node_path + ">" +
                                             signal_params.pandora_xboost_display_id;
  signal_params.pandora_xboost_node_key =
    PandoraXBoostBuildNodeKey(strategy_key,
                              root_side,
                              parent_event,
                              safe_depth,
                              signal_params.signal_type,
                              0,
                              signal_params.pandora_xboost_node_path);
  signal_params.pandora_xboost_sample_id = "";
  signal_params.pandora_xboost_broker_trade_id = "";
  signal_params.pandora_xboost_selected_rank = 0;
  signal_params.pandora_xboost_model_samples = 0;
  signal_params.pandora_xboost_broker_node_samples = 0;
  signal_params.pandora_xboost_model_score_r = 0.0;
  signal_params.pandora_xboost_model_posterior_r = 0.0;
  signal_params.pandora_xboost_model_conservative_r = 0.0;
}

void PandoraXBoostPrepareRootSignal(SignalParams &signal_params)
{
  if(!PandoraXBoostEnabled())
    return;
  if(!IsPandoraSignal(signal_params))
    return;

  datetime root_date = g_pandora_box_state.day_anchor;
  if(root_date <= 0)
    root_date = ResolveCurrentDayStart();

  SignalTypes root_side = signal_params.signal_type;
  PandoraXBoostCloseEvents root_event = PandoraXBoostRootEventForDirection(root_side);
  string strategy_key = PandoraXBoostBuildStrategyKey();
  string root_id = StringFormat("%s|%s|%s",
                                strategy_key,
                                PandoraXBoostDateKey(root_date),
                                PandoraXBoostDirectionLabel(root_side));
  bool same_root = (g_pandora_xboost_root.root_id == root_id);
  bool broker_active = same_root && g_pandora_xboost_root.broker_active;
  int broker_trade_count = same_root ? g_pandora_xboost_root.broker_trade_count : 0;

  g_pandora_xboost_root.active = true;
  g_pandora_xboost_root.broker_active = broker_active;
  g_pandora_xboost_root.root_side = root_side;
  g_pandora_xboost_root.last_event = root_event;
  g_pandora_xboost_root.root_date = root_date;
  g_pandora_xboost_root.strategy_key = strategy_key;
  g_pandora_xboost_root.root_id = root_id;
  g_pandora_xboost_root.current_depth = 1;
  g_pandora_xboost_root.broker_trade_count = broker_trade_count;

  PandoraXBoostPrepareSignalMetadata(signal_params,
                                     strategy_key,
                                     root_id,
                                     root_side,
                                     root_event,
                                     1,
                                     true);
  PandoraXBoostBuildRootCandidates(signal_params);
  PandoraXBoostApplyBrokerDecision(signal_params);
  PandoraXBoostLogEvent("PANDORA_XBOOST_ROOT",
                        StringFormat("depth=1 id=%s root=%s mode=%s node=%s",
                                     signal_params.pandora_xboost_display_id,
                                     root_id,
                                     PandoraXBoostModeLabel(Pandora_XBoost_Mode),
                                     signal_params.pandora_xboost_node_key));
}

PandoraXBoostCloseEvents PandoraXBoostResolveCloseEvent(const SignalParams &signal_params,
                                                        const bool force_close)
{
  if(force_close)
    return PANDORA_XBOOST_EVENT_FORCE_CLOSE;

  SignalTypes direction = signal_params.signal_type;
  bool trailing_seen = (signal_params.pandora_trailing_step_index > 0 ||
                        signal_params.pandora_trailing_stop_price > 0.0);

  if(signal_params.pandora_close_outcome == PANDORA_CLOSE_TP)
  {
    if(trailing_seen)
      return (direction == BULLISH) ? PANDORA_XBOOST_EVENT_TTPL
                                    : PANDORA_XBOOST_EVENT_TTPS;
    return (direction == BULLISH) ? PANDORA_XBOOST_EVENT_TPL
                                  : PANDORA_XBOOST_EVENT_TPS;
  }

  if(signal_params.pandora_close_outcome == PANDORA_CLOSE_BE)
  {
    if(trailing_seen)
      return (direction == BULLISH) ? PANDORA_XBOOST_EVENT_TBEL
                                    : PANDORA_XBOOST_EVENT_TBES;
    return PANDORA_XBOOST_EVENT_TBE;
  }

  if(signal_params.pandora_close_outcome == PANDORA_CLOSE_SL)
    return (direction == BULLISH) ? PANDORA_XBOOST_EVENT_SLL1
                                  : PANDORA_XBOOST_EVENT_SLS1;

  return PANDORA_XBOOST_EVENT_NONE;
}

double PandoraXBoostResolveSignalRMultiple(const SignalParams &signal_params)
{
  if(!IsPandoraSignal(signal_params))
    return 0.0;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    return 0.0;

  double entry_price = signal_params.pandora_source_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.pandora_local_entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.entry_price;
  double close_price = signal_params.close_price;
  if(close_price <= 0.0)
    close_price = signal_params.pandora_local_close_price;
  if(entry_price <= 0.0 || close_price <= 0.0)
    return 0.0;

  double sl_points = PandoraResolveSignalSLPoints(signal_params, false);
  if(sl_points <= 0.0)
    return 0.0;

  double profit_points = 0.0;
  if(signal_params.signal_type == BULLISH)
    profit_points = (close_price - entry_price) / point_size;
  else if(signal_params.signal_type == BEARISH)
    profit_points = (entry_price - close_price) / point_size;
  else
    return 0.0;

  return profit_points / sl_points;
}

struct PandoraXBoostStats
{
  ulong    key_hash;
  string   node_key;
  int      samples;
  int      wins;
  int      losses;
  int      be;
  double   total_r;
  double   avg_r;
  double   avg_win_r;
  double   avg_loss_r;
  double   max_win_r;
  double   max_loss_r;
  double   max_drawdown_r;
  double   expectancy_r;
  datetime last_seen;

  PandoraXBoostStats()
  {
    key_hash       = 0;
    node_key       = "";
    samples        = 0;
    wins           = 0;
    losses         = 0;
    be             = 0;
    total_r        = 0.0;
    avg_r          = 0.0;
    avg_win_r      = 0.0;
    avg_loss_r     = 0.0;
    max_win_r      = 0.0;
    max_loss_r     = 0.0;
    max_drawdown_r = 0.0;
    expectancy_r   = 0.0;
    last_seen      = 0;
  }

  PandoraXBoostStats(const PandoraXBoostStats &stats)
  {
    key_hash       = stats.key_hash;
    node_key       = stats.node_key;
    samples        = stats.samples;
    wins           = stats.wins;
    losses         = stats.losses;
    be             = stats.be;
    total_r        = stats.total_r;
    avg_r          = stats.avg_r;
    avg_win_r      = stats.avg_win_r;
    avg_loss_r     = stats.avg_loss_r;
    max_win_r      = stats.max_win_r;
    max_loss_r     = stats.max_loss_r;
    max_drawdown_r = stats.max_drawdown_r;
    expectancy_r   = stats.expectancy_r;
    last_seen      = stats.last_seen;
  }
};

struct PandoraXBoostCandidate
{
  SignalTypes                    candidate_side;
  PandoraXBoostCandidateStatuses status;
  PandoraXBoostCloseEvents       parent_event;
  ulong                          key_hash;
  string                         node_key;
  string                         node_path;
  string                         display_id;
  string                         reason;
  int                            depth;
  int                            samples;
  double                         expectancy_r;
  double                         edge_r;
  double                         score_r;
  double                         posterior_r;
  double                         conservative_score_r;
  double                         uncertainty_penalty_r;
  double                         depth_penalty_r;
  double                         broker_degradation_r;
  double                         robust_score_r;
  double                         win_rate;
  double                         loss_rate;
  double                         be_rate;
  double                         median_r;
  double                         profit_factor_r;
  double                         payoff_ratio_r;
  double                         outlier_dependency_r;
  double                         fragility_penalty_r;
  double                         trailing_payoff_credit_r;
  double                         forward_stability_r;
  double                         forward_penalty_r;
  double                         broker_node_degradation_r;
  int                            local_window_120_samples;
  int                            local_window_60_samples;
  int                            sample_window_120_samples;
  int                            sample_window_60_samples;
  int                            broker_node_samples;
  int                            broker_path_samples;
  int                            broker_recent_samples;
  double                         local_window_120_avg_r;
  double                         local_window_60_avg_r;
  double                         sample_window_120_avg_r;
  double                         sample_window_60_avg_r;
  datetime                       sample_window_last_seen;
  int                            sample_window_age_days;
  string                         sample_window_freshness_reason;
  double                         broker_node_avg_r;
  double                         broker_path_avg_r;
  double                         broker_recent_avg_r;
  double                         adaptive_recent_r;
  double                         calendar_recent_r;
  double                         sample_recent_r;
  double                         hybrid_shrinkage_r;
  double                         soft_fragility_r;
  double                         soft_broker_r;
  double                         v5_score_r;

  PandoraXBoostCandidate()
  {
    candidate_side = NO_SIGNAL;
    status         = PANDORA_XBOOST_CANDIDATE_NONE;
    parent_event   = PANDORA_XBOOST_EVENT_NONE;
    key_hash       = 0;
    node_key       = "";
    node_path      = "";
    display_id     = "";
    reason         = "";
    depth          = 0;
    samples        = 0;
    expectancy_r   = 0.0;
    edge_r         = 0.0;
    score_r        = 0.0;
    posterior_r    = 0.0;
    conservative_score_r = 0.0;
    uncertainty_penalty_r = 0.0;
    depth_penalty_r = 0.0;
    broker_degradation_r = 0.0;
    robust_score_r = 0.0;
    win_rate = 0.0;
    loss_rate = 0.0;
    be_rate = 0.0;
    median_r = 0.0;
    profit_factor_r = 0.0;
    payoff_ratio_r = 0.0;
    outlier_dependency_r = 0.0;
    fragility_penalty_r = 0.0;
    trailing_payoff_credit_r = 0.0;
    forward_stability_r = 0.0;
    forward_penalty_r = 0.0;
    broker_node_degradation_r = 0.0;
    local_window_120_samples = 0;
    local_window_60_samples = 0;
    sample_window_120_samples = 0;
    sample_window_60_samples = 0;
    broker_node_samples = 0;
    broker_path_samples = 0;
    broker_recent_samples = 0;
    local_window_120_avg_r = 0.0;
    local_window_60_avg_r = 0.0;
    sample_window_120_avg_r = 0.0;
    sample_window_60_avg_r = 0.0;
    sample_window_last_seen = 0;
    sample_window_age_days = -1;
    sample_window_freshness_reason = "NO_SAMPLE";
    broker_node_avg_r = 0.0;
    broker_path_avg_r = 0.0;
    broker_recent_avg_r = 0.0;
    adaptive_recent_r = 0.0;
    calendar_recent_r = 0.0;
    sample_recent_r = 0.0;
    hybrid_shrinkage_r = 0.0;
    soft_fragility_r = 0.0;
    soft_broker_r = 0.0;
    v5_score_r = 0.0;
  }

  PandoraXBoostCandidate(const PandoraXBoostCandidate &candidate)
  {
    candidate_side = candidate.candidate_side;
    status         = candidate.status;
    parent_event   = candidate.parent_event;
    key_hash       = candidate.key_hash;
    node_key       = candidate.node_key;
    node_path      = candidate.node_path;
    display_id     = candidate.display_id;
    reason         = candidate.reason;
    depth          = candidate.depth;
    samples        = candidate.samples;
    expectancy_r   = candidate.expectancy_r;
    edge_r         = candidate.edge_r;
    score_r        = candidate.score_r;
    posterior_r    = candidate.posterior_r;
    conservative_score_r = candidate.conservative_score_r;
    uncertainty_penalty_r = candidate.uncertainty_penalty_r;
    depth_penalty_r = candidate.depth_penalty_r;
    broker_degradation_r = candidate.broker_degradation_r;
    robust_score_r = candidate.robust_score_r;
    win_rate = candidate.win_rate;
    loss_rate = candidate.loss_rate;
    be_rate = candidate.be_rate;
    median_r = candidate.median_r;
    profit_factor_r = candidate.profit_factor_r;
    payoff_ratio_r = candidate.payoff_ratio_r;
    outlier_dependency_r = candidate.outlier_dependency_r;
    fragility_penalty_r = candidate.fragility_penalty_r;
    trailing_payoff_credit_r = candidate.trailing_payoff_credit_r;
    forward_stability_r = candidate.forward_stability_r;
    forward_penalty_r = candidate.forward_penalty_r;
    broker_node_degradation_r = candidate.broker_node_degradation_r;
    local_window_120_samples = candidate.local_window_120_samples;
    local_window_60_samples = candidate.local_window_60_samples;
    sample_window_120_samples = candidate.sample_window_120_samples;
    sample_window_60_samples = candidate.sample_window_60_samples;
    broker_node_samples = candidate.broker_node_samples;
    broker_path_samples = candidate.broker_path_samples;
    broker_recent_samples = candidate.broker_recent_samples;
    local_window_120_avg_r = candidate.local_window_120_avg_r;
    local_window_60_avg_r = candidate.local_window_60_avg_r;
    sample_window_120_avg_r = candidate.sample_window_120_avg_r;
    sample_window_60_avg_r = candidate.sample_window_60_avg_r;
    sample_window_last_seen = candidate.sample_window_last_seen;
    sample_window_age_days = candidate.sample_window_age_days;
    sample_window_freshness_reason = candidate.sample_window_freshness_reason;
    broker_node_avg_r = candidate.broker_node_avg_r;
    broker_path_avg_r = candidate.broker_path_avg_r;
    broker_recent_avg_r = candidate.broker_recent_avg_r;
    adaptive_recent_r = candidate.adaptive_recent_r;
    calendar_recent_r = candidate.calendar_recent_r;
    sample_recent_r = candidate.sample_recent_r;
    hybrid_shrinkage_r = candidate.hybrid_shrinkage_r;
    soft_fragility_r = candidate.soft_fragility_r;
    soft_broker_r = candidate.soft_broker_r;
    v5_score_r = candidate.v5_score_r;
  }
};

struct PandoraXBoostRootState
{
  bool                      active;
  bool                      broker_active;
  SignalTypes               root_side;
  PandoraXBoostCloseEvents  last_event;
  datetime                  root_date;
  string                    strategy_key;
  string                    root_id;
  int                       current_depth;
  int                       broker_trade_count;

  PandoraXBoostRootState()
  {
    active             = false;
    broker_active      = false;
    root_side          = NO_SIGNAL;
    last_event         = PANDORA_XBOOST_EVENT_NONE;
    root_date          = 0;
    strategy_key       = "";
    root_id            = "";
    current_depth      = 0;
    broker_trade_count = 0;
  }

  PandoraXBoostRootState(const PandoraXBoostRootState &state)
  {
    active             = state.active;
    broker_active      = state.broker_active;
    root_side          = state.root_side;
    last_event         = state.last_event;
    root_date          = state.root_date;
    strategy_key       = state.strategy_key;
    root_id            = state.root_id;
    current_depth      = state.current_depth;
    broker_trade_count = state.broker_trade_count;
  }
};

struct PandoraXBoostBrokerTradeRow
{
  string                    broker_trade_id;
  string                    strategy_key;
  string                    root_id;
  datetime                  root_date;
  string                    node_key;
  string                    node_path;
  string                    sample_id;
  int                       depth;
  int                       broker_trade_index;
  SignalTypes               side;
  datetime                  entry_time;
  datetime                  close_time;
  double                    entry_price;
  double                    close_price;
  double                    sl_points;
  double                    r_multiple_broker;
  double                    net_profit;
  PandoraXBoostCloseEvents  close_event;
  string                    close_reason;
  double                    model_score_r;
  double                    model_posterior_r;
  int                       model_samples;
  int                       broker_node_samples;
  datetime                  seen_at;

  PandoraXBoostBrokerTradeRow()
  {
    broker_trade_id = "";
    strategy_key = "";
    root_id = "";
    root_date = 0;
    node_key = "";
    node_path = "";
    sample_id = "";
    depth = 0;
    broker_trade_index = 0;
    side = NO_SIGNAL;
    entry_time = 0;
    close_time = 0;
    entry_price = 0.0;
    close_price = 0.0;
    sl_points = 0.0;
    r_multiple_broker = 0.0;
    net_profit = 0.0;
    close_event = PANDORA_XBOOST_EVENT_NONE;
    close_reason = "";
    model_score_r = 0.0;
    model_posterior_r = 0.0;
    model_samples = 0;
    broker_node_samples = 0;
    seen_at = 0;
  }

  PandoraXBoostBrokerTradeRow(const PandoraXBoostBrokerTradeRow &row)
  {
    broker_trade_id = row.broker_trade_id;
    strategy_key = row.strategy_key;
    root_id = row.root_id;
    root_date = row.root_date;
    node_key = row.node_key;
    node_path = row.node_path;
    sample_id = row.sample_id;
    depth = row.depth;
    broker_trade_index = row.broker_trade_index;
    side = row.side;
    entry_time = row.entry_time;
    close_time = row.close_time;
    entry_price = row.entry_price;
    close_price = row.close_price;
    sl_points = row.sl_points;
    r_multiple_broker = row.r_multiple_broker;
    net_profit = row.net_profit;
    close_event = row.close_event;
    close_reason = row.close_reason;
    model_score_r = row.model_score_r;
    model_posterior_r = row.model_posterior_r;
    model_samples = row.model_samples;
    broker_node_samples = row.broker_node_samples;
    seen_at = row.seen_at;
  }
};

struct PandoraXBoostSampleRow
{
  string   sample_id;
  string   node_key;
  double   r_multiple;
  datetime seen_at;

  PandoraXBoostSampleRow()
  {
    sample_id = "";
    node_key = "";
    r_multiple = 0.0;
    seen_at = 0;
  }

  PandoraXBoostSampleRow(const PandoraXBoostSampleRow &row)
  {
    sample_id = row.sample_id;
    node_key = row.node_key;
    r_multiple = row.r_multiple;
    seen_at = row.seen_at;
  }
};

struct PandoraXBoostSessionMaskRow
{
  int    date_key;
  bool   train_allowed;
  bool   trade_allowed;
  string status;
  string reason;

  PandoraXBoostSessionMaskRow()
  {
    date_key = 0;
    train_allowed = false;
    trade_allowed = false;
    status = "";
    reason = "";
  }

  PandoraXBoostSessionMaskRow(const PandoraXBoostSessionMaskRow &row)
  {
    date_key = row.date_key;
    train_allowed = row.train_allowed;
    trade_allowed = row.trade_allowed;
    status = row.status;
    reason = row.reason;
  }
};

struct PandoraXBoostRollingStats
{
  int      samples;
  double   total_r;
  double   sum_r2;
  double   avg_r;
  datetime last_seen;

  PandoraXBoostRollingStats()
  {
    samples = 0;
    total_r = 0.0;
    sum_r2 = 0.0;
    avg_r = 0.0;
    last_seen = 0;
  }

  PandoraXBoostRollingStats(const PandoraXBoostRollingStats &stats)
  {
    samples = stats.samples;
    total_r = stats.total_r;
    sum_r2 = stats.sum_r2;
    avg_r = stats.avg_r;
    last_seen = stats.last_seen;
  }
};

struct PandoraXBoostDistributionStats
{
  int      samples;
  int      wins;
  int      losses;
  int      be;
  double   total_r;
  double   total_win_r;
  double   total_loss_r;
  double   avg_r;
  double   avg_win_r;
  double   avg_loss_r;
  double   win_rate;
  double   loss_rate;
  double   be_rate;
  double   median_r;
  double   profit_factor_r;
  double   payoff_ratio_r;
  double   outlier_dependency_r;

  PandoraXBoostDistributionStats()
  {
    samples = 0;
    wins = 0;
    losses = 0;
    be = 0;
    total_r = 0.0;
    total_win_r = 0.0;
    total_loss_r = 0.0;
    avg_r = 0.0;
    avg_win_r = 0.0;
    avg_loss_r = 0.0;
    win_rate = 0.0;
    loss_rate = 0.0;
    be_rate = 0.0;
    median_r = 0.0;
    profit_factor_r = 0.0;
    payoff_ratio_r = 0.0;
    outlier_dependency_r = 0.0;
  }

  PandoraXBoostDistributionStats(const PandoraXBoostDistributionStats &stats)
  {
    samples = stats.samples;
    wins = stats.wins;
    losses = stats.losses;
    be = stats.be;
    total_r = stats.total_r;
    total_win_r = stats.total_win_r;
    total_loss_r = stats.total_loss_r;
    avg_r = stats.avg_r;
    avg_win_r = stats.avg_win_r;
    avg_loss_r = stats.avg_loss_r;
    win_rate = stats.win_rate;
    loss_rate = stats.loss_rate;
    be_rate = stats.be_rate;
    median_r = stats.median_r;
    profit_factor_r = stats.profit_factor_r;
    payoff_ratio_r = stats.payoff_ratio_r;
    outlier_dependency_r = stats.outlier_dependency_r;
  }
};

PandoraXBoostRootState g_pandora_xboost_root;
PandoraXBoostStats     g_pandora_xboost_stats[];
string                 g_pandora_xboost_sample_ids[];
PandoraXBoostSampleRow g_pandora_xboost_sample_rows[];
PandoraXBoostCandidate g_pandora_xboost_top_candidates[];
string                 g_pandora_xboost_pending_sample_rows[];
PandoraXBoostBrokerTradeRow g_pandora_xboost_broker_trades[];
string                 g_pandora_xboost_broker_trade_ids[];
string                 g_pandora_xboost_pending_broker_trade_rows[];
PandoraXBoostSessionMaskRow g_pandora_xboost_session_mask_rows[];
bool                   g_pandora_xboost_session_mask_loaded = false;
bool                   g_pandora_xboost_session_mask_failed = false;
string                 g_pandora_xboost_session_mask_file = "";
bool                   g_pandora_xboost_storage_loaded = false;
bool                   g_pandora_xboost_storage_dirty  = false;
datetime               g_pandora_xboost_storage_load_time = 0;
string                 g_pandora_xboost_lookup_cache_key = "";
ulong                  g_pandora_xboost_lookup_cache_hash = 0;
int                    g_pandora_xboost_lookup_cache_index = -1;

void PandoraXBoostClearTopCandidates()
{
  ArrayResize(g_pandora_xboost_top_candidates, 0, 0);
}

void PandoraXBoostResetRuntimeState()
{
  PandoraXBoostRootState reset_root;
  g_pandora_xboost_root = reset_root;
  PandoraXBoostClearTopCandidates();
}

bool PandoraXBoostStringStartsWith(const string value,
                                   const string prefix)
{
  if(prefix == "")
    return false;
  return (StringFind(value, prefix) == 0);
}

datetime PandoraXBoostRollingCutoffDays(const int days)
{
  if(days <= 0)
    return 0;
  return TimeCurrent() - (days * 86400);
}

int PandoraXBoostDateIntFromTime(const datetime value)
{
  datetime safe_value = value;
  if(safe_value <= 0)
    safe_value = TimeCurrent();

  MqlDateTime ts;
  if(!TimeToStruct(safe_value, ts))
    return 0;
  return (ts.year * 10000) + (ts.mon * 100) + ts.day;
}

int PandoraXBoostDateIntFromMaskValue(const string raw_value)
{
  string value = raw_value;
  StringReplace(value, "-", "");
  StringReplace(value, ".", "");
  StringReplace(value, "/", "");
  if(StringLen(value) < 8)
    return 0;
  return (int)StringToInteger(StringSubstr(value, 0, 8));
}

bool PandoraXBoostBoolFromMaskValue(const string raw_value)
{
  string value = raw_value;
  StringToLower(value);
  return (value == "true" || value == "1" || value == "yes");
}

bool PandoraXBoostSessionMaskConfigured()
{
  return (Pandora_XBoost_Session_Mask_File != "");
}

void PandoraXBoostResetSessionMask()
{
  ArrayResize(g_pandora_xboost_session_mask_rows, 0, 0);
  g_pandora_xboost_session_mask_loaded = false;
  g_pandora_xboost_session_mask_failed = false;
  g_pandora_xboost_session_mask_file = "";
}

bool PandoraXBoostAddSessionMaskRow(const int date_key,
                                    const bool train_allowed,
                                    const bool trade_allowed,
                                    const string status,
                                    const string reason)
{
  if(date_key <= 0)
    return false;

  int total = ArraySize(g_pandora_xboost_session_mask_rows);
  ArrayResize(g_pandora_xboost_session_mask_rows, total + 1, 256);
  g_pandora_xboost_session_mask_rows[total].date_key = date_key;
  g_pandora_xboost_session_mask_rows[total].train_allowed = train_allowed;
  g_pandora_xboost_session_mask_rows[total].trade_allowed = trade_allowed;
  g_pandora_xboost_session_mask_rows[total].status = status;
  g_pandora_xboost_session_mask_rows[total].reason = reason;
  return true;
}

void PandoraXBoostSortSessionMaskRows()
{
  int total = ArraySize(g_pandora_xboost_session_mask_rows);
  for(int i = 1; i < total; i++)
  {
    PandoraXBoostSessionMaskRow row = g_pandora_xboost_session_mask_rows[i];
    int j = i - 1;
    while(j >= 0 && g_pandora_xboost_session_mask_rows[j].date_key > row.date_key)
    {
      g_pandora_xboost_session_mask_rows[j + 1] =
        g_pandora_xboost_session_mask_rows[j];
      j--;
    }
    g_pandora_xboost_session_mask_rows[j + 1] = row;
  }
}

void PandoraXBoostSetSessionMaskLoaded(const string filename,
                                       const bool loaded,
                                       const bool failed)
{
  g_pandora_xboost_session_mask_file = filename;
  g_pandora_xboost_session_mask_loaded = loaded;
  g_pandora_xboost_session_mask_failed = failed;
}

bool PandoraXBoostFindSessionMaskRow(const int date_key,
                                     PandoraXBoostSessionMaskRow &row)
{
  int left = 0;
  int right = ArraySize(g_pandora_xboost_session_mask_rows) - 1;
  while(left <= right)
  {
    int middle = (left + right) / 2;
    int current_key = g_pandora_xboost_session_mask_rows[middle].date_key;
    if(current_key == date_key)
    {
      row = g_pandora_xboost_session_mask_rows[middle];
      return true;
    }
    if(current_key < date_key)
      left = middle + 1;
    else
      right = middle - 1;
  }
  return false;
}

bool PandoraXBoostSessionMaskAllowsDate(const datetime day_anchor,
                                        const bool broker_decision,
                                        string &reason)
{
  reason = "";
  if(!PandoraXBoostSessionMaskConfigured())
    return true;
  if(!g_pandora_xboost_session_mask_loaded ||
     g_pandora_xboost_session_mask_failed)
  {
    reason = "MASK_NOT_LOADED";
    return false;
  }

  int date_key = PandoraXBoostDateIntFromTime(day_anchor);
  if(date_key <= 0)
  {
    reason = "MASK_INVALID_DATE";
    return false;
  }

  PandoraXBoostSessionMaskRow row;
  if(!PandoraXBoostFindSessionMaskRow(date_key, row))
  {
    reason = StringFormat("MASK_MISSING_DATE_%d", date_key);
    return false;
  }

  bool allowed = broker_decision ? row.trade_allowed : row.train_allowed;
  if(allowed)
    return true;

  string status = row.status;
  if(status == "")
    status = "blocked";
  string detail = row.reason;
  if(detail == "")
    detail = broker_decision ? "trade_allowed_false" : "train_allowed_false";
  reason = StringFormat("SESSION_MASK_%d_%s_%s",
                        date_key,
                        status,
                        detail);
  return false;
}

bool PandoraXBoostSessionMaskAllowsTraining(const datetime day_anchor,
                                            string &reason)
{
  return PandoraXBoostSessionMaskAllowsDate(day_anchor, false, reason);
}

bool PandoraXBoostSessionMaskAllowsBroker(const datetime day_anchor,
                                          string &reason)
{
  return PandoraXBoostSessionMaskAllowsDate(day_anchor, true, reason);
}

void PandoraXBoostRollingStatsAdd(PandoraXBoostRollingStats &stats,
                                  const double r_multiple,
                                  const datetime seen_at)
{
  stats.samples++;
  stats.total_r += r_multiple;
  stats.sum_r2 += r_multiple * r_multiple;
  stats.avg_r = stats.total_r / stats.samples;
  if(seen_at > stats.last_seen)
    stats.last_seen = seen_at;
}

void PandoraXBoostDistributionStatsAdd(PandoraXBoostDistributionStats &stats,
                                       const double r_multiple)
{
  stats.samples++;
  stats.total_r += r_multiple;
  stats.avg_r = stats.total_r / stats.samples;

  if(r_multiple > PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R)
  {
    stats.wins++;
    stats.total_win_r += r_multiple;
  }
  else if(r_multiple < -PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R)
  {
    stats.losses++;
    stats.total_loss_r += r_multiple;
  }
  else
  {
    stats.be++;
  }
}

double PandoraXBoostMedianFromSortedValues(double &values[])
{
  int total = ArraySize(values);
  if(total <= 0)
    return 0.0;

  int middle = total / 2;
  if((total % 2) == 1)
    return values[middle];

  return (values[middle - 1] + values[middle]) * 0.5;
}

double PandoraXBoostOutlierDependencyFromSortedValues(double &values[],
                                                      const double total_win_r,
                                                      const double total_r)
{
  if(total_win_r <= 0.0 || total_r <= 0.0)
    return 0.0;

  int total = ArraySize(values);
  int selected = 0;
  double top_win_r = 0.0;
  for(int i = total - 1; i >= 0; i--)
  {
    if(values[i] <= PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R)
      continue;

    top_win_r += values[i];
    selected++;
    if(selected >= PANDORA_XBOOST_ROBUST_OUTLIER_TOP_COUNT)
      break;
  }

  if(top_win_r <= 0.0)
    return 0.0;

  double dependency = top_win_r / total_win_r;
  if(dependency < 0.0)
    dependency = 0.0;
  if(dependency > 1.0)
    dependency = 1.0;
  return dependency;
}

bool PandoraXBoostRememberSampleRow(const string sample_id,
                                    const string node_key,
                                    const double r_multiple,
                                    const datetime seen_at)
{
  if(sample_id == "" || node_key == "")
    return false;

  PandoraXBoostSampleRow row;
  row.sample_id = sample_id;
  row.node_key = node_key;
  row.r_multiple = r_multiple;
  row.seen_at = seen_at;

  int total = ArraySize(g_pandora_xboost_sample_rows);
  ArrayResize(g_pandora_xboost_sample_rows, total + 1, 128);
  g_pandora_xboost_sample_rows[total] = row;
  return true;
}

int PandoraXBoostSampleAgeDays(const datetime seen_at)
{
  if(seen_at <= 0)
    return -1;

  long age_seconds = (long)(TimeCurrent() - seen_at);
  if(age_seconds < 0)
    age_seconds = 0;

  return (int)(age_seconds / 86400);
}

string PandoraXBoostSampleFreshnessReason(const datetime seen_at)
{
  int age_days = PandoraXBoostSampleAgeDays(seen_at);
  if(age_days < 0)
    return "NO_SAMPLE";
  if(age_days > PANDORA_XBOOST_SAMPLE_FRESHNESS_MAX_DAYS)
    return "STALE";
  return "FRESH";
}

bool PandoraXBoostAggregateLastNodeSamples(const string node_key,
                                           const int sample_limit,
                                           PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  if(node_key == "" || sample_limit <= 0)
    return false;

  datetime selected_times[];
  double selected_values[];
  ArrayResize(selected_times, sample_limit);
  ArrayResize(selected_values, sample_limit);

  int selected = 0;
  int total = ArraySize(g_pandora_xboost_sample_rows);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostSampleRow row = g_pandora_xboost_sample_rows[i];
    if(row.node_key != node_key)
      continue;
    if(row.seen_at <= 0)
      continue;

    int insert_index = selected;
    if(selected < sample_limit)
    {
      selected++;
      insert_index = selected - 1;
    }
    else
    {
      insert_index = selected - 1;
      if(row.seen_at <= selected_times[insert_index])
        continue;
    }

    selected_times[insert_index] = row.seen_at;
    selected_values[insert_index] = row.r_multiple;

    while(insert_index > 0 &&
          selected_times[insert_index] > selected_times[insert_index - 1])
    {
      datetime swap_time = selected_times[insert_index - 1];
      double swap_value = selected_values[insert_index - 1];
      selected_times[insert_index - 1] = selected_times[insert_index];
      selected_values[insert_index - 1] = selected_values[insert_index];
      selected_times[insert_index] = swap_time;
      selected_values[insert_index] = swap_value;
      insert_index--;
    }
  }

  for(int i = 0; i < selected; i++)
    PandoraXBoostRollingStatsAdd(stats,
                                 selected_values[i],
                                 selected_times[i]);

  return (stats.samples > 0);
}

bool PandoraXBoostAggregateNodeSamples(const string node_key,
                                       const datetime cutoff_time,
                                       PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  if(node_key == "")
    return false;

  int total = ArraySize(g_pandora_xboost_sample_rows);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostSampleRow row = g_pandora_xboost_sample_rows[i];
    if(row.node_key != node_key)
      continue;
    if(cutoff_time > 0 && row.seen_at < cutoff_time)
      continue;

    PandoraXBoostRollingStatsAdd(stats, row.r_multiple, row.seen_at);
  }
  return (stats.samples > 0);
}

bool PandoraXBoostAggregateNodeDistribution(const string node_key,
                                            const datetime cutoff_time,
                                            PandoraXBoostDistributionStats &stats)
{
  PandoraXBoostDistributionStats reset_stats;
  stats = reset_stats;
  if(node_key == "")
    return false;

  double values[];
  int value_total = 0;
  int total = ArraySize(g_pandora_xboost_sample_rows);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostSampleRow row = g_pandora_xboost_sample_rows[i];
    if(row.node_key != node_key)
      continue;
    if(cutoff_time > 0 && row.seen_at < cutoff_time)
      continue;

    ArrayResize(values, value_total + 1, 64);
    values[value_total] = row.r_multiple;
    value_total++;
    PandoraXBoostDistributionStatsAdd(stats, row.r_multiple);
  }

  if(stats.samples <= 0)
    return false;

  if(stats.samples > 0)
  {
    stats.win_rate = (double)stats.wins / (double)stats.samples;
    stats.loss_rate = (double)stats.losses / (double)stats.samples;
    stats.be_rate = (double)stats.be / (double)stats.samples;
  }
  if(stats.wins > 0)
    stats.avg_win_r = stats.total_win_r / (double)stats.wins;
  if(stats.losses > 0)
    stats.avg_loss_r = stats.total_loss_r / (double)stats.losses;

  double loss_abs_r = MathAbs(stats.total_loss_r);
  if(loss_abs_r > 0.0)
    stats.profit_factor_r = stats.total_win_r / loss_abs_r;
  else if(stats.total_win_r > 0.0)
    stats.profit_factor_r = stats.total_win_r;

  double avg_loss_abs_r = MathAbs(stats.avg_loss_r);
  if(avg_loss_abs_r > 0.0)
    stats.payoff_ratio_r = stats.avg_win_r / avg_loss_abs_r;
  else if(stats.avg_win_r > 0.0)
    stats.payoff_ratio_r = stats.avg_win_r;

  ArraySort(values);
  stats.median_r = PandoraXBoostMedianFromSortedValues(values);
  stats.outlier_dependency_r =
    PandoraXBoostOutlierDependencyFromSortedValues(values,
                                                  stats.total_win_r,
                                                  stats.total_r);
  return true;
}

void PandoraXBoostApplyDistributionMetrics(PandoraXBoostCandidate &candidate,
                                           const PandoraXBoostDistributionStats &stats)
{
  candidate.win_rate = stats.win_rate;
  candidate.loss_rate = stats.loss_rate;
  candidate.be_rate = stats.be_rate;
  candidate.median_r = stats.median_r;
  candidate.profit_factor_r = stats.profit_factor_r;
  candidate.payoff_ratio_r = stats.payoff_ratio_r;
  candidate.outlier_dependency_r = stats.outlier_dependency_r;
}

bool PandoraXBoostCollectNodeSampleValues(const string node_key,
                                          const datetime cutoff_time,
                                          double &values[],
                                          datetime &seen_times[])
{
  ArrayResize(values, 0, 0);
  ArrayResize(seen_times, 0, 0);
  if(node_key == "")
    return false;

  int value_total = 0;
  int total = ArraySize(g_pandora_xboost_sample_rows);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostSampleRow row = g_pandora_xboost_sample_rows[i];
    if(row.node_key != node_key)
      continue;
    if(cutoff_time > 0 && row.seen_at < cutoff_time)
      continue;

    ArrayResize(values, value_total + 1, 64);
    ArrayResize(seen_times, value_total + 1, 64);
    values[value_total] = row.r_multiple;
    seen_times[value_total] = row.seen_at;
    value_total++;
  }

  return (value_total > 0);
}

void PandoraXBoostSortSampleValuesByTime(double &values[],
                                         datetime &seen_times[])
{
  int total = ArraySize(values);
  for(int i = 1; i < total; i++)
  {
    double value_key = values[i];
    datetime time_key = seen_times[i];
    int j = i - 1;
    while(j >= 0 && seen_times[j] > time_key)
    {
      values[j + 1] = values[j];
      seen_times[j + 1] = seen_times[j];
      j--;
    }
    values[j + 1] = value_key;
    seen_times[j + 1] = time_key;
  }
}

double PandoraXBoostAverageValueRange(double &values[],
                                      const int start_index,
                                      const int count)
{
  int total = ArraySize(values);
  if(total <= 0 || count <= 0 || start_index < 0 || start_index >= total)
    return 0.0;

  int end_index = start_index + count;
  if(end_index > total)
    end_index = total;

  double sum = 0.0;
  int used = 0;
  for(int i = start_index; i < end_index; i++)
  {
    sum += values[i];
    used++;
  }
  if(used <= 0)
    return 0.0;
  return sum / (double)used;
}

bool PandoraXBoostComputeForwardStability(const string node_key,
                                          const int min_segment_samples,
                                          double &stability_r,
                                          double &penalty_r)
{
  stability_r = 0.0;
  penalty_r = 0.0;
  int safe_min_samples = min_segment_samples;
  if(safe_min_samples < 1)
    safe_min_samples = 1;

  double values[];
  datetime seen_times[];
  if(!PandoraXBoostCollectNodeSampleValues(node_key, 0, values, seen_times))
    return false;

  int total = ArraySize(values);
  if(total < safe_min_samples * 2)
    return false;

  PandoraXBoostSortSampleValuesByTime(values, seen_times);
  int segment_count = (total >= safe_min_samples * 3) ? 3 : 2;
  int latest_count = total / segment_count;
  if(latest_count < safe_min_samples)
    latest_count = safe_min_samples;
  if(latest_count >= total)
    return false;

  int latest_start = total - latest_count;
  int previous_count = latest_start;
  double previous_avg = PandoraXBoostAverageValueRange(values, 0, previous_count);
  double latest_avg = PandoraXBoostAverageValueRange(values,
                                                    latest_start,
                                                    latest_count);
  stability_r = latest_avg - previous_avg;
  if(stability_r < 0.0)
  {
    penalty_r = MathAbs(stability_r) *
                PANDORA_XBOOST_ROBUST_FORWARD_PENALTY_WEIGHT;
    penalty_r = PandoraXBoostClampDouble(penalty_r,
                                         0.0,
                                         PANDORA_XBOOST_ROBUST_FORWARD_PENALTY_CAP_R);
  }
  return true;
}

bool PandoraXBoostAggregateStrategySamples(const string strategy_key,
                                           const datetime cutoff_time,
                                           PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  if(strategy_key == "")
    return false;

  int total = ArraySize(g_pandora_xboost_sample_rows);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostSampleRow row = g_pandora_xboost_sample_rows[i];
    if(!PandoraXBoostStringStartsWith(row.node_key, strategy_key))
      continue;
    if(cutoff_time > 0 && row.seen_at < cutoff_time)
      continue;

    PandoraXBoostRollingStatsAdd(stats, row.r_multiple, row.seen_at);
  }
  return (stats.samples > 0);
}

bool PandoraXBoostBrokerTradeMatchesStrategy(const PandoraXBoostBrokerTradeRow &trade_row,
                                             const string strategy_key)
{
  if(strategy_key == "")
    return false;
  return (trade_row.strategy_key == strategy_key);
}

string PandoraXBoostParentNodePath(const string node_path)
{
  int last_pos = -1;
  int search_pos = 0;
  while(true)
  {
    int pos = StringFind(node_path, ">", search_pos);
    if(pos < 0)
      break;
    last_pos = pos;
    search_pos = pos + 1;
  }

  if(last_pos <= 0)
    return "";
  return StringSubstr(node_path, 0, last_pos);
}

bool PandoraXBoostSelectedIndexExists(int &selected_indices[],
                                      const int selected_total,
                                      const int candidate_index)
{
  for(int i = 0; i < selected_total; i++)
  {
    if(selected_indices[i] == candidate_index)
      return true;
  }
  return false;
}

bool PandoraXBoostAggregateBrokerNodeTrades(const string node_key,
                                            PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  if(node_key == "")
    return false;

  int total = ArraySize(g_pandora_xboost_broker_trades);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostBrokerTradeRow trade_row = g_pandora_xboost_broker_trades[i];
    if(trade_row.node_key != node_key)
      continue;

    PandoraXBoostRollingStatsAdd(stats,
                                 trade_row.r_multiple_broker,
                                 trade_row.close_time);
  }
  return (stats.samples > 0);
}

bool PandoraXBoostAggregateBrokerPathFamilyTrades(const string strategy_key,
                                                  const string node_path,
                                                  PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  string parent_path = PandoraXBoostParentNodePath(node_path);
  if(strategy_key == "" || parent_path == "")
    return false;

  string family_prefix = parent_path + ">";
  int total = ArraySize(g_pandora_xboost_broker_trades);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostBrokerTradeRow trade_row = g_pandora_xboost_broker_trades[i];
    if(!PandoraXBoostBrokerTradeMatchesStrategy(trade_row, strategy_key))
      continue;
    if(trade_row.node_path == node_path)
      continue;
    if(!PandoraXBoostStringStartsWith(trade_row.node_path, family_prefix))
      continue;

    PandoraXBoostRollingStatsAdd(stats,
                                 trade_row.r_multiple_broker,
                                 trade_row.close_time);
  }
  return (stats.samples > 0);
}

bool PandoraXBoostAggregateBrokerRecentTrades(const string strategy_key,
                                              const int max_trades,
                                              PandoraXBoostRollingStats &stats)
{
  PandoraXBoostRollingStats reset_stats;
  stats = reset_stats;
  if(strategy_key == "" || max_trades <= 0)
    return false;

  int selected_indices[];
  int selected_total = 0;
  int total = ArraySize(g_pandora_xboost_broker_trades);
  for(int rank = 0; rank < max_trades; rank++)
  {
    int best_index = -1;
    datetime best_close_time = 0;
    for(int i = 0; i < total; i++)
    {
      if(PandoraXBoostSelectedIndexExists(selected_indices,
                                          selected_total,
                                          i))
        continue;

      PandoraXBoostBrokerTradeRow trade_row = g_pandora_xboost_broker_trades[i];
      if(!PandoraXBoostBrokerTradeMatchesStrategy(trade_row, strategy_key))
        continue;
      if(trade_row.close_time <= 0)
        continue;
      if(best_index < 0 || trade_row.close_time > best_close_time)
      {
        best_index = i;
        best_close_time = trade_row.close_time;
      }
    }

    if(best_index < 0)
      break;

    ArrayResize(selected_indices, selected_total + 1, max_trades);
    selected_indices[selected_total] = best_index;
    selected_total++;

    PandoraXBoostBrokerTradeRow selected = g_pandora_xboost_broker_trades[best_index];
    PandoraXBoostRollingStatsAdd(stats,
                                 selected.r_multiple_broker,
                                 selected.close_time);
  }
  return (stats.samples > 0);
}

int PandoraXBoostBayesPriorWeightForDepth(const int depth)
{
  if(depth <= 1)
    return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_1;
  if(depth == 2)
    return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_2;
  if(depth == 3)
    return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_3;
  if(depth == 4)
    return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_4;
  return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_5;
}

double PandoraXBoostRollingVariance(const PandoraXBoostRollingStats &stats)
{
  if(stats.samples <= 1)
    return 0.0;

  double mean_square = stats.total_r * stats.total_r / stats.samples;
  double variance = (stats.sum_r2 - mean_square) / (stats.samples - 1);
  if(variance < 0.0)
    variance = 0.0;
  return variance;
}

double PandoraXBoostStandardErrorR(const PandoraXBoostRollingStats &stats)
{
  if(stats.samples <= 1)
    return 0.0;

  double variance = PandoraXBoostRollingVariance(stats);
  if(variance <= 0.0)
    return 0.0;

  return MathSqrt(variance / stats.samples);
}

double PandoraXBoostBayesianPosteriorAverage(const int node_samples,
                                             const double node_avg_r,
                                             const double prior_avg_r,
                                             const int prior_weight)
{
  int safe_samples = node_samples;
  if(safe_samples < 0)
    safe_samples = 0;
  int safe_prior_weight = prior_weight;
  if(safe_prior_weight < 0)
    safe_prior_weight = 0;

  int denominator = safe_samples + safe_prior_weight;
  if(denominator <= 0)
    return 0.0;

  return ((safe_samples * node_avg_r) +
          (safe_prior_weight * prior_avg_r)) / denominator;
}

double PandoraXBoostClampDouble(const double value,
                                const double min_value,
                                const double max_value)
{
  if(value < min_value)
    return min_value;
  if(value > max_value)
    return max_value;
  return value;
}

double PandoraXBoostComputeFragilityPenalty(const PandoraXBoostCandidate &candidate)
{
  if(candidate.samples <= 0)
    return 0.0;

  double penalty_r = 0.0;
  if(candidate.median_r < -PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R)
  {
    penalty_r += MathAbs(candidate.median_r) *
                 PANDORA_XBOOST_ROBUST_MEDIAN_PENALTY_WEIGHT;
  }

  if(candidate.loss_rate > PANDORA_XBOOST_ROBUST_LOSS_RATE_FLOOR)
  {
    penalty_r += (candidate.loss_rate - PANDORA_XBOOST_ROBUST_LOSS_RATE_FLOOR) *
                 PANDORA_XBOOST_ROBUST_LOSS_RATE_PENALTY_WEIGHT;
  }

  if(candidate.outlier_dependency_r > PANDORA_XBOOST_ROBUST_OUTLIER_FLOOR &&
     candidate.median_r < PANDORA_XBOOST_ROBUST_BE_TOLERANCE_R)
  {
    penalty_r += (candidate.outlier_dependency_r - PANDORA_XBOOST_ROBUST_OUTLIER_FLOOR) *
                 PANDORA_XBOOST_ROBUST_OUTLIER_PENALTY_WEIGHT;
  }

  return PandoraXBoostClampDouble(penalty_r,
                                  0.0,
                                  PANDORA_XBOOST_ROBUST_FRAGILITY_CAP_R);
}

double PandoraXBoostComputeTrailingPayoffCredit(const PandoraXBoostCandidate &candidate)
{
  if(candidate.samples <= 0 || candidate.expectancy_r <= 0.0)
    return 0.0;
  if(candidate.payoff_ratio_r < PANDORA_XBOOST_ROBUST_PAYOFF_MIN_RATIO)
    return 0.0;
  if(candidate.profit_factor_r < PANDORA_XBOOST_ROBUST_PAYOFF_MIN_PROFIT_FACTOR)
    return 0.0;

  double payoff_credit =
    (candidate.payoff_ratio_r - PANDORA_XBOOST_ROBUST_PAYOFF_MIN_RATIO) * 0.01;
  double factor_credit =
    (candidate.profit_factor_r - PANDORA_XBOOST_ROBUST_PAYOFF_MIN_PROFIT_FACTOR) * 0.02;
  double credit_r = payoff_credit + factor_credit;

  if(candidate.outlier_dependency_r > PANDORA_XBOOST_ROBUST_OUTLIER_FLOOR)
  {
    double outlier_discount = 1.0 -
      ((candidate.outlier_dependency_r - PANDORA_XBOOST_ROBUST_OUTLIER_FLOOR) * 0.50);
    outlier_discount = PandoraXBoostClampDouble(outlier_discount, 0.50, 1.0);
    credit_r *= outlier_discount;
  }

  return PandoraXBoostClampDouble(credit_r,
                                  0.0,
                                  PANDORA_XBOOST_ROBUST_PAYOFF_CREDIT_CAP_R);
}

bool PandoraXBoostResolveWindowBlend(const int fast_samples,
                                     const double fast_avg_r,
                                     const int slow_samples,
                                     const double slow_avg_r,
                                     const int min_samples,
                                     double &blend_r)
{
  bool has_fast = (fast_samples >= min_samples);
  bool has_slow = (slow_samples >= min_samples);
  if(has_fast && has_slow)
  {
    blend_r = (fast_avg_r * 0.60) + (slow_avg_r * 0.40);
    return true;
  }
  if(has_fast)
  {
    blend_r = fast_avg_r;
    return true;
  }
  if(has_slow)
  {
    blend_r = slow_avg_r;
    return true;
  }
  blend_r = 0.0;
  return false;
}

void PandoraXBoostApplyV5ShadowScore(PandoraXBoostCandidate &candidate,
                                     const int min_samples)
{
  double calendar_recent = 0.0;
  bool has_calendar =
    PandoraXBoostResolveWindowBlend(candidate.local_window_60_samples,
                                    candidate.local_window_60_avg_r,
                                    candidate.local_window_120_samples,
                                    candidate.local_window_120_avg_r,
                                    min_samples,
                                    calendar_recent);

  double sample_recent = 0.0;
  bool has_sample =
    PandoraXBoostResolveWindowBlend(candidate.sample_window_60_samples,
                                    candidate.sample_window_60_avg_r,
                                    candidate.sample_window_120_samples,
                                    candidate.sample_window_120_avg_r,
                                    min_samples,
                                    sample_recent);

  candidate.calendar_recent_r = has_calendar ? calendar_recent : 0.0;
  candidate.sample_recent_r = has_sample ? sample_recent : 0.0;
  if(has_calendar && has_sample)
  {
    candidate.adaptive_recent_r =
      (calendar_recent * PANDORA_XBOOST_V5_CALENDAR_RECENT_WEIGHT) +
      (sample_recent * PANDORA_XBOOST_V5_SAMPLE_RECENT_WEIGHT);
  }
  else if(has_calendar)
    candidate.adaptive_recent_r = calendar_recent;
  else if(has_sample)
    candidate.adaptive_recent_r = sample_recent;
  else
    candidate.adaptive_recent_r = candidate.posterior_r;

  candidate.hybrid_shrinkage_r =
    candidate.posterior_r * PANDORA_XBOOST_V5_SHRINKAGE_WEIGHT;
  candidate.soft_fragility_r =
    candidate.fragility_penalty_r * PANDORA_XBOOST_V5_FRAGILITY_WEIGHT;
  candidate.soft_broker_r =
    candidate.broker_degradation_r * PANDORA_XBOOST_V5_BROKER_WEIGHT;
  candidate.v5_score_r = candidate.adaptive_recent_r +
                         candidate.hybrid_shrinkage_r +
                         candidate.trailing_payoff_credit_r -
                         candidate.soft_fragility_r -
                         (candidate.forward_penalty_r * PANDORA_XBOOST_V5_FORWARD_WEIGHT) -
                         candidate.soft_broker_r -
                         candidate.depth_penalty_r;
  if(candidate.sample_window_freshness_reason == "STALE")
    candidate.v5_score_r -= PANDORA_XBOOST_SAMPLE_FRESHNESS_PENALTY_R;
}

bool PandoraXBoostV5RecentWeaknessBlocks(const PandoraXBoostCandidate &candidate,
                                         const int min_samples,
                                         string &reason)
{
  reason = "";
  double floor_r = -PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R;
  double calendar_recent = 0.0;
  bool has_calendar =
    PandoraXBoostResolveWindowBlend(candidate.local_window_60_samples,
                                    candidate.local_window_60_avg_r,
                                    candidate.local_window_120_samples,
                                    candidate.local_window_120_avg_r,
                                    min_samples,
                                    calendar_recent);
  double sample_recent = 0.0;
  bool has_sample =
    PandoraXBoostResolveWindowBlend(candidate.sample_window_60_samples,
                                    candidate.sample_window_60_avg_r,
                                    candidate.sample_window_120_samples,
                                    candidate.sample_window_120_avg_r,
                                    min_samples,
                                    sample_recent);

  if(has_calendar && has_sample &&
     calendar_recent < floor_r &&
     sample_recent < floor_r)
  {
    reason = "V5_RECENT";
    return true;
  }
  return false;
}

void PandoraXBoostApplyV5AdmissionScore(PandoraXBoostCandidate &candidate)
{
  candidate.score_r = candidate.v5_score_r;
}

void PandoraXBoostApplyRobustCandidateScore(PandoraXBoostCandidate &candidate)
{
  candidate.fragility_penalty_r =
    PandoraXBoostComputeFragilityPenalty(candidate);
  candidate.trailing_payoff_credit_r =
    PandoraXBoostComputeTrailingPayoffCredit(candidate);
  candidate.robust_score_r = candidate.conservative_score_r +
                             candidate.trailing_payoff_credit_r -
                             candidate.fragility_penalty_r -
                             candidate.forward_penalty_r -
                             candidate.broker_node_degradation_r;
  candidate.score_r = candidate.robust_score_r;
}

bool PandoraXBoostIsDerivedNode(const SignalParams &signal_params)
{
  return (signal_params.pandora_xboost_enabled &&
          signal_params.pandora_xboost_depth > 1);
}

bool PandoraXBoostShouldSkipPandoraDailyOutcome(const SignalParams &signal_params)
{
  return PandoraXBoostIsDerivedNode(signal_params);
}

bool PandoraXBoostShouldSkipDailySignalOutcome(const SignalParams &signal_params)
{
  return (PandoraXBoostIsDerivedNode(signal_params) &&
          !signal_params.pandora_xboost_broker_selected);
}

bool PandoraXBoostBrokerDailyLimitAllows(const SignalParams &signal_params)
{
  if(!PandoraXBoostIsDerivedNode(signal_params))
    return true;
  return DailySignalLimitAllowsAttempt(signal_params.signal_type);
}

void PandoraXBoostRegisterBrokerDailyStart(const SignalParams &signal_params)
{
  if(!PandoraXBoostIsDerivedNode(signal_params))
    return;
  RegisterDailySignalStart(signal_params);
}

int PandoraXBoostMinSamplesForDepth(const int depth)
{
  if(depth <= 1)
    return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_1;
  if(depth == 2)
    return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_2;
  if(depth == 3)
    return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3;
  if(depth == 4)
    return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_4;
  return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_5;
}

int PandoraXBoostFindStatsIndexByNodeKey(const string node_key)
{
  if(node_key == "")
    return -1;

  ulong key_hash = PandoraXBoostHashKey(node_key);
  int cached_total = ArraySize(g_pandora_xboost_stats);
  if(g_pandora_xboost_lookup_cache_index >= 0 &&
     g_pandora_xboost_lookup_cache_index < cached_total &&
     g_pandora_xboost_lookup_cache_hash == key_hash &&
     g_pandora_xboost_lookup_cache_key == node_key &&
     g_pandora_xboost_stats[g_pandora_xboost_lookup_cache_index].node_key == node_key)
  {
    return g_pandora_xboost_lookup_cache_index;
  }

  int total = ArraySize(g_pandora_xboost_stats);
  for(int i = 0; i < total; i++)
  {
    if(g_pandora_xboost_stats[i].key_hash == key_hash &&
       g_pandora_xboost_stats[i].node_key == node_key)
    {
      g_pandora_xboost_lookup_cache_key = node_key;
      g_pandora_xboost_lookup_cache_hash = key_hash;
      g_pandora_xboost_lookup_cache_index = i;
      return i;
    }
  }
  return -1;
}

bool PandoraXBoostLookupStats(const string node_key,
                              PandoraXBoostStats &stats)
{
  int stats_index = PandoraXBoostFindStatsIndexByNodeKey(node_key);
  if(stats_index < 0)
    return false;

  stats = g_pandora_xboost_stats[stats_index];
  return true;
}

int PandoraXBoostEnsureStatsIndex(const string node_key)
{
  int existing = PandoraXBoostFindStatsIndexByNodeKey(node_key);
  if(existing >= 0)
    return existing;

  PandoraXBoostStats stats;
  stats.node_key = node_key;
  stats.key_hash = PandoraXBoostHashKey(node_key);

  int total = ArraySize(g_pandora_xboost_stats);
  ArrayResize(g_pandora_xboost_stats, total + 1, 128);
  g_pandora_xboost_stats[total] = stats;
  return total;
}

void PandoraXBoostUpdateStats(const string node_key,
                              const double r_multiple,
                              const datetime seen_at)
{
  int stats_index = PandoraXBoostEnsureStatsIndex(node_key);
  if(stats_index < 0)
    return;

  PandoraXBoostStats stats = g_pandora_xboost_stats[stats_index];
  double win_sum = stats.avg_win_r * stats.wins;
  double loss_sum = stats.avg_loss_r * stats.losses;

  stats.samples++;
  stats.total_r += r_multiple;
  stats.avg_r = (stats.samples > 0) ? stats.total_r / stats.samples : 0.0;

  if(r_multiple > 0.0)
  {
    stats.wins++;
    win_sum += r_multiple;
    stats.avg_win_r = win_sum / stats.wins;
    if(stats.wins == 1 || r_multiple > stats.max_win_r)
      stats.max_win_r = r_multiple;
  }
  else if(r_multiple < 0.0)
  {
    stats.losses++;
    loss_sum += r_multiple;
    stats.avg_loss_r = loss_sum / stats.losses;
    if(stats.losses == 1 || r_multiple < stats.max_loss_r)
      stats.max_loss_r = r_multiple;
    if(r_multiple < stats.max_drawdown_r)
      stats.max_drawdown_r = r_multiple;
  }
  else
  {
    stats.be++;
  }

  stats.expectancy_r = stats.avg_r;
  stats.last_seen = seen_at;
  g_pandora_xboost_stats[stats_index] = stats;
  g_pandora_xboost_storage_dirty = true;
}

int PandoraXBoostCandidateStatusRank(const PandoraXBoostCandidateStatuses status)
{
  switch(status)
  {
    case PANDORA_XBOOST_CANDIDATE_READY:
      return 4;
    case PANDORA_XBOOST_CANDIDATE_WATCH:
      return 3;
    case PANDORA_XBOOST_CANDIDATE_WAIT:
      return 2;
    case PANDORA_XBOOST_CANDIDATE_BLOCK:
      return 1;
    case PANDORA_XBOOST_CANDIDATE_NONE:
    default:
      return 0;
  }
}

bool PandoraXBoostCandidateIsBetter(const PandoraXBoostCandidate &left,
                                    const PandoraXBoostCandidate &right)
{
  int left_rank = PandoraXBoostCandidateStatusRank(left.status);
  int right_rank = PandoraXBoostCandidateStatusRank(right.status);
  if(left_rank != right_rank)
    return (left_rank > right_rank);
  if(left.score_r != right.score_r)
    return (left.score_r > right.score_r);
  return (left.expectancy_r > right.expectancy_r);
}

void PandoraXBoostSortTopCandidates()
{
  int total = ArraySize(g_pandora_xboost_top_candidates);
  for(int i = 0; i < total - 1; i++)
  {
    for(int j = i + 1; j < total; j++)
    {
      if(PandoraXBoostCandidateIsBetter(g_pandora_xboost_top_candidates[j],
                                        g_pandora_xboost_top_candidates[i]))
      {
        PandoraXBoostCandidate tmp = g_pandora_xboost_top_candidates[i];
        g_pandora_xboost_top_candidates[i] = g_pandora_xboost_top_candidates[j];
        g_pandora_xboost_top_candidates[j] = tmp;
      }
    }
  }
}

void PandoraXBoostAddTopCandidate(const PandoraXBoostCandidate &candidate)
{
  if(candidate.status == PANDORA_XBOOST_CANDIDATE_NONE)
    return;

  int total = ArraySize(g_pandora_xboost_top_candidates);
  if(total < PANDORA_XBOOST_TOP_CANDIDATE_LIMIT)
  {
    ArrayResize(g_pandora_xboost_top_candidates, total + 1, PANDORA_XBOOST_TOP_CANDIDATE_LIMIT);
    g_pandora_xboost_top_candidates[total] = candidate;
  }
  else if(PandoraXBoostCandidateIsBetter(candidate,
                                         g_pandora_xboost_top_candidates[total - 1]))
  {
    g_pandora_xboost_top_candidates[total - 1] = candidate;
  }

  PandoraXBoostSortTopCandidates();
}

string PandoraXBoostBuildCandidatePath(const string parent_node_path,
                                       const SignalTypes candidate_side,
                                       const PandoraXBoostCloseEvents parent_event)
{
  string display_id = PandoraXBoostBuildDisplayId(candidate_side, parent_event);
  if(parent_node_path == "")
    return display_id;
  return parent_node_path + ">" + display_id;
}

bool PandoraXBoostCandidateHasMinimumStats(const PandoraXBoostCandidate &candidate)
{
  int min_samples = PandoraXBoostMinSamplesForDepth(candidate.depth);
  return (candidate.status != PANDORA_XBOOST_CANDIDATE_BLOCK &&
          candidate.samples >= min_samples &&
          candidate.score_r >= PANDORA_XBOOST_ROBUST_MIN_SCORE_R);
}

bool PandoraXBoostRollingWindowBlocks(const PandoraXBoostCandidate &candidate,
                                      const int min_samples,
                                      string &reason)
{
  double floor_r = -PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R;
  if(candidate.local_window_60_samples >= min_samples &&
     candidate.local_window_60_avg_r < floor_r)
  {
    reason = "ROLLING_60";
    return true;
  }
  if(candidate.local_window_120_samples >= min_samples &&
     candidate.local_window_120_avg_r < floor_r)
  {
    reason = "ROLLING_120";
    return true;
  }
  return false;
}

bool PandoraXBoostSampleWindowBlocks(const PandoraXBoostCandidate &candidate,
                                     const int min_samples,
                                     string &reason)
{
  double floor_r = -PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R;
  if(candidate.sample_window_60_samples >= min_samples &&
     candidate.sample_window_60_avg_r < floor_r)
  {
    reason = "SAMPLE_60";
    return true;
  }
  if(candidate.sample_window_120_samples >= min_samples &&
     candidate.sample_window_120_avg_r < floor_r)
  {
    reason = "SAMPLE_120";
    return true;
  }
  return false;
}

void PandoraXBoostApplySampleFreshnessPenalty(PandoraXBoostCandidate &candidate)
{
  if(candidate.sample_window_last_seen <= 0)
    return;
  if(candidate.sample_window_age_days <= PANDORA_XBOOST_SAMPLE_FRESHNESS_MAX_DAYS)
    return;

  candidate.sample_window_freshness_reason = "STALE";
  candidate.score_r -= PANDORA_XBOOST_SAMPLE_FRESHNESS_PENALTY_R;
  candidate.robust_score_r = candidate.score_r;
}

void PandoraXBoostApplyBrokerCalibration(PandoraXBoostCandidate &candidate,
                                         const string strategy_key)
{
  PandoraXBoostRollingStats broker_node;
  if(PandoraXBoostAggregateBrokerNodeTrades(candidate.node_key, broker_node))
  {
    candidate.broker_node_samples = broker_node.samples;
    candidate.broker_node_avg_r = broker_node.avg_r;
  }

  PandoraXBoostRollingStats broker_path;
  if(PandoraXBoostAggregateBrokerPathFamilyTrades(strategy_key,
                                                  candidate.node_path,
                                                  broker_path))
  {
    candidate.broker_path_samples = broker_path.samples;
    candidate.broker_path_avg_r = broker_path.avg_r;
  }

  PandoraXBoostRollingStats broker_recent;
  if(PandoraXBoostAggregateBrokerRecentTrades(strategy_key,
                                              PANDORA_XBOOST_BROKER_RECENT_TRADES,
                                              broker_recent))
  {
    candidate.broker_recent_samples = broker_recent.samples;
    candidate.broker_recent_avg_r = broker_recent.avg_r;
  }

  double degradation_r = 0.0;
  string degradation_reason = "";
  if(candidate.broker_node_samples >= PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES)
  {
    if(candidate.broker_node_avg_r < candidate.score_r)
    {
      degradation_r += (candidate.score_r - candidate.broker_node_avg_r) *
                       PANDORA_XBOOST_ROBUST_BROKER_NODE_WEIGHT;
      degradation_reason = "BROKER_NODE";
    }
  }
  if(candidate.broker_path_samples >= PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES)
  {
    if(candidate.broker_path_avg_r < candidate.score_r)
    {
      degradation_r += (candidate.score_r - candidate.broker_path_avg_r) *
                       PANDORA_XBOOST_ROBUST_BROKER_PATH_WEIGHT;
      if(degradation_reason == "")
        degradation_reason = "BROKER_PATH";
    }
  }

  if(degradation_r <= 0.0)
    return;

  degradation_r = PandoraXBoostClampDouble(degradation_r,
                                           0.0,
                                           PANDORA_XBOOST_ROBUST_BROKER_DEGRADATION_CAP_R);
  candidate.broker_node_degradation_r = degradation_r;
  candidate.broker_degradation_r = degradation_r;
  candidate.score_r -= degradation_r;
  candidate.robust_score_r = candidate.score_r;
  if(candidate.score_r < PANDORA_XBOOST_ROBUST_MIN_SCORE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = (degradation_reason == "") ? "BROKER_DEGRADE"
                                                  : degradation_reason;
  }
}

void PandoraXBoostBuildCandidate(const string strategy_key,
                                 const SignalTypes root_side,
                                 const PandoraXBoostCloseEvents parent_event,
                                 const int depth,
                                 const SignalTypes candidate_side,
                                 const string parent_node_path,
                                 PandoraXBoostCandidate &candidate)
{
  int safe_depth = depth;
  if(safe_depth < 1)
    safe_depth = 1;

  string node_path = PandoraXBoostBuildCandidatePath(parent_node_path,
                                                    candidate_side,
                                                    parent_event);
  string node_key = PandoraXBoostBuildNodeKey(strategy_key,
                                              root_side,
                                              parent_event,
                                              safe_depth,
                                              candidate_side,
                                              0,
                                              node_path);

  candidate.candidate_side = candidate_side;
  candidate.status         = PANDORA_XBOOST_CANDIDATE_WAIT;
  candidate.parent_event   = parent_event;
  candidate.key_hash       = PandoraXBoostHashKey(node_key);
  candidate.node_key       = node_key;
  candidate.node_path      = node_path;
  candidate.display_id     = PandoraXBoostBuildDisplayId(candidate_side, parent_event);
  candidate.reason         = "NO_STATS";
  candidate.depth          = safe_depth;
  candidate.samples        = 0;
  candidate.expectancy_r   = 0.0;
  candidate.edge_r         = 0.0;
  candidate.score_r        = 0.0;
  candidate.posterior_r    = 0.0;
  candidate.conservative_score_r = 0.0;
  candidate.uncertainty_penalty_r = 0.0;
  candidate.depth_penalty_r = 0.0;
  candidate.broker_degradation_r = 0.0;
  candidate.robust_score_r = 0.0;
  candidate.win_rate = 0.0;
  candidate.loss_rate = 0.0;
  candidate.be_rate = 0.0;
  candidate.median_r = 0.0;
  candidate.profit_factor_r = 0.0;
  candidate.payoff_ratio_r = 0.0;
  candidate.outlier_dependency_r = 0.0;
  candidate.fragility_penalty_r = 0.0;
  candidate.trailing_payoff_credit_r = 0.0;
  candidate.forward_stability_r = 0.0;
  candidate.forward_penalty_r = 0.0;
  candidate.broker_node_degradation_r = 0.0;
  candidate.local_window_120_samples = 0;
  candidate.local_window_60_samples = 0;
  candidate.sample_window_120_samples = 0;
  candidate.sample_window_60_samples = 0;
  candidate.broker_node_samples = 0;
  candidate.broker_path_samples = 0;
  candidate.broker_recent_samples = 0;
  candidate.local_window_120_avg_r = 0.0;
  candidate.local_window_60_avg_r = 0.0;
  candidate.sample_window_120_avg_r = 0.0;
  candidate.sample_window_60_avg_r = 0.0;
  candidate.sample_window_last_seen = 0;
  candidate.sample_window_age_days = -1;
  candidate.sample_window_freshness_reason = "NO_SAMPLE";
  candidate.broker_node_avg_r = 0.0;
  candidate.broker_path_avg_r = 0.0;
  candidate.broker_recent_avg_r = 0.0;
  candidate.adaptive_recent_r = 0.0;
  candidate.calendar_recent_r = 0.0;
  candidate.sample_recent_r = 0.0;
  candidate.hybrid_shrinkage_r = 0.0;
  candidate.soft_fragility_r = 0.0;
  candidate.soft_broker_r = 0.0;
  candidate.v5_score_r = 0.0;

  PandoraXBoostRollingStats window_120;
  if(PandoraXBoostAggregateNodeSamples(node_key,
                                       PandoraXBoostRollingCutoffDays(PANDORA_XBOOST_ROLLING_DAYS_120),
                                       window_120))
  {
    candidate.local_window_120_samples = window_120.samples;
    candidate.local_window_120_avg_r = window_120.avg_r;
  }

  PandoraXBoostRollingStats window_60;
  if(PandoraXBoostAggregateNodeSamples(node_key,
                                       PandoraXBoostRollingCutoffDays(PANDORA_XBOOST_ROLLING_DAYS_60),
                                       window_60))
  {
    candidate.local_window_60_samples = window_60.samples;
    candidate.local_window_60_avg_r = window_60.avg_r;
  }

  PandoraXBoostRollingStats sample_window_120;
  if(PandoraXBoostAggregateLastNodeSamples(node_key,
                                           PANDORA_XBOOST_SAMPLE_WINDOW_120,
                                           sample_window_120))
  {
    candidate.sample_window_120_samples = sample_window_120.samples;
    candidate.sample_window_120_avg_r = sample_window_120.avg_r;
    candidate.sample_window_last_seen = sample_window_120.last_seen;
    candidate.sample_window_age_days =
      PandoraXBoostSampleAgeDays(sample_window_120.last_seen);
    candidate.sample_window_freshness_reason =
      PandoraXBoostSampleFreshnessReason(sample_window_120.last_seen);
  }

  PandoraXBoostRollingStats sample_window_60;
  if(PandoraXBoostAggregateLastNodeSamples(node_key,
                                           PANDORA_XBOOST_SAMPLE_WINDOW_60,
                                           sample_window_60))
  {
    candidate.sample_window_60_samples = sample_window_60.samples;
    candidate.sample_window_60_avg_r = sample_window_60.avg_r;
    if(sample_window_60.last_seen > candidate.sample_window_last_seen)
    {
      candidate.sample_window_last_seen = sample_window_60.last_seen;
      candidate.sample_window_age_days =
        PandoraXBoostSampleAgeDays(sample_window_60.last_seen);
      candidate.sample_window_freshness_reason =
        PandoraXBoostSampleFreshnessReason(sample_window_60.last_seen);
    }
  }

  PandoraXBoostStats stats;
  if(!PandoraXBoostLookupStats(node_key, stats))
    return;

  candidate.samples      = stats.samples;
  candidate.expectancy_r = stats.expectancy_r;
  int min_samples = PandoraXBoostMinSamplesForDepth(safe_depth);

  PandoraXBoostDistributionStats distribution_stats;
  if(PandoraXBoostAggregateNodeDistribution(node_key, 0, distribution_stats))
    PandoraXBoostApplyDistributionMetrics(candidate, distribution_stats);

  PandoraXBoostRollingStats node_all;
  bool has_node_all = PandoraXBoostAggregateNodeSamples(node_key, 0, node_all);
  int bayes_samples = has_node_all ? node_all.samples : stats.samples;
  double node_avg_r = has_node_all ? node_all.avg_r : stats.expectancy_r;

  PandoraXBoostRollingStats strategy_all;
  double prior_avg_r = 0.0;
  if(PandoraXBoostAggregateStrategySamples(strategy_key, 0, strategy_all))
    prior_avg_r = strategy_all.avg_r;

  int prior_weight = PandoraXBoostBayesPriorWeightForDepth(safe_depth);
  double posterior_r =
    PandoraXBoostBayesianPosteriorAverage(bayes_samples,
                                          node_avg_r,
                                          prior_avg_r,
                                          prior_weight);
  double standard_error_r = has_node_all
                            ? PandoraXBoostStandardErrorR(node_all)
                            : 0.0;
  double uncertainty_penalty_r = 0.0;
  if(standard_error_r > 0.0)
    uncertainty_penalty_r = PANDORA_XBOOST_BAYES_UNCERTAINTY_Z * standard_error_r;
  else if(bayes_samples <= 1)
    uncertainty_penalty_r = PANDORA_XBOOST_BAYES_UNCERTAINTY_FLOOR_R;

  double depth_penalty_r = (safe_depth - 1) * PANDORA_XBOOST_DEPTH_PENALTY_R;
  double conservative_score_r = posterior_r -
                                uncertainty_penalty_r -
                                depth_penalty_r;

  candidate.posterior_r = posterior_r;
  candidate.uncertainty_penalty_r = uncertainty_penalty_r;
  candidate.depth_penalty_r = depth_penalty_r;
  candidate.conservative_score_r = conservative_score_r;
  candidate.score_r = conservative_score_r;
  PandoraXBoostComputeForwardStability(node_key,
                                       min_samples,
                                       candidate.forward_stability_r,
                                       candidate.forward_penalty_r);
  PandoraXBoostApplyRobustCandidateScore(candidate);
  PandoraXBoostApplySampleFreshnessPenalty(candidate);
  PandoraXBoostApplyV5ShadowScore(candidate, min_samples);

  if(stats.samples < min_samples)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_WAIT;
    candidate.reason = StringFormat("SAMPLES_%d_%d", stats.samples, min_samples);
    return;
  }

  string recent_weakness_reason = "";
  if(PandoraXBoostV5RecentWeaknessBlocks(candidate,
                                         min_samples,
                                         recent_weakness_reason))
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = recent_weakness_reason;
    return;
  }

  PandoraXBoostApplyV5AdmissionScore(candidate);
  if(candidate.score_r < PANDORA_XBOOST_ROBUST_MIN_SCORE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = (candidate.sample_window_freshness_reason == "STALE")
                       ? "STALE_SAMPLE"
                       : "V5_SCORE";
    return;
  }

  PandoraXBoostApplyBrokerCalibration(candidate, strategy_key);
  PandoraXBoostApplyV5ShadowScore(candidate, min_samples);
  if(candidate.status == PANDORA_XBOOST_CANDIDATE_BLOCK)
    return;

  PandoraXBoostApplyV5AdmissionScore(candidate);
  if(candidate.score_r < PANDORA_XBOOST_ROBUST_MIN_SCORE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = (candidate.sample_window_freshness_reason == "STALE")
                       ? "STALE_SAMPLE"
                       : "V5_SCORE";
    return;
  }

  candidate.status = PANDORA_XBOOST_CANDIDATE_WATCH;
  candidate.reason = "EDGE";
}

void PandoraXBoostApplyCandidateEdge(PandoraXBoostCandidate &candidate,
                                     const PandoraXBoostCandidate &alternative,
                                     const bool has_alternative)
{
  if(candidate.status == PANDORA_XBOOST_CANDIDATE_BLOCK)
    return;
  if(!PandoraXBoostCandidateHasMinimumStats(candidate))
    return;

  double alternative_expectancy = 0.0;
  bool alternative_ready_stats = false;
  if(has_alternative)
  {
    alternative_expectancy = alternative.score_r;
    alternative_ready_stats = PandoraXBoostCandidateHasMinimumStats(alternative);
  }

  candidate.edge_r = candidate.score_r - alternative_expectancy;
  if(candidate.edge_r < PANDORA_XBOOST_MIN_EDGE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_WATCH;
    candidate.reason = "EDGE";
    return;
  }

  if(alternative_ready_stats && candidate.score_r <= alternative.score_r)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_WATCH;
    candidate.reason = "ALT_SCORE";
    return;
  }

  candidate.status = PANDORA_XBOOST_CANDIDATE_READY;
  candidate.reason = "READY";
}

void PandoraXBoostLogTopCandidates()
{
  if(!Enable_Logs && !Enable_File_Logs)
    return;

  int total = ArraySize(g_pandora_xboost_top_candidates);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostCandidate candidate = g_pandora_xboost_top_candidates[i];
    string message = StringFormat("rank=%d depth=%d id=%s status=%s samples=%d exp=%.3f post=%.3f score=%.3f edge=%.3f med=%.3f wr=%.3f pf=%.3f payoff=%.3f frag=%.3f credit=%.3f fwd=%.3f bd=%.3f v5=%.3f ar=%.3f cr=%.3f sr=%.3f shr=%.3f sfrag=%.3f sbr=%.3f w120_days=%d/%.3f w60_days=%d/%.3f s120=%d/%.3f s60=%d/%.3f age=%d/%s brnode=%d/%.3f brpath=%d/%.3f br30=%d/%.3f reason=%s model=%s",
                                  i + 1,
                                  candidate.depth,
                                  candidate.display_id,
                                  PandoraXBoostCandidateStatusLabel(candidate.status),
                                  candidate.samples,
                                  candidate.expectancy_r,
                                  candidate.posterior_r,
                                  candidate.score_r,
                                  candidate.edge_r,
                                  candidate.median_r,
                                  candidate.win_rate,
                                  candidate.profit_factor_r,
                                  candidate.payoff_ratio_r,
                                  candidate.fragility_penalty_r,
                                  candidate.trailing_payoff_credit_r,
                                  candidate.forward_stability_r,
                                  candidate.broker_degradation_r,
                                  candidate.v5_score_r,
                                  candidate.adaptive_recent_r,
                                  candidate.calendar_recent_r,
                                  candidate.sample_recent_r,
                                  candidate.hybrid_shrinkage_r,
                                  candidate.soft_fragility_r,
                                  candidate.soft_broker_r,
                                  candidate.local_window_120_samples,
                                  candidate.local_window_120_avg_r,
                                  candidate.local_window_60_samples,
                                  candidate.local_window_60_avg_r,
                                  candidate.sample_window_120_samples,
                                  candidate.sample_window_120_avg_r,
                                  candidate.sample_window_60_samples,
                                  candidate.sample_window_60_avg_r,
                                  candidate.sample_window_age_days,
                                  candidate.sample_window_freshness_reason,
                                  candidate.broker_node_samples,
                                  candidate.broker_node_avg_r,
                                  candidate.broker_path_samples,
                                  candidate.broker_path_avg_r,
                                  candidate.broker_recent_samples,
                                  candidate.broker_recent_avg_r,
                                  candidate.reason,
                                  candidate.node_key);
    if(Enable_Logs)
      Print("PANDORA_XBOOST_DRYRUN ", message);
    PandoraXBoostLogEvent("PANDORA_XBOOST_DRYRUN", message);
  }
}

void PandoraXBoostBuildCandidateSet(const string strategy_key,
                                    const SignalTypes root_side,
                                    const PandoraXBoostCloseEvents parent_event,
                                    const int depth,
                                    const string parent_node_path,
                                    const bool include_both_sides,
                                    const SignalTypes single_side)
{
  PandoraXBoostClearTopCandidates();
  if(!PandoraXBoostEnabled())
    return;

  PandoraXBoostCandidate bullish_candidate;
  PandoraXBoostCandidate bearish_candidate;
  bool has_bullish = false;
  bool has_bearish = false;

  if(include_both_sides || single_side == BULLISH)
  {
    PandoraXBoostBuildCandidate(strategy_key,
                                root_side,
                                parent_event,
                                depth,
                                BULLISH,
                                parent_node_path,
                                bullish_candidate);
    has_bullish = true;
  }

  if(include_both_sides || single_side == BEARISH)
  {
    PandoraXBoostBuildCandidate(strategy_key,
                                root_side,
                                parent_event,
                                depth,
                                BEARISH,
                                parent_node_path,
                                bearish_candidate);
    has_bearish = true;
  }

  if(has_bullish)
    PandoraXBoostApplyCandidateEdge(bullish_candidate, bearish_candidate, has_bearish);
  if(has_bearish)
    PandoraXBoostApplyCandidateEdge(bearish_candidate, bullish_candidate, has_bullish);

  if(has_bullish)
    PandoraXBoostAddTopCandidate(bullish_candidate);
  if(has_bearish)
    PandoraXBoostAddTopCandidate(bearish_candidate);

  PandoraXBoostLogTopCandidates();
}

void PandoraXBoostBuildRootCandidates(const SignalParams &root_signal)
{
  if(!PandoraXBoostEnabled())
  {
    PandoraXBoostClearTopCandidates();
    return;
  }
  if(!root_signal.pandora_xboost_enabled)
    return;

  PandoraXBoostBuildCandidateSet(root_signal.pandora_xboost_strategy_key,
                                 root_signal.pandora_xboost_root_side,
                                 root_signal.pandora_xboost_parent_event,
                                 root_signal.pandora_xboost_depth,
                                 "",
                                 false,
                                 root_signal.signal_type);
}

void PandoraXBoostBuildNextCandidatesFromClosedSignal(const SignalParams &closed_signal,
                                                      const PandoraXBoostCloseEvents close_event,
                                                      const int next_depth)
{
  if(!PandoraXBoostEnabled())
  {
    PandoraXBoostClearTopCandidates();
    return;
  }
  if(!closed_signal.pandora_xboost_enabled)
    return;

  string strategy_key = closed_signal.pandora_xboost_strategy_key;
  if(strategy_key == "")
    strategy_key = PandoraXBoostBuildStrategyKey();

  SignalTypes root_side = closed_signal.pandora_xboost_root_side;
  if(root_side == NO_SIGNAL)
    root_side = closed_signal.signal_type;

  PandoraXBoostBuildCandidateSet(strategy_key,
                                 root_side,
                                 close_event,
                                 next_depth,
                                 closed_signal.pandora_xboost_node_path,
                                 true,
                                 NO_SIGNAL);
}

void PandoraXBoostForceLocalOnly(SignalParams &signal_params)
{
  signal_params.pandora_xboost_local_only = true;
  signal_params.pandora_xboost_broker_selected = false;
  signal_params.pandora_xboost_broker_trade_index = 0;
  signal_params.pandora_xboost_broker_trade_id = "";
  signal_params.pandora_xboost_selected_rank = 0;
  signal_params.pandora_xboost_model_samples = 0;
  signal_params.pandora_xboost_broker_node_samples = 0;
  signal_params.pandora_xboost_model_score_r = 0.0;
  signal_params.pandora_xboost_model_posterior_r = 0.0;
  signal_params.pandora_xboost_model_conservative_r = 0.0;
  signal_params.pandora_first_entry_target_depth = PANDORA_FIRST_ENTRY_OFF_DEPTH;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
}

bool PandoraXBoostFindReadyCandidateForSignal(const SignalParams &signal_params,
                                              PandoraXBoostCandidate &candidate,
                                              int &rank)
{
  rank = 0;
  int total = ArraySize(g_pandora_xboost_top_candidates);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostCandidate current = g_pandora_xboost_top_candidates[i];
    if(current.status != PANDORA_XBOOST_CANDIDATE_READY)
      continue;
    if(current.candidate_side != signal_params.signal_type)
      continue;
    if(current.node_key != signal_params.pandora_xboost_node_key)
      continue;

    candidate = current;
    rank = i + 1;
    return true;
  }
  return false;
}

bool PandoraXBoostBrokerBudgetAllowsDepth(const int depth,
                                          int &next_trade_index)
{
  next_trade_index = 0;
  int max_depth = PandoraXBoostClampDepth(Pandora_XBoost_Max_Depth);
  if(max_depth < 1)
    return false;
  if(depth < 1 || depth > max_depth)
    return false;
  if(g_pandora_xboost_root.broker_active)
    return false;

  next_trade_index = g_pandora_xboost_root.broker_trade_count + 1;
  if(next_trade_index > max_depth)
    return false;
  return true;
}

bool PandoraXBoostApplyBrokerDecision(SignalParams &signal_params)
{
  if(!PandoraXBoostEnabled() || !signal_params.pandora_xboost_enabled)
    return false;

  PandoraXBoostForceLocalOnly(signal_params);
  if(!PandoraXBoostInferenceMode())
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SKIP",
                          StringFormat("depth=%d id=%s reason=MODE_%s",
                                       signal_params.pandora_xboost_depth,
                                       signal_params.pandora_xboost_display_id,
                                       PandoraXBoostModeLabel(Pandora_XBoost_Mode)));
    return false;
  }

  datetime broker_day = g_pandora_box_state.day_anchor;
  if(broker_day <= 0)
    broker_day = ResolveCurrentDayStart();
  string mask_reason = "";
  if(!PandoraXBoostSessionMaskAllowsBroker(broker_day, mask_reason))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SKIP",
                          StringFormat("depth=%d id=%s reason=SESSION_MASK detail=%s date=%s",
                                       signal_params.pandora_xboost_depth,
                                       signal_params.pandora_xboost_display_id,
                                       mask_reason,
                                       PandoraXBoostDateKey(broker_day)));
    return false;
  }

  PandoraXBoostCandidate candidate;
  int selected_rank = 0;
  if(!PandoraXBoostFindReadyCandidateForSignal(signal_params,
                                               candidate,
                                               selected_rank))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SKIP",
                          StringFormat("depth=%d id=%s reason=NO_READY_CANDIDATE",
                                       signal_params.pandora_xboost_depth,
                                       signal_params.pandora_xboost_display_id));
    return false;
  }
  if(!PandoraXBoostBrokerDailyLimitAllows(signal_params))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SKIP",
                          StringFormat("depth=%d id=%s reason=DAILY_LIMIT",
                                       signal_params.pandora_xboost_depth,
                                       signal_params.pandora_xboost_display_id));
    return false;
  }

  int next_trade_index = 0;
  if(!PandoraXBoostBrokerBudgetAllowsDepth(signal_params.pandora_xboost_depth,
                                           next_trade_index))
  {
    PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SKIP",
                          StringFormat("depth=%d id=%s reason=BUDGET_OR_ACTIVE",
                                       signal_params.pandora_xboost_depth,
                                       signal_params.pandora_xboost_display_id));
    return false;
  }

  signal_params.pandora_xboost_local_only = false;
  signal_params.pandora_xboost_broker_selected = true;
  signal_params.pandora_xboost_broker_trade_index = next_trade_index;
  signal_params.pandora_xboost_selected_rank = selected_rank;
  signal_params.pandora_xboost_model_samples = candidate.samples;
  signal_params.pandora_xboost_broker_node_samples =
    candidate.broker_node_samples;
  signal_params.pandora_xboost_model_score_r = candidate.score_r;
  signal_params.pandora_xboost_model_posterior_r =
    (candidate.posterior_r != 0.0) ? candidate.posterior_r
                                   : candidate.expectancy_r;
  signal_params.pandora_xboost_model_conservative_r =
    (candidate.conservative_score_r != 0.0) ? candidate.conservative_score_r
                                            : candidate.score_r;
  signal_params.pandora_first_entry_target_depth = PANDORA_FIRST_ENTRY_BREAKOUT_DEPTH;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
  signal_params.pandora_broker_stop_sync_status = Pandora_Box_Set_Broker_SLTP
                                                  ? PANDORA_BROKER_STOPS_PENDING
                                                  : PANDORA_BROKER_STOPS_NOT_REQUIRED;
  g_pandora_xboost_root.broker_active = true;
  g_pandora_xboost_root.broker_trade_count = next_trade_index;
  PandoraXBoostRegisterBrokerDailyStart(signal_params);

  string selected_message =
    StringFormat("strategy=%s depth=%d trade=%d rank=%d id=%s model=%s path=%s samples=%d exp=%.3f post=%.3f score=%.3f edge=%.3f med=%.3f pf=%.3f brnode=%d/%.3f brpath=%d/%.3f br30=%d/%.3f reason=%s",
                 signal_params.pandora_xboost_strategy_key,
                 signal_params.pandora_xboost_depth,
                 next_trade_index,
                 selected_rank,
                 signal_params.pandora_xboost_display_id,
                 candidate.node_key,
                 candidate.node_path,
                 candidate.samples,
                 candidate.expectancy_r,
                 candidate.posterior_r,
                 candidate.score_r,
                 candidate.edge_r,
                 candidate.median_r,
                 candidate.profit_factor_r,
                 candidate.broker_node_samples,
                 candidate.broker_node_avg_r,
                 candidate.broker_path_samples,
                 candidate.broker_path_avg_r,
                 candidate.broker_recent_samples,
                 candidate.broker_recent_avg_r,
                 candidate.reason);
  if(Enable_Logs)
    Print("PANDORA_XBOOST_BROKER_SELECTED " + selected_message);
  PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SELECTED", selected_message);
  return true;
}

void PandoraXBoostReleaseBrokerAfterClose(const SignalParams &signal_params)
{
  if(!signal_params.pandora_xboost_enabled ||
     !signal_params.pandora_xboost_broker_selected)
    return;

  if(signal_params.pandora_xboost_broker_trade_index > 0 &&
     !signal_params.pandora_broker_send_attempted &&
     g_pandora_xboost_root.broker_trade_count == signal_params.pandora_xboost_broker_trade_index)
  {
    g_pandora_xboost_root.broker_trade_count--;
    if(g_pandora_xboost_root.broker_trade_count < 0)
      g_pandora_xboost_root.broker_trade_count = 0;
  }

  g_pandora_xboost_root.broker_active = false;
}

void PandoraXBoostAppendSummaryLines(string &summary_lines[])
{
  if(!PandoraXBoostEnabled())
    return;

  int max_depth = PandoraXBoostClampDepth(Pandora_XBoost_Max_Depth);
  string root_label = PandoraXBoostDirectionLabel(g_pandora_xboost_root.root_side);
  string day_label = (g_pandora_xboost_root.root_date > 0)
                     ? PandoraXBoostDateKey(g_pandora_xboost_root.root_date)
                     : "none";
  int idx = ArraySize(summary_lines);
  ArrayResize(summary_lines, idx + 1);
  summary_lines[idx] = StringFormat("XBOOST %s v%d root=%s day=%s d=%d broker=%d/%d",
                                    PandoraXBoostModeLabel(Pandora_XBoost_Mode),
                                    PANDORA_XBOOST_SCHEMA_VERSION,
                                    root_label,
                                    day_label,
                                    g_pandora_xboost_root.current_depth,
                                    g_pandora_xboost_root.broker_trade_count,
                                    max_depth);

  idx = ArraySize(summary_lines);
  ArrayResize(summary_lines, idx + 1);
  summary_lines[idx] = StringFormat("XB data stats=%d samples=%d broker=%d pend=%d/%d %s",
                                    ArraySize(g_pandora_xboost_stats),
                                    ArraySize(g_pandora_xboost_sample_ids),
                                    ArraySize(g_pandora_xboost_broker_trades),
                                    ArraySize(g_pandora_xboost_pending_sample_rows),
                                    ArraySize(g_pandora_xboost_pending_broker_trade_rows),
                                    PandoraXBoostStorageShortLabel());

  int total = ArraySize(g_pandora_xboost_top_candidates);
  if(total > PANDORA_XBOOST_TOP_CANDIDATE_LIMIT)
    total = PANDORA_XBOOST_TOP_CANDIDATE_LIMIT;

  for(int i = 0; i < total; i++)
  {
    PandoraXBoostCandidate candidate = g_pandora_xboost_top_candidates[i];
    int line_index = ArraySize(summary_lines);
    ArrayResize(summary_lines, line_index + 1);
    string reason = (candidate.status == PANDORA_XBOOST_CANDIDATE_READY)
                    ? ""
                    : " reason=" + candidate.reason;
    string broker_label = (candidate.broker_node_samples > 0)
                          ? StringFormat(" brn=%.2f", candidate.broker_node_avg_r)
                          : "";
    summary_lines[line_index] = StringFormat("XB%d %s %s n=%d v4=%.2f p=%.2f med=%.2f pf=%.2f%s%s",
                                             i + 1,
                                             candidate.display_id,
                                             PandoraXBoostCandidateStatusLabel(candidate.status),
                                             candidate.samples,
                                             candidate.score_r,
                                             candidate.posterior_r,
                                             candidate.median_r,
                                             candidate.profit_factor_r,
                                             broker_label,
                                             reason);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
