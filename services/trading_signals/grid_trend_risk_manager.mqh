#ifndef _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_

bool GridTrendSarAlligatorBreach(const SignalTypes direction,
                                 const ENUM_TIMEFRAMES target_tf,
                                 const GridRiskTrendStrategyConfig &risk_config)
{
  int fast_index = -1;
  int slow_index = -1;

  GridRiskTrendTimeframeSources risk_source = GridResolveRiskTrendSource(risk_config);
  StrategyTrendModes risk_mode = GridResolveActiveRiskMode(risk_source);

  if(TrendModeUsesTeethAlligator(risk_mode))
  {
    fast_index = 2; // lips
    slow_index = 1; // teeth
  }
  else if(TrendModeUsesJawsAlligator(risk_mode))
  {
    fast_index = 1; // teeth
    slow_index = 0; // jaws
  }
  else
  {
    return false;
  }

  double fast_value = 0.0;
  double slow_value = 0.0;
  if(!GridResolveAlligatorBufferPrice(target_tf, fast_index, fast_value))
    return false;
  if(!GridResolveAlligatorBufferPrice(target_tf, slow_index, slow_value))
    return false;

  if(direction == BULLISH)
    return fast_value < slow_value;
  if(direction == BEARISH)
    return fast_value > slow_value;
  return false;
}

bool GridEnsureSarSignalInitialized(SignalParams &signal_params,
                                    const bool log_activation)
{
  if(!signal_params.is_sar_signal)
    return true;
  if(signal_params.grid_initialized)
    return true;

  if(!GridSarEntryConditionReady(signal_params))
    return true;

  if(!BuildGridOrderForSignal(signal_params))
  {
    Print("Trend risk SAR: failed to build reversal grid.");
    return false;
  }

  if(log_activation && ArraySize(signal_params.grid_orders) > 0)
  {
    string reference_label = (Grid_Risk_Alligator_Reference == GRID_RISK_REF_TEETH) ? "TEETH" : "JAWS";
    GridLogEvent(StringFormat("GRID_RISK_TREND_%s_SAR_OPEN", reference_label),
                 signal_params,
                 signal_params.grid_orders[0]);
  }
  return true;
}

bool GridSpawnRiskSarSignal(const SignalTypes direction,
                            double lot_size,
                            const double cumulative_loss)
{
  double normalized_lot = NormalizeVolumeForSymbol(_Symbol, lot_size);
  if(normalized_lot <= 0.0)
  {
    normalized_lot = NormalizeVolumeForSymbol(_Symbol, Grid_Lot_Strategy_Size);
    if(normalized_lot <= 0.0)
      return false;
  }

  SignalParams sar_signal;
  sar_signal.signal_type = direction;
  sar_signal.lot_size    = normalized_lot;
  sar_signal.is_sar_signal = true;
  sar_signal.entry_time  = TimeCurrent();
  sar_signal.entry_price = GridCurrentPriceForDirection(direction, true);
  sar_signal.sar_cumulative_loss = MathMax(cumulative_loss, 0.0);
  sar_signal.strategy_context       = CONTEXT_SLOT_BASE;
  sar_signal.strategy_timeframe     = Strategy_Timeframe;
  sar_signal.strategy_context_label = StrategyContextLabel(CONTEXT_SLOT_BASE);

  if(!GridEnsureSarSignalInitialized(sar_signal, true))
    return false;

  if(!sar_signal.grid_initialized && Enable_Logs)
    Print("Trend risk SAR pending activation; waiting for MA cross before building grid.");

  if(direction == BULLISH)
    AddElementToArray(running_bullish_signals, sar_signal);
  else
    AddElementToArray(running_bearish_signals, sar_signal);

  // Logging handled inside GridEnsureSarSignalInitialized when activation occurs.
  return true;
}

double GridResolveSarLotReferencePoints(const SignalTypes new_direction,
                                        const SignalParams &original_signal,
                                        const GridOrderState &original_state)
{
  SignalParams preview_signal;
  preview_signal.signal_type = new_direction;
  preview_signal.strategy_timeframe = original_signal.strategy_timeframe;

  double base_distance_points = 0.0;
  double entry_reference_price = 0.0;
  ENUM_TIMEFRAMES context_tf = preview_signal.strategy_timeframe;
  if(context_tf == PERIOD_CURRENT)
    context_tf = Strategy_Timeframe;

  if(CalculateBaseGridContext(preview_signal,
                              context_tf,
                              base_distance_points,
                              entry_reference_price))
  {
    if(base_distance_points > 0.0)
      return base_distance_points;
  }

  double reference_points = GridResolveLotReferencePoints(original_signal, original_state);
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_base_distance_points;
  if(reference_points <= 0.0)
    reference_points = original_signal.grid_entry_gap_points;

  if(reference_points <= 0.0)
  {
    double point_size = GridResolvePointSizeSafe();
    double entry_reference = original_state.entry_reference_price;
    double tp_price = original_state.take_profit_price;
    if(point_size > 0.0 && entry_reference > 0.0 && tp_price > 0.0)
      reference_points = MathAbs(tp_price - entry_reference) / point_size;
  }

  return MathMax(reference_points, 0.0);
}

