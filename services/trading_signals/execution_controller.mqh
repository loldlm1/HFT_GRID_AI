#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_

bool ResolveDeterministicM1Rates(double &close_0_out,
                                 double &high_1_out,
                                 double &low_1_out)
{
  static long   cached_tick_msc = -1;
  static double cached_close_0 = 0.0;
  static double cached_high_1 = 0.0;
  static double cached_low_1 = 0.0;

  MqlTick latest_tick;
  long tick_msc = 0;
  if(SymbolInfoTick(_Symbol, latest_tick))
    tick_msc = (long)latest_tick.time_msc;

  if(tick_msc > 0 && tick_msc == cached_tick_msc)
  {
    close_0_out = cached_close_0;
    high_1_out  = cached_high_1;
    low_1_out   = cached_low_1;
    return (close_0_out > 0.0 && high_1_out > 0.0 && low_1_out > 0.0);
  }

  close_0_out = iClose(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 0);
  high_1_out  = iHigh(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1);
  low_1_out   = iLow(_Symbol, DETERMINISTIC_BASE_TIMEFRAME, 1);

  cached_tick_msc = tick_msc;
  cached_close_0  = close_0_out;
  cached_high_1   = high_1_out;
  cached_low_1    = low_1_out;

  return (close_0_out > 0.0 && high_1_out > 0.0 && low_1_out > 0.0);
}

double ResolveDeterministicTpPrice(const SignalTypes direction,
                                   const double entry_price,
                                   const double stop_anchor_price)
{
  if(entry_price <= 0.0 || stop_anchor_price <= 0.0)
    return 0.0;

  double risk_distance = MathAbs(entry_price - stop_anchor_price);
  if(risk_distance <= 0.0)
    return 0.0;

  double tp_factor = (TP_Percent > 0.0) ? (TP_Percent / 100.0) : 1.0;
  double tp_distance = risk_distance * tp_factor;

  if(direction == BULLISH)
    return entry_price + tp_distance;
  if(direction == BEARISH)
    return entry_price - tp_distance;

  return 0.0;
}

double ResolveDeterministicRMultipleTpPrice(const SignalTypes direction,
                                            const double entry_price,
                                            const double stop_anchor_price,
                                            const double r_multiple)
{
  if(entry_price <= 0.0 || stop_anchor_price <= 0.0 || r_multiple <= 0.0)
    return 0.0;

  double risk_distance = MathAbs(entry_price - stop_anchor_price);
  if(risk_distance <= 0.0)
    return 0.0;

  if(direction == BULLISH)
    return entry_price + risk_distance * r_multiple;
  if(direction == BEARISH)
    return entry_price - risk_distance * r_multiple;

  return 0.0;
}

double ResolveExecutionLegSetTotalVolume(const SignalParams &signal_params)
{
  double total_volume = 0.0;
  int total_legs = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(!state.opens_position)
      continue;
    if(state.lot_size > 0.0)
      total_volume += state.lot_size;
  }
  return total_volume;
}

