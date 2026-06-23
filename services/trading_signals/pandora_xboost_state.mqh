//+------------------------------------------------------------------+
//|                       pandora_xboost_state.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_

const int    PANDORA_XBOOST_SCHEMA_VERSION       = 3;
const int    PANDORA_XBOOST_MIN_DEPTH            = 0;
const int    PANDORA_XBOOST_MAX_DEPTH            = 3;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_1  = 30;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_2  = 20;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3  = 12;
const double PANDORA_XBOOST_MIN_EXPECTANCY_R     = 0.05;
const double PANDORA_XBOOST_MIN_EDGE_R           = 0.05;
const double PANDORA_XBOOST_DEPTH_PENALTY_R      = 0.03;
const int    PANDORA_XBOOST_TOP_CANDIDATE_LIMIT  = 3;
const int    PANDORA_XBOOST_ROLLING_DAYS_120     = 120;
const int    PANDORA_XBOOST_ROLLING_DAYS_60      = 60;
const int    PANDORA_XBOOST_BROKER_RECENT_TRADES = 30;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_1 = 30;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_2 = 20;
const int    PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_3 = 12;
const double PANDORA_XBOOST_BAYES_UNCERTAINTY_Z = 1.0;
const double PANDORA_XBOOST_BAYES_UNCERTAINTY_FLOOR_R = 0.03;
const double PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R = 0.03;
const double PANDORA_XBOOST_BROKER_DEGRADATION_FLOOR_R = -0.05;
const double PANDORA_XBOOST_BROKER_DEGRADATION_WEIGHT = 1.0;
const int    PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES = 5;
const int    PANDORA_XBOOST_BROKER_MIN_RECENT_SAMPLES = 10;

void PandoraXBoostBuildRootCandidates(const SignalParams &root_signal);
void PandoraXBoostBuildNextCandidatesFromClosedSignal(const SignalParams &closed_signal,
                                                      const PandoraXBoostCloseEvents close_event,
                                                      const int next_depth);
bool PandoraXBoostApplyBrokerDecision(SignalParams &signal_params);
void PandoraXBoostReleaseBrokerAfterClose(const SignalParams &signal_params);
void PandoraXBoostResetRuntimeState();
void PandoraXBoostLogEvent(const string label, const string message);
string PandoraXBoostStorageShortLabel();

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
  signal_params.pandora_xboost_broker_window_samples = 0;
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
  int                            local_window_120_samples;
  int                            local_window_60_samples;
  int                            broker_node_samples;
  int                            broker_recent_samples;
  double                         local_window_120_avg_r;
  double                         local_window_60_avg_r;
  double                         broker_node_avg_r;
  double                         broker_recent_avg_r;

  PandoraXBoostCandidate()
  {
    candidate_side = NO_SIGNAL;
    status         = PANDORA_XBOOST_CANDIDATE_NONE;
    parent_event   = PANDORA_XBOOST_EVENT_NONE;
    key_hash       = 0;
    node_key       = "";
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
    local_window_120_samples = 0;
    local_window_60_samples = 0;
    broker_node_samples = 0;
    broker_recent_samples = 0;
    local_window_120_avg_r = 0.0;
    local_window_60_avg_r = 0.0;
    broker_node_avg_r = 0.0;
    broker_recent_avg_r = 0.0;
  }

  PandoraXBoostCandidate(const PandoraXBoostCandidate &candidate)
  {
    candidate_side = candidate.candidate_side;
    status         = candidate.status;
    parent_event   = candidate.parent_event;
    key_hash       = candidate.key_hash;
    node_key       = candidate.node_key;
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
    local_window_120_samples = candidate.local_window_120_samples;
    local_window_60_samples = candidate.local_window_60_samples;
    broker_node_samples = candidate.broker_node_samples;
    broker_recent_samples = candidate.broker_recent_samples;
    local_window_120_avg_r = candidate.local_window_120_avg_r;
    local_window_60_avg_r = candidate.local_window_60_avg_r;
    broker_node_avg_r = candidate.broker_node_avg_r;
    broker_recent_avg_r = candidate.broker_recent_avg_r;
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
  int                       broker_window_samples;
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
    broker_window_samples = 0;
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
    broker_window_samples = row.broker_window_samples;
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

PandoraXBoostRootState g_pandora_xboost_root;
PandoraXBoostStats     g_pandora_xboost_stats[];
string                 g_pandora_xboost_sample_ids[];
PandoraXBoostSampleRow g_pandora_xboost_sample_rows[];
PandoraXBoostCandidate g_pandora_xboost_top_candidates[];
string                 g_pandora_xboost_pending_sample_rows[];
PandoraXBoostBrokerTradeRow g_pandora_xboost_broker_trades[];
string                 g_pandora_xboost_broker_trade_ids[];
string                 g_pandora_xboost_pending_broker_trade_rows[];
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
  return PANDORA_XBOOST_BAYES_PRIOR_WEIGHT_DEPTH_3;
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
  return PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3;
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
          candidate.conservative_score_r >= PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R);
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

