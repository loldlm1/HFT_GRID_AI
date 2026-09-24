#ifndef PIVOT_DATASET_ADAPTER_MQH
#define PIVOT_DATASET_ADAPTER_MQH

bool g_pivot_dataset_research_discarded = false;
int g_pivot_dataset_broker_peak = 0;

void PivotDatasetFail(const string operation, const string filename = "",
                       const int error_code = 0, const string context = "")
{
  ModelFail(operation + (filename == "" ? "" : "|" + filename) +
            (error_code == 0 ? "" : "|error=" + ModelInteger(error_code)) +
            (context == "" ? "" : "|" + context));
}

bool PivotDatasetRejectReference(const string reason, const string context = "")
{
  PivotDatasetFail(reason, "", 0, context);
  return false;
}

void PivotDatasetRegisterDuplicateIdentity() { ModelFail("PIVOT_DUPLICATE_IDENTITY"); }

void PivotDatasetCaptureResearchFailure()
{
  if(PivotTrialResearchIntegrityFailed()) ModelFail("PIVOT_TRIAL_INTEGRITY");
}

void PivotDatasetClock(ModelRow &row, const int field, const long msc, const datetime seconds)
{
  if(msc > 0) row.Clock(field, msc);
  else if(seconds > 0) row.Clock(field, (long)seconds * 1000, true);
}

string PivotDatasetWindowId(const string symbol, const ENUM_TIMEFRAMES timeframe, const datetime opening)
{
  return symbol + ":" + ModelInteger(PeriodSeconds(timeframe)) + ":" + ModelInteger(opening);
}

string PivotDatasetOriginId(const string symbol, const ENUM_TIMEFRAMES timeframe,
                             const datetime opening, const PivotLevelIds level)
{
  string key = symbol + "|" + EnumToString(timeframe) + "|" + ModelInteger(opening) + "|" + PivotLevelLabel(level);
  return "origin_" + StringFormat("%I64u", PivotTrialStableHash(key));
}

string PivotDatasetBrokerSignalId(const string origin_id)
{
  return "broker_" + StringFormat("%I64u", PivotTrialStableHash(origin_id + "|STRUCTURAL_1R"));
}

string PivotDatasetAttemptId(const string origin_id) { return origin_id + ":ATTEMPT"; }
string PivotDatasetBrokerTrialId(const string origin_id) { return origin_id + ":BROKER:1"; }
string PivotDatasetDirection(const SignalTypes direction) { return direction == BULLISH ? "BUY" : "SELL"; }

bool PivotDatasetInitialize()
{
  ModelCaptureConfig config;
  config.enabled = Enable_Signal_Feature_Export;
  config.run_id = Signal_Feature_Run_Id;
  config.engine = "PIVOT_MACRO_V1";
  config.symbol = _Symbol;
  config.macro = Macro_Timeframe;
  config.micro = Micro_Timeframe;
  config.exness = Broker_Session == EXNESS_SESSION;
  config.lot_type = EnumToString(Lot_Type);
  config.lot_size = Lot_Strategy_Size;
  config.reference_balance = PIVOT_EXECUTION_REFERENCE_BALANCE;
  config.broker_cap = PIVOT_TRIAL_ACTIVE_STATE_CAP;
  config.virtual_cap = PIVOT_TRIAL_ACTIVE_STATE_CAP;
  ResetPivotTrialLaneState();
  return ModelInitialize(config);
}

struct PivotDatasetPendingOrigin
{
  PivotTrialOriginSnapshot origin;
  string broker_attempt_status;
  bool h1_lanes_declared;

  PivotDatasetPendingOrigin()
  {
    Reset();
  }

  PivotDatasetPendingOrigin(const PivotDatasetPendingOrigin &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    origin.Reset();
    broker_attempt_status = "NOT_EVALUATED";
    h1_lanes_declared = false;
  }

  void CopyFrom(const PivotDatasetPendingOrigin &other)
  {
    origin.CopyFrom(other.origin);
    broker_attempt_status = other.broker_attempt_status;
    h1_lanes_declared = other.h1_lanes_declared;
  }
};

PivotDatasetPendingOrigin g_pivot_dataset_pending_origins[];
PivotTrialParityLink g_pivot_dataset_parity_links[];
const int PIVOT_DATASET_ORIGIN_STATE_RESERVE = 8;
const int PIVOT_DATASET_PARITY_LINK_RESERVE = 16;

int FindPivotDatasetParityLink(const string parity_trial_id)
{
  if(parity_trial_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_dataset_parity_links); i++)
  {
    if(g_pivot_dataset_parity_links[i].parity_trial_id == parity_trial_id)
      return i;
  }
  return -1;
}

bool RemovePivotDatasetParityLinkAt(const int index)
{
  int total = ArraySize(g_pivot_dataset_parity_links);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_dataset_parity_links[i].CopyFrom(
      g_pivot_dataset_parity_links[i + 1]);
  int reserve = total - 1 > 0 ? PIVOT_DATASET_PARITY_LINK_RESERVE : 0;
  return ArrayResize(g_pivot_dataset_parity_links,
                     total - 1,
                     reserve) == total - 1;
}

bool PivotDatasetFinalizeParityLink(const int index)
{
  if(index < 0 || index >= ArraySize(g_pivot_dataset_parity_links))
    return false;
  PivotTrialParityLink link(g_pivot_dataset_parity_links[index]);
  if(!link.virtual_outcome_recorded || !link.broker_outcome_linked)
    return true;
  if(link.summary_counted)
    return PivotDatasetRejectReference("PARITY_SUMMARY_DUPLICATE");

  g_pivot_dataset_parity_links[index].summary_counted = true;
  if(!RemovePivotDatasetParityLinkAt(index))
    return PivotDatasetRejectReference("PARITY_LINK_REMOVE_FAILED");
  return true;
}