bool AccountSupportsPartialTPHedging()
{
  long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  return (margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

bool ResolveDeterministicPartialLegVolumes(const double total_volume,
                                           double &volumes[],
                                           string &reason_out)
{
  reason_out = "";
  ArrayResize(volumes, PARTIAL_TP_LEVELS_TOTAL);
  for(int i = 0; i < PARTIAL_TP_LEVELS_TOTAL; i++)
    volumes[i] = 0.0;

  double normalized_total = NormalizeVolumeDownForSymbol(_Symbol, total_volume);
  if(normalized_total <= 0.0)
  {
    reason_out = "total_volume_invalid";
    return false;
  }

  double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  if(min_vol <= 0.0)
  {
    reason_out = "min_volume_invalid";
    return false;
  }

  double minimum_required = min_vol * PARTIAL_TP_LEVELS_TOTAL;
  if(normalized_total + EXECUTION_VOLUME_EPSILON < minimum_required)
  {
    reason_out = StringFormat("total_volume=%.4f<min_required=%.4f",
                              normalized_total,
                              minimum_required);
    return false;
  }

  double remaining = normalized_total;
  for(int level_index = 0; level_index < PARTIAL_TP_LEVELS_TOTAL - 1; level_index++)
  {
    int remaining_levels = PARTIAL_TP_LEVELS_TOTAL - level_index - 1;
    double min_remaining = min_vol * remaining_levels;
    double max_for_leg = remaining - min_remaining;
    if(max_for_leg + EXECUTION_VOLUME_EPSILON < min_vol)
    {
      reason_out = "remaining_volume_below_min";
      return false;
    }

    double requested = normalized_total * PartialTPVolumeFraction(level_index);
    double slice = NormalizeVolumeDownForSymbol(_Symbol, requested);
    if(slice + EXECUTION_VOLUME_EPSILON < min_vol)
      slice = min_vol;
    if(slice > max_for_leg + EXECUTION_VOLUME_EPSILON)
      slice = NormalizeVolumeDownForSymbol(_Symbol, max_for_leg);

    if(slice + EXECUTION_VOLUME_EPSILON < min_vol)
    {
      reason_out = "slice_volume_below_min";
      return false;
    }

    volumes[level_index] = slice;
    remaining -= slice;
  }

  double final_slice = NormalizeVolumeDownForSymbol(_Symbol, remaining);
  if(final_slice + EXECUTION_VOLUME_EPSILON < min_vol)
  {
    reason_out = "final_slice_below_min";
    return false;
  }
  volumes[PARTIAL_TP_LEVELS_TOTAL - 1] = final_slice;

  double assigned_total = 0.0;
  for(int i = 0; i < PARTIAL_TP_LEVELS_TOTAL; i++)
    assigned_total += volumes[i];

  if(assigned_total <= 0.0 ||
     assigned_total > normalized_total + EXECUTION_VOLUME_EPSILON)
  {
    reason_out = "assigned_volume_invalid";
    return false;
  }

  return true;
}

bool UpdateDeterministicPartialRiskTelemetry(SignalParams &signal_params,
                                             const double entry_reference,
                                             const double stop_anchor)
{
  double expected_sl_loss = 0.0;
  double expected_tp_profit = 0.0;
  double assigned_volume = 0.0;

  int total_legs = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(!state.opens_position || state.lot_size <= 0.0)
      continue;

    double sl_profit = 0.0;
    if(ResolveBrokerProfitForExecution(signal_params.signal_type,
                                       state.lot_size,
                                       entry_reference,
                                       stop_anchor,
                                       sl_profit))
      expected_sl_loss += MathAbs(sl_profit);

    double tp_profit = 0.0;
    if(ResolveBrokerProfitForExecution(signal_params.signal_type,
                                       state.lot_size,
                                       entry_reference,
                                       state.take_profit_price,
                                       tp_profit))
      expected_tp_profit += tp_profit;

    assigned_volume += state.lot_size;
  }

  if(assigned_volume <= 0.0)
    return false;

  if(signal_params.execution_risk_target_amount > 0.0 ||
     ResolveEffectiveExecutionLotType(Lot_Type) == EXECUTION_LOT_TARGET_CURRENCY)
  {
    signal_params.execution_risk_plan_valid = true;
	    signal_params.execution_risk_plan_reason = "partial_tp_legs_ok";
	    signal_params.execution_expected_sl_loss = expected_sl_loss;
	    signal_params.execution_expected_tp_profit = expected_tp_profit;
	    signal_params.execution_normalized_lot_size = assigned_volume;
	    if(signal_params.execution_risk_target_amount > 0.0)
	      signal_params.execution_target_error_amount =
	        signal_params.execution_risk_target_amount - expected_sl_loss;
	  }

  return true;
}

bool ConfigureDeterministicExecutionLegs(SignalParams &signal_params,
                                         const double entry_reference,
                                         const double stop_anchor,
                                         const double risk_points,
                                         const double planned_lot,
                                         string &reason_out)
{
  reason_out = "";
  if(entry_reference <= 0.0 || stop_anchor <= 0.0 || risk_points <= 0.0)
  {
    reason_out = "entry_stop_or_risk_invalid";
    return false;
  }

  if(!PartialTPEnabled())
  {
    double tp_price = ResolveDeterministicTpPrice(signal_params.signal_type,
                                                 entry_reference,
                                                 stop_anchor);
    if(planned_lot <= 0.0 || tp_price <= 0.0)
    {
      reason_out = "single_leg_lot_or_tp_invalid";
      return false;
    }

    ArrayResize(signal_params.execution_legs, 0);
    ExecutionLegState leg_state;
    leg_state.level_index               = 0;
    leg_state.status                    = EXECUTION_LEG_PENDING;
    leg_state.entry_style               = EXECUTION_ENTRY_STYLE_STOP;
    leg_state.entry_reference_price     = entry_reference;
    leg_state.next_level_price          = stop_anchor;
    leg_state.take_profit_price         = tp_price;
    leg_state.initial_take_profit_price = tp_price;
    leg_state.lot_size                  = planned_lot;
    leg_state.initial_lot_size          = planned_lot;
    leg_state.opens_position            = true;
    leg_state.limit_activation_armed    = true;
    AddElementToArray(signal_params.execution_legs, leg_state);

    signal_params.execution_base_lot_size = planned_lot;
    signal_params.raw_take_profit_price = tp_price;
    return true;
  }

  if(!AccountSupportsPartialTPHedging())
  {
    reason_out = "account_not_hedging";
    return false;
  }

  double volumes[];
  if(!ResolveDeterministicPartialLegVolumes(planned_lot,
                                            volumes,
                                            reason_out))
    return false;

  ArrayResize(signal_params.execution_legs, 0);
  double assigned_total = 0.0;
  for(int level_index = 0; level_index < PARTIAL_TP_LEVELS_TOTAL; level_index++)
  {
    double tp_price = ResolveDeterministicRMultipleTpPrice(signal_params.signal_type,
                                                          entry_reference,
                                                          stop_anchor,
                                                          PartialTPLevelR(level_index));
    if(tp_price <= 0.0 || volumes[level_index] <= 0.0)
    {
      reason_out = "partial_leg_tp_or_volume_invalid";
      return false;
    }

    ExecutionLegState leg_state;
    leg_state.level_index               = level_index;
    leg_state.status                    = EXECUTION_LEG_PENDING;
    leg_state.entry_style               = EXECUTION_ENTRY_STYLE_STOP;
    leg_state.entry_reference_price     = entry_reference;
    leg_state.next_level_price          = stop_anchor;
    leg_state.take_profit_price         = tp_price;
    leg_state.initial_take_profit_price = tp_price;
    leg_state.lot_size                  = volumes[level_index];
    leg_state.initial_lot_size          = volumes[level_index];
    leg_state.opens_position            = true;
    leg_state.limit_activation_armed    = true;
    AddElementToArray(signal_params.execution_legs, leg_state);
    assigned_total += volumes[level_index];
  }

  signal_params.execution_base_lot_size = assigned_total;
  signal_params.raw_take_profit_price =
    signal_params.execution_legs[PARTIAL_TP_LEVELS_TOTAL - 1].take_profit_price;
  UpdateDeterministicPartialRiskTelemetry(signal_params,
                                          entry_reference,
                                          stop_anchor);
  return true;
}

bool EnsureDeterministicExecutionLeg(SignalParams &signal_params)
{
  if(!signal_params.deterministic_strategy)
    return false;

  if(ArraySize(signal_params.execution_legs) > 0)
  {
    signal_params.execution_initialized = true;
    return true;
  }

  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double entry_reference = signal_params.raw_entry_trigger_price;
  double stop_anchor = signal_params.raw_stop_anchor_price;
  if(entry_reference <= 0.0 || stop_anchor <= 0.0)
    return false;

  double risk_points = MathAbs(entry_reference - stop_anchor) / point_size;
  risk_points = EnforceBrokerDistance(g_symbol_constraints, risk_points);
  if(risk_points <= 0.0)
    return false;

	  double planned_lot = ResolveBaseExecutionLot(risk_points);
	  if(ResolveEffectiveExecutionLotType(Lot_Type) == EXECUTION_LOT_TARGET_CURRENCY)
	  {
	    double risk_capped_lot = 0.0;
	    if(!ResolveRiskCappedTargetCurrencyLot(signal_params,
	                                           entry_reference,
	                                           stop_anchor,
	                                           ResolveDeterministicTpPrice(signal_params.signal_type,
	                                                                       entry_reference,
	                                                                       stop_anchor),
	                                           risk_capped_lot))
	      return false;
	    planned_lot = risk_capped_lot;
	  }

	  string configure_reason = "";
	  if(!ConfigureDeterministicExecutionLegs(signal_params,
	                                         entry_reference,
	                                         stop_anchor,
	                                         risk_points,
	                                         planned_lot,
	                                         configure_reason))
	  {
	    signal_params.admission_status = EXECUTION_ADMISSION_BLOCKED;
	    signal_params.admission_block_source = "execution_leg_config";
	    signal_params.admission_block_reason = configure_reason;
	    signal_params.admission_updated_time = TimeCurrent();
	    DeterministicSignalStatsRecordAdmissionEvent(signal_params, "admission_blocked");
	    return false;
	  }

	  signal_params.execution_initialized = true;
	  signal_params.execution_base_distance_points = risk_points;
	  signal_params.execution_initial_indicator_distance_points = risk_points;
	  signal_params.execution_resolved_distance_points = risk_points;
	  signal_params.execution_entry_reference_price = entry_reference;
	  signal_params.raw_risk_distance = MathAbs(entry_reference - stop_anchor);

	  ExecutionLogEvent("DETERMINISTIC_SIGNAL_INIT", signal_params, signal_params.execution_legs[0]);
	  return true;
	}

bool DeterministicEntryTriggered(const SignalTypes direction,
                                 const double close_0,
                                 const double trigger_price)
{
  if(trigger_price <= 0.0 || close_0 <= 0.0)
    return false;

  if(direction == BULLISH)
    return close_0 > trigger_price;
  if(direction == BEARISH)
    return close_0 < trigger_price;

  return false;
}

bool DeterministicStopTriggered(const SignalParams &signal_params,
                                const double close_0)
{
  if(close_0 <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return close_0 < signal_params.raw_stop_anchor_price;
  if(signal_params.signal_type == BEARISH)
    return close_0 > signal_params.raw_stop_anchor_price;

	  return false;
	}

bool DeterministicPendingStopInvalidated(const SignalParams &signal_params,
                                         const double close_0)
{
  if(signal_params.raw_stop_anchor_price <= 0.0)
    return false;

  double stop_side_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, false);
  if(stop_side_price <= 0.0)
    stop_side_price = close_0;
  if(stop_side_price <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return (stop_side_price <= signal_params.raw_stop_anchor_price);
  if(signal_params.signal_type == BEARISH)
    return (stop_side_price >= signal_params.raw_stop_anchor_price);

  return false;
}

bool CancelDeterministicPendingSignalAtStop(SignalParams &signal_params,
                                            const int leg_index,
                                            const double close_0)
{
  if(!signal_params.deterministic_strategy)
    return false;
  if(signal_params.signal_state == CLOSED)
    return false;
  if(DeterministicSignalHasBrokerExposure(signal_params))
    return false;
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(leg_state.status != EXECUTION_LEG_PENDING)
    return false;
  if(!DeterministicPendingStopInvalidated(signal_params, close_0))
    return false;

  int total_legs = ArraySize(signal_params.execution_legs);
  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(state.status == EXECUTION_LEG_PENDING ||
       state.status == EXECUTION_LEG_WAITING)
    {
      state.status = EXECUTION_LEG_COMPLETED;
      state.last_action_time = TimeCurrent();
      signal_params.execution_legs[i] = state;
    }
  }

  signal_params.signal_state = CLOSED;
  signal_params.deterministic_stats_terminal_reason = "PENDING_SL_INVALIDATED";
  signal_params.admission_status = EXECUTION_ADMISSION_BLOCKED;
  signal_params.admission_block_source = "pending_signal";
  signal_params.admission_block_reason = "stop_reached_before_entry";
  signal_params.admission_updated_time = TimeCurrent();
  ExecutionLogEvent("DETERMINISTIC_PENDING_SL_INVALIDATED",
                    signal_params,
                    leg_state);
  return true;
}

bool DeterministicTakeProfitTriggered(const SignalParams &signal_params,
                                      const ExecutionLegState &leg_state)
{
  if(leg_state.take_profit_price <= 0.0)
    return false;

  double exit_side_price = ExecutionCurrentPriceForDirection(signal_params.signal_type, false);
  if(exit_side_price <= 0.0)
    return false;

  if(signal_params.signal_type == BULLISH)
    return exit_side_price >= leg_state.take_profit_price;
  if(signal_params.signal_type == BEARISH)
    return exit_side_price <= leg_state.take_profit_price;

  return false;
}

bool DeterministicMacroStillConfirms(const SignalParams &signal_params)
{
  double macro_now = 0.0;
  double macro_prev = 0.0;
  return EvaluateDeterministicMacroConfirmation(signal_params.strategy_id,
                                                signal_params.signal_type,
                                                macro_now,
                                                macro_prev);
}

int ResolveDeterministicEntryBaseShift(const SignalParams &signal_params)
{
  int base_shift = signal_params.strategy_base_delay;
  if(base_shift <= 0)
    base_shift = DeterministicStrategyBaseDelay(signal_params.strategy_id);
  return base_shift;
}

double ResolveDeterministicPendingEntryCandidate(const SignalTypes direction,
                                                 const double high_1,
                                                 const double low_1)
{
  if(direction == BULLISH)
    return high_1;
  if(direction == BEARISH)
    return low_1;

  return 0.0;
}

bool DeterministicPendingEntryAnchorImproves(const SignalTypes direction,
                                            const double current_trigger,
                                            const double candidate_trigger,
                                            const double stop_anchor,
                                            const double point_size)
{
  if(current_trigger <= 0.0 || candidate_trigger <= 0.0 || stop_anchor <= 0.0)
    return false;

  double tolerance = point_size;
  if(tolerance <= 0.0)
    tolerance = 0.0000001;

  if(direction == BULLISH)
  {
    if(candidate_trigger <= stop_anchor + tolerance)
      return false;
    return (candidate_trigger < current_trigger - tolerance);
  }

  if(direction == BEARISH)
  {
    if(candidate_trigger >= stop_anchor - tolerance)
      return false;
    return (candidate_trigger > current_trigger + tolerance);
  }

  return false;
}

bool DeterministicPendingEntryRiskBrokerSafe(const double entry_trigger,
                                            const double stop_anchor,
                                            const double point_size,
                                            double &risk_points_out)
{
  risk_points_out = 0.0;

  if(entry_trigger <= 0.0 || stop_anchor <= 0.0 || point_size <= 0.0)
    return false;

  double raw_risk_points = MathAbs(entry_trigger - stop_anchor) / point_size;
  if(raw_risk_points <= 0.0)
    return false;

  double broker_safe_points = EnforceBrokerDistance(g_symbol_constraints,
                                                    raw_risk_points);
  if(broker_safe_points > raw_risk_points + 0.0000001)
    return false;

  risk_points_out = broker_safe_points;
  return (risk_points_out > 0.0);
}

bool RefreshDeterministicPendingEntryAnchor(SignalParams &signal_params,
                                            const int leg_index,
                                            const double close_0,
                                            const double high_1,
                                            const double low_1)
{
  if(!signal_params.deterministic_strategy)
    return false;
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return false;
  if(DeterministicSignalHasBrokerExposure(signal_params))
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(leg_state.status != EXECUTION_LEG_PENDING)
    return false;
  if(leg_state.position_ticket > 0 || leg_state.entry_price > 0.0)
    return false;

  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return false;

  double current_trigger = signal_params.raw_entry_trigger_price;
  if(current_trigger <= 0.0)
    current_trigger = leg_state.entry_reference_price;

  double stop_anchor = signal_params.raw_stop_anchor_price;
  double candidate_trigger = ResolveDeterministicPendingEntryCandidate(signal_params.signal_type,
                                                                      high_1,
                                                                      low_1);
  if(!DeterministicPendingEntryAnchorImproves(signal_params.signal_type,
                                             current_trigger,
                                             candidate_trigger,
                                             stop_anchor,
                                             point_size))
    return false;

  double risk_before_points = MathAbs(current_trigger - stop_anchor) / point_size;
  double risk_after_points = 0.0;
  if(!DeterministicPendingEntryRiskBrokerSafe(candidate_trigger,
                                             stop_anchor,
                                             point_size,
                                             risk_after_points))
    return false;

	  double tp_price = ResolveDeterministicTpPrice(signal_params.signal_type,
	                                               candidate_trigger,
	                                               stop_anchor);
	  if(tp_price <= 0.0)
	    return false;

	  double lot_size = ResolveBaseExecutionLot(risk_after_points);
  if(ResolveEffectiveExecutionLotType(Lot_Type) == EXECUTION_LOT_TARGET_CURRENCY)
  {
    if(!ResolveRiskCappedTargetCurrencyLot(signal_params,
                                           candidate_trigger,
                                           stop_anchor,
                                           tp_price,
                                           lot_size))
      return false;
  }
	  if(lot_size <= 0.0)
	    return false;

	  double tp_before = leg_state.take_profit_price;
	  double lot_before = PartialTPEnabled()
	                      ? ResolveExecutionLegSetTotalVolume(signal_params)
	                      : leg_state.lot_size;

	  signal_params.raw_entry_trigger_price = candidate_trigger;
	  signal_params.entry_price = candidate_trigger;
	  signal_params.stop_loss = stop_anchor;
	  signal_params.execution_entry_reference_price = candidate_trigger;
  signal_params.execution_base_distance_points = risk_after_points;
  signal_params.execution_initial_indicator_distance_points = risk_after_points;
  signal_params.execution_resolved_distance_points = risk_after_points;
	  signal_params.execution_base_lot_size = lot_size;
	  signal_params.raw_risk_distance = MathAbs(candidate_trigger - stop_anchor);
	  signal_params.raw_take_profit_price = tp_price;

	  string configure_reason = "";
	  if(!ConfigureDeterministicExecutionLegs(signal_params,
	                                         candidate_trigger,
	                                         stop_anchor,
	                                         risk_after_points,
	                                         lot_size,
	                                         configure_reason))
	    return false;

	  ExecutionLegState refreshed_leg_state = signal_params.execution_legs[leg_index];

	  ExecutionLogDeterministicEntryRefresh(signal_params,
	                                        refreshed_leg_state,
	                                        current_trigger,
	                                        candidate_trigger,
	                                        candidate_trigger,
                                        close_0,
                                        high_1,
                                        low_1,
	                                        risk_before_points,
	                                        risk_after_points,
	                                        tp_before,
	                                        refreshed_leg_state.take_profit_price,
	                                        lot_before,
	                                        signal_params.execution_base_lot_size,
	                                        "closer_to_stop");
	  return true;
	}

void RefreshDeterministicTpFromBrokerEntry(SignalParams &signal_params,
                                           const int leg_index)
{
  if(PartialTPEnabled())
    return;

  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  double entry_price = leg_state.entry_price;
  if(entry_price <= 0.0)
    entry_price = leg_state.entry_reference_price;

  double tp_price = ResolveDeterministicTpPrice(signal_params.signal_type,
                                                entry_price,
                                                signal_params.raw_stop_anchor_price);
  if(tp_price <= 0.0)
    return;

  leg_state.take_profit_price = tp_price;
  leg_state.initial_take_profit_price = tp_price;
  signal_params.raw_take_profit_price = tp_price;
  signal_params.execution_legs[leg_index] = leg_state;
}

bool PrepareDeterministicPendingEntryAdmission(SignalParams &signal_params,
                                               const int leg_index,
                                               const double close_0,
                                               const double high_1,
                                               const double low_1,
                                               ExecutionLegState &leg_state_out,
                                               ExecutionLegTradeAdmissionContext &admission_context_out)
{
  leg_state_out = ExecutionLegState();
  admission_context_out = ExecutionLegTradeAdmissionContext();

  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return false;

  RefreshDeterministicPendingEntryAnchor(signal_params,
                                         leg_index,
                                         close_0,
                                         high_1,
                                         low_1);

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(leg_state.status != EXECUTION_LEG_PENDING)
    return false;

  if(!DeterministicEntryTriggered(signal_params.signal_type,
                                  close_0,
                                  signal_params.raw_entry_trigger_price))
    return false;

  double current_entry_anchor = ResolveDeterministicPendingEntryCandidate(signal_params.signal_type,
                                                                         high_1,
                                                                         low_1);
  if(!DeterministicEntryTriggered(signal_params.signal_type,
                                  close_0,
                                  current_entry_anchor))
  {
    ExecutionLogDeterministicEntryAnchorBlocked(signal_params,
                                                leg_state,
                                                close_0,
                                                high_1,
                                                low_1,
                                                current_entry_anchor,
                                                "current_anchor_not_broken");
    return false;
  }

  double base_ma_now = 0.0;
  double base_ma_prev = 0.0;
  double macro_ma_now = 0.0;
  double macro_ma_prev = 0.0;
  int base_shift = ResolveDeterministicEntryBaseShift(signal_params);
  bool base_confirms = EvaluateDeterministicCurrentBaseConfirmation(signal_params.strategy_id,
                                                                    signal_params.signal_type,
                                                                    base_ma_now,
                                                                    base_ma_prev);
  bool macro_confirms = EvaluateDeterministicMacroConfirmation(signal_params.strategy_id,
                                                               signal_params.signal_type,
                                                               macro_ma_now,
                                                               macro_ma_prev);

  if(!base_confirms)
  {
    leg_state.status = EXECUTION_LEG_COMPLETED;
    signal_params.execution_legs[leg_index] = leg_state;
    signal_params.signal_state = CLOSED;
    ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_BASE_EXPIRED",
                                               signal_params,
                                               leg_state,
                                               base_shift,
                                               base_confirms,
                                               base_ma_now,
                                               base_ma_prev,
                                               DETERMINISTIC_MACRO_DELAY,
                                               macro_confirms,
                                               macro_ma_now,
                                               macro_ma_prev,
                                               close_0,
                                               high_1,
                                               low_1);
    return false;
  }

  if(!macro_confirms)
  {
    leg_state.status = EXECUTION_LEG_COMPLETED;
    signal_params.execution_legs[leg_index] = leg_state;
    signal_params.signal_state = CLOSED;
    ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_MACRO_EXPIRED",
                                               signal_params,
                                               leg_state,
                                               base_shift,
                                               base_confirms,
                                               base_ma_now,
                                               base_ma_prev,
                                               DETERMINISTIC_MACRO_DELAY,
                                               macro_confirms,
                                               macro_ma_now,
                                               macro_ma_prev,
                                               close_0,
                                               high_1,
                                               low_1);
    return false;
  }

  ExecutionLogDeterministicEntryConfirmation("DETERMINISTIC_ENTRY_CONFIRM",
                                             signal_params,
                                             leg_state,
                                             base_shift,
                                             base_confirms,
                                             base_ma_now,
                                             base_ma_prev,
                                             DETERMINISTIC_MACRO_DELAY,
                                             macro_confirms,
                                             macro_ma_now,
                                             macro_ma_prev,
                                             close_0,
                                             high_1,
                                             low_1);

  double requested_lot = leg_state.lot_size;
  double normalized_volume = NormalizeVolumeForSymbol(_Symbol, requested_lot);
  double point_size = ExecutionResolvePointSize();
  if(!PrepareExecutionLegTradeAdmission(signal_params,
                                        leg_state,
                                        point_size,
                                        normalized_volume,
                                        admission_context_out))
    return false;

  string ml_filter_block_reason = "";
  if(!DeterministicSignalMLFilterAllowsEntry(signal_params,
                                             leg_state,
                                             ml_filter_block_reason))
  {
    leg_state.status = EXECUTION_LEG_COMPLETED;
    leg_state.last_action_time = TimeCurrent();
    signal_params.execution_legs[leg_index] = leg_state;
    signal_params.signal_state = CLOSED;
    signal_params.deterministic_stats_terminal_reason = "ML_FILTER_BLOCKED";
    ExecutionLogGuardrailBlock("ML_FILTER_BLOCKED",
                               signal_params,
                               leg_state,
                               ml_filter_block_reason);
    return false;
  }

	  leg_state_out = signal_params.execution_legs[leg_index];
	  return true;
	}

