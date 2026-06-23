//+------------------------------------------------------------------+
//|                       pandora_xboost_state.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_

const int    PANDORA_XBOOST_SCHEMA_VERSION       = 1;
const int    PANDORA_XBOOST_MIN_DEPTH            = 0;
const int    PANDORA_XBOOST_MAX_DEPTH            = 3;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_1  = 30;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_2  = 20;
const int    PANDORA_XBOOST_MIN_SAMPLES_DEPTH_3  = 12;
const double PANDORA_XBOOST_MIN_EXPECTANCY_R     = 0.05;
const double PANDORA_XBOOST_MIN_EDGE_R           = 0.05;
const double PANDORA_XBOOST_DEPTH_PENALTY_R      = 0.03;
const int    PANDORA_XBOOST_TOP_CANDIDATE_LIMIT  = 3;

void PandoraXBoostBuildRootCandidates(const SignalParams &root_signal);
void PandoraXBoostBuildNextCandidatesFromClosedSignal(const SignalParams &closed_signal,
                                                      const PandoraXBoostCloseEvents close_event,
                                                      const int next_depth);

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
                                 const datetime root_date,
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
  return StringFormat("%s|%s|%s|%s|%d|%s|%s",
                      strategy_key,
                      PandoraXBoostDateKey(root_date),
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
                                        const datetime root_date,
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
                              root_date,
                              root_side,
                              parent_event,
                              safe_depth,
                              signal_params.signal_type,
                              0,
                              signal_params.pandora_xboost_node_path);
  signal_params.pandora_xboost_sample_id = "";
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

  g_pandora_xboost_root.active = true;
  g_pandora_xboost_root.broker_active = false;
  g_pandora_xboost_root.root_side = root_side;
  g_pandora_xboost_root.last_event = root_event;
  g_pandora_xboost_root.root_date = root_date;
  g_pandora_xboost_root.strategy_key = strategy_key;
  g_pandora_xboost_root.root_id = root_id;
  g_pandora_xboost_root.current_depth = 1;
  g_pandora_xboost_root.broker_trade_count = 0;

  PandoraXBoostPrepareSignalMetadata(signal_params,
                                     strategy_key,
                                     root_id,
                                     root_date,
                                     root_side,
                                     root_event,
                                     1,
                                     true);
  PandoraXBoostBuildRootCandidates(signal_params);

  signal_params.pandora_first_entry_target_depth = PANDORA_FIRST_ENTRY_OFF_DEPTH;
  signal_params.pandora_broker_execution_status = PANDORA_BROKER_NOT_ATTEMPTED;
  signal_params.pandora_broker_stop_sync_status = PANDORA_BROKER_STOPS_NOT_REQUIRED;
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

PandoraXBoostRootState g_pandora_xboost_root;
PandoraXBoostStats     g_pandora_xboost_stats[];
string                 g_pandora_xboost_sample_ids[];
PandoraXBoostCandidate g_pandora_xboost_top_candidates[];
string                 g_pandora_xboost_pending_sample_rows[];
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
  return (candidate.samples >= min_samples &&
          candidate.expectancy_r >= PANDORA_XBOOST_MIN_EXPECTANCY_R);
}

void PandoraXBoostBuildCandidate(const string strategy_key,
                                 const datetime root_date,
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
                                              root_date,
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

  PandoraXBoostStats stats;
  if(!PandoraXBoostLookupStats(node_key, stats))
    return;

  candidate.samples      = stats.samples;
  candidate.expectancy_r = stats.expectancy_r;
  candidate.score_r      = stats.expectancy_r -
                           ((safe_depth - 1) * PANDORA_XBOOST_DEPTH_PENALTY_R);

  int min_samples = PandoraXBoostMinSamplesForDepth(safe_depth);
  if(stats.samples < min_samples)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_WAIT;
    candidate.reason = StringFormat("SAMPLES_%d_%d", stats.samples, min_samples);
    return;
  }

  if(stats.expectancy_r < PANDORA_XBOOST_MIN_EXPECTANCY_R)
  {
    candidate.status = PANDORA_XBOOST_CANDIDATE_BLOCK;
    candidate.reason = "EXPECTANCY";
    return;
  }

  candidate.status = PANDORA_XBOOST_CANDIDATE_WATCH;
  candidate.reason = "EDGE";
}

void PandoraXBoostApplyCandidateEdge(PandoraXBoostCandidate &candidate,
                                     const PandoraXBoostCandidate &alternative,
                                     const bool has_alternative)
{
  if(!PandoraXBoostCandidateHasMinimumStats(candidate))
    return;

  double alternative_expectancy = 0.0;
  bool alternative_ready_stats = false;
  if(has_alternative)
  {
    alternative_expectancy = alternative.expectancy_r;
    alternative_ready_stats = PandoraXBoostCandidateHasMinimumStats(alternative);
  }

  candidate.edge_r = candidate.expectancy_r - alternative_expectancy;
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
  if(!Enable_Logs)
    return;

  int total = ArraySize(g_pandora_xboost_top_candidates);
  for(int i = 0; i < total; i++)
  {
    PandoraXBoostCandidate candidate = g_pandora_xboost_top_candidates[i];
    PrintFormat("PANDORA_XBOOST_DRYRUN rank=%d depth=%d id=%s status=%s samples=%d exp=%.3f edge=%.3f score=%.3f reason=%s",
                i + 1,
                candidate.depth,
                candidate.display_id,
                PandoraXBoostCandidateStatusLabel(candidate.status),
                candidate.samples,
                candidate.expectancy_r,
                candidate.edge_r,
                candidate.score_r,
                candidate.reason);
  }
}

void PandoraXBoostBuildCandidateSet(const string strategy_key,
                                    const datetime root_date,
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
                                root_date,
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
                                root_date,
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

  datetime root_date = g_pandora_xboost_root.root_date;
  if(root_date <= 0)
    root_date = ResolveCurrentDayStart();

  PandoraXBoostBuildCandidateSet(root_signal.pandora_xboost_strategy_key,
                                 root_date,
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

  datetime root_date = g_pandora_xboost_root.root_date;
  if(root_date <= 0)
    root_date = g_pandora_box_state.day_anchor;
  if(root_date <= 0)
    root_date = ResolveCurrentDayStart();

  SignalTypes root_side = closed_signal.pandora_xboost_root_side;
  if(root_side == NO_SIGNAL)
    root_side = closed_signal.signal_type;

  PandoraXBoostBuildCandidateSet(strategy_key,
                                 root_date,
                                 root_side,
                                 close_event,
                                 next_depth,
                                 closed_signal.pandora_xboost_node_path,
                                 true,
                                 NO_SIGNAL);
}

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