bool PivotDatasetRegisterParityLink(const PivotTrialEntry &trial)
{
  if(trial.identity.role != PIVOT_TRIAL_ROLE_BROKER_PARITY ||
     trial.identity.parity_trial_id == "" ||
     trial.identity.trial_id != trial.identity.parity_trial_id ||
     trial.identity.origin_id == "" ||
     trial.identity.broker_signal_id == "" ||
     FindPivotDatasetParityLink(trial.identity.parity_trial_id) >= 0)
    return PivotDatasetRejectReference("PARITY_LINK_REGISTER_INVALID");
  int total = ArraySize(g_pivot_dataset_parity_links);
  if(total >= PIVOT_TRIAL_ACTIVE_STATE_CAP)
    return PivotDatasetRejectReference("PARITY_LINK_CAP_REACHED");
  if(ArrayResize(g_pivot_dataset_parity_links,
                 total + 1,
                 PIVOT_DATASET_PARITY_LINK_RESERVE) != total + 1)
    return PivotDatasetRejectReference("PARITY_LINK_RESIZE_FAILED");
  g_pivot_dataset_parity_links[total].Reset();
  g_pivot_dataset_parity_links[total].origin_id = trial.identity.origin_id;
  g_pivot_dataset_parity_links[total].broker_signal_id =
    trial.identity.broker_signal_id;
  g_pivot_dataset_parity_links[total].parity_trial_id =
    trial.identity.parity_trial_id;
  g_pivot_dataset_parity_links[total].accepted_request_copied = true;
  return true;
}

bool PivotDatasetLinkParityVirtualOutcome(const PivotTrialOutcome &outcome)
{
  int index = FindPivotDatasetParityLink(outcome.identity.parity_trial_id);
  if(index < 0 ||
     g_pivot_dataset_parity_links[index].origin_id !=
       outcome.identity.origin_id ||
     g_pivot_dataset_parity_links[index].broker_signal_id !=
       outcome.identity.broker_signal_id ||
     g_pivot_dataset_parity_links[index].virtual_outcome_recorded)
    return PivotDatasetRejectReference("PARITY_VIRTUAL_LINK_INVALID");
  g_pivot_dataset_parity_links[index].virtual_outcome_recorded = true;
  g_pivot_dataset_parity_links[index].virtual_first_touch = outcome.first_touch;
  return PivotDatasetFinalizeParityLink(index);
}

bool PivotDatasetParityHasVirtualOutcome(const string parity_trial_id)
{
  int index = FindPivotDatasetParityLink(parity_trial_id);
  return index >= 0 &&
         g_pivot_dataset_parity_links[index].virtual_outcome_recorded;
}

bool PivotDatasetLinkParityBrokerOutcome(const PivotSignal &signal)
{
  int index = FindPivotDatasetParityLink(signal.parity_trial_id);
  if(index < 0 ||
     g_pivot_dataset_parity_links[index].origin_id != signal.origin_id ||
     g_pivot_dataset_parity_links[index].broker_signal_id !=
       signal.broker_signal_id ||
     g_pivot_dataset_parity_links[index].broker_outcome_linked)
    return PivotDatasetRejectReference("PARITY_BROKER_LINK_INVALID");
  g_pivot_dataset_parity_links[index].broker_outcome_linked = true;
  g_pivot_dataset_parity_links[index].broker_binary_eligible =
    signal.execution.binary_eligible;
  g_pivot_dataset_parity_links[index].broker_binary_target =
    signal.execution.binary_target;
  return PivotDatasetFinalizeParityLink(index);
}

int FindPivotDatasetPendingOrigin(const string origin_id)
{
  if(origin_id == "")
    return -1;
  for(int i = 0; i < ArraySize(g_pivot_dataset_pending_origins); i++)
  {
    if(g_pivot_dataset_pending_origins[i].origin.origin_id == origin_id)
      return i;
  }
  return -1;
}

bool RemovePivotDatasetPendingOriginAt(const int index)
{
  int total = ArraySize(g_pivot_dataset_pending_origins);
  if(index < 0 || index >= total)
    return false;
  for(int i = index; i < total - 1; i++)
    g_pivot_dataset_pending_origins[i].CopyFrom(
      g_pivot_dataset_pending_origins[i + 1]);
  int reserve = total > 1 ? PIVOT_DATASET_ORIGIN_STATE_RESERVE : 0;
  if(ArrayResize(g_pivot_dataset_pending_origins, total - 1, reserve) == total - 1)
    return true;
  PivotDatasetFail("ORIGIN_STATE_REMOVE", "", GetLastError(), IntegerToString(index));
  return false;
}

string PivotDatasetBrokerAttemptStatus(const PivotSignal &signal)
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



bool PivotDatasetEmitSignal(PivotSignal &signal)
{
  g_model_sequence++;
  MqlTick tick;
  ZeroMemory(tick);
  tick.time = signal.trigger_time;
  tick.time_msc = signal.trigger_time_msc;
  tick.bid = signal.trigger_bid;
  tick.ask = signal.trigger_ask;
  string snapshot_id = signal.origin_id + ":FEATURES";
  if(!ModelCapture(signal.origin_id, snapshot_id, "PIVOT_ORIGIN", g_model_sequence, tick)) return false;
  signal.feature_complete = g_model_last_capture_complete;
  ModelRow row;
  row.Init(MODEL_SIGNAL_EVENTS);
  row.Set(MODEL_F_SIGNAL_EVENTS_SIGNAL_ID, signal.origin_id);
  row.Integer(MODEL_F_SIGNAL_EVENTS_SEQUENCE, g_model_sequence);
  row.Set(MODEL_F_SIGNAL_EVENTS_SYMBOL, _Symbol);
  row.Set(MODEL_F_SIGNAL_EVENTS_DIRECTION, PivotDatasetDirection(signal.direction));
  PivotDatasetClock(row, MODEL_F_SIGNAL_EVENTS_SIGNAL_TIME_MSC, signal.trigger_time_msc, signal.trigger_time);
  row.Clock(MODEL_F_SIGNAL_EVENTS_SOURCE_TIME_MSC, (long)signal.source_bar_open * 1000, true);
  row.Set(MODEL_F_SIGNAL_EVENTS_MACRO_WINDOW_ID, signal.window_id);
  row.Number(MODEL_F_SIGNAL_EVENTS_BID, signal.trigger_bid);
  row.Number(MODEL_F_SIGNAL_EVENTS_ASK, signal.trigger_ask);
  row.Set(MODEL_F_SIGNAL_EVENTS_ADMISSION, "DISCOVERED");
  if(!ModelWrite(row)) return false;
  row.Init(MODEL_ENTRY_ATTEMPTS);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_ATTEMPT_ID, PivotDatasetAttemptId(signal.origin_id));
  row.Set(MODEL_F_ENTRY_ATTEMPTS_SIGNAL_ID, signal.origin_id);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_SNAPSHOT_ID, snapshot_id);
  row.Integer(MODEL_F_ENTRY_ATTEMPTS_SEQUENCE, g_model_sequence);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_ENTRY_TYPE, "PIVOT_ORIGIN");
  row.Set(MODEL_F_ENTRY_ATTEMPTS_DIRECTION, PivotDatasetDirection(signal.direction));
  PivotDatasetClock(row, MODEL_F_ENTRY_ATTEMPTS_DECISION_TIME_MSC, signal.trigger_time_msc, signal.trigger_time);
  row.Set(MODEL_F_ENTRY_ATTEMPTS_MACRO_WINDOW_ID, signal.window_id);
  row.Number(MODEL_F_ENTRY_ATTEMPTS_BID, signal.trigger_bid);
  row.Number(MODEL_F_ENTRY_ATTEMPTS_ASK, signal.trigger_ask);
  return ModelWrite(row);
}

