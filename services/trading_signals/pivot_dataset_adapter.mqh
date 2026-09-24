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

void PivotDatasetClock(ModelRow &row, const string name, const long msc, const datetime seconds)
{
  if(msc > 0) row.Clock(name, msc);
  else if(seconds > 0) row.Clock(name, (long)seconds * 1000, true);
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
  row.Set("signal_id", signal.origin_id);
  row.Integer("sequence", g_model_sequence);
  row.Set("symbol", _Symbol);
  row.Set("direction", PivotDatasetDirection(signal.direction));
  PivotDatasetClock(row, "signal_time_msc", signal.trigger_time_msc, signal.trigger_time);
  row.Clock("source_time_msc", (long)signal.source_bar_open * 1000, true);
  row.Set("macro_window_id", signal.window_id);
  row.Number("bid", signal.trigger_bid);
  row.Number("ask", signal.trigger_ask);
  row.Set("admission", "DISCOVERED");
  if(!ModelWrite(row)) return false;
  row.Init(MODEL_ENTRY_ATTEMPTS);
  row.Set("attempt_id", PivotDatasetAttemptId(signal.origin_id));
  row.Set("signal_id", signal.origin_id);
  row.Set("snapshot_id", snapshot_id);
  row.Integer("sequence", g_model_sequence);
  row.Set("entry_type", "PIVOT_ORIGIN");
  row.Set("direction", PivotDatasetDirection(signal.direction));
  PivotDatasetClock(row, "decision_time_msc", signal.trigger_time_msc, signal.trigger_time);
  row.Set("macro_window_id", signal.window_id);
  row.Number("bid", signal.trigger_bid);
  row.Number("ask", signal.trigger_ask);
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
  row.Set("signal_id", origin.origin_id);
  row.Set("broker_signal_id", origin.broker_signal_id);
  row.Set("level_id", PivotLevelLabel(origin.level_id));
  row.Number("pivot_raw_price", origin.pivot_raw_price);
  row.Number("pivot_trade_price", origin.pivot_trade_price);
  row.Number("next_outward_pivot_price", origin.next_outward_pivot_price);
  row.Number("midpoint_50_price", origin.midpoint_50_price);
  row.Number("structural_entry_price", origin.structural_entry_price);
  row.Number("structural_take_profit", origin.structural_take_profit);
  row.Number("stops_level_points", origin.stops_level_points);
  row.Number("freeze_level_points", origin.freeze_level_points);
  row.Number("structural_sl_price", origin.structural_stop_loss);
  row.Flag("identity_consumed", true);
  row.Flag("h1_lanes_declared", pending.h1_lanes_declared);
  row.Set("broker_attempt_status", pending.broker_attempt_status);
  row.Set("origin_terminal_status", terminal_status);
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
    row.Number("entry_bid", trial.geometry.entry_bid);
    row.Number("entry_ask", trial.geometry.entry_ask);
    row.Number("entry_price", trial.geometry.entry_price > 0.0 ? trial.geometry.entry_price : EMPTY_VALUE);
    row.Set("entry_quote_side", PivotTrialQuoteSideLabel(trial.geometry.entry_quote_side));
    row.Set("exit_quote_side", PivotTrialQuoteSideLabel(trial.geometry.exit_quote_side));
  }
  row.Number("midpoint_50_price", trial.midpoint_50_price > 0.0 ? trial.midpoint_50_price : EMPTY_VALUE);
  row.Flag("midpoint_touched", trial.midpoint_touched);
  if(geometry)
  {
    row.Number("sl", trial.geometry.stop_loss_price);
    row.Number("tp", trial.geometry.take_profit_price);
    row.Number("requested_risk_distance_price", trial.geometry.requested_risk_distance_price);
    row.Number("requested_risk_distance_points", trial.geometry.requested_risk_distance_points);
    row.Number("normalized_risk_distance_price", trial.geometry.normalized_risk_distance_price);
    row.Number("normalized_risk_distance_points", trial.geometry.normalized_risk_distance_points);
    row.Number("minimum_risk_distance_points", trial.geometry.minimum_risk_distance_points);
    row.Integer("normalized_risk_ticks", trial.geometry.normalized_risk_ticks);
    row.Set("geometry_equivalence_id", trial.geometry.geometry_equivalence_id);
  }
  row.Number("spread_points", trial.geometry.spread_points);
  row.Number("point_size", trial.geometry.point_size);
  row.Number("trade_tick_size", trial.geometry.trade_tick_size);
  row.Number("stops_level_points", trial.geometry.stops_level_points);
  row.Number("freeze_level_points", trial.geometry.freeze_level_points);
  row.Flag("distance_eligible", geometry && trial.geometry.distance_eligible);
  row.Set("lot_mode", EnumToString(Lot_Type));
  row.Number("lot_strategy_size", Lot_Strategy_Size);
  row.Number("reference_balance", Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT ? PIVOT_EXECUTION_REFERENCE_BALANCE : EMPTY_VALUE);
  row.Set("account_currency", ModelSafeMetadata(AccountInfoString(ACCOUNT_CURRENCY)));
  if(trial.money_plan.complete)
  {
    row.Number("volume", trial.money_plan.normalized_volume);
    row.Number("risk_budget_amount", trial.money_plan.risk_budget_amount);
    row.Number("requested_volume", trial.money_plan.requested_volume);
    row.Number("virtual_expected_stop_loss", trial.money_plan.virtual_expected_stop_loss);
    row.Number("virtual_expected_take_profit", trial.money_plan.virtual_expected_take_profit);
    row.Number("virtual_expected_reward_risk_ratio", trial.money_plan.virtual_expected_reward_risk_ratio);
  }
  row.Flag("virtual_money_plan_complete", trial.money_plan.complete);
  row.Flag("origin_window_active_at_entry", trial.origin_window_active_at_entry);
}