void PandoraXBoostApplyBrokerCalibration(PandoraXBoostCandidate &candidate,
                                         const string strategy_key)
{
  PandoraXBoostRollingStats broker_node;
  if(PandoraXBoostAggregateBrokerNodeTrades(candidate.node_key, broker_node))
  {
    candidate.broker_node_samples = broker_node.samples;
    candidate.broker_node_avg_r = broker_node.avg_r;
  }

  PandoraXBoostRollingStats broker_recent;
  if(PandoraXBoostAggregateBrokerRecentTrades(strategy_key,
                                              PANDORA_XBOOST_BROKER_RECENT_TRADES,
                                              broker_recent))
  {
    candidate.broker_recent_samples = broker_recent.samples;
    candidate.broker_recent_avg_r = broker_recent.avg_r;
  }

  if(candidate.broker_recent_samples >= PANDORA_XBOOST_BROKER_MIN_RECENT_SAMPLES &&
     candidate.broker_recent_avg_r < PANDORA_XBOOST_BROKER_DEGRADATION_FLOOR_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = "BROKER_30";
    return;
  }

  if(candidate.broker_node_samples >= PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES &&
     candidate.broker_node_avg_r < PANDORA_XBOOST_BROKER_DEGRADATION_FLOOR_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = "BROKER_NODE";
    return;
  }

  double broker_reference_r = candidate.score_r;
  bool has_broker_reference = false;
  if(candidate.broker_node_samples >= PANDORA_XBOOST_BROKER_MIN_NODE_SAMPLES)
  {
    broker_reference_r = candidate.broker_node_avg_r;
    has_broker_reference = true;
  }
  if(candidate.broker_recent_samples >= PANDORA_XBOOST_BROKER_MIN_RECENT_SAMPLES)
  {
    if(!has_broker_reference || candidate.broker_recent_avg_r < broker_reference_r)
      broker_reference_r = candidate.broker_recent_avg_r;
    has_broker_reference = true;
  }

  if(!has_broker_reference || broker_reference_r >= candidate.score_r)
    return;

  double degradation_r =
    (candidate.score_r - broker_reference_r) *
    PANDORA_XBOOST_BROKER_DEGRADATION_WEIGHT;
  if(degradation_r <= 0.0)
    return;

  candidate.broker_degradation_r = degradation_r;
  candidate.score_r -= degradation_r;
  candidate.conservative_score_r = candidate.score_r;
  if(candidate.score_r < PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = "BROKER_DEGRADE";
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
  candidate.local_window_120_samples = 0;
  candidate.local_window_60_samples = 0;
  candidate.broker_node_samples = 0;
  candidate.broker_recent_samples = 0;
  candidate.local_window_120_avg_r = 0.0;
  candidate.local_window_60_avg_r = 0.0;
  candidate.broker_node_avg_r = 0.0;
  candidate.broker_recent_avg_r = 0.0;

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

  PandoraXBoostStats stats;
  if(!PandoraXBoostLookupStats(node_key, stats))
    return;

  candidate.samples      = stats.samples;
  candidate.expectancy_r = stats.expectancy_r;

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

  int min_samples = PandoraXBoostMinSamplesForDepth(safe_depth);
  if(stats.samples < min_samples)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_WAIT;
    candidate.reason = StringFormat("SAMPLES_%d_%d", stats.samples, min_samples);
    return;
  }

  if(candidate.conservative_score_r < PANDORA_XBOOST_BAYES_MIN_CONSERVATIVE_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = "BAYES_SCORE";
    return;
  }

  string rolling_reason = "";
  if(PandoraXBoostRollingWindowBlocks(candidate, min_samples, rolling_reason))
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = rolling_reason;
    return;
  }

  PandoraXBoostApplyBrokerCalibration(candidate, strategy_key);
  if(candidate.status == PANDORA_XBOOST_CANDIDATE_BLOCK)
    return;

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
    string message = StringFormat("rank=%d depth=%d id=%s status=%s samples=%d exp=%.3f post=%.3f score=%.3f edge=%.3f u=%.3f dp=%.3f bd=%.3f w120=%d/%.3f w60=%d/%.3f brnode=%d/%.3f br30=%d/%.3f reason=%s model=%s",
                                  i + 1,
                                  candidate.depth,
                                  candidate.display_id,
                                  PandoraXBoostCandidateStatusLabel(candidate.status),
                                  candidate.samples,
                                  candidate.expectancy_r,
                                  candidate.posterior_r,
                                  candidate.score_r,
                                  candidate.edge_r,
                                  candidate.uncertainty_penalty_r,
                                  candidate.depth_penalty_r,
                                  candidate.broker_degradation_r,
                                  candidate.local_window_120_samples,
                                  candidate.local_window_120_avg_r,
                                  candidate.local_window_60_samples,
                                  candidate.local_window_60_avg_r,
                                  candidate.broker_node_samples,
                                  candidate.broker_node_avg_r,
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
  signal_params.pandora_xboost_broker_window_samples = 0;
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
  signal_params.pandora_xboost_broker_window_samples =
    candidate.broker_recent_samples;
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

  if(Enable_Logs)
  {
    PrintFormat("PANDORA_XBOOST_BROKER_SELECTED depth=%d trade=%d rank=%d id=%s samples=%d exp=%.3f edge=%.3f",
                signal_params.pandora_xboost_depth,
                next_trade_index,
                selected_rank,
                signal_params.pandora_xboost_display_id,
                candidate.samples,
                candidate.expectancy_r,
                candidate.edge_r);
  }
  PandoraXBoostLogEvent("PANDORA_XBOOST_BROKER_SELECTED",
                        StringFormat("depth=%d trade=%d rank=%d id=%s samples=%d exp=%.3f edge=%.3f",
                                     signal_params.pandora_xboost_depth,
                                     next_trade_index,
                                     selected_rank,
                                     signal_params.pandora_xboost_display_id,
                                     candidate.samples,
                                     candidate.expectancy_r,
                                     candidate.edge_r));
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
    string broker_label = (candidate.broker_recent_samples > 0)
                          ? StringFormat(" br30=%.2f", candidate.broker_recent_avg_r)
                          : "";
    summary_lines[line_index] = StringFormat("XB%d %s %s n=%d p=%.2f c=%.2f%s%s",
                                             i + 1,
                                             candidate.display_id,
                                             PandoraXBoostCandidateStatusLabel(candidate.status),
                                             candidate.samples,
                                             candidate.posterior_r,
                                             candidate.score_r,
                                             broker_label,
                                             reason);
  }
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