bool PivotDatasetRegisterOrigin(PivotSignal &signal)
{
  if(!ModelReady())
    return false;
  if(signal.origin_id == "" || signal.window_id == "" ||
     signal.broker_signal_id == "" ||
     signal.active_bar_open <= 0 || signal.trigger_time <= 0 ||
     signal.trigger_bid <= 0.0 || signal.trigger_ask < signal.trigger_bid ||
     !signal.levels.valid ||
     !MathIsValidNumber(signal.route.structural_stop_loss) ||
     signal.route.structural_stop_loss <= 0.0)
    return PivotDatasetRejectReference("REGISTER_ORIGIN_INVALID");
  if(FindPivotDatasetPendingOrigin(signal.origin_id) >= 0)
  {
    PivotDatasetRegisterDuplicateIdentity();
    return false;
  }

  PivotDatasetPendingOrigin pending;
  PivotTrialOriginSnapshot origin;
  origin.origin_id = signal.origin_id;
  origin.window_id = signal.window_id;
  origin.broker_signal_id = signal.broker_signal_id;
  origin.symbol = _Symbol;
  origin.macro_timeframe = signal.pivot_timeframe;
  origin.micro_timeframe = Micro_Timeframe;
  origin.active_bar_open = signal.active_bar_open;
  origin.trigger_time = signal.trigger_time;
  origin.trigger_time_msc = signal.trigger_time_msc;
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
    return PivotDatasetRejectReference("REGISTER_ORIGIN_LEVEL_INVALID");
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
    return PivotDatasetRejectReference("REGISTER_ORIGIN_GEOMETRY_INVALID");
  origin.levels.CopyFrom(signal.levels);
  pending.origin.CopyFrom(origin);
  pending.broker_attempt_status = PivotDatasetBrokerAttemptStatus(signal);
  pending.h1_lanes_declared = signal.h1_lanes_declared;

  int total = ArraySize(g_pivot_dataset_pending_origins);
  if(total >= PIVOT_LEVEL_COUNT) return PivotDatasetRejectReference("ORIGIN_WINDOW_CAP");
  if(ArrayResize(g_pivot_dataset_pending_origins,
                 total + 1,
                 PIVOT_DATASET_ORIGIN_STATE_RESERVE) != total + 1)
  {
    PivotDatasetFail("ORIGIN_STATE_RESIZE");
    return false;
  }
  g_pivot_dataset_pending_origins[total].CopyFrom(pending);
  return PivotDatasetEmitSignal(signal);
}

bool PivotDatasetUpdateOrigin(const PivotSignal &signal)
{
  if(!Enable_Signal_Feature_Export)
    return true;
  if(!ModelReady())
    return false;
  int index = FindPivotDatasetPendingOrigin(signal.origin_id);
  if(index < 0)
  {
    if(signal.origin_registered && signal.origin_export_finalized &&
       signal.origin_id != "" && signal.window_id != "")
      return true;
    return PivotDatasetRejectReference("UPDATE_ORIGIN_NOT_FOUND");
  }
  g_pivot_dataset_pending_origins[index].broker_attempt_status =
    PivotDatasetBrokerAttemptStatus(signal);
  g_pivot_dataset_pending_origins[index].h1_lanes_declared = signal.h1_lanes_declared;
  return true;
}

bool PivotDatasetMarkOriginMatrixDeclared(const string origin_id)
{
  int index = FindPivotDatasetPendingOrigin(origin_id);
  if(index < 0)
    return PivotDatasetRejectReference("MATRIX_ORIGIN_NOT_FOUND", origin_id);
  g_pivot_dataset_pending_origins[index].h1_lanes_declared = true;
  return true;
}

bool PivotDatasetRecordOrigin(const PivotDatasetPendingOrigin &pending, const string terminal_status)
{
  if(!ModelReady()) return false;
  PivotTrialOriginSnapshot origin(pending.origin);
  ModelRow row;
  row.Init(MODEL_PIVOT_ORIGINS);
  row.Set(MODEL_F_PIVOT_ORIGINS_SIGNAL_ID, origin.origin_id);
  row.Set(MODEL_F_PIVOT_ORIGINS_BROKER_SIGNAL_ID, origin.broker_signal_id);
  row.Set(MODEL_F_PIVOT_ORIGINS_LEVEL_ID, PivotLevelLabel(origin.level_id));
  row.Number(MODEL_F_PIVOT_ORIGINS_PIVOT_RAW_PRICE, origin.pivot_raw_price);
  row.Number(MODEL_F_PIVOT_ORIGINS_PIVOT_TRADE_PRICE, origin.pivot_trade_price);
  row.Number(MODEL_F_PIVOT_ORIGINS_NEXT_OUTWARD_PIVOT_PRICE, origin.next_outward_pivot_price);
  row.Number(MODEL_F_PIVOT_ORIGINS_MIDPOINT_50_PRICE, origin.midpoint_50_price);
  row.Number(MODEL_F_PIVOT_ORIGINS_STRUCTURAL_ENTRY_PRICE, origin.structural_entry_price);
  row.Number(MODEL_F_PIVOT_ORIGINS_STRUCTURAL_TAKE_PROFIT, origin.structural_take_profit);
  row.Number(MODEL_F_PIVOT_ORIGINS_STOPS_LEVEL_POINTS, origin.stops_level_points);
  row.Number(MODEL_F_PIVOT_ORIGINS_FREEZE_LEVEL_POINTS, origin.freeze_level_points);
  row.Number(MODEL_F_PIVOT_ORIGINS_STRUCTURAL_SL_PRICE, origin.structural_stop_loss);
  row.Flag(MODEL_F_PIVOT_ORIGINS_IDENTITY_CONSUMED, true);
  row.Flag(MODEL_F_PIVOT_ORIGINS_H1_LANES_DECLARED, pending.h1_lanes_declared);
  row.Set(MODEL_F_PIVOT_ORIGINS_BROKER_ATTEMPT_STATUS, pending.broker_attempt_status);
  row.Set(MODEL_F_PIVOT_ORIGINS_ORIGIN_TERMINAL_STATUS, terminal_status);
  return ModelWrite(row);
}