bool PivotDatasetRecordVirtualTrial(const PivotTrialEntry &trial)
{
  if(!ModelReady()) return false;
  bool parity = trial.identity.role == PIVOT_TRIAL_ROLE_BROKER_PARITY;
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set("trial_id", trial.identity.trial_id);
  row.Set("attempt_id", PivotDatasetAttemptId(trial.identity.origin_id));
  row.Set("role", parity ? "PARITY" : "VIRTUAL");
  row.Set("entry_policy", PivotTrialEntryPolicyLabel(trial.identity.entry_policy));
  row.Integer("rr", trial.identity.tp_r_multiple);
  PivotDatasetClock(row, "declared_time_msc", trial.declared_time_msc, trial.declared_time);
  PivotDatasetClock(row, "entry_time_msc", trial.entry_time_msc, trial.entry_time);
  row.Set("eligibility", PivotDatasetEligibility(trial));
  row.Set("reason", ModelNullable(trial.ineligible_reason));
  PivotDatasetTrialGeometry(row, trial);
  return ModelWrite(row) && (!parity || PivotDatasetRegisterParityLink(trial));
}

void PivotDatasetOutcomeGeometry(ModelRow &row, const PivotTrialEntry &trial)
{
  if(trial.entry_time > 0)
  {
    PivotDatasetClock(row, "entry_time_msc", trial.entry_time_msc, trial.entry_time);
    row.Number("entry_price", trial.geometry.entry_price > 0.0 ? trial.geometry.entry_price : EMPTY_VALUE);
  }
  if(trial.eligibility_status == PIVOT_TRIAL_ELIGIBILITY_ACTIVE && trial.geometry.valid)
  {
    row.Number("sl", trial.geometry.stop_loss_price);
    row.Number("tp", trial.geometry.take_profit_price);
  }
  if(trial.money_plan.complete) row.Number("volume", trial.money_plan.normalized_volume);
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
  row.Set("trial_id", outcome.identity.trial_id);
  row.Set("attempt_id", PivotDatasetAttemptId(outcome.identity.origin_id));
  row.Set("role", parity ? "PARITY" : "VIRTUAL");
  row.Integer("rr", outcome.identity.tp_r_multiple);
  row.Set("status", status);
  PivotDatasetClock(row, "observed_time_msc", outcome.terminal_time_msc, outcome.terminal_time);
  PivotDatasetOutcomeGeometry(row, outcome.trial);
  row.Flag("binary_eligible", complete && !parity && outcome.virtual_binary_eligible);
  if(complete && !parity && outcome.virtual_binary_eligible) row.Integer("binary_label", outcome.virtual_binary_target);
  else row.Set("exclusion_reason", parity ? "PARITY" : (outcome.virtual_exclusion_reason == "" ? status : outcome.virtual_exclusion_reason));
  row.Number("observed_exit_bid", outcome.observed_exit_bid);
  row.Number("observed_exit_ask", outcome.observed_exit_ask);
  row.Number("observed_exit_price", outcome.observed_exit_price);
  row.Set("exit_quote_side", PivotTrialQuoteSideLabel(outcome.exit_quote_side));
  row.Flag("first_touch_consistent", outcome.first_touch_consistent);
  if(complete)
  {
    if(!outcome.virtual_quote_gross_available) return PivotDatasetRejectReference("VIRTUAL_PROFIT_UNAVAILABLE");
    PivotDatasetClock(row, "exit_time_msc", outcome.terminal_time_msc, outcome.terminal_time);
    row.Number("exit_price", outcome.observed_exit_price);
    row.Number("threshold_price", outcome.threshold_price);
    row.Number("gap_points", outcome.gap_points);
    row.Number("nominal_r", outcome.virtual_nominal_r);
    row.Number("gross_profit", outcome.virtual_quote_gross_profit);
    double direction = outcome.direction == BULLISH ? 1.0 : -1.0;
    double risk = direction * (outcome.trial.geometry.entry_price - outcome.trial.geometry.stop_loss_price);
    row.Number("gross_r", risk > 0.0 ? direction * (outcome.observed_exit_price - outcome.trial.geometry.entry_price) / risk : EMPTY_VALUE);
    long entry = outcome.trial.entry_time_msc > 0 ? outcome.trial.entry_time_msc : (long)outcome.trial.entry_time * 1000;
    long closed = outcome.terminal_time_msc > 0 ? outcome.terminal_time_msc : (long)outcome.terminal_time * 1000;
    row.Integer("duration_ms", closed - entry);
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
  row.Set("trial_id", PivotDatasetBrokerTrialId(signal.origin_id));
  row.Set("attempt_id", PivotDatasetAttemptId(signal.origin_id));
  row.Set("role", "BROKER");
  row.Integer("rr", 1);
  row.Set("status", status);
  row.Set("broker_reason", ModelNullable(execution.terminal_reason));
  row.Clock("observed_time_msc", g_model_last_time);
  row.Number("sl", execution.stop_loss_price);
  row.Number("tp", execution.take_profit_price);
  row.Number("volume", execution.normalized_volume);
  row.Flag("binary_eligible", closed && execution.binary_eligible);
  if(closed && execution.binary_eligible) row.Integer("binary_label", execution.binary_target);
  else row.Set("exclusion_reason", execution.exclusion_reason == "" ? status : execution.exclusion_reason);
  row.Flag("broker_entry_confirmed", entered);
  row.Flag("broker_close_confirmed", closed);
  if(execution.order_ticket > 0) row.Integer("order_ticket", (long)execution.order_ticket);
  if(execution.entry_deal_ticket > 0) row.Integer("entry_deal_ticket", (long)execution.entry_deal_ticket);
  if(execution.position_ticket > 0) row.Integer("position_ticket", (long)execution.position_ticket);
  if(execution.position_identifier > 0) row.Integer("position_id", (long)execution.position_identifier);
  row.Number("submitted_request_price", execution.planned_entry_price);
  row.Number("request_risk_distance_points", execution.risk_distance_points);
  row.Number("request_reward_distance_points", execution.reward_distance_points);
  row.Number("request_price_reward_risk_ratio", execution.price_reward_risk_ratio);
  row.Number("quote_expected_stop_loss", execution.quote_expected_stop_loss);
  row.Number("quote_expected_take_profit", execution.quote_expected_take_profit);
  row.Number("quote_expected_reward_risk_ratio", execution.quote_expected_reward_risk_ratio);
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    row.Number("risk_budget_amount", execution.risk_budget_amount);
    row.Number("risk_budget_utilization_ratio", execution.risk_budget_utilization_ratio);
  }
  if(entered)
  {
    PivotDatasetClock(row, "entry_time_msc", execution.broker_entry_time_msc, execution.broker_entry_time);
    row.Number("entry_price", execution.broker_entry_price);
    row.Number("fill_deviation_points", (execution.broker_entry_price - execution.planned_entry_price) / _Point);
  }
  if(closed)
  {
    PivotDatasetClock(row, "exit_time_msc", execution.close_time_msc, execution.close_time);
    row.Number("exit_price", execution.close_price);
    row.Integer("last_close_deal_ticket", (long)execution.last_close_deal_ticket);
    row.Integer("close_deal_count", execution.close_deal_count);
    row.Number("broker_closed_volume", execution.closed_volume);
    row.Number("gross_profit", execution.gross_profit);
    row.Number("costs", execution.commission + execution.swap + execution.fee);
    row.Number("net_profit", execution.net_profit);
    row.Number("broker_commission", execution.commission);
    row.Number("broker_swap", execution.swap);
    row.Number("broker_fee", execution.fee);
    row.Number("broker_net_execution_r", execution.net_execution_r);
    row.Number("exit_slippage_points", execution.exit_slippage_points);
    row.Flag("close_reason_consistent", execution.close_reason_consistent);
    if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
    {
      row.Number("broker_gross_budget_r", execution.gross_budget_r);
      row.Number("broker_net_budget_r", execution.net_budget_r);
    }
    double direction = signal.direction == BULLISH ? 1.0 : -1.0;
    double risk = direction * (execution.broker_entry_price - execution.stop_loss_price);
    row.Number("gross_r", risk > 0.0 ? direction * (execution.close_price - execution.broker_entry_price) / risk : EMPTY_VALUE);
    long entry = execution.broker_entry_time_msc > 0 ? execution.broker_entry_time_msc : (long)execution.broker_entry_time * 1000;
    long closed_at = execution.close_time_msc > 0 ? execution.close_time_msc : (long)execution.close_time * 1000;
    row.Integer("duration_ms", closed_at - entry);
  }
  return ModelWrite(row) && (signal.parity_trial_id == "" || PivotDatasetLinkParityBrokerOutcome(signal));
}

