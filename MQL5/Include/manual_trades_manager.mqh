//+------------------------------------------------------------------+
//|                                               ControlsDialog.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
int    Daily_Bullish_Signals  = 0;
int    Daily_Bearish_Signals  = 0;
int    Position_TP_Multiplier = 1;
double Custom_SL_Buy_Price    = 0;
double Custom_SL_Sell_Price   = 0;
double Bullish_Low_SL         = 0;
double Bearish_High_SL        = 0;
double EA_button_open_sell    = false;
double EA_button_open_buy     = false;

//+------------------------------------------------------------------+
//| Create the Infrastructure panel                                         |
//+------------------------------------------------------------------+
void KeydownButtonsEvent(long keydown_pressed)
{
  bool  close_status      = false;
  ulong ticket            = 0;

  if(46 == keydown_pressed) // CLOSE LAST POSITION (DEL)
  {
    ticket = GetMostRecentPosition();
    CloseFreezeStopsPosition(ticket);
  }

  if(103 == keydown_pressed) //CLOSE ALL BUYS (7)
  {
    CloseAllPositions(BULLISH, close_status);
  }

  if(104 == keydown_pressed) //CLOSE ALL SELLS (8)
  {
    CloseAllPositions(BEARISH, close_status);
  }

  if(66 == keydown_pressed) // (B)
  {
    //SetAllPositionsBE();
  }

  if(81 == keydown_pressed) // (Q)
  {

  }

  if(87 == keydown_pressed) // (W)
  {

  }


  if(69 == keydown_pressed) // (E)
  {
    //SetAllStoredPositionsBE();
  }

  if(82 == keydown_pressed) // (R)
  {
    //SetAllStoredPositionsTP();
  }

  if(68 == keydown_pressed) // SET/DISABLE STOP LOSS & TP (D)
  {

  }

  if(97 == keydown_pressed) // (1)
  {
    // BUY BUTTOM +++
    EA_button_open_buy  = true;
    EA_button_open_sell = false;
    RemoveSellSLZone();
  }

  if(98 == keydown_pressed) // (2)
  {
    // SELL BUTTOM +++
    EA_button_open_sell = true;
    EA_button_open_buy  = false;
    RemoveBuySLZone();
  }

  if(13 == keydown_pressed) // (ENTER NUMBER)
  {
    if(EA_button_open_buy)
    {
      if(OpenCustomBuy(1))
      {
        OpenCustomBuy(3);
        RemoveBuySLZone();
        EA_button_open_buy = false;
      }
    }

    if(EA_button_open_sell)
    {
      if(OpenCustomSell(1))
      {
        OpenCustomSell(3);
        RemoveSellSLZone();
        EA_button_open_sell = false;
      }
    }
  }

  if(27 == keydown_pressed) // (ESC)
  {
    // ESC RERMOVES EVERYTHING
    RemoveBuySLZone();
    RemoveSellSLZone();
    EA_button_open_buy  = false;
    EA_button_open_sell = false;
  }
}

void BuildCustomStructBuy()
{
  double open_price        = NormalizeDouble(Ask, _Digits);
  double atr_lower_price_0 = GetATRFactorLowerPrice(_Period, 0);
  double atr_lower_price_1 = GetATRFactorLowerPrice(_Period, 1);
  double atr_lower_price   = atr_lower_price_0 <= atr_lower_price_1 ? atr_lower_price_0 : atr_lower_price_1;

  if(Custom_SL_Buy_Price > 0) atr_lower_price = Custom_SL_Buy_Price - local_spread;

  // BUILDING THE GRADIENT POSITION
  BuildGradientBuyZone(open_price, atr_lower_price);
}

void BuildCustomStructSell()
{
  double open_price        = NormalizeDouble(Bid, _Digits);
  double atr_upper_price_0 = GetATRFactorUpperPrice(_Period, 0);
  double atr_upper_price_1 = GetATRFactorUpperPrice(_Period, 1);
  double atr_upper_price   = atr_upper_price_0 >= atr_upper_price_1 ? atr_upper_price_0 : atr_upper_price_1;

  if(Custom_SL_Sell_Price > 0) atr_upper_price = Custom_SL_Sell_Price + local_spread;

  // BUILDING THE GRADIENT POSITION
  BuildGradientSellZone(open_price, atr_upper_price);
}

