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

void PivotHftResetPendingCampaignForNewMicroBar(const datetime current_bar)
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

  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
  {
    PivotHftAuditLog("CAMPAIGN_EXPIRED",
                     StringFormat("dir=%s|level=%s|bar=%I64d|status=%s",
                                  EnumToString(g_pivot_hft_campaign.direction),
                                  PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level),
                                  (long)g_pivot_hft_campaign.micro_bar_time,
                                  EnumToString(g_pivot_hft_campaign.status)));
    g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_EXPIRED;
    PivotHftResetCampaign();
  }
  g_pivot_hft_last_micro_bar = current_bar;
}

void PivotHftStartCampaign(const SignalTypes direction,
                           const PivotHftPivotLevels level,
                           const double level_price,
                           const datetime micro_bar_time)
{
  PivotHftCampaignState campaign;
  campaign.status          = PIVOT_HFT_CAMPAIGN_TRACKING;
  campaign.direction       = direction;
  campaign.pivot_level     = level;
  campaign.pivot_price     = level_price;
  campaign.micro_bar_time  = micro_bar_time;
  campaign.arm_time        = TimeCurrent();
  campaign.tracked_extreme = PivotHftCurrentEntryQuote(direction);
  campaign.trigger_price   = 0.0;
  campaign.attempt_count   = 0;
  campaign.sequence_id     = StringFormat("pivot_hft_%I64d_%s_%s",
                                           (long)micro_bar_time,
                                           EnumToString(direction),
                                           PivotHftLevelLabel(level));
  g_pivot_hft_campaign = campaign;
  PivotHftAuditLog("CAMPAIGN_ARMED",
                   StringFormat("sequence=%s|dir=%s|level=%s|price=%.5f|bar=%I64d|extreme=%.5f",
                                campaign.sequence_id,
                                EnumToString(direction),
                                PivotHftLevelLabel(level),
                                level_price,
                                (long)micro_bar_time,
                                campaign.tracked_extreme));
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

bool PivotHftSelectCurrentTouchedLevel(const double close_price,
                                       SignalTypes &direction,
                                       PivotHftPivotLevels &level,
                                       double &level_price)
{
  direction = NO_SIGNAL;
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(close_price <= 0.0 || !g_pivot_hft_pivots.valid)
    return false;

  bool sell_candidate = false;
  bool buy_candidate = false;
  PivotHftPivotLevels sell_level = PIVOT_HFT_LEVEL_NONE;
  PivotHftPivotLevels buy_level = PIVOT_HFT_LEVEL_NONE;
  double sell_price = 0.0;
  double buy_price = 0.0;

  if(PivotHftDirectionAllowed(BEARISH) &&
     close_price >= g_pivot_hft_bands_upper)
    sell_candidate = PivotHftLatestResistanceTouched(close_price,
                                                      sell_level,
                                                      sell_price);
  if(PivotHftDirectionAllowed(BULLISH) &&
     close_price <= g_pivot_hft_bands_lower)
    buy_candidate = PivotHftLatestSupportTouched(close_price,
                                                 buy_level,
                                                 buy_price);

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

void PivotHftReplaceCampaignIfLatestLevelChanged(const double close_price,
                                                 const datetime micro_bar_time)
{
  SignalTypes direction = NO_SIGNAL;
  PivotHftPivotLevels level = PIVOT_HFT_LEVEL_NONE;
  double level_price = 0.0;
  if(!PivotHftSelectCurrentTouchedLevel(close_price,
                                        direction,
                                        level,
                                        level_price))
    return;

  if(PivotHftCampaignMatches(direction, level, level_price))
    return;

  bool replacing_campaign =
    (g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE);
  PivotHftPivotLevels previous_level = g_pivot_hft_campaign.pivot_level;
  string previous_sequence = g_pivot_hft_campaign.sequence_id;
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE &&
     PivotHftCampaignBelongsToCurrentMicroBar() &&
     g_pivot_hft_campaign.direction == direction &&
     (int)level < (int)g_pivot_hft_campaign.pivot_level)
    return;
  if(PivotHftCampaignLevelOccupied(micro_bar_time, level))
  {
    PivotHftAuditLog("CAMPAIGN_LEVEL_OCCUPIED",
                     StringFormat("dir=%s|level=%s|bar=%I64d",
                                  EnumToString(direction),
                                  PivotHftLevelLabel(level),
                                  (long)micro_bar_time));
    PivotHftResetCampaign();
    return;
  }

  PivotHftStartCampaign(direction, level, level_price, micro_bar_time);
  if(replacing_campaign)
  {
    PivotHftAuditLog("CAMPAIGN_REPLACED",
                     StringFormat("previous_sequence=%s|previous_level=%s|sequence=%s|level=%s|price=%.5f",
                                  previous_sequence,
                                  PivotHftLevelLabel(previous_level),
                                  g_pivot_hft_campaign.sequence_id,
                                  PivotHftLevelLabel(level),
                                  level_price));
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
  if(!PivotHftCampaignBelongsToCurrentMicroBar())
    return;

  double current_quote = PivotHftCurrentEntryQuote(g_pivot_hft_campaign.direction);
  if(current_quote <= 0.0)
    return;

  if(g_pivot_hft_campaign.direction == BEARISH)
  {
    if(g_pivot_hft_campaign.tracked_extreme <= 0.0 ||
       current_quote > g_pivot_hft_campaign.tracked_extreme)
      g_pivot_hft_campaign.tracked_extreme = current_quote;

    double trigger_distance = PivotHftDistanceToPrice(Pivot_HFT_Retracement_Points);
    if(trigger_distance > 0.0 &&
       current_quote <= g_pivot_hft_campaign.tracked_extreme - trigger_distance)
    {
      g_pivot_hft_campaign.trigger_price = current_quote;
      g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_ORDER_WAIT;
      PivotHftAuditLog("ENTRY_TRIGGERED",
                       StringFormat("sequence=%s|dir=%s|level=%s|extreme=%.5f|threshold=%.5f|quote=%.5f|retrace_pts=%.2f",
                                    g_pivot_hft_campaign.sequence_id,
                                    EnumToString(g_pivot_hft_campaign.direction),
                                    PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level),
                                    g_pivot_hft_campaign.tracked_extreme,
                                    PivotHftNormalizePrice(g_pivot_hft_campaign.tracked_extreme - trigger_distance),
                                    current_quote,
                                    Pivot_HFT_Retracement_Points));
    }
    return;
  }

  if(g_pivot_hft_campaign.tracked_extreme <= 0.0 ||
     current_quote < g_pivot_hft_campaign.tracked_extreme)
    g_pivot_hft_campaign.tracked_extreme = current_quote;

  double trigger_distance = PivotHftDistanceToPrice(Pivot_HFT_Retracement_Points);
  if(trigger_distance > 0.0 &&
     current_quote >= g_pivot_hft_campaign.tracked_extreme + trigger_distance)
  {
    g_pivot_hft_campaign.trigger_price = current_quote;
    g_pivot_hft_campaign.status = PIVOT_HFT_CAMPAIGN_ORDER_WAIT;
    PivotHftAuditLog("ENTRY_TRIGGERED",
                     StringFormat("sequence=%s|dir=%s|level=%s|extreme=%.5f|threshold=%.5f|quote=%.5f|retrace_pts=%.2f",
                                  g_pivot_hft_campaign.sequence_id,
                                  EnumToString(g_pivot_hft_campaign.direction),
                                  PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level),
                                  g_pivot_hft_campaign.tracked_extreme,
                                  PivotHftNormalizePrice(g_pivot_hft_campaign.tracked_extreme + trigger_distance),
                                  current_quote,
                                  Pivot_HFT_Retracement_Points));
  }
}