bool ApplyDeterministicPartialPreparedEntryAdmission(SignalParams &signal_params)
{
  int total_legs = ArraySize(signal_params.execution_legs);
  if(total_legs != PARTIAL_TP_LEVELS_TOTAL)
  {
    signal_params.admission_status = EXECUTION_ADMISSION_BLOCKED;
    signal_params.admission_block_source = "partial_tp_legs";
    signal_params.admission_block_reason = "leg_count_invalid";
    signal_params.admission_updated_time = TimeCurrent();
    DeterministicSignalStatsRecordAdmissionEvent(signal_params, "admission_blocked");
    return false;
  }

  ExecutionLegTradeAdmissionContext contexts[];
  ArrayResize(contexts, total_legs);
  double point_size = ExecutionResolvePointSize();
  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(state.status != EXECUTION_LEG_PENDING ||
       !state.opens_position ||
       state.lot_size <= 0.0)
    {
      signal_params.admission_status = EXECUTION_ADMISSION_BLOCKED;
      signal_params.admission_block_source = "partial_tp_legs";
      signal_params.admission_block_reason =
        StringFormat("leg_%d_not_ready", i + 1);
      signal_params.admission_updated_time = TimeCurrent();
      DeterministicSignalStatsRecordAdmissionEvent(signal_params, "admission_blocked");
      return false;
    }

    double normalized_volume = state.lot_size;
    if(!PrepareExecutionLegTradeAdmission(signal_params,
                                          state,
                                          point_size,
                                          normalized_volume,
                                          contexts[i]))
      return false;
  }

  for(int i = 0; i < total_legs; i++)
  {
    ExecutionLegState state = signal_params.execution_legs[i];
    if(ApplyExecutionLegTradeAdmission(signal_params,
                                       state,
                                       contexts[i]))
      continue;

    signal_params.deterministic_stats_terminal_reason = "PARTIAL_TP_ENTRY_FAILED";
    CloseAllExecutionLegs(signal_params, point_size);
    signal_params.signal_state = CLOSED;
    ExecutionLogGuardrailBlock("PARTIAL_TP_ENTRY_FAILED",
                               signal_params,
                               state,
                               StringFormat("failed_leg=%d", i + 1));
    return false;
  }

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);
  return true;
}

