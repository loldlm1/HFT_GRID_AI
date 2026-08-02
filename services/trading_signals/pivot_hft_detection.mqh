//+------------------------------------------------------------------+
//|                       pivot_hft_detection.mqh                    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DETECTION_MQH_

bool     g_pivot_hft_tick_micro_bar_cached = false;
datetime g_pivot_hft_tick_micro_bar = 0;
bool     g_pivot_hft_tick_close_cached = false;
double   g_pivot_hft_tick_micro_close = 0.0;

void PivotHftBeginTickDataCache()
{
  g_pivot_hft_tick_micro_bar_cached = false;
  g_pivot_hft_tick_micro_bar = 0;
  g_pivot_hft_tick_close_cached = false;
  g_pivot_hft_tick_micro_close = 0.0;
}

datetime PivotHftCurrentMicroBar()
{
  if(!g_pivot_hft_tick_micro_bar_cached)
  {
    g_pivot_hft_tick_micro_bar =
      iTime(_Symbol, Pivot_HFT_Micro_Timeframe, 0);
    g_pivot_hft_tick_micro_bar_cached = true;
  }
  return g_pivot_hft_tick_micro_bar;
}

double PivotHftCurrentMicroClose()
{
  if(!g_pivot_hft_tick_close_cached)
  {
    g_pivot_hft_tick_micro_close =
      iClose(_Symbol, Pivot_HFT_Micro_Timeframe, 0);
    g_pivot_hft_tick_close_cached = true;
  }
  return g_pivot_hft_tick_micro_close;
}

double PivotHftCurrentEntryQuote(const SignalTypes direction)
{
  if(direction == BULLISH)
    return g_ask;
  if(direction == BEARISH)
    return g_bid;
  return 0.0;
}

bool PivotHftCampaignBelongsToCurrentMicroBar()
{
  datetime current_bar = PivotHftCurrentMicroBar();
  return (current_bar > 0 &&
          g_pivot_hft_campaign.micro_bar_time == current_bar);
}

void PivotHftObserveMicroBarTransition(const datetime current_bar)
{
  if(current_bar <= 0)
    return;
  if(g_pivot_hft_last_micro_bar == 0)
  {
    g_pivot_hft_last_micro_bar = current_bar;
    return;
  }
  if(current_bar == g_pivot_hft_last_micro_bar)
    return;

  datetime previous_bar = g_pivot_hft_last_micro_bar;
  g_pivot_hft_last_micro_bar = current_bar;
  PivotHftResetOccupiedAuditState();

  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_TRACKING &&
     g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_ORDER_WAIT)
    return;
  if(g_pivot_hft_campaign.micro_bar_time <= 0 ||
     g_pivot_hft_campaign.micro_bar_time >= current_bar)
    return;

  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
    micro_seconds = 60;
  long age_bars = (long)((current_bar -
                          g_pivot_hft_campaign.micro_bar_time) /
                         micro_seconds);
  if(age_bars < 1)
    age_bars = 1;
  PivotHftAuditLog("CAMPAIGN_CARRIED_FORWARD",
                   StringFormat("sequence=%s|dir=%s|level=%s|origin_bar=%I64d|previous_bar=%I64d|current_bar=%I64d|age_bars=%I64d|status=%s",
                                g_pivot_hft_campaign.sequence_id,
                                EnumToString(g_pivot_hft_campaign.direction),
                                PivotHftLevelLabel(
                                  g_pivot_hft_campaign.pivot_level),
                                (long)g_pivot_hft_campaign.micro_bar_time,
                                (long)previous_bar,
                                (long)current_bar,
                                age_bars,
                                EnumToString(g_pivot_hft_campaign.status)));
}