bool PivotDatasetRecordWindow(const PivotFractalWindowState &window,
                               const datetime terminal_time, const string status)
{
  if(!ModelReady()) return false;
  string id = PivotDatasetWindowId(_Symbol, window.timeframe, window.active_bar_open);
  for(int i = ArraySize(g_pivot_dataset_pending_origins) - 1; i >= 0; i--)
  {
    if(g_pivot_dataset_pending_origins[i].origin.window_id != id) continue;
    if(!PivotDatasetRecordOrigin(g_pivot_dataset_pending_origins[i], status) ||
       !RemovePivotDatasetPendingOriginAt(i)) return false;
  }
  return true;
}


string PivotDatasetEligibility(const PivotTrialEntry &trial)
{
  return trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE ? "ELIGIBLE" : PivotTrialEligibilityLabel(trial.eligibility_status);
}

void PivotDatasetTrialGeometry(ModelRow &row, const PivotTrialEntry &trial)
{
  bool pending = !trial.midpoint_touched && trial.identity.entry_policy == PIVOT_TRIAL_ENTRY_MIDPOINT_50;
  bool geometry = trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE && trial.geometry.valid;
  if(!pending)
  {
    row.Number(MODEL_F_TRIALS_ENTRY_BID, trial.geometry.entry_bid);
    row.Number(MODEL_F_TRIALS_ENTRY_ASK, trial.geometry.entry_ask);
    row.Number(MODEL_F_TRIALS_ENTRY_PRICE, trial.geometry.entry_price > 0.0 ? trial.geometry.entry_price : EMPTY_VALUE);
    row.Set(MODEL_F_TRIALS_ENTRY_QUOTE_SIDE, PivotTrialQuoteSideLabel(trial.geometry.entry_quote_side));
    row.Set(MODEL_F_TRIALS_EXIT_QUOTE_SIDE, PivotTrialQuoteSideLabel(trial.geometry.exit_quote_side));
  }
  row.Number(MODEL_F_TRIALS_MIDPOINT_50_PRICE, trial.midpoint_50_price > 0.0 ? trial.midpoint_50_price : EMPTY_VALUE);
  row.Flag(MODEL_F_TRIALS_MIDPOINT_TOUCHED, trial.midpoint_touched);
  if(geometry)
  {
    row.Number(MODEL_F_TRIALS_SL, trial.geometry.stop_loss_price);
    row.Number(MODEL_F_TRIALS_TP, trial.geometry.take_profit_price);
    row.Number(MODEL_F_TRIALS_REQUESTED_RISK_DISTANCE_PRICE, trial.geometry.requested_risk_distance_price);
    row.Number(MODEL_F_TRIALS_REQUESTED_RISK_DISTANCE_POINTS, trial.geometry.requested_risk_distance_points);
    row.Number(MODEL_F_TRIALS_NORMALIZED_RISK_DISTANCE_PRICE, trial.geometry.normalized_risk_distance_price);
    row.Number(MODEL_F_TRIALS_NORMALIZED_RISK_DISTANCE_POINTS, trial.geometry.normalized_risk_distance_points);
    row.Number(MODEL_F_TRIALS_MINIMUM_RISK_DISTANCE_POINTS, trial.geometry.minimum_risk_distance_points);
    row.Integer(MODEL_F_TRIALS_NORMALIZED_RISK_TICKS, trial.geometry.normalized_risk_ticks);
    row.Set(MODEL_F_TRIALS_GEOMETRY_EQUIVALENCE_ID, trial.geometry.geometry_equivalence_id);
  }
  row.Number(MODEL_F_TRIALS_SPREAD_POINTS, trial.geometry.spread_points);
  row.Number(MODEL_F_TRIALS_POINT_SIZE, trial.geometry.point_size);
  row.Number(MODEL_F_TRIALS_TRADE_TICK_SIZE, trial.geometry.trade_tick_size);
  row.Number(MODEL_F_TRIALS_STOPS_LEVEL_POINTS, trial.geometry.stops_level_points);
  row.Number(MODEL_F_TRIALS_FREEZE_LEVEL_POINTS, trial.geometry.freeze_level_points);
  row.Flag(MODEL_F_TRIALS_DISTANCE_ELIGIBLE, geometry && trial.geometry.distance_eligible);
  row.Set(MODEL_F_TRIALS_LOT_MODE, EnumToString(Lot_Type));
  row.Number(MODEL_F_TRIALS_LOT_STRATEGY_SIZE, Lot_Strategy_Size);
  row.Number(MODEL_F_TRIALS_REFERENCE_BALANCE, Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT ? PIVOT_EXECUTION_REFERENCE_BALANCE : EMPTY_VALUE);
  row.Set(MODEL_F_TRIALS_ACCOUNT_CURRENCY, ModelSafeMetadata(AccountInfoString(ACCOUNT_CURRENCY)));
  if(trial.money_plan.complete)
  {
    row.Number(MODEL_F_TRIALS_VOLUME, trial.money_plan.normalized_volume);
    row.Number(MODEL_F_TRIALS_RISK_BUDGET_AMOUNT, trial.money_plan.risk_budget_amount);
    row.Number(MODEL_F_TRIALS_REQUESTED_VOLUME, trial.money_plan.requested_volume);
    row.Number(MODEL_F_TRIALS_VIRTUAL_EXPECTED_STOP_LOSS, trial.money_plan.virtual_expected_stop_loss);
    row.Number(MODEL_F_TRIALS_VIRTUAL_EXPECTED_TAKE_PROFIT, trial.money_plan.virtual_expected_take_profit);
    row.Number(MODEL_F_TRIALS_VIRTUAL_EXPECTED_REWARD_RISK_RATIO, trial.money_plan.virtual_expected_reward_risk_ratio);
  }
  row.Flag(MODEL_F_TRIALS_VIRTUAL_MONEY_PLAN_COMPLETE, trial.money_plan.complete);
  row.Flag(MODEL_F_TRIALS_ORIGIN_WINDOW_ACTIVE_AT_ENTRY, trial.origin_window_active_at_entry);
}