bool ApplyDeterministicPreparedEntryAdmission(SignalParams &signal_params,
                                              const int leg_index,
                                              ExecutionLegState &leg_state,
                                              const ExecutionLegTradeAdmissionContext &admission_context)
{
  string pattern_filter_block_reason = "";
  if(!PatternAuditSelectedAdmissionAllowsEntry(signal_params,
                                               leg_state,
                                               pattern_filter_block_reason))
  {
    leg_state.status = EXECUTION_LEG_COMPLETED;
    leg_state.last_action_time = TimeCurrent();
    signal_params.execution_legs[leg_index] = leg_state;
    signal_params.signal_state = CLOSED;
    signal_params.deterministic_stats_terminal_reason = "PATTERN_AUDIT_FILTER_BLOCKED";
    ExecutionLogGuardrailBlock("PATTERN_AUDIT_FILTER_BLOCKED",
                               signal_params,
                               leg_state,
                               pattern_filter_block_reason);
	    return false;
	  }

	  bool entry_applied = false;
	  int feature_leg_index = leg_index;
	  if(PartialTPEnabled())
	  {
	    entry_applied = ApplyDeterministicPartialPreparedEntryAdmission(signal_params);
	    feature_leg_index = 0;
	  }
	  else
	  {
	    entry_applied = ApplyExecutionLegTradeAdmission(signal_params,
	                                                   leg_state,
	                                                   admission_context);
	    if(entry_applied)
	      RefreshDeterministicTpFromBrokerEntry(signal_params, leg_index);
	  }

	  if(!entry_applied)
	    return false;

	  DeterministicSignalStatsRecordFeature(signal_params,
	                                        signal_params.execution_legs[feature_leg_index]);
	  PatternAuditPlaybackRecordSignal(signal_params,
	                                   signal_params.execution_legs[feature_leg_index]);
	  DeterministicSignalMLShadowRecordPrediction(signal_params,
	                                              signal_params.execution_legs[feature_leg_index]);
	  ExecutionLogEvent("DETERMINISTIC_ENTRY", signal_params, signal_params.execution_legs[feature_leg_index]);
	  return true;
	}