void PivotHftStartCampaign(const SignalTypes direction,
                           const PivotHftPivotLevels level,
                           const double level_price,
                           const datetime micro_bar_time,
                           const string admitted_sequence_id = "",
                           const ulong retry_source_ticket = 0,
                           const int retry_ordinal = 1,
                           const int attempt_count = 0,
                           const string retry_source_id = "",
                           const double modeled_entry_slippage_points = 0.0,
                           const double modeled_close_slippage_points = 0.0,
                           const double modeled_cost_per_lot = 0.0,
                           const string model_source_execution_id = "",
                           const PivotHftExecutionSources
                             model_source_execution_source =
                               PIVOT_HFT_EXECUTION_BROKER,
                           const PivotHftModelValueProvenance
                             entry_slippage_provenance =
                               PIVOT_HFT_MODEL_VALUE_UNAVAILABLE,
                           const PivotHftModelValueProvenance
                             close_slippage_provenance =
                               PIVOT_HFT_MODEL_VALUE_UNAVAILABLE,
                           const PivotHftModelValueProvenance
                             cost_per_lot_provenance =
                               PIVOT_HFT_MODEL_VALUE_UNAVAILABLE)
{
  PivotHftClearExpiredCampaignVisual();
  PivotHftCampaignState campaign;
  campaign.status          = PIVOT_HFT_CAMPAIGN_TRACKING;
  campaign.direction       = direction;
  campaign.pivot_level     = level;
  campaign.pivot_price     = level_price;
  campaign.micro_bar_time  = micro_bar_time;
  campaign.arm_time        = TimeCurrent();
  campaign.tracked_extreme = PivotHftCurrentEntryQuote(direction);
  campaign.trigger_price   = 0.0;
  campaign.attempt_count   = (attempt_count > 0) ? attempt_count : 0;
  campaign.retry_ordinal   = (retry_ordinal > 1) ? retry_ordinal : 1;
  campaign.retry_source_ticket = retry_source_ticket;
  campaign.retry_source_id = retry_source_id;
  campaign.model_source_execution_id = model_source_execution_id;
  campaign.model_source_execution_source = model_source_execution_source;
  campaign.entry_slippage_provenance = entry_slippage_provenance;
  campaign.close_slippage_provenance = close_slippage_provenance;
  campaign.cost_per_lot_provenance = cost_per_lot_provenance;
  campaign.modeled_entry_slippage_points =
    modeled_entry_slippage_points;
  campaign.modeled_close_slippage_points =
    modeled_close_slippage_points;
  campaign.modeled_cost_per_lot = modeled_cost_per_lot;
  campaign.sequence_id     = admitted_sequence_id;
  if(campaign.sequence_id == "")
  {
    campaign.sequence_id = StringFormat("pivot_hft_%I64d_%s_%s",
                                        (long)micro_bar_time,
                                        EnumToString(direction),
                                        PivotHftLevelLabel(level));
  }
  g_pivot_hft_campaign = campaign;
  int retry_number = PivotHftMarketRetryNumber(campaign.retry_ordinal);
  PivotHftExecutionSources execution_source =
    PivotHftExecutionSourceForRetry(retry_number);
  PivotHftAuditLog("CAMPAIGN_ARMED",
                   StringFormat("sequence=%s|dir=%s|level=%s|price=%.5f|bar=%I64d|extreme=%.5f|retry_number=%d|retry_ordinal=%d|attempt=%d|execution_source=%s|source_ticket=%I64u|source_id=%s|%s",
                                campaign.sequence_id,
                                EnumToString(direction),
                                PivotHftLevelLabel(level),
                                level_price,
                                (long)micro_bar_time,
                                campaign.tracked_extreme,
                                retry_number,
                                campaign.retry_ordinal,
                                campaign.attempt_count + 1,
                                PivotHftExecutionSourceLabel(
                                  execution_source),
                                campaign.retry_source_ticket,
                                campaign.retry_source_id,
                                PivotHftCampaignModelProvenanceAuditFields(
                                  campaign)));
}

double PivotHftCampaignEntryThreshold(
  const PivotHftCampaignState &campaign)
{
  if(campaign.tracked_extreme <= 0.0)
    return 0.0;

  double trigger_distance = PivotHftDistanceToPrice(
    Pivot_HFT_Retracement_Points);
  if(Pivot_HFT_Retracement_Points <= 0.0 || trigger_distance <= 0.0)
    return PivotHftNormalizePrice(campaign.tracked_extreme);
  if(campaign.direction == BEARISH)
    return PivotHftNormalizePrice(campaign.tracked_extreme - trigger_distance);
  if(campaign.direction == BULLISH)
    return PivotHftNormalizePrice(campaign.tracked_extreme + trigger_distance);
  return 0.0;
}