bool PivotDatasetRecordVirtualTrial(const PivotTrialEntry &trial)
{
  if(!ModelReady()) return false;
  bool parity = trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set(MODEL_F_TRIALS_TRIAL_ID, trial.identity.trial_id);
  row.Set(MODEL_F_TRIALS_ATTEMPT_ID, PivotDatasetAttemptId(trial.identity.origin_id));
  row.Set(MODEL_F_TRIALS_ROLE, parity ? "PARITY" : "VIRTUAL");
  row.Set(MODEL_F_TRIALS_ENTRY_POLICY, PivotTrialEntryPolicyLabel(trial.identity.entry_policy));
  row.Integer(MODEL_F_TRIALS_RR, trial.identity.tp_r_multiple);
  PivotDatasetClock(row, MODEL_F_TRIALS_DECLARED_TIME_MSC, trial.declared_time_msc, trial.declared_time);
  PivotDatasetClock(row, MODEL_F_TRIALS_ENTRY_TIME_MSC, trial.entry_time_msc, trial.entry_time);
  row.Set(MODEL_F_TRIALS_ELIGIBILITY, PivotDatasetEligibility(trial));
  row.Set(MODEL_F_TRIALS_REASON, ModelNullable(trial.ineligible_reason));
  PivotDatasetTrialGeometry(row, trial);
  return ModelWrite(row) && (!parity || PivotDatasetRegisterParityLink(trial));
}

void PivotDatasetOutcomeGeometry(ModelRow &row, const PivotTrialEntry &trial)
{
  if(trial.entry_time > 0)
  {
    PivotDatasetClock(row, MODEL_F_OUTCOMES_ENTRY_TIME_MSC, trial.entry_time_msc, trial.entry_time);
    row.Number(MODEL_F_OUTCOMES_ENTRY_PRICE, trial.geometry.entry_price > 0.0 ? trial.geometry.entry_price : EMPTY_VALUE);
  }
  if(trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE && trial.geometry.valid)
  {
    row.Number(MODEL_F_OUTCOMES_SL, trial.geometry.stop_loss_price);
    row.Number(MODEL_F_OUTCOMES_TP, trial.geometry.take_profit_price);
  }
  if(trial.money_plan.complete) row.Number(MODEL_F_OUTCOMES_VOLUME, trial.money_plan.normalized_volume);
}

bool PivotDatasetRecordVirtualOutcome(const PivotTrialOutcome &outcome)
{
  if(!ModelReady()) return false;
  bool parity = outcome.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  bool tp = outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_TP_FIRST;
  bool sl = outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_SL_FIRST;
  bool complete = tp || sl;
  string status = complete ? (tp ? "TP_FIRST" : "SL_FIRST") : "CENSORED_RUN_END";
  if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_NOT_TRIGGERED) status = "NOT_TRIGGERED";
  if(outcome.first_touch == PIVOT_TRIAL_FIRST_TOUCH_INELIGIBLE) status = PivotDatasetEligibility(outcome.trial);
  ModelRow row;
  row.Init(MODEL_OUTCOMES);
  row.Set(MODEL_F_OUTCOMES_TRIAL_ID, outcome.identity.trial_id);
  row.Set(MODEL_F_OUTCOMES_ATTEMPT_ID, PivotDatasetAttemptId(outcome.identity.origin_id));
  row.Set(MODEL_F_OUTCOMES_ROLE, parity ? "PARITY" : "VIRTUAL");
  row.Integer(MODEL_F_OUTCOMES_RR, outcome.identity.tp_r_multiple);
  row.Set(MODEL_F_OUTCOMES_STATUS, status);
  PivotDatasetClock(row, MODEL_F_OUTCOMES_OBSERVED_TIME_MSC, outcome.terminal_time_msc, outcome.terminal_time);
  PivotDatasetOutcomeGeometry(row, outcome.trial);
  row.Flag(MODEL_F_OUTCOMES_BINARY_ELIGIBLE, complete && !parity && outcome.virtual_binary_eligible);
  if(complete && !parity && outcome.virtual_binary_eligible) row.Integer(MODEL_F_OUTCOMES_BINARY_LABEL, outcome.virtual_binary_target);
  else row.Set(MODEL_F_OUTCOMES_EXCLUSION_REASON, parity ? "PARITY" : (outcome.virtual_exclusion_reason == "" ? status : outcome.virtual_exclusion_reason));
  row.Number(MODEL_F_OUTCOMES_OBSERVED_EXIT_BID, outcome.observed_exit_bid);
  row.Number(MODEL_F_OUTCOMES_OBSERVED_EXIT_ASK, outcome.observed_exit_ask);
  row.Number(MODEL_F_OUTCOMES_OBSERVED_EXIT_PRICE, outcome.observed_exit_price);
  row.Set(MODEL_F_OUTCOMES_EXIT_QUOTE_SIDE, PivotTrialQuoteSideLabel(outcome.exit_quote_side));
  row.Flag(MODEL_F_OUTCOMES_FIRST_TOUCH_CONSISTENT, outcome.first_touch_consistent);
  if(complete)
  {
    if(!outcome.virtual_quote_gross_available) return PivotDatasetRejectReference("VIRTUAL_PROFIT_UNAVAILABLE");
    PivotDatasetClock(row, MODEL_F_OUTCOMES_EXIT_TIME_MSC, outcome.terminal_time_msc, outcome.terminal_time);
    row.Number(MODEL_F_OUTCOMES_EXIT_PRICE, outcome.observed_exit_price);
    row.Number(MODEL_F_OUTCOMES_THRESHOLD_PRICE, outcome.threshold_price);
    row.Number(MODEL_F_OUTCOMES_GAP_POINTS, outcome.gap_points);
    row.Number(MODEL_F_OUTCOMES_NOMINAL_R, outcome.virtual_nominal_r);
    row.Number(MODEL_F_OUTCOMES_GROSS_PROFIT, outcome.virtual_quote_gross_profit);
    double direction = outcome.direction == BULLISH ? 1.0 : -1.0;
    double risk = direction * (outcome.trial.geometry.entry_price - outcome.trial.geometry.stop_loss_price);
    row.Number(MODEL_F_OUTCOMES_GROSS_R, risk > 0.0 ? direction * (outcome.observed_exit_price - outcome.trial.geometry.entry_price) / risk : EMPTY_VALUE);
    long entry = outcome.trial.entry_time_msc > 0 ? outcome.trial.entry_time_msc : (long)outcome.trial.entry_time * 1000;
    long closed = outcome.terminal_time_msc > 0 ? outcome.terminal_time_msc : (long)outcome.terminal_time * 1000;
    row.Integer(MODEL_F_OUTCOMES_DURATION_MS, closed - entry);
  }
  return ModelWrite(row) && (!parity || PivotDatasetLinkParityVirtualOutcome(outcome));
}