void UpdateDeterministicActiveExecutionLifecycle(SignalParams &signal_params,
                                                 const int leg_index,
                                                 const double close_0)
{
  if(leg_index < 0 || leg_index >= ArraySize(signal_params.execution_legs))
    return;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  if(leg_state.status != EXECUTION_LEG_ACTIVE)
    return;

  if(DeterministicStopTriggered(signal_params, close_0))
  {
    CloseAllExecutionLegs(signal_params, ExecutionResolvePointSize());
    signal_params.deterministic_stats_terminal_reason = "SL";
    ExecutionLogEvent("DETERMINISTIC_SL", signal_params, leg_state);
    return;
  }

	  if(PartialTPEnabled())
	  {
	    if(IsExecutionSignalComplete(signal_params))
	      signal_params.signal_state = CLOSED;
	    return;
	  }

  if(DeterministicTakeProfitTriggered(signal_params, leg_state))
  {
    CloseAllExecutionLegs(signal_params, ExecutionResolvePointSize());
    signal_params.deterministic_stats_terminal_reason = "TP";
    int source_attempt_count = 0;
    bool newly_consumed = RegisterDeterministicSourceConsumedTp(signal_params,
                                                               source_attempt_count);
    ExecutionLogEvent("DETERMINISTIC_TP", signal_params, leg_state);
    if(newly_consumed)
    {
      ExecutionLogDeterministicSourceConsumed(signal_params,
                                              leg_state,
                                              source_attempt_count,
                                              "TP");
    }
    return;
  }

  if(IsExecutionSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

void UpdateDeterministicExecutionLifecycle(SignalParams &signal_params)
{
  if(signal_params.signal_state == CLOSED)
    return;

  if(!EnsureDeterministicExecutionLeg(signal_params))
  {
    signal_params.signal_state = CLOSED;
    return;
  }

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);

  int leg_index = 0;
  if(ArraySize(signal_params.execution_legs) <= leg_index)
    return;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  double close_0 = 0.0;
  double high_1 = 0.0;
  double low_1 = 0.0;
  if(!ResolveDeterministicM1Rates(close_0, high_1, low_1))
    return;

	  if(leg_state.status == EXECUTION_LEG_PENDING)
	  {
	    if(CancelDeterministicPendingSignalAtStop(signal_params,
	                                             leg_index,
	                                             close_0))
	      return;

	    ExecutionLegTradeAdmissionContext admission_context;
	    if(!PrepareDeterministicPendingEntryAdmission(signal_params,
	                                                  leg_index,
                                                  close_0,
                                                  high_1,
                                                  low_1,
                                                  leg_state,
                                                  admission_context))
      return;

    ApplyDeterministicPreparedEntryAdmission(signal_params,
                                             leg_index,
                                             leg_state,
                                             admission_context);
    return;
  }

  UpdateDeterministicActiveExecutionLifecycle(signal_params, leg_index, close_0);
}

bool UpdateDeterministicExecutionLifecycleForMLArbitration(SignalParams &signal_params,
                                                           const int direction_array,
                                                           const int signal_index,
                                                           const datetime activation_time,
                                                           MLArbitrationCandidate &candidate_out)
{
  candidate_out = MLArbitrationCandidate();

  if(signal_params.signal_state == CLOSED)
    return false;

  if(!signal_params.deterministic_strategy)
  {
    UpdateExecutionLifecycle(signal_params);
    return false;
  }

  if(!EnsureDeterministicExecutionLeg(signal_params))
  {
    signal_params.signal_state = CLOSED;
    return false;
  }

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);

  int leg_index = 0;
  if(ArraySize(signal_params.execution_legs) <= leg_index)
    return false;

  ExecutionLegState leg_state = signal_params.execution_legs[leg_index];
  double close_0 = 0.0;
  double high_1 = 0.0;
  double low_1 = 0.0;
  if(!ResolveDeterministicM1Rates(close_0, high_1, low_1))
    return false;

	  if(leg_state.status == EXECUTION_LEG_PENDING)
	  {
	    if(CancelDeterministicPendingSignalAtStop(signal_params,
	                                             leg_index,
	                                             close_0))
	      return false;

	    ExecutionLegTradeAdmissionContext admission_context;
	    if(!PrepareDeterministicPendingEntryAdmission(signal_params,
	                                                  leg_index,
                                                  close_0,
                                                  high_1,
                                                  low_1,
                                                  leg_state,
                                                  admission_context))
      return false;

    return MLArbitrationBuildCandidate(signal_params,
                                       leg_state,
                                       admission_context,
                                       direction_array,
                                       signal_index,
                                       leg_index,
                                       activation_time,
                                       candidate_out);
  }

  UpdateDeterministicActiveExecutionLifecycle(signal_params, leg_index, close_0);
  return false;
}

