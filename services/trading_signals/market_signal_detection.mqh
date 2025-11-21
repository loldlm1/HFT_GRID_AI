//+------------------------------------------------------------------+
//|                             market_signal_detection.mqh         |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_

void DetectBullishSignal()
{
  if(!CanAttemptSignal(BULLISH)) return;

  SignalParams signal_bullish;

  signal_bullish.signal_type = BULLISH;
  signal_bullish.entry_price = g_ask;
  signal_bullish.entry_time  = iTime(_Symbol, PERIOD_CURRENT, 0);

  SetTFBandsPercentDataToSignalParams(signal_bullish);
  SetTFAlligatorDataToSignalParams(signal_bullish);
  SetTFStochasticDataToSignalParams(signal_bullish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bullish);
  SetTFBodyMADataToSignalParams(signal_bullish);

  if(!LoadTrendStructureData(signal_bullish))
    return;
  if(!LoadMacroStructureData(signal_bullish))
    return;
  if(!LoadSessionStructureData(signal_bullish))
    return;

  if(!EvaluateSignalTrigger(signal_bullish, BULLISH))
    return;

  if(!BaseChannelMaFilterAllowsSignal(signal_bullish))
  {
    if(Enable_Logs)
      Print("Base channel MA filter blocked bullish signal.");
    return;
  }

  if(!LoadTrendFilterData(signal_bullish))
    return;
  if(!TrendFilterAllowsSignal(signal_bullish, BULLISH))
  {
    if(Enable_Logs)
      Print("Trend filter blocked bullish signal.");
    return;
  }

  if(!LoadMacroFilterData(signal_bullish))
    return;
  if(!MacroFilterAllowsSignal(signal_bullish, BULLISH))
  {
    if(Enable_Logs)
      Print("Macro filter blocked bullish signal.");
    return;
  }

  if(!LoadSessionFilterData(signal_bullish))
    return;
  if(!SessionFilterAllowsSignal(signal_bullish, BULLISH))
  {
    if(Enable_Logs)
      Print("Session filter blocked bullish signal.");
    return;
  }

  if(!TrendChannelMaFilterAllowsSignal(signal_bullish))
  {
    if(Enable_Logs)
      Print("Trend channel MA filter blocked bullish signal.");
    return;
  }

  if(!MacroChannelMaFilterAllowsSignal(signal_bullish))
  {
    if(Enable_Logs)
      Print("Macro channel MA filter blocked bullish signal.");
    return;
  }

  if(!SessionChannelMaFilterAllowsSignal(signal_bullish))
  {
    if(Enable_Logs)
      Print("Session channel MA filter blocked bullish signal.");
    return;
  }

  if(!BuildGridOrderForSignal(signal_bullish))
  {
    Print("Grid plan failed for bullish signal, aborting detection.");
    return;
  }

  if(!ChannelGuardAllowsPendingSignal(signal_bullish, "BULLISH"))
    return;

  AddElementToArray(running_bullish_signals, signal_bullish);
  RegisterFreshStructureUsage(signal_bullish);
  RegisterDailySignalStart(signal_bullish);
}

void DetectBearishSignal()
{
  if(!CanAttemptSignal(BEARISH)) return;

  SignalParams signal_bearish;

  signal_bearish.signal_type = BEARISH;
  signal_bearish.entry_price = g_bid;
  signal_bearish.entry_time  = iTime(_Symbol, PERIOD_CURRENT, 0);

  SetTFBandsPercentDataToSignalParams(signal_bearish);
  SetTFAlligatorDataToSignalParams(signal_bearish);
  SetTFStochasticDataToSignalParams(signal_bearish);
  SetTFStochasticMarketStructureDataToSignalParams(signal_bearish);
  SetTFBodyMADataToSignalParams(signal_bearish);

  if(!LoadTrendStructureData(signal_bearish))
    return;
  if(!LoadMacroStructureData(signal_bearish))
    return;
  if(!LoadSessionStructureData(signal_bearish))
    return;

  if(!EvaluateSignalTrigger(signal_bearish, BEARISH))
    return;

  if(!BaseChannelMaFilterAllowsSignal(signal_bearish))
  {
    if(Enable_Logs)
      Print("Base channel MA filter blocked bearish signal.");
    return;
  }

  if(!LoadTrendFilterData(signal_bearish))
    return;
  if(!TrendFilterAllowsSignal(signal_bearish, BEARISH))
  {
    if(Enable_Logs)
      Print("Trend filter blocked bearish signal.");
    return;
  }

  if(!LoadMacroFilterData(signal_bearish))
    return;
  if(!MacroFilterAllowsSignal(signal_bearish, BEARISH))
  {
    if(Enable_Logs)
      Print("Macro filter blocked bearish signal.");
    return;
  }

  if(!LoadSessionFilterData(signal_bearish))
    return;
  if(!SessionFilterAllowsSignal(signal_bearish, BEARISH))
  {
    if(Enable_Logs)
      Print("Session filter blocked bearish signal.");
    return;
  }

  if(!TrendChannelMaFilterAllowsSignal(signal_bearish))
  {
    if(Enable_Logs)
      Print("Trend channel MA filter blocked bearish signal.");
    return;
  }

  if(!MacroChannelMaFilterAllowsSignal(signal_bearish))
  {
    if(Enable_Logs)
      Print("Macro channel MA filter blocked bearish signal.");
    return;
  }

  if(!SessionChannelMaFilterAllowsSignal(signal_bearish))
  {
    if(Enable_Logs)
      Print("Session channel MA filter blocked bearish signal.");
    return;
  }

  if(!BuildGridOrderForSignal(signal_bearish))
  {
    Print("Grid plan failed for bearish signal, aborting detection.");
    return;
  }

  if(!ChannelGuardAllowsPendingSignal(signal_bearish, "BEARISH"))
    return;

  AddElementToArray(running_bearish_signals, signal_bearish);
  RegisterFreshStructureUsage(signal_bearish);
  RegisterDailySignalStart(signal_bearish);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_DETECTION_MQH_