bool PivotDatasetRecordBrokerOutcome(const PivotSignal &signal, const bool run_end = false)
{
  if(!ModelReady() || !signal.execution.send_attempted) return false;
  PivotSignalExecution execution(signal.execution);
  bool entered = execution.broker_entry_confirmed;
  bool closed = execution.broker_close_confirmed;
  bool tp = closed && execution.terminal_reason == "BROKER_TP";
  bool sl = closed && execution.terminal_reason == "BROKER_SL";
  string status = closed ? (tp ? "TP_FIRST" : (sl ? "SL_FIRST" : "OTHER_CLOSE")) :
                  (run_end ? "CENSORED_RUN_END" : "REJECTED");
  ModelRow row;
  row.Init(MODEL_OUTCOMES);
  row.Set(MODEL_F_OUTCOMES_TRIAL_ID, PivotDatasetBrokerTrialId(signal.origin_id));
  row.Set(MODEL_F_OUTCOMES_ATTEMPT_ID, PivotDatasetAttemptId(signal.origin_id));
  row.Set(MODEL_F_OUTCOMES_ROLE, "BROKER");
  row.Integer(MODEL_F_OUTCOMES_RR, 1);
  row.Set(MODEL_F_OUTCOMES_STATUS, status);
  row.Set(MODEL_F_OUTCOMES_BROKER_REASON, ModelNullable(execution.terminal_reason));
  row.Clock(MODEL_F_OUTCOMES_OBSERVED_TIME_MSC, g_model_last_time);
  row.Number(MODEL_F_OUTCOMES_SL, execution.stop_loss_price);
  row.Number(MODEL_F_OUTCOMES_TP, execution.take_profit_price);
  row.Number(MODEL_F_OUTCOMES_VOLUME, execution.normalized_volume);
  row.Flag(MODEL_F_OUTCOMES_BINARY_ELIGIBLE, closed && execution.binary_eligible);
  if(closed && execution.binary_eligible) row.Integer(MODEL_F_OUTCOMES_BINARY_LABEL, execution.binary_target);
  else row.Set(MODEL_F_OUTCOMES_EXCLUSION_REASON, execution.exclusion_reason == "" ? status : execution.exclusion_reason);
  row.Flag(MODEL_F_OUTCOMES_BROKER_ENTRY_CONFIRMED, entered);
  row.Flag(MODEL_F_OUTCOMES_BROKER_CLOSE_CONFIRMED, closed);
  if(execution.order_ticket > 0) row.Integer(MODEL_F_OUTCOMES_ORDER_TICKET, (long)execution.order_ticket);
  if(execution.entry_deal_ticket > 0) row.Integer(MODEL_F_OUTCOMES_ENTRY_DEAL_TICKET, (long)execution.entry_deal_ticket);
  if(execution.position_ticket > 0) row.Integer(MODEL_F_OUTCOMES_POSITION_TICKET, (long)execution.position_ticket);
  if(execution.position_identifier > 0) row.Integer(MODEL_F_OUTCOMES_POSITION_ID, (long)execution.position_identifier);
  row.Number(MODEL_F_OUTCOMES_SUBMITTED_REQUEST_PRICE, execution.planned_entry_price);
  row.Number(MODEL_F_OUTCOMES_REQUEST_RISK_DISTANCE_POINTS, execution.risk_distance_points);
  row.Number(MODEL_F_OUTCOMES_REQUEST_REWARD_DISTANCE_POINTS, execution.reward_distance_points);
  row.Number(MODEL_F_OUTCOMES_REQUEST_PRICE_REWARD_RISK_RATIO, execution.price_reward_risk_ratio);
  row.Number(MODEL_F_OUTCOMES_QUOTE_EXPECTED_STOP_LOSS, execution.quote_expected_stop_loss);
  row.Number(MODEL_F_OUTCOMES_QUOTE_EXPECTED_TAKE_PROFIT, execution.quote_expected_take_profit);
  row.Number(MODEL_F_OUTCOMES_QUOTE_EXPECTED_REWARD_RISK_RATIO, execution.quote_expected_reward_risk_ratio);
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    row.Number(MODEL_F_OUTCOMES_RISK_BUDGET_AMOUNT, execution.risk_budget_amount);
    row.Number(MODEL_F_OUTCOMES_RISK_BUDGET_UTILIZATION_RATIO, execution.risk_budget_utilization_ratio);
  }
  if(entered)
  {
    PivotDatasetClock(row, MODEL_F_OUTCOMES_ENTRY_TIME_MSC, execution.broker_entry_time_msc, execution.broker_entry_time);
    row.Number(MODEL_F_OUTCOMES_ENTRY_PRICE, execution.broker_entry_price);
    row.Number(MODEL_F_OUTCOMES_FILL_DEVIATION_POINTS, (execution.broker_entry_price - execution.planned_entry_price) / _Point);
  }
  if(closed)
  {
    PivotDatasetClock(row, MODEL_F_OUTCOMES_EXIT_TIME_MSC, execution.close_time_msc, execution.close_time);
    row.Number(MODEL_F_OUTCOMES_EXIT_PRICE, execution.close_price);
    row.Integer(MODEL_F_OUTCOMES_LAST_CLOSE_DEAL_TICKET, (long)execution.last_close_deal_ticket);
    row.Integer(MODEL_F_OUTCOMES_CLOSE_DEAL_COUNT, execution.close_deal_count);
    row.Number(MODEL_F_OUTCOMES_BROKER_CLOSED_VOLUME, execution.closed_volume);
    row.Number(MODEL_F_OUTCOMES_GROSS_PROFIT, execution.gross_profit);
    row.Number(MODEL_F_OUTCOMES_COSTS, execution.commission + execution.swap + execution.fee);
    row.Number(MODEL_F_OUTCOMES_NET_PROFIT, execution.net_profit);
    row.Number(MODEL_F_OUTCOMES_BROKER_COMMISSION, execution.commission);
    row.Number(MODEL_F_OUTCOMES_BROKER_SWAP, execution.swap);
    row.Number(MODEL_F_OUTCOMES_BROKER_FEE, execution.fee);
    row.Number(MODEL_F_OUTCOMES_BROKER_NET_EXECUTION_R, execution.net_execution_r);
    row.Number(MODEL_F_OUTCOMES_EXIT_SLIPPAGE_POINTS, execution.exit_slippage_points);
    row.Flag(MODEL_F_OUTCOMES_CLOSE_REASON_CONSISTENT, execution.close_reason_consistent);
    if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
    {
      row.Number(MODEL_F_OUTCOMES_BROKER_GROSS_BUDGET_R, execution.gross_budget_r);
      row.Number(MODEL_F_OUTCOMES_BROKER_NET_BUDGET_R, execution.net_budget_r);
    }
    double direction = signal.direction == BULLISH ? 1.0 : -1.0;
    double risk = direction * (execution.broker_entry_price - execution.stop_loss_price);
    row.Number(MODEL_F_OUTCOMES_GROSS_R, risk > 0.0 ? direction * (execution.close_price - execution.broker_entry_price) / risk : EMPTY_VALUE);
    long entry = execution.broker_entry_time_msc > 0 ? execution.broker_entry_time_msc : (long)execution.broker_entry_time * 1000;
    long closed_at = execution.close_time_msc > 0 ? execution.close_time_msc : (long)execution.close_time * 1000;
    row.Integer(MODEL_F_OUTCOMES_DURATION_MS, closed_at - entry);
  }
  return ModelWrite(row) && (signal.parity_trial_id == "" || PivotDatasetLinkParityBrokerOutcome(signal));
}