void PivotHftAuditOccupiedCandidateState(
  const datetime micro_bar_time,
  const SignalTypes direction,
  const ulong occupied_mask,
  const PivotHftPivotLevels selected_level)
{
  if(!Enable_File_Logs)
    return;

  if(occupied_mask == 0)
    return;

  if(!PivotHftRegisterOccupiedAuditSignature(micro_bar_time,
                                              direction,
                                              occupied_mask,
                                              selected_level))
    return;

  string direction_label = (direction == NO_SIGNAL)
                           ? "BOTH"
                           : EnumToString(direction);
  PivotHftAuditLog("CAMPAIGN_LEVEL_OCCUPIED",
                   StringFormat("dir=%s|bar=%I64d|occupied_mask=%I64u|selected_level=%s|campaign=%s",
                                direction_label,
                                (long)micro_bar_time,
                                occupied_mask,
                                PivotHftLevelLabel(selected_level),
                                g_pivot_hft_campaign.sequence_id));
}

bool PivotHftCampaignMatches(const SignalTypes direction,
                             const PivotHftPivotLevels level,
                             const double level_price)
{
  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_IDLE)
    return false;
  if(!PivotHftCampaignBelongsToCurrentMicroBar())
    return false;
  if(g_pivot_hft_campaign.direction != direction)
    return false;
  if(g_pivot_hft_campaign.pivot_level != level)
    return false;

  double tolerance = PivotHftTickSize() * 0.5;
  return (MathAbs(g_pivot_hft_campaign.pivot_price - level_price) <= tolerance);
}

bool PivotHftResolveSupersessionOwner(
  PivotHftPositionState &owner_state)
{
  owner_state = PivotHftPositionState();
  bool owner_found = false;
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    bool active_owner = (state.status == PIVOT_HFT_POSITION_ACTIVE ||
                         state.status == PIVOT_HFT_POSITION_CLOSE_WAIT);
    bool pending_retry_owner =
      (state.status == PIVOT_HFT_POSITION_CLOSED &&
       state.reattempt_pending);
    if(!active_owner && !pending_retry_owner)
      continue;
    if(state.emergency_lifecycle ||
       (state.direction != BULLISH && state.direction != BEARISH))
      continue;
    if(owner_found)
      return false;
    owner_state = state;
    owner_found = true;
  }
  return owner_found;
}

bool PivotHftSelectCurrentAdmissibleLevel(
  const double close_price,
  const datetime micro_bar_time,
  SignalTypes &direction,
  PivotHftPivotLevels &level,
  double &level_price)
{
  direction = NO_SIGNAL;
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(close_price <= 0.0 || micro_bar_time <= 0 ||
     !g_pivot_hft_pivots.valid)
    return false;

  ulong occupied_levels = PivotHftCampaignOccupiedLevelMask(
    micro_bar_time);
  PivotHftPivotLevels sell_level = PIVOT_HFT_LEVEL_NONE;
  PivotHftPivotLevels buy_level = PIVOT_HFT_LEVEL_NONE;
  double sell_price = 0.0;
  double buy_price = 0.0;
  ulong sell_occupied_mask = 0;
  ulong buy_occupied_mask = 0;
  bool sell_touched = false;
  bool buy_touched = false;
  bool sell_candidate = false;
  bool buy_candidate = false;

  if(PivotHftDirectionAllowed(BEARISH) &&
     close_price >= g_pivot_hft_bands_upper)
  {
    sell_candidate = PivotHftLatestUnoccupiedResistanceTouched(
      close_price,
      occupied_levels,
      sell_level,
      sell_price,
      sell_occupied_mask,
      sell_touched);
  }
  if(PivotHftDirectionAllowed(BULLISH) &&
     close_price <= g_pivot_hft_bands_lower)
  {
    buy_candidate = PivotHftLatestUnoccupiedSupportTouched(
      close_price,
      occupied_levels,
      buy_level,
      buy_price,
      buy_occupied_mask,
      buy_touched);
  }

  if(sell_candidate == buy_candidate)
    return false;
  if(sell_candidate)
  {
    direction = BEARISH;
    level = sell_level;
    level_price = sell_price;
    return true;
  }

  direction = BULLISH;
  level = buy_level;
  level_price = buy_price;
  return true;
}

