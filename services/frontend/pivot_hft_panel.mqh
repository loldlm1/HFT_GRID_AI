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
      return "EXPIRED";
    case PIVOT_HFT_CAMPAIGN_COMPLETED:
      return "COMPLETED";
    case PIVOT_HFT_CAMPAIGN_IDLE:
    default:
      return "IDLE";
  }
}

int PivotHftActivePositionCount()
{
  int active_count = 0;
  int total = ArraySize(g_pivot_hft_positions);
  for(int i = 0; i < total; i++)
  {
    PivotHftPositionStatuses status = g_pivot_hft_positions[i].status;
    if(status == PIVOT_HFT_POSITION_ACTIVE ||
       status == PIVOT_HFT_POSITION_CLOSE_WAIT)
      active_count++;
  }
  return active_count;
}

double PivotHftCampaignRetracementTrigger()
{
  if(g_pivot_hft_campaign.trigger_price > 0.0)
    return g_pivot_hft_campaign.trigger_price;
  if(g_pivot_hft_campaign.tracked_extreme <= 0.0)
    return 0.0;

  double distance = PivotHftDistanceToPrice(Pivot_HFT_Retracement_Points);
  if(distance <= 0.0)
    return 0.0;
  if(g_pivot_hft_campaign.direction == BEARISH)
    return PivotHftNormalizePrice(g_pivot_hft_campaign.tracked_extreme - distance);
  if(g_pivot_hft_campaign.direction == BULLISH)
    return PivotHftNormalizePrice(g_pivot_hft_campaign.tracked_extreme + distance);
  return 0.0;
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

    text += StringFormat("\n#%I64u %s %s entry %.5f SL %.5f step %d BE %s",
                         state.position_ticket,
                         PivotHftDirectionToken(state.direction),
                         PivotHftLevelLabel(state.pivot_level),
                         state.entry_price,
                         state.local_sl_price,
                         state.trailing_step_index,
                         PivotHftPositionAtBreakEvenOrBetter(state) ? "YES" : "NO");
    displayed++;
  }
  return text;
}

string PivotHftBuildPanelText()
{
  string campaign_level = PivotHftLevelLabel(g_pivot_hft_campaign.pivot_level);
  string campaign_direction = (g_pivot_hft_campaign.direction == NO_SIGNAL)
                              ? "-"
                              : PivotHftDirectionToken(g_pivot_hft_campaign.direction);

  string text = "PIVOT HFT";
  text += StringFormat("\nMicro %s | Pivot %s | Session %s",
                       EnumToString(Pivot_HFT_Micro_Timeframe),
                       EnumToString(Pivot_HFT_Pivot_Timeframe),
                       SessionTimeFilterActiveSessionLabel());
  text += StringFormat("\nBands %.5f / %.5f | P %.5f",
                       g_pivot_hft_bands_lower,
                       g_pivot_hft_bands_upper,
                       g_pivot_hft_pivots.pivot);
  text += StringFormat("\nCampaign %s | %s %s %.5f | extreme %.5f",
                       PivotHftCampaignStatusLabel(g_pivot_hft_campaign.status),
                       campaign_direction,
                       campaign_level,
                       g_pivot_hft_campaign.pivot_price,
                       g_pivot_hft_campaign.tracked_extreme);
  text += StringFormat("\nRetrace trigger %.5f | Active positions %d | %s",
                       PivotHftCampaignRetracementTrigger(),
                       PivotHftActivePositionCount(),
                       MarketStatusErrorSummary());
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