bool PivotDatasetRecordBrokerTrial(const PivotSignal &signal, const BrokerExecutionCheck &check)
{
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set(MODEL_F_TRIALS_TRIAL_ID, PivotDatasetBrokerTrialId(signal.origin_id));
  row.Set(MODEL_F_TRIALS_ATTEMPT_ID, PivotDatasetAttemptId(signal.origin_id));
  row.Set(MODEL_F_TRIALS_ROLE, "BROKER");
  row.Set(MODEL_F_TRIALS_ENTRY_POLICY, "STRUCTURAL");
  row.Integer(MODEL_F_TRIALS_RR, 1);
  PivotDatasetClock(row, MODEL_F_TRIALS_DECLARED_TIME_MSC, check.broker_time_msc, check.broker_time);
  row.Number(MODEL_F_TRIALS_ENTRY_PRICE, check.planned_entry_price);
  row.Number(MODEL_F_TRIALS_SL, check.stop_loss_price);
  row.Number(MODEL_F_TRIALS_TP, check.take_profit_price);
  row.Number(MODEL_F_TRIALS_VOLUME, check.normalized_volume);
  row.Set(MODEL_F_TRIALS_ELIGIBILITY, check.allowed ? "ACCEPTED" : "REJECTED");
  row.Set(MODEL_F_TRIALS_REASON, ModelNullable(check.block_reason));
  if(!ModelWrite(row)) return false;
  return check.allowed || PivotDatasetRecordBrokerOutcome(signal);
}