PivotHftSupersessionCandidate PivotHftBuildSupersessionCandidate(
  const SignalTypes direction,
  const PivotHftPivotLevels level,
  const double level_price,
  const datetime micro_bar_time,
  const PivotHftExecutionSources owner_execution_source,
  const PivotHftPivotLevels owner_level,
  const double owner_price,
  const ulong owner_ticket,
  const ulong owner_position_identifier,
  const string owner_execution_id,
  const string owner_sequence_id,
  const int owner_retry_number)
{
  PivotHftSupersessionCandidate candidate;
  candidate.valid = true;
  candidate.direction = direction;
  candidate.pivot_level = level;
  candidate.pivot_price = level_price;
  candidate.pivot_activation_bar = g_pivot_hft_last_macro_bar;
  candidate.pivot_source_bar = g_pivot_hft_pivots.source_bar_time;
  candidate.admission_micro_bar = micro_bar_time;
  candidate.admitted_at = TimeCurrent();
  candidate.owner_execution_source = owner_execution_source;
  candidate.owner_pivot_level = owner_level;
  candidate.owner_pivot_price = owner_price;
  candidate.owner_position_ticket = owner_ticket;
  candidate.owner_position_identifier = owner_position_identifier;
  candidate.owner_execution_id = owner_execution_id;
  candidate.owner_campaign_sequence_id = owner_sequence_id;
  candidate.owner_retry_number = owner_retry_number;
  return candidate;
}

bool PivotHftObserveDeeperSupersessionCandidate(
  const double close_price,
  const datetime micro_bar_time)
{
  PivotHftPositionState owner_state;
  if(!PivotHftResolveSupersessionOwner(owner_state) ||
     !PivotHftPositionMatchesPivotSnapshot(owner_state,
                                           g_pivot_hft_pivots))
    return false;

  SignalTypes direction = NO_SIGNAL;
  PivotHftPivotLevels level = PIVOT_HFT_LEVEL_NONE;
  double level_price = 0.0;
  if(!PivotHftSelectCurrentAdmissibleLevel(close_price,
                                           micro_bar_time,
                                           direction,
                                           level,
                                           level_price) ||
     direction != owner_state.direction ||
     !DailySignalLimitAllowsAttempt(direction) ||
     !PivotHftLevelIsStrictlyDeeper(direction,
                                    level,
                                    owner_state.pivot_level))
    return false;

  if(g_pivot_hft_supersession_candidate.valid)
  {
    if(!PivotHftSupersessionCandidateOwnedByPosition(
         g_pivot_hft_supersession_candidate,
         owner_state) ||
       !PivotHftLevelIsStrictlyDeeper(
         direction,
         level,
         g_pivot_hft_supersession_candidate.pivot_level))
      return false;
  }

  PivotHftSupersessionCandidate candidate =
    PivotHftBuildSupersessionCandidate(
      direction,
      level,
      level_price,
      micro_bar_time,
      owner_state.execution_source,
      owner_state.pivot_level,
      owner_state.pivot_price,
      owner_state.position_ticket,
      owner_state.position_identifier,
      PivotHftPositionExecutionId(owner_state),
      owner_state.campaign_sequence_id,
      PivotHftMarketRetryNumber(owner_state.campaign_retry_ordinal));
  return PivotHftLatchSupersessionCandidate(candidate);
}