bool GridApplyTrendRiskManagement(SignalParams &signal_params,
                                  const GridOrderState &override_state,
                                  const bool has_override,
                                  const bool use_entry_reference_price)
{
  GridRiskTrendStrategyConfig risk_config = GridBuildRiskTrendStrategyConfig();
  if(risk_config.mode == GRID_RM_TREND_OFF)
    return false;

  ENUM_TIMEFRAMES target_tf = GridResolveRiskTrendStrategyTimeframe(risk_config);
  double reference_price = 0.0;
  if(!GridResolveAlligatorRiskReferencePrice(target_tf, reference_price))
    return false;
  if(reference_price <= 0.0)
    return false;

  GridOrderState state_candidate = override_state;
  if(!has_override)
  {
    if(!GridFindLatestFilledOrder(signal_params, state_candidate))
      return false;
  }

  double current_price        = GridCurrentPriceForDirection(signal_params.signal_type, true);
  double next_level_price     = state_candidate.next_level_price;
  bool   has_next_level_price = (next_level_price > 0.0);
  bool   next_level_breach    = false;
  if(has_next_level_price)
  {
    if(signal_params.signal_type == BULLISH)
      next_level_breach = (next_level_price < reference_price && current_price < next_level_price);
    else if(signal_params.signal_type == BEARISH)
      next_level_breach = (next_level_price > reference_price && current_price > next_level_price);
  }

  bool ma_breach = GridTrendSarAlligatorBreach(signal_params.signal_type,
                                               target_tf,
                                               risk_config);

  if(!next_level_breach || !ma_breach)
    return false;

  bool needs_floating = GridRiskTrendModeRequiresFloating(risk_config);
  double floating_profit = 0.0;
  if(needs_floating)
    floating_profit = GridCollectSignalFloatingProfit(signal_params);

  if(!GridRiskTrendModeAllowsExit(risk_config, floating_profit))
    return false;

  double sar_lot = state_candidate.lot_size;
  if(sar_lot <= 0.0)
    sar_lot = signal_params.grid_base_lot_size;
  if(sar_lot <= 0.0)
    sar_lot = Grid_Lot_Strategy_Size;

  SignalTypes sar_direction = (signal_params.signal_type == BULLISH) ? BEARISH : BULLISH;
  double realized_loss = 0.0;
  double cumulative_loss = signal_params.sar_cumulative_loss;
  if(GridRiskTrendModeUsesSar(risk_config) && floating_profit < 0.0)
  {
    realized_loss = -floating_profit;
    cumulative_loss += realized_loss;
  }
  if(GridRiskTrendModeUsesSar(risk_config) && floating_profit < 0.0)
  {
    double multiplier = Grid_Lot_Multiplier;
    if(multiplier <= 0.0)
      multiplier = 1.0;

    double coverage_amount = cumulative_loss * multiplier;
    if(coverage_amount > 0.0)
    {
      double reference_points = GridResolveSarLotReferencePoints(sar_direction, signal_params, state_candidate);
      if(reference_points > 0.0)
      {
        double converted = ConvertAmountToLots(_Symbol, coverage_amount, reference_points);
        if(converted > 0.0)
          sar_lot = converted;
      }
    }
  }

  double point_size = GridResolvePointSize();
  GridCloseAllLevels(signal_params, point_size);
  if(GridRiskTrendModeUsesSar(risk_config))
    signal_params.sar_cumulative_loss = cumulative_loss;

  string log_suffix = "SL";
  if(risk_config.mode == GRID_RM_TREND_BE)
    log_suffix = "BE";
  else if(GridRiskTrendModeUsesSar(risk_config))
    log_suffix = "SAR_CLOSE";
  string log_label = GridRiskTrendComposeLogLabel(risk_config, log_suffix);
  GridOrderState log_state = state_candidate;
  if(use_entry_reference_price && log_state.entry_price <= 0.0)
    log_state.entry_price = current_price;
  GridLogEvent(log_label, signal_params, log_state);
  signal_params.signal_state = CLOSED;

  if(GridRiskTrendModeUsesSar(risk_config))
  {
    if(!GridSpawnRiskSarSignal(sar_direction, sar_lot, cumulative_loss))
      Print("Trend risk SAR: failed to launch reversal grid.");
  }
  return true;
}


#endif // _SERVICES_TRADING_SIGNALS_GRID_TREND_RISK_MANAGER_MQH_