bool OpenCustomBuy(int tp_multiplier)
{
  Position_TP_Multiplier = tp_multiplier;
  SignalParams bullish_signal_params;
 
  bullish_signal_params.strategy_type = stoch_divergence_signal;
  SetPositionRiskManagment(_Period, BULLISH, bullish_signal_params);

  if(Custom_SL_Buy_Price > 0) bullish_signal_params.position_sl = Custom_SL_Buy_Price - local_spread;

  bool position_opened = OpenBuyPosition(bullish_signal_params, TimeCurrent(), _Period);

  if(position_opened)
  {
    Daily_Bullish_Signals += 1;
    StoreBullishSignalParams(_Period, bullish_signal_params);
  }

  return position_opened;
}

bool OpenCustomSell(int tp_multiplier)
{
  Position_TP_Multiplier = tp_multiplier;
  SignalParams bearish_signal_params;
 
  bearish_signal_params.strategy_type = stoch_divergence_signal;
  SetPositionRiskManagment(_Period, BEARISH, bearish_signal_params);

  if(Custom_SL_Sell_Price > 0) bearish_signal_params.position_sl = Custom_SL_Sell_Price + local_spread;

  bool position_opened = OpenSellPosition(bearish_signal_params, TimeCurrent(), _Period);

  if(position_opened)
  {
    Daily_Bearish_Signals += 1;
    StoreBearishSignalParams(_Period, bearish_signal_params);
  }

  return position_opened;
}

void SetPositionRiskManagment(ENUM_TIMEFRAMES timeframe, int type, SignalParams &signal_params)
{
  double open_price                = 0;
  double stop_loss                 = 0;
  double ratio_fibo_tp             = 0;
  double custom_step_size_points   = 0;
  double custom_step_size_decimals = 0;
  double take_profit               = 0;
  double stops_level               = (m_symbol.StopsLevel()/decimal_digits);
  double tp_points                 = Position_Step_Size/decimal_digits;
  double atr_points                = Position_Step_Size;
  int    bullish_positions_total   = EAPositionsTotal(BULLISH);
  int    bearish_positions_total   = EAPositionsTotal(BEARISH);

  if(type == BULLISH)
  {
    custom_step_size_decimals               = Position_Step_Size/decimal_digits;
    open_price                              = NormalizeDouble(Ask, _Digits);
    take_profit                             = NormalizeDouble(open_price+tp_points, _Digits);
    stop_loss                               = open_price-custom_step_size_decimals;

    CalculateATRBasedBullishSL(timeframe, open_price, take_profit, stop_loss, atr_points, stops_level);

    signal_params.position_open_price       = open_price;
    signal_params.position_sl               = stop_loss;
    signal_params.position_tp               = (bullish_positions_total <= 0 || TargetPosType == Indicator_SL_TP) ? take_profit : 0;
    signal_params.position_grid_points      = atr_points;
    signal_params.grid_start_price          = open_price;
    signal_params.position_percentage       = Percentage_Lot_Risk;
  }

  if(type == BEARISH)
  {
    custom_step_size_decimals              = Position_Step_Size/decimal_digits;
    open_price                             = NormalizeDouble(Bid, _Digits);
    take_profit                            = NormalizeDouble(open_price-tp_points, _Digits);
    stop_loss                              = open_price+custom_step_size_decimals;

    CalculateATRBasedBearishSL(timeframe, open_price, take_profit, stop_loss, atr_points, stops_level);

    signal_params.position_open_price      = open_price;
    signal_params.position_sl              = stop_loss;
    signal_params.position_tp              = (bearish_positions_total <= 0 || TargetPosType == Indicator_SL_TP) ? take_profit : 0;
    signal_params.position_grid_points     = atr_points;
    signal_params.grid_start_price         = open_price;
    signal_params.position_percentage      = Percentage_Lot_Risk;
  }
}

// ATR Risk Based