bool PivotHftSupersedePendingRetryCampaign(
  const double close_price,
  const datetime micro_bar_time)
{
  if((g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_TRACKING &&
      g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_ORDER_WAIT) ||
     PivotHftMarketRetryNumber(g_pivot_hft_campaign.retry_ordinal) <= 0)
    return false;

  SignalTypes direction = NO_SIGNAL;
  PivotHftPivotLevels level = PIVOT_HFT_LEVEL_NONE;
  double level_price = 0.0;
  if(!PivotHftSelectCurrentAdmissibleLevel(close_price,
                                           micro_bar_time,
                                           direction,
                                           level,
                                           level_price) ||
     direction != g_pivot_hft_campaign.direction ||
     !DailySignalLimitAllowsAttempt(direction) ||
     !PivotHftLevelIsStrictlyDeeper(
       direction,
       level,
       g_pivot_hft_campaign.pivot_level))
    return false;

  double fresh_extreme = PivotHftCurrentEntryQuote(direction);
  if(fresh_extreme <= 0.0)
    return false;
  if(g_pivot_hft_supersession_candidate.valid)
    return false;

  PivotHftCampaignState previous_campaign = g_pivot_hft_campaign;
  int previous_retry_number = PivotHftMarketRetryNumber(
    previous_campaign.retry_ordinal);
  PivotHftSupersessionCandidate candidate =
    PivotHftBuildSupersessionCandidate(
      direction,
      level,
      level_price,
      micro_bar_time,
      PivotHftExecutionSourceForRetry(previous_retry_number),
      previous_campaign.pivot_level,
      previous_campaign.pivot_price,
      previous_campaign.retry_source_ticket,
      0,
      previous_campaign.retry_source_id,
      previous_campaign.sequence_id,
      previous_retry_number);
  PivotHftLatchSupersessionCandidate(candidate);

  PivotHftStartCampaign(direction,
                        level,
                        level_price,
                        micro_bar_time);
  g_pivot_hft_campaign.tracked_extreme = fresh_extreme;
  PivotHftCampaignState replacement_campaign = g_pivot_hft_campaign;
  PivotHftCaptureReplacedCampaignVisual(previous_campaign,
                                        replacement_campaign,
                                        micro_bar_time,
                                        "deeper_pivot_superseded");
  PivotHftTerminateSupersessionCandidate(
    "promoted_from_tracking_retry",
    replacement_campaign.sequence_id);
  PivotHftAuditLog("RETRY_CAMPAIGN_SUPERSEDED",
                   StringFormat("transition_version=1|transition_reason=deeper_pivot_admitted|previous_sequence=%s|previous_level=%s|previous_retry_number=%d|previous_attempt=%d|previous_execution_source=%s|sequence=%s|level=%s|retry_number=0|attempt=1|execution_source=BROKER|fresh_extreme=%.5f|candidate_admission_bar=%I64d",
                                previous_campaign.sequence_id,
                                PivotHftLevelLabel(
                                  previous_campaign.pivot_level),
                                previous_retry_number,
                                previous_campaign.attempt_count + 1,
                                PivotHftExecutionSourceLabel(
                                  PivotHftExecutionSourceForRetry(
                                    previous_retry_number)),
                                replacement_campaign.sequence_id,
                                PivotHftLevelLabel(
                                  replacement_campaign.pivot_level),
                                fresh_extreme,
                                (long)candidate.admission_micro_bar));
  return true;
}