bool PivotDatasetRecordExecutionCheck(const PivotSignal &signal, const BrokerExecutionCheck &check)
{
  if(!ModelReady()) return false;
  if(ArraySize(g_pivot_signals) > g_pivot_dataset_broker_peak) g_pivot_dataset_broker_peak = ArraySize(g_pivot_signals);
  bool send = check.phase == "SEND_RESULT" && signal.execution.send_attempted;
  bool entry = signal.execution.broker_entry_confirmed;
  bool closed = check.phase == "TERMINAL" && signal.execution.broker_close_confirmed;
  ModelRow row;
  row.Init(MODEL_EXECUTION_CHECKS);
  row.Set(MODEL_F_EXECUTION_CHECKS_CHECK_ID, signal.broker_signal_id + ":" + ModelInteger(check.sequence) + ":" + check.phase);
  row.Set(MODEL_F_EXECUTION_CHECKS_ATTEMPT_ID, PivotDatasetAttemptId(signal.origin_id));
  row.Set(MODEL_F_EXECUTION_CHECKS_ACTION, check.phase);
  PivotDatasetClock(row, MODEL_F_EXECUTION_CHECKS_TIME_MSC, check.broker_time_msc, check.broker_time);
  row.Integer(MODEL_F_EXECUTION_CHECKS_SEQUENCE, check.sequence);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ALLOWED, check.allowed);
  row.Set(MODEL_F_EXECUTION_CHECKS_REASON, check.block_reason == "" ? (check.allowed ? "ACCEPTED" : "NOT_ALLOWED") : check.block_reason);
  row.Number(MODEL_F_EXECUTION_CHECKS_VOLUME, check.normalized_volume);
  row.Number(MODEL_F_EXECUTION_CHECKS_ENTRY_PRICE, check.planned_entry_price);
  row.Number(MODEL_F_EXECUTION_CHECKS_SL, check.stop_loss_price);
  row.Number(MODEL_F_EXECUTION_CHECKS_TP, check.take_profit_price);
  row.Number(MODEL_F_EXECUTION_CHECKS_MARGIN, check.required_margin);
  row.Number(MODEL_F_EXECUTION_CHECKS_STOP_PROFIT, check.quote_expected_stop_loss);
  row.Integer(MODEL_F_EXECUTION_CHECKS_ACCOUNT_MARGIN_MODE, check.account_margin_mode);
  row.Integer(MODEL_F_EXECUTION_CHECKS_SYMBOL_TRADE_MODE, check.symbol_trade_mode);
  row.Number(MODEL_F_EXECUTION_CHECKS_BID, check.bid);
  row.Number(MODEL_F_EXECUTION_CHECKS_ASK, check.ask);
  row.Number(MODEL_F_EXECUTION_CHECKS_SPREAD_POINTS, check.spread_points);
  row.Number(MODEL_F_EXECUTION_CHECKS_POINT_SIZE, check.point_size);
  row.Number(MODEL_F_EXECUTION_CHECKS_TRADE_TICK_SIZE, check.trade_tick_size);
  row.Number(MODEL_F_EXECUTION_CHECKS_STOPS_DISTANCE_POINTS, check.stops_distance_points);
  row.Number(MODEL_F_EXECUTION_CHECKS_FREEZE_DISTANCE_POINTS, check.freeze_distance_points);
  row.Number(MODEL_F_EXECUTION_CHECKS_RISK_DISTANCE_POINTS, check.risk_distance_points);
  row.Number(MODEL_F_EXECUTION_CHECKS_REWARD_DISTANCE_POINTS, check.reward_distance_points);
  row.Number(MODEL_F_EXECUTION_CHECKS_REQUESTED_VOLUME, check.requested_volume);
  row.Number(MODEL_F_EXECUTION_CHECKS_VOLUME_MIN, check.volume_min);
  row.Number(MODEL_F_EXECUTION_CHECKS_VOLUME_MAX, check.volume_max);
  row.Number(MODEL_F_EXECUTION_CHECKS_VOLUME_STEP, check.volume_step);
  row.Number(MODEL_F_EXECUTION_CHECKS_QUOTE_EXPECTED_TAKE_PROFIT, check.quote_expected_take_profit);
  row.Number(MODEL_F_EXECUTION_CHECKS_QUOTE_EXPECTED_REWARD_RISK_RATIO, check.quote_expected_reward_risk_ratio);
  row.Number(MODEL_F_EXECUTION_CHECKS_ACCOUNT_BALANCE, check.account_balance);
  row.Number(MODEL_F_EXECUTION_CHECKS_FREE_MARGIN, check.free_margin);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ACCOUNT_MARGIN_MODE_SUPPORTED, check.account_margin_mode_supported);
  row.Flag(MODEL_F_EXECUTION_CHECKS_SYMBOL_TRADE_MODE_ALLOWED, check.symbol_trade_mode_allowed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_MARKET_SESSION_OPEN, check.market_session_open);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ACCOUNT_TRADE_ALLOWED, check.account_trade_allowed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ACCOUNT_EXPERT_TRADE_ALLOWED, check.account_expert_trade_allowed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_TERMINAL_TRADE_ALLOWED, check.terminal_trade_allowed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_MQL_TRADE_ALLOWED, check.mql_trade_allowed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_VOLUME_VALID, check.volume_valid);
  row.Flag(MODEL_F_EXECUTION_CHECKS_FOK_SUPPORTED, check.fok_supported);
  row.Flag(MODEL_F_EXECUTION_CHECKS_MARGIN_VALID, check.margin_valid);
  row.Flag(MODEL_F_EXECUTION_CHECKS_GEOMETRY_VALID, check.geometry_valid);
  row.Flag(MODEL_F_EXECUTION_CHECKS_STOP_DISTANCE_VALID, check.stop_distance_valid);
  row.Flag(MODEL_F_EXECUTION_CHECKS_FREEZE_DISTANCE_VALID, check.freeze_distance_valid);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ORDER_CHECK_PERFORMED, check.order_check_performed);
  row.Flag(MODEL_F_EXECUTION_CHECKS_ORDER_CHECK_ALLOWED, check.order_check_allowed);
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    row.Number(MODEL_F_EXECUTION_CHECKS_RISK_BUDGET_AMOUNT, check.risk_budget_amount);
    row.Number(MODEL_F_EXECUTION_CHECKS_RISK_BUDGET_UTILIZATION_RATIO, check.risk_budget_utilization_ratio);
  }
  row.Set(MODEL_F_EXECUTION_CHECKS_FILL_POLICY, "ORDER_FILLING_FOK");
  row.Set(MODEL_F_EXECUTION_CHECKS_ORDER_CHECK_COMMENT, ModelNullable(check.order_check_comment));
  row.Set(MODEL_F_EXECUTION_CHECKS_BLOCK_SOURCE, ModelNullable(check.block_source));
  if(check.order_check_performed) row.Integer(MODEL_F_EXECUTION_CHECKS_CHECK_RETCODE, (long)check.order_check_retcode);
  row.Flag(MODEL_F_EXECUTION_CHECKS_SEND_PERFORMED, send);
  row.Flag(MODEL_F_EXECUTION_CHECKS_SEND_SUCCEEDED, send && check.allowed);
  if(send)
  {
    row.Set(MODEL_F_EXECUTION_CHECKS_TRADE_ACTION, "TRADE_ACTION_DEAL");
    row.Integer(MODEL_F_EXECUTION_CHECKS_SEND_RETCODE, (long)check.send_retcode);
    row.Set(MODEL_F_EXECUTION_CHECKS_SEND_COMMENT, ModelNullable(check.send_comment));
  }
  ulong order = signal.execution.order_ticket > 0 ? signal.execution.order_ticket : check.order_ticket;
  ulong deal = closed ? signal.execution.last_close_deal_ticket : (entry ? signal.execution.entry_deal_ticket : check.deal_ticket);
  if(order > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_ORDER_TICKET, (long)order);
  if(deal > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_DEAL_TICKET, (long)deal);
  if(signal.execution.position_ticket > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_POSITION_TICKET, (long)signal.execution.position_ticket);
  if(signal.execution.position_identifier > 0) row.Integer(MODEL_F_EXECUTION_CHECKS_POSITION_ID, (long)signal.execution.position_identifier);
  row.Flag(MODEL_F_EXECUTION_CHECKS_BROKER_ENTRY_CONFIRMED, entry);
  row.Flag(MODEL_F_EXECUTION_CHECKS_BROKER_CLOSE_CONFIRMED, closed);
  if(entry)
  {
    row.Number(MODEL_F_EXECUTION_CHECKS_BROKER_ENTRY_PRICE, signal.execution.broker_entry_price);
    row.Number(MODEL_F_EXECUTION_CHECKS_BROKER_VOLUME, signal.execution.broker_volume);
    row.Number(MODEL_F_EXECUTION_CHECKS_BROKER_STOP_LOSS, signal.execution.broker_stop_loss);
    row.Number(MODEL_F_EXECUTION_CHECKS_BROKER_TAKE_PROFIT, signal.execution.broker_take_profit);
  }
  if(closed)
  {
    row.Number(MODEL_F_EXECUTION_CHECKS_CLOSE_PRICE, signal.execution.close_price);
    row.Number(MODEL_F_EXECUTION_CHECKS_CLOSED_VOLUME, signal.execution.closed_volume);
    row.Set(MODEL_F_EXECUTION_CHECKS_TERMINAL_REASON, ModelNullable(signal.execution.terminal_reason));
  }
  row.Flag(MODEL_F_EXECUTION_CHECKS_PROTECTION_MODIFIED, false);
  if(!ModelWrite(row)) return false;
  return !send || PivotDatasetRecordBrokerTrial(signal, check);
}

void DiscardFailedPivotResearch()
{
  if(!g_model_failed || g_pivot_dataset_research_discarded) return;
  g_pivot_dataset_research_discarded = true;
  ArrayFree(g_pivot_dataset_pending_origins);
  ArrayFree(g_pivot_dataset_parity_links);
  ArrayFree(g_pivot_trial_active_states);
  ModelReleaseBuffers();
  ModelCloseIndicators();
  PrintFormat("PIVOT_DATASET_RESEARCH_RELEASED | broker_states=%d", ArraySize(g_pivot_signals));
}

#endif