void UpdateExecutionLifecycle(SignalParams &signal_params)
{
  if(signal_params.deterministic_strategy)
  {
    UpdateDeterministicExecutionLifecycle(signal_params);
    return;
  }

  if(!signal_params.execution_initialized)
  {
    return;
  }
  if(signal_params.signal_state == CLOSED)
    return;

  ReconcileSignalBrokerPositions(signal_params);
  RefreshSignalExposureState(signal_params);

  double         point_size        = ExecutionResolvePointSize();
  SignalTypes    direction         = signal_params.signal_type;
  int            execution_leg_index  = ArraySize(signal_params.execution_legs)-1;
  ExecutionLegState execution_leg        = signal_params.execution_legs[execution_leg_index];

  if(LimitSignalExpiredOnStructureChange(signal_params))
  {
    signal_params.signal_state = CLOSED;
    ExecutionLogEvent("LIMIT_EXPIRED_STRUCTURE", signal_params, execution_leg);
    return;
  }

  if(execution_leg.status == EXECUTION_LEG_PENDING)
  {
    if(UpdateExecutionLegForSignal(signal_params))
      execution_leg = signal_params.execution_legs[execution_leg_index];

    double requested_lot = execution_leg.lot_size;
    double normalized_volume = 0.0;
    if(execution_leg.opens_position && requested_lot > 0.0)
      normalized_volume = NormalizeVolumeForSymbol(_Symbol, requested_lot);
    double entry_side_price = ExecutionCurrentPriceForDirection(direction, true);
    bool use_limit_edge_activation = UsesNonBreakoutLimitEdgeActivation(signal_params, execution_leg);

    if(use_limit_edge_activation && !execution_leg.limit_activation_armed)
    {
      if(ShouldArmNonBreakoutLimitActivation(signal_params, execution_leg, entry_side_price))
      {
        execution_leg.limit_activation_armed = true;
        signal_params.execution_legs[execution_leg_index] = execution_leg;
        ExecutionLogEvent("LIMIT_EDGE_ARMED", signal_params, execution_leg);
      }
    }

    bool can_activate = (!use_limit_edge_activation || execution_leg.limit_activation_armed);
    if(can_activate &&
       ExecutionShouldActivateStopLeg(signal_params, execution_leg, direction))
    {
      if(execution_leg.opens_position &&
         ExecutionUsesTargetProfitLotMode() &&
         requested_lot <= 0.0)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_ACTIVATION_FAILED_TARGET_LOT", signal_params, execution_leg);
        return;
      }

      if(ExecuteExecutionLegTrade(signal_params, execution_leg, point_size, normalized_volume))
      {
        UpdateExecutionLegForSignal(signal_params);
        execution_leg = signal_params.execution_legs[execution_leg_index];
        ExecutionLogEvent("LEVEL_REACHED", signal_params, execution_leg);
      }
      else if(execution_leg.opens_position && ExecutionUsesTargetProfitLotMode())
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_ACTIVATION_FAILED_SEND", signal_params, execution_leg);
        return;
      }
    }
  }

  execution_leg = signal_params.execution_legs[execution_leg_index];

  if(execution_leg.status == EXECUTION_LEG_ACTIVE)
  {
    double current_price = ExecutionCurrentPriceForDirection(direction, false);
    if(execution_leg.take_profit_price > 0.0)
    {
      bool hit_tp = (direction == BULLISH && current_price >= execution_leg.take_profit_price) ||
                    (direction == BEARISH && current_price <= execution_leg.take_profit_price);
      if(hit_tp)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("LEVEL_TP_HIT", signal_params, execution_leg);
        return;
      }
    }
    bool next_level_triggered = ExecutionShouldActivateNextLegLimit(signal_params,
                                                                 execution_leg,
                                                                 direction);
    if(next_level_triggered)
    {
      ExecutionLogNextLegTriggerDecision(signal_params, execution_leg, direction);
      int level_stop_limit = ResolveFoundationLevelStopLimit();
      bool level_limit_hit = ShouldBlockNextLevelByStopLimit(level_stop_limit,
                                                             execution_leg.level_index);
      ExecutionLogStopLimitDecision(signal_params,
                               execution_leg,
                               level_stop_limit,
                               level_limit_hit);

      if(level_limit_hit)
      {
        CloseAllExecutionLegs(signal_params, point_size);
        ExecutionLogEvent("EXECUTION_STOP_LEVEL_LIMIT", signal_params, execution_leg);
      }
      else
      {
        BuildExecutionLegForSignal(signal_params);
        ExecutionLogEvent("NEXT_LEVEL_ACTIVATED", signal_params, execution_leg);
      }
    }
  }

  if(IsExecutionSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_CONTROLLER_MQH_