void CalculateATRBasedBullishSL(ENUM_TIMEFRAMES timeframe, double &open_price, double &take_profit, double &stop_loss, double &atr_points, double stops_level)
{
  int atr_price_index = 1;

  open_price                = NormalizeDouble(Ask, _Digits);
  double closing_price      = NormalizeDouble(Bid-stops_level, _Digits); // BID CLOSES SL FOR BUYS
  double profit_price       = NormalizeDouble(Ask+stops_level, _Digits);
  double atr_lower_price_0  = GetATRFactorLowerPrice(timeframe, 0);
  double atr_cross_price    = GetATRFactorLowerPrice(timeframe, atr_price_index);
  double atr_lower_price_1  = atr_lower_price_0 <= atr_cross_price ? atr_lower_price_0 : atr_cross_price;

  if(Custom_SL_Buy_Price > 0) atr_lower_price_1 = Custom_SL_Buy_Price - local_spread;

  double atr_lower_points   = NormalizeDouble(open_price-atr_lower_price_1, _Digits);

  take_profit = NormalizeDouble(open_price+(atr_lower_points*Position_TP_Multiplier), _Digits);
  stop_loss   = atr_lower_price_1;
  atr_points  = atr_lower_points*decimal_digits;

  if(stop_loss >= closing_price)
  {
    stop_loss        = closing_price-(1/decimal_digits);
    atr_lower_points = NormalizeDouble(open_price-stop_loss, _Digits);
    take_profit      = NormalizeDouble(open_price+(atr_lower_points*Position_TP_Multiplier), _Digits);
  }
}

void CalculateATRBasedBearishSL(ENUM_TIMEFRAMES timeframe, double &open_price, double &take_profit, double &stop_loss, double &atr_points, double stops_level)
{
  int atr_price_index = 1;

  open_price               = NormalizeDouble(Bid, _Digits);
  double closing_price     = NormalizeDouble(Ask+stops_level, _Digits); // ASK CLOSE SL FOR SELLS
  double profit_price      = NormalizeDouble(Bid-stops_level, _Digits);
  double atr_upper_price_0 = GetATRFactorUpperPrice(timeframe, 0);
  double atr_cross_price   = GetATRFactorUpperPrice(timeframe, atr_price_index);
  double atr_upper_price_1 = atr_upper_price_0 >= atr_cross_price ? atr_upper_price_0 : atr_cross_price;

  if(Custom_SL_Sell_Price > 0) atr_upper_price_1 = Custom_SL_Sell_Price + local_spread;
  
  double atr_upper_points  = NormalizeDouble(atr_upper_price_1-open_price, _Digits);

  take_profit = NormalizeDouble(open_price-(atr_upper_points*Position_TP_Multiplier), _Digits);
  stop_loss   = atr_upper_price_1;
  atr_points  = atr_upper_points*decimal_digits;

  if(stop_loss <= closing_price)
  {
    stop_loss        = closing_price+(1/decimal_digits);
    atr_upper_points = NormalizeDouble(stop_loss-open_price, _Digits);
    take_profit      = NormalizeDouble(open_price-(atr_upper_points*Position_TP_Multiplier), _Digits);
  }
}

// ++ FRONT END ++

void BuildGradientBuyZone(double open_price, double sl_price)
{
  int      subwindow        = 0;
  long     w_height         = 0;
  long     w_width          = 0;
  datetime start_chart_time = 0;
  datetime end_chart_time   = 0;
  double   start_price      = 0;
  double   end_price        = 0;
  double current_price_size = 0;
  double past_price_size    = 0;
  string   base_buy_name    = "CUSTOM_BUY_OPEN";
  string   each_buy_name    = "";
  double   range_price_size = (open_price - sl_price) / 11;
  color    base_buy_color[11] = {
    C'243, 255, 230',
    C'240, 255, 223',
    C'237, 255, 216',
    C'234, 255, 209',
    C'232, 255, 202',
    C'229, 254, 195',
    C'226, 254, 188',
    C'223, 254, 181',
    C'221, 254, 174',
    C'218, 254, 167',
    C'215, 254, 160'
  };
  uchar    opacity          = 8;
  color    argb_color       = C'215,254,160';
  ChartGetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS, 0, w_height);
  ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS, 0, w_width);
  ChartXYToTimePrice(0, 0, 0, subwindow, start_chart_time, start_price);
  ChartXYToTimePrice(0, (int)w_width, 0, subwindow, end_chart_time, end_price);

  for(int i = 0; i <= 11; i++)
  {
    each_buy_name      = base_buy_name + "_" + (string)i;
    current_price_size = sl_price + i * range_price_size;

    if(past_price_size > 0)
    {
      argb_color = base_buy_color[i-1];
      if(ObjectFind(ChartID(), each_buy_name) < 0) ObjectCreate(ChartID(), each_buy_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);

      ObjectSetInteger(ChartID(), each_buy_name, OBJPROP_TIME, 0, start_chart_time);
      ObjectSetInteger(ChartID(), each_buy_name, OBJPROP_TIME, 1, end_chart_time);
      ObjectSetDouble(ChartID(), each_buy_name, OBJPROP_PRICE, 0, past_price_size);
      ObjectSetDouble(ChartID(), each_buy_name, OBJPROP_PRICE, 1, current_price_size);
      ObjectSetInteger(ChartID(), each_buy_name, OBJPROP_COLOR, argb_color);
      ObjectSetInteger(ChartID(), each_buy_name, OBJPROP_FILL, true);
      ObjectSetInteger(ChartID(), each_buy_name, OBJPROP_BACK, true);
    }

    past_price_size = current_price_size;
  }
}