bool PivotHftEntryIntentReady()
{
  return (g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_ORDER_WAIT &&
          PivotHftCampaignBelongsToCurrentMicroBar());
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
                     StringFormat("sequence=%s|attempt=%d|extreme=%.5f",
                                  g_pivot_hft_campaign.sequence_id,
                                  g_pivot_hft_campaign.attempt_count,
                                  g_pivot_hft_campaign.tracked_extreme));
  }
}

bool PivotHftDetectEntryIntent(const bool allow_new_campaign)
{
  datetime current_micro_bar = PivotHftCurrentMicroBar();
  if(current_micro_bar <= 0)
    return false;

  PivotHftResetPendingCampaignForNewMicroBar(current_micro_bar);
  if(!PivotHftRefreshPivotSnapshot(false))
    return false;
  if(!PivotHftRefreshBandsSnapshot(false))
    return false;

  if(g_pivot_hft_campaign.status == PIVOT_HFT_CAMPAIGN_TRACKING)
  {
    double tracking_close = PivotHftCurrentMicroClose();
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

  double close_price = PivotHftCurrentMicroClose();
  if(close_price <= 0.0)
    return false;

  PivotHftReplaceCampaignIfLatestLevelChanged(close_price,
                                              current_micro_bar);
  PivotHftUpdateTrackedExtreme();
  return PivotHftEntryIntentReady();
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_DETECTION_MQH_