bool PivotDatasetRecordBrokerTrial(const PivotSignal &signal, const BrokerExecutionCheck &check)
{
  ModelRow row;
  row.Init(MODEL_TRIALS);
  row.Set("trial_id", PivotDatasetBrokerTrialId(signal.origin_id));
  row.Set("attempt_id", PivotDatasetAttemptId(signal.origin_id));
  row.Set("role", "BROKER");
  row.Set("entry_policy", "STRUCTURAL");
  row.Integer("rr", 1);
  PivotDatasetClock(row, "declared_time_msc", check.broker_time_msc, check.broker_time);
  row.Number("entry_price", check.planned_entry_price);
  row.Number("sl", check.stop_loss_price);
  row.Number("tp", check.take_profit_price);
  row.Number("volume", check.normalized_volume);
  row.Set("eligibility", check.allowed ? "ACCEPTED" : "REJECTED");
  row.Set("reason", ModelNullable(check.block_reason));
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
  row.Set("check_id", signal.broker_signal_id + ":" + ModelInteger(check.sequence) + ":" + check.phase);
  row.Set("attempt_id", PivotDatasetAttemptId(signal.origin_id));
  row.Set("action", check.phase);
  PivotDatasetClock(row, "time_msc", check.broker_time_msc, check.broker_time);
  row.Integer("sequence", check.sequence);
  row.Flag("allowed", check.allowed);
  row.Set("reason", check.block_reason == "" ? (check.allowed ? "ACCEPTED" : "NOT_ALLOWED") : check.block_reason);
  row.Number("volume", check.normalized_volume);
  row.Number("entry_price", check.planned_entry_price);
  row.Number("sl", check.stop_loss_price);
  row.Number("tp", check.take_profit_price);
  row.Number("margin", check.required_margin);
  row.Number("stop_profit", check.quote_expected_stop_loss);
  row.Integer("account_margin_mode", check.account_margin_mode);
  row.Integer("symbol_trade_mode", check.symbol_trade_mode);
  row.Number("bid", check.bid);
  row.Number("ask", check.ask);
  row.Number("spread_points", check.spread_points);
  row.Number("point_size", check.point_size);
  row.Number("trade_tick_size", check.trade_tick_size);
  row.Number("stops_distance_points", check.stops_distance_points);
  row.Number("freeze_distance_points", check.freeze_distance_points);
  row.Number("risk_distance_points", check.risk_distance_points);
  row.Number("reward_distance_points", check.reward_distance_points);
  row.Number("requested_volume", check.requested_volume);
  row.Number("volume_min", check.volume_min);
  row.Number("volume_max", check.volume_max);
  row.Number("volume_step", check.volume_step);
  row.Number("quote_expected_take_profit", check.quote_expected_take_profit);
  row.Number("quote_expected_reward_risk_ratio", check.quote_expected_reward_risk_ratio);
  row.Number("account_balance", check.account_balance);
  row.Number("free_margin", check.free_margin);
  row.Flag("account_margin_mode_supported", check.account_margin_mode_supported);
  row.Flag("symbol_trade_mode_allowed", check.symbol_trade_mode_allowed);
  row.Flag("market_session_open", check.market_session_open);
  row.Flag("account_trade_allowed", check.account_trade_allowed);
  row.Flag("account_expert_trade_allowed", check.account_expert_trade_allowed);
  row.Flag("terminal_trade_allowed", check.terminal_trade_allowed);
  row.Flag("mql_trade_allowed", check.mql_trade_allowed);
  row.Flag("volume_valid", check.volume_valid);
  row.Flag("fok_supported", check.fok_supported);
  row.Flag("margin_valid", check.margin_valid);
  row.Flag("geometry_valid", check.geometry_valid);
  row.Flag("stop_distance_valid", check.stop_distance_valid);
  row.Flag("freeze_distance_valid", check.freeze_distance_valid);
  row.Flag("order_check_performed", check.order_check_performed);
  row.Flag("order_check_allowed", check.order_check_allowed);
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    row.Number("risk_budget_amount", check.risk_budget_amount);
    row.Number("risk_budget_utilization_ratio", check.risk_budget_utilization_ratio);
  }
  row.Set("fill_policy", "ORDER_FILLING_FOK");
  row.Set("order_check_comment", ModelNullable(check.order_check_comment));
  row.Set("block_source", ModelNullable(check.block_source));
  if(check.order_check_performed) row.Integer("check_retcode", (long)check.order_check_retcode);
  row.Flag("send_performed", send);
  row.Flag("send_succeeded", send && check.allowed);
  if(send)
  {
    row.Set("trade_action", "TRADE_ACTION_DEAL");
    row.Integer("send_retcode", (long)check.send_retcode);
    row.Set("send_comment", ModelNullable(check.send_comment));
  }
  ulong order = signal.execution.order_ticket > 0 ? signal.execution.order_ticket : check.order_ticket;
  ulong deal = closed ? signal.execution.last_close_deal_ticket : (entry ? signal.execution.entry_deal_ticket : check.deal_ticket);
  if(order > 0) row.Integer("order_ticket", (long)order);
  if(deal > 0) row.Integer("deal_ticket", (long)deal);
  if(signal.execution.position_ticket > 0) row.Integer("position_ticket", (long)signal.execution.position_ticket);
  if(signal.execution.position_identifier > 0) row.Integer("position_id", (long)signal.execution.position_identifier);
  row.Flag("broker_entry_confirmed", entry);
  row.Flag("broker_close_confirmed", closed);
  if(entry)
  {
    row.Number("broker_entry_price", signal.execution.broker_entry_price);
    row.Number("broker_volume", signal.execution.broker_volume);
    row.Number("broker_stop_loss", signal.execution.broker_stop_loss);
    row.Number("broker_take_profit", signal.execution.broker_take_profit);
  }
  if(closed)
  {
    row.Number("close_price", signal.execution.close_price);
    row.Number("closed_volume", signal.execution.closed_volume);
    row.Set("terminal_reason", ModelNullable(signal.execution.terminal_reason));
  }
  row.Flag("protection_modified", false);
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
  for(int file = 0; file < MODEL_FILE_COUNT; file++) ArrayFree(g_model_buffers[file].rows);
  ModelCloseIndicators();
  PrintFormat("PIVOT_DATASET_RESEARCH_RELEASED | broker_states=%d", ArraySize(g_pivot_signals));
}

#endif