void BuildGradientSellZone(double open_price, double sl_price)
{
  int      subwindow        = 0;
  long     w_height         = 0;
  long     w_width          = 0;
  datetime start_chart_time = 0;
  datetime end_chart_time   = 0;
  double   start_price      = 0;
  double   end_price        = 0;
  double current_price_size = 0;
  double past_price_size    = 0;
  string   base_sell_name   = "CUSTOM_SELL_OPEN";
  string   each_sell_name   = "";
  double   range_price_size = (sl_price - open_price) / 11;
  color    base_sell_color[11] = {
    C'255, 223, 217',
    C'254, 226, 219',
    C'254, 228, 222',
    C'253, 231, 224',
    C'253, 234, 226',
    C'252, 236, 228',
    C'252, 239, 231',
    C'251, 242, 233',
    C'250, 244, 235',
    C'250, 247, 237',
    C'249, 250, 240'
  };
  uchar    opacity          = 8;
  color    argb_color       = C'255,223,217';
  ChartGetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS, 0, w_height);
  ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS, 0, w_width);
  ChartXYToTimePrice(0, 0, 0, subwindow, start_chart_time, start_price);
  ChartXYToTimePrice(0, (int)w_width, 0, subwindow, end_chart_time, end_price);

  for(int i = 0; i <= 11; i++)
  {
    each_sell_name      = base_sell_name + "_" + (string)i;
    current_price_size = open_price + i * range_price_size;

    if(past_price_size > 0)
    {
      argb_color = base_sell_color[i-1];
      if(ObjectFind(ChartID(), each_sell_name) < 0) ObjectCreate(ChartID(), each_sell_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);

      ObjectSetInteger(ChartID(), each_sell_name, OBJPROP_TIME, 0, start_chart_time);
      ObjectSetInteger(ChartID(), each_sell_name, OBJPROP_TIME, 1, end_chart_time);
      ObjectSetDouble(ChartID(), each_sell_name, OBJPROP_PRICE, 0, past_price_size);
      ObjectSetDouble(ChartID(), each_sell_name, OBJPROP_PRICE, 1, current_price_size);
      ObjectSetInteger(ChartID(), each_sell_name, OBJPROP_COLOR, argb_color);
      ObjectSetInteger(ChartID(), each_sell_name, OBJPROP_FILL, true);
      ObjectSetInteger(ChartID(), each_sell_name, OBJPROP_BACK, true);
    }

    past_price_size = current_price_size;
  }
}

void RemoveBuySLZone()
{
  for(int i = 1; i <= 11; i++)
  {
    ObjectDelete(ChartID(), "CUSTOM_BUY_OPEN" + "_" + (string)i);
  }
  Bullish_Low_SL = 0;
  Custom_SL_Buy_Price  = 0;
}

void RemoveSellSLZone()
{
  for(int i = 1; i <= 11; i++)
  {
    ObjectDelete(ChartID(), "CUSTOM_SELL_OPEN" + "_" + (string)i);
  }
  Bearish_High_SL = 0;
  Custom_SL_Sell_Price  = 0;
}

void RemoveObjectsByName(string name)
{
  long chart_id = ChartID();
  int  total    = ObjectsTotal(chart_id, 0);

  for(int i=total-1; i >= 0; i--)
  {
    string obj_name = ObjectName(chart_id, i, 0);

    if(StringFind(obj_name, name) == 0)
    {
      ObjectDelete(chart_id, obj_name);
    }
  }
}

///++++++++++++++++++++++++///
