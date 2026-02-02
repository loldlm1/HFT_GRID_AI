
bool CheckCCISignal(int direction, int current_indicator_handle)
{
  double signal=CCI(1, current_indicator_handle);
  if(signal==EMPTY_VALUE) return(false);

  //--- check the Buy signal
  if(direction==BULLISH && (signal<-50)) return true;

  //--- check the Sell signal
  if(direction==BEARISH && (signal>50)) return true;

  return(false);
}

bool CheckRSIConfirmation(int direction, int current_indicator_handle)
{
  double signal=RSI(1, current_indicator_handle);
  if(signal==EMPTY_VALUE) return(false);

  //--- check the Buy signal
  if(direction==BULLISH && (signal<40)) return true;

  //--- check the Sell signal
  if(direction==BEARISH && (signal>60)) return true;

  //--- successful completion of the check
  return(false);
}

bool CheckMFIConfirmation(int direction, int current_indicator_handle)
{
  double signal=MFI(1, current_indicator_handle);
  if(signal==EMPTY_VALUE) return(false);

  //--- check the Buy signal
  if(direction==BULLISH && (signal<40)) return true;

  //--- check the Sell signal
  if(direction==BEARISH && (signal>60)) return true;

  //--- successful completion of the check
  return(false);
}

bool CheckStochConfirmation(int direction, int current_indicator_handle)
{
  double main_2   = StochMain(2, current_indicator_handle);
  double main_1   = StochMain(1, current_indicator_handle);
  double signal_1 = StochSignal(1, current_indicator_handle);

  //--- check the Buy signal
  if(
    direction == BULLISH  &&
    main_1     < 20
  ) return true;

  //--- check the Sell signal
  if(
    direction == BEARISH &&
    main_1     > 80
  ) return true;

  //--- successful completion of the check
  return(false);
}

// CONFIRMATION TO CLOSE A SIGNAL OPENED BY ITS INDICATOR
bool CheckIndicatorSignalOverBS(int direction, int current_indicator_handle)
{
  double confirmation = 0;

  if(Robot_Indicator == ROBOT_RSI)   confirmation = RSI(1, current_indicator_handle);
  if(Robot_Indicator == ROBOT_STOCH) confirmation = StochMain(1, current_indicator_handle);

  if(confirmation == EMPTY_VALUE)
  {
    Print("[ERROR] CONFIRMATION CLOSED VARIABLE IS EMPTY_VALUE...");
    TesterStop();
  }

  //--- check to close Buy signal
  if(direction==BULLISH && (confirmation>Risk_Indicator_TP_Percent)) return true;

  //--- check to close Sell signal
  if(direction==BEARISH && (confirmation<Risk_Indicator_TP_Percent)) return true;

  return false;
}

//+------------------------------------------------------------------+
//| CCI indicator value at the specified bar                         |
//+------------------------------------------------------------------+
double CCI(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, 0, 0, index+2, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the CCI indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}

//+------------------------------------------------------------------+
//| MFI indicator value at the specified bar                         |
//+------------------------------------------------------------------+
double MFI(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, 0, 0, index+2, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the MFI indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| RSI indicator value at the specified bar                         |
//+------------------------------------------------------------------+
double RSI(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, 0, 0, index+2, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the RSI indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| Stochastic indicator value at the specified bar                  |
//+------------------------------------------------------------------+
double StochMain(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, MAIN_LINE, 0, index+4, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| Stochastic Signal value at the specified bar                  |
//+------------------------------------------------------------------+
double StochSignal(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, SIGNAL_LINE, 0, index+4, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| B % indicator value at the specified bar                  |
//+------------------------------------------------------------------+
double BPercentMain(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, 0, 0, index+4, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the iB % indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| B % Signal value at the specified bar                  |
//+------------------------------------------------------------------+
double BPercentSignal(int index, int current_indicator_handle)
{
  double indicator_values[];
  if(CopyBuffer(current_indicator_handle, 1, 0, index+4, indicator_values)<0)
  {
    //--- if the copying fails, report the error code
    PrintFormat("Failed to copy data from the iB % indicator, error code %d", GetLastError());
    return(EMPTY_VALUE);
  }
  ArraySetAsSeries(indicator_values, true);
  return(NormalizeDouble(indicator_values[index], 2));
}
//+------------------------------------------------------------------+
//| ATR FACTOR indicator value at the specified bar                  |
//+------------------------------------------------------------------+
double GetATRFactorUpperPrice(int shift, int current_indicator_handle)
{
	double indicator_values[];
	ArraySetAsSeries(indicator_values, true);

	if(CopyBuffer(current_indicator_handle, 0, 0, shift+2, indicator_values) < 0)
  {
    Print("ERROR LOADING ATR INDICATOR HANDLE DATA... ", current_indicator_handle);
    TesterStop();
    return EMPTY_VALUE;
  }

	return NormalizeDouble(indicator_values[shift], _Digits+1);
}

double GetATRFactorLowerPrice(int shift, int current_indicator_handle)
{
	double indicator_values[];
	ArraySetAsSeries(indicator_values, true);

	if(CopyBuffer(current_indicator_handle, 1, 0, shift+2, indicator_values) < 0)
  {
    Print("ERROR LOADING ATR INDICATOR HANDLE DATA... ", current_indicator_handle);
    TesterStop();
    return EMPTY_VALUE;
  }

	return NormalizeDouble(indicator_values[shift], _Digits+1);
}

double GetATRFactorPoints(int shift, int current_indicator_handle)
{
	double indicator_values[];
	ArraySetAsSeries(indicator_values, true);

	if(CopyBuffer(current_indicator_handle, 2, 0, shift+2, indicator_values) < 0)
  {
    Print("ERROR LOADING ATR INDICATOR HANDLE DATA... ", current_indicator_handle);
    TesterStop();
    return EMPTY_VALUE;
  }

	return NormalizeDouble(indicator_values[shift], _Digits+1);
}
