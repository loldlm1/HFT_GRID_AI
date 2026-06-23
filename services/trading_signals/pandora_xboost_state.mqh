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
      int safe_step = MathMax(step_index, 1);
      return StringFormat("TTPL%d", safe_step);
    }
    case PANDORA_XBOOST_EVENT_TTPS:
    {
      int safe_step = MathMax(step_index, 1);
      return StringFormat("TTPS%d", safe_step);
    }
    case PANDORA_XBOOST_EVENT_FORCE_CLOSE:
      return "FORCE_CLOSE";
    case PANDORA_XBOOST_EVENT_NONE:
    default:
      return "NONE";
  }
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

#endif // _SERVICES_TRADING_SIGNALS_PANDORA_XBOOST_STATE_MQH_