void PivotHftReplaceCampaignIfLatestLevelChanged(const double close_price,
                                                 const datetime micro_bar_time)
{
  SignalTypes direction = NO_SIGNAL;
  PivotHftPivotLevels level = PIVOT_HFT_LEVEL_NONE;
  double level_price = 0.0;
  ulong occupied_mask = 0;
  bool sell_touched = false;
  bool buy_touched = false;
  bool sell_candidate = false;
  bool buy_candidate = false;
  bool sell_side = (PivotHftDirectionAllowed(BEARISH) &&
                    close_price >= g_pivot_hft_bands_upper);
  bool buy_side = (PivotHftDirectionAllowed(BULLISH) &&
                   close_price <= g_pivot_hft_bands_lower);
  if(!sell_side && !buy_side)
  {
    PivotHftAuditOccupiedCandidateState(micro_bar_time,
                                         NO_SIGNAL,
                                         0,
                                         PIVOT_HFT_LEVEL_NONE);
    return;
  }

  ulong occupied_levels = PivotHftCampaignOccupiedLevelMask(micro_bar_time);

  if(sell_side)
    sell_candidate = PivotHftLatestUnoccupiedResistanceTouched(
      close_price,
      occupied_levels,
      level,
      level_price,
      occupied_mask,
      sell_touched);

  PivotHftPivotLevels buy_level = PIVOT_HFT_LEVEL_NONE;
  double buy_price = 0.0;
  ulong buy_occupied_mask = 0;
  if(buy_side)
    buy_candidate = PivotHftLatestUnoccupiedSupportTouched(
      close_price,
      occupied_levels,
      buy_level,
      buy_price,
      buy_occupied_mask,
      buy_touched);

  occupied_mask |= buy_occupied_mask;
  if(sell_touched && buy_touched)
  {
    PivotHftAuditOccupiedCandidateState(micro_bar_time,
                                         NO_SIGNAL,
                                         occupied_mask,
                                         PIVOT_HFT_LEVEL_NONE);
    return;
  }

  if(sell_candidate)
    direction = BEARISH;
  else if(buy_candidate)
  {
    direction = BULLISH;
    level = buy_level;
    level_price = buy_price;
  }
  else
  {
    if(sell_touched)
      direction = BEARISH;
    else if(buy_touched)
      direction = BULLISH;
    PivotHftAuditOccupiedCandidateState(micro_bar_time,
                                         direction,
                                         occupied_mask,
                                         PIVOT_HFT_LEVEL_NONE);
    return;
  }

  PivotHftAuditOccupiedCandidateState(micro_bar_time,
                                       direction,
                                       occupied_mask,
                                       level);

  if(PivotHftCampaignMatches(direction, level, level_price))
    return;

  bool replacing_campaign =
    (g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE);
  PivotHftCampaignState previous_campaign = g_pivot_hft_campaign;
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE &&
     PivotHftCampaignBelongsToCurrentMicroBar() &&
     g_pivot_hft_campaign.direction == direction &&
     !PivotHftLevelIsStrictlyDeeper(
       direction,
       level,
       g_pivot_hft_campaign.pivot_level))
    return;
  PivotHftStartCampaign(direction, level, level_price, micro_bar_time);
  if(replacing_campaign)
  {
    PivotHftCampaignState replacement_campaign = g_pivot_hft_campaign;
    PivotHftCaptureReplacedCampaignVisual(previous_campaign,
                                          replacement_campaign,
                                          micro_bar_time);
    int previous_retry_number = PivotHftMarketRetryNumber(
      previous_campaign.retry_ordinal);
    int replacement_retry_number = PivotHftMarketRetryNumber(
      replacement_campaign.retry_ordinal);
    PivotHftAuditLog("CAMPAIGN_REPLACED",
                     StringFormat("previous_sequence=%s|previous_dir=%s|previous_level=%s|previous_price=%.5f|previous_origin_bar=%I64d|previous_status=%s|previous_retry_number=%d|previous_retry_ordinal=%d|previous_execution_source=%s|previous_source_ticket=%I64u|previous_source_id=%s|terminal_reason=latest_level_replaced|sequence=%s|dir=%s|level=%s|price=%.5f|origin_bar=%I64d|retry_number=%d|retry_ordinal=%d|execution_source=%s",
                                  previous_campaign.sequence_id,
                                  EnumToString(previous_campaign.direction),
                                  PivotHftLevelLabel(
                                    previous_campaign.pivot_level),
                                  previous_campaign.pivot_price,
                                  (long)previous_campaign.micro_bar_time,
                                  EnumToString(previous_campaign.status),
                                  previous_retry_number,
                                  previous_campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    PivotHftExecutionSourceForRetry(
                                      previous_retry_number)),
                                  previous_campaign.retry_source_ticket,
                                  previous_campaign.retry_source_id,
                                  replacement_campaign.sequence_id,
                                  EnumToString(replacement_campaign.direction),
                                  PivotHftLevelLabel(
                                    replacement_campaign.pivot_level),
                                  replacement_campaign.pivot_price,
                                  (long)replacement_campaign.micro_bar_time,
                                  replacement_retry_number,
                                  replacement_campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    PivotHftExecutionSourceForRetry(
                                      replacement_retry_number))));
  }
  if(Enable_Logs)
  {
    PrintFormat("PIVOT_HFT_CAMPAIGN_ARMED dir=%s level=%s price=%.5f bar=%s",
                EnumToString(direction),
                PivotHftLevelLabel(level),
                level_price,
                TimeToString(micro_bar_time, TIME_DATE | TIME_SECONDS));
  }
}

