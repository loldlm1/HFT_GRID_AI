//+------------------------------------------------------------------+
//|                         pivot_hft_panel.mqh                      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_PIVOT_HFT_PANEL_MQH_
#define _SERVICES_FRONTEND_PIVOT_HFT_PANEL_MQH_

string g_pivot_hft_last_panel_text = "";

string PivotHftCampaignStatusLabel(const PivotHftCampaignStatuses status)
{
  switch(status)
  {
    case PIVOT_HFT_CAMPAIGN_ARMED:
      return "ARMED";
    case PIVOT_HFT_CAMPAIGN_TRACKING:
      return "TRACKING";
    case PIVOT_HFT_CAMPAIGN_ORDER_WAIT:
      return "ENTRY READY";
    case PIVOT_HFT_CAMPAIGN_EXPIRED:
      return "CANCELLED";
    case PIVOT_HFT_CAMPAIGN_COMPLETED:
      return "COMPLETED";
    case PIVOT_HFT_CAMPAIGN_IDLE:
    default:
      return "IDLE";
  }
}

string PivotHftCampaignDisplayStatus(
  const PivotHftCampaignState &campaign)
{
  string label = PivotHftCampaignStatusLabel(campaign.status);
  if(campaign.retry_ordinal > 1)
    label = StringFormat("RETRY %d %s",
                         PivotHftMarketRetryNumber(campaign.retry_ordinal),
                         label);
  if(campaign.entry_safety.blocked)
    label += " RISK BLOCKED";
  return label;
}

string PivotHftCampaignSourceLabel(
  const PivotHftCampaignState &campaign)
{
  if(campaign.retry_ordinal <= 1 || campaign.retry_source_ticket == 0)
    return "";
  return StringFormat(" | source #%I64u", campaign.retry_source_ticket);
}

int PivotHftPositionCountByStatus(const PivotHftPositionStatuses target_status)
{
  int status_count = 0;
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
    if(g_pivot_hft_positions[i].status == target_status)
      status_count++;
  return status_count;
}

double PivotHftCampaignRetracementThresholdForState(
  const PivotHftCampaignState &campaign)
{
  if(campaign.tracked_extreme <= 0.0)
    return 0.0;

  if(Pivot_HFT_Retracement_Points <= 0.0)
    return 0.0;
  return PivotHftCampaignEntryThreshold(campaign);
}

bool PivotHftPositionAtBreakEvenOrBetter(const PivotHftPositionState &state)
{
  if(state.entry_price <= 0.0 || state.local_sl_price <= 0.0)
    return false;
  if(state.direction == BULLISH)
    return state.local_sl_price >= state.entry_price;
  if(state.direction == BEARISH)
    return state.local_sl_price <= state.entry_price;
  return false;
}

string PivotHftBuildPositionPanelLines()
{
  string text = "";
  int displayed = 0;
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total && displayed < 6; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    if(state.status != PIVOT_HFT_POSITION_ACTIVE &&
       state.status != PIVOT_HFT_POSITION_CLOSE_WAIT)
      continue;

    string target_text = "";
    if(state.local_tp_price > 0.0)
      target_text = StringFormat(" | TP %.5f", state.local_tp_price);

    string lifecycle_label = "LIVE";
    if(state.status == PIVOT_HFT_POSITION_CLOSE_WAIT)
    {
      lifecycle_label = StringFormat("CLOSE WAIT %s",
        PivotHftCloseTriggerLabel(state.close_trigger));
    }
    string retry_text = "";
    if(state.campaign_retry_ordinal > 1)
      retry_text = StringFormat(
        " | RETRY %d",
        PivotHftMarketRetryNumber(state.campaign_retry_ordinal));

    text += StringFormat("\n%s #%I64u %s %s%s | E %.5f | R %.2fpt BAND | SL %.5f | STEP %.2fpt[%d]%s",
                         lifecycle_label,
                         state.position_ticket,
                         PivotHftDirectionToken(state.direction),
                         PivotHftLevelLabel(state.pivot_level),
                         retry_text,
                         state.entry_price,
                         state.initial_sl_points,
                         state.local_sl_price,
                         state.trailing_step_points,
                         state.trailing_step_index,
                         target_text);
    displayed++;
  }
  return text;
}

bool PivotHftResolvePanelEntrySafety(
  const PivotHftCampaignState &campaign,
  PivotHftEntrySafetySnapshot &entry_safety)
{
  entry_safety = PivotHftEntrySafetySnapshot();
  if(campaign.entry_safety.evaluated_at > 0)
  {
    entry_safety = campaign.entry_safety;
    return true;
  }

  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionState state = g_pivot_hft_positions[i];
    if(state.status != PIVOT_HFT_POSITION_ACTIVE &&
       state.status != PIVOT_HFT_POSITION_CLOSE_WAIT)
      continue;
    if(state.entry_safety.evaluated_at <= 0)
      continue;
    entry_safety = state.entry_safety;
    return true;
  }
  return false;
}