void PivotHftUpdateTrackedExtreme()
{
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_TRACKING)
    return;

  double current_quote = PivotHftCurrentEntryQuote(g_pivot_hft_campaign.direction);
  if(current_quote <= 0.0)
    return;

  double trigger_distance = PivotHftDistanceToPrice(
    Pivot_HFT_Retracement_Points);
  if(Pivot_HFT_Retracement_Points <= 0.0)
  {
    g_pivot_hft_campaign.trigger_price = current_quote;
    g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_ORDER_WAIT;
    PivotHftAuditLog("ENTRY_TRIGGERED",
                     StringFormat("sequence=%s|dir=%s|level=%s|mode=IMMEDIATE|extreme=%.5f|threshold=%.5f|quote=%.5f|retrace_pts=%.2f|retry_number=%d|retry_ordinal=%d|execution_source=%s|source_ticket=%I64u|source_id=%s",
                                  g_pivot_hft_campaign.sequence_id,
                                  EnumToString(g_pivot_hft_campaign.direction),
                                  PivotHftLevelLabel(
                                    g_pivot_hft_campaign.pivot_level),
                                  g_pivot_hft_campaign.tracked_extreme,
                                  current_quote,
                                  current_quote,
                                  Pivot_HFT_Retracement_Points,
                                  PivotHftMarketRetryNumber(
                                    g_pivot_hft_campaign.retry_ordinal),
                                  g_pivot_hft_campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    PivotHftExecutionSourceForRetry(
                                      PivotHftMarketRetryNumber(
                                        g_pivot_hft_campaign.retry_ordinal))),
                                  g_pivot_hft_campaign.retry_source_ticket,
                                  g_pivot_hft_campaign.retry_source_id));
    return;
  }

  if(g_pivot_hft_campaign.direction == BEARISH)
  {
    if(g_pivot_hft_campaign.tracked_extreme <= 0.0 ||
       current_quote > g_pivot_hft_campaign.tracked_extreme)
      g_pivot_hft_campaign.tracked_extreme = current_quote;

    if(trigger_distance > 0.0 &&
       current_quote <= g_pivot_hft_campaign.tracked_extreme - trigger_distance)
    {
      g_pivot_hft_campaign.trigger_price = current_quote;
      g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_ORDER_WAIT;
      PivotHftAuditLog("ENTRY_TRIGGERED",
                       StringFormat("sequence=%s|dir=%s|level=%s|mode=RETRACEMENT|extreme=%.5f|threshold=%.5f|quote=%.5f|retrace_pts=%.2f|retry_number=%d|retry_ordinal=%d|execution_source=%s|source_ticket=%I64u|source_id=%s",
                                    g_pivot_hft_campaign.sequence_id,
                                    EnumToString(g_pivot_hft_campaign.direction),
                                    PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level),
                                    g_pivot_hft_campaign.tracked_extreme,
                                    PivotHftCampaignEntryThreshold(
                                      g_pivot_hft_campaign),
                                    current_quote,
                                    Pivot_HFT_Retracement_Points,
                                    PivotHftMarketRetryNumber(
                                      g_pivot_hft_campaign.retry_ordinal),
                                    g_pivot_hft_campaign.retry_ordinal,
                                    PivotHftExecutionSourceLabel(
                                      PivotHftExecutionSourceForRetry(
                                        PivotHftMarketRetryNumber(
                                          g_pivot_hft_campaign.retry_ordinal))),
                                    g_pivot_hft_campaign.retry_source_ticket,
                                    g_pivot_hft_campaign.retry_source_id));
    }
    return;
  }

  if(g_pivot_hft_campaign.tracked_extreme <= 0.0 ||
     current_quote < g_pivot_hft_campaign.tracked_extreme)
    g_pivot_hft_campaign.tracked_extreme = current_quote;

  if(trigger_distance > 0.0 &&
     current_quote >= g_pivot_hft_campaign.tracked_extreme + trigger_distance)
  {
    g_pivot_hft_campaign.trigger_price = current_quote;
    g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_ORDER_WAIT;
    PivotHftAuditLog("ENTRY_TRIGGERED",
                     StringFormat("sequence=%s|dir=%s|level=%s|mode=RETRACEMENT|extreme=%.5f|threshold=%.5f|quote=%.5f|retrace_pts=%.2f|retry_number=%d|retry_ordinal=%d|execution_source=%s|source_ticket=%I64u|source_id=%s",
                                  g_pivot_hft_campaign.sequence_id,
                                  EnumToString(g_pivot_hft_campaign.direction),
                                  PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level),
                                  g_pivot_hft_campaign.tracked_extreme,
                                  PivotHftCampaignEntryThreshold(
                                    g_pivot_hft_campaign),
                                  current_quote,
                                  Pivot_HFT_Retracement_Points,
                                  PivotHftMarketRetryNumber(
                                    g_pivot_hft_campaign.retry_ordinal),
                                  g_pivot_hft_campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    PivotHftExecutionSourceForRetry(
                                      PivotHftMarketRetryNumber(
                                        g_pivot_hft_campaign.retry_ordinal))),
                                  g_pivot_hft_campaign.retry_source_ticket,
                                  g_pivot_hft_campaign.retry_source_id));
  }
}

bool PivotHftEntryIntentReady()
{
  return (g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_ORDER_WAIT);
}

void PivotHftMarkEntryRetryable()
{
  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_ORDER_WAIT)
  {
    g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_TRACKING;
    g_pivot_hft_campaign.trigger_price = 0.0;
    g_pivot_hft_campaign.attempt_count++;
    g_pivot_hft_campaign.tracked_extreme =
      PivotHftCurrentEntryQuote(g_pivot_hft_campaign.direction);
    PivotHftAuditLog("ENTRY_RETRYABLE",
                     StringFormat("sequence=%s|attempt=%d|extreme=%.5f|retry_number=%d|retry_ordinal=%d|execution_source=%s|source_ticket=%I64u|source_id=%s",
                                  g_pivot_hft_campaign.sequence_id,
                                  g_pivot_hft_campaign.attempt_count,
                                  g_pivot_hft_campaign.tracked_extreme,
                                  PivotHftMarketRetryNumber(
                                    g_pivot_hft_campaign.retry_ordinal),
                                  g_pivot_hft_campaign.retry_ordinal,
                                  PivotHftExecutionSourceLabel(
                                    PivotHftExecutionSourceForRetry(
                                      PivotHftMarketRetryNumber(
                                        g_pivot_hft_campaign.retry_ordinal))),
                                  g_pivot_hft_campaign.retry_source_ticket,
                                  g_pivot_hft_campaign.retry_source_id));
  }
}

bool PivotHftDetectEntryIntent(const bool allow_new_campaign,
                               const bool allow_candidate_observation)
{
  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(current_micro_bar <= 0)
    return false;

  if(!PivotHftRefreshPivotSnapshot(false))
    return false;
  if(!PivotHftRefreshBandsSnapshot(false))
    return false;
  PivotHftObserveMicroBarTransition(current_micro_bar);

  double close_price = 0.0;
  if(allow_candidate_observation ||
     (allow_new_campaign &&
      (g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_TRACKING ||
       g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_ORDER_WAIT)))
    close_price = PivotHftCurrentMicroClose();

  if(allow_candidate_observation && close_price > 0.0)
    PivotHftObserveDeeperSupersessionCandidate(close_price,
                                               current_micro_bar);

  if(allow_new_campaign && close_price > 0.0)
    PivotHftSupersedePendingRetryCampaign(close_price,
                                          current_micro_bar);

  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_TRACKING &&
     PivotHftCampaignBelongsToCurrentMicroBar() &&
     PivotHftMarketRetryNumber(g_pivot_hft_campaign.retry_ordinal) == 0)
  {
    double tracking_close = close_price;
    if(tracking_close <= 0.0)
      tracking_close = PivotHftCurrentMicroClose();
    if(tracking_close > 0.0)
      PivotHftReplaceCampaignIfLatestLevelChanged(tracking_close,
                                                  current_micro_bar);
  }

  if(PivotHftEntryIntentReady())
    return true;

  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_TRACKING)
  {
    PivotHftUpdateTrackedExtreme();
    return PivotHftEntryIntentReady();
  }

  if(!allow_new_campaign)
    return false;

  if(close_price <= 0.0)
    close_price = PivotHftCurrentMicroClose();
  if(close_price <= 0.0)
    return false;

  PivotHftReplaceCampaignIfLatestLevelChanged(close_price,
                                              current_micro_bar);
  PivotHftUpdateTrackedExtreme();
  return PivotHftEntryIntentReady();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DETECTION_MQH_