string PivotHftBuildEntrySafetyPanelLine(
  const PivotHftCampaignState &campaign)
{
  PivotHftEntrySafetySnapshot entry_safety;
  if(!PivotHftResolvePanelEntrySafety(campaign, entry_safety))
    return "\nSafety WAIT | no evaluated entry intent";

  string safety_label = (entry_safety.valid && !entry_safety.blocked)
                        ? "SAFE"
                        : "RISK BLOCKED";
  return StringFormat("\nSafety %s | SL requested %.2f / required %.2f | spread %.2f | broker floor %.2f",
                      safety_label,
                      entry_safety.requested_sl_points,
                      entry_safety.required_initial_sl_points,
                      entry_safety.spread_points,
                      entry_safety.broker_floor_points);
}

string PivotHftLevelStatusList(const PivotHftLevelTestStatuses status)
{
  string text = "";
  for(int i = (int)PIVOT_HFT_LEVEL_R1;
      i < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      i++)
  {
    PivotHftPivotLevels level = (PivotHftPivotLevels)i;
    if(PivotHftGetLevelTestStatus(level) != status)
      continue;
    if(text != "")
      text += ",";
    text += PivotHftLevelLabel(level);
  }
  return (text == "") ? "-" : text;
}

void PivotHftResolvePanelCampaign(PivotHftCampaignState &campaign)
{
  campaign = g_pivot_hft_campaign;
  if(campaign.status == PIVOT_HFT_CAMPAIGN_IDLE)
    PivotHftGetExpiredCampaignVisual(campaign);
}

string PivotHftBuildPanelText()
{
  PivotHftCampaignState campaign;
  PivotHftResolvePanelCampaign(campaign);
  string campaign_level = PivotHftLevelLabel(campaign.pivot_level);
  string campaign_direction = (campaign.direction == NO_SIGNAL)
                              ? "-"
                              : PivotHftDirectionToken(campaign.direction);
  string retracement_text = (Pivot_HFT_Retracement_Points <= 0.0)
                            ? "IMMEDIATE"
                            : StringFormat("%.5f",
                                PivotHftCampaignRetracementThresholdForState(
                                  campaign));

  string text = "PIVOT HFT";
  text += StringFormat("\nMicro %s | Pivot %s | Session %s",
                       EnumToString(Pivot_HFT_Micro_Timeframe),
                       EnumToString(Pivot_HFT_Pivot_Timeframe),
                       SessionTimeFilterActiveSessionLabel());
  text += StringFormat("\nBands %.5f / %.5f | P %.5f",
                       g_pivot_hft_bands_lower,
                       g_pivot_hft_bands_upper,
                       g_pivot_hft_pivots.pivot);
  text += StringFormat("\nCampaign %s | %s %s %.5f | extreme %.5f%s",
                       PivotHftCampaignDisplayStatus(campaign),
                       campaign_direction,
                       campaign_level,
                       campaign.pivot_price,
                       campaign.tracked_extreme,
                       PivotHftCampaignSourceLabel(campaign));
  text += StringFormat("\nRetrace %s | Retry max %d | trigger quote %.5f | Live %d | CloseWait %d | %s",
                       retracement_text,
                       Pivot_HFT_Max_Retries_Per_Level,
                       campaign.trigger_price,
                       PivotHftPositionCountByStatus(
                         PIVOT_HFT_POSITION_ACTIVE),
                       PivotHftPositionCountByStatus(
                         PIVOT_HFT_POSITION_CLOSE_WAIT),
                       MarketStatusErrorSummary());
  text += PivotHftBuildEntrySafetyPanelLine(campaign);
  text += StringFormat("\nLevels burned %s | test open %s | history %s",
                       PivotHftLevelStatusList(PIVOT_HFT_LEVEL_BURNED),
                       PivotHftLevelStatusList(PIVOT_HFT_LEVEL_TOUCHED_OPEN),
                       PivotHftLevelTestStateReady() ? "READY" : "WAIT");
  text += PivotHftBuildPositionPanelLines();
  return text;
}

void RefreshPivotHftPanel()
{
  string panel_text = PivotHftBuildPanelText();
  if(panel_text == g_pivot_hft_last_panel_text)
    return;

  Comment(panel_text);
  g_pivot_hft_last_panel_text = panel_text;
}

void ClearPivotHftPanel()
{
  Comment("");
  g_pivot_hft_last_panel_text = "";
}

#endif // _SERVICES_FRONTEND_PIVOT_HFT_PANEL_MQH_
