/*
enum ImbalancePriceType
{
  IMB_PRICE_CLOSE = 0,
  IMB_PRICE_LOW   = 1,
  IMB_PRICE_HIGH  = 2
};

struct ImbalanceModel
{
  datetime imb_time;
  double   imb_high;
  double   imb_low;
  bool     imb_valid;

  ImbalanceModel()
  {
    imb_time  = 0;
    imb_high  = 0;
    imb_low   = 0;
    imb_valid = false;
  }
};

// ++ IMBALANCES ALGO LOGIC ++

int CheckBullishImbalancesTrend(ENUM_TIMEFRAMES timeframe)
{
  ImbalanceModel bullish_imbalances[];
  ImbalanceModel new_imbalance;
  bool     inside_imbalance  = false;
  datetime time_1            = iTime(_Symbol, timeframe, 1);
  double   low_price_1       = iLow(_Symbol, timeframe, 1);
  double   prev_low          = 0;
  double   prev_high         = 0;
  double   curr_high         = 0;
  double   curr_close        = 0;
  datetime curr_time         = 0;
  double   curr_low          = 0;
  double   next_low          = 0;
  bool     imb_valid         = false;
  double   imb_high          = 0;
  double   imb_low           = 0;

  // STORE VALID IMBALANCES IN 34 PERIODS
  for(int i = 34; i >= 2; i--)
  {
    prev_low   = iLow(_Symbol, timeframe, i+1);
    prev_high  = iHigh(_Symbol, timeframe, i+1);
    curr_high  = iHigh(_Symbol, timeframe, i);
    curr_close = iClose(_Symbol, timeframe, i);
    curr_time  = iTime(_Symbol, timeframe, i);
    curr_low   = iLow(_Symbol, timeframe, i);
    next_low   = iLow(_Symbol, timeframe, i-1);

    // Detectar imbalance alcista
    if(curr_close > prev_high)
    {
      // Creamos un nuevo imbalance y lo añadimos al array
      new_imbalance.imb_time  = iTime(_Symbol, timeframe, i);
      new_imbalance.imb_high  = prev_high;
      new_imbalance.imb_low   = prev_low;
      new_imbalance.imb_valid = true;
      bullish_imb_total = AddElementToArray(bullish_imbalances, new_imbalance);
    }

    // Verificar mitigaciones
    for(int j = bullish_imb_total - 1; j >= 0; j--)
    {
      // Si el bajo de la vela actual toca el alto del imbalance, se mitiga
      if(curr_time > bullish_imbalances[j].imb_time && curr_low <= bullish_imbalances[j].imb_high && bullish_imbalances[j].imb_valid)
      {
        bullish_imb_total = RemoveElementFromArray(bullish_imbalances, j); // Eliminamos los imbalances mitigados
      }
    }
  }

  // LOOP CURRENT CLOSE PRICE ON THE STORED IMBALANCES
  for(int imb_i = 0; imb_i < bullish_imb_total; imb_i++)
  {
    inside_imbalance = false;
    imb_valid        = bullish_imbalances[imb_i].imb_valid;
    imb_high         = bullish_imbalances[imb_i].imb_high;
    imb_low          = bullish_imbalances[imb_i].imb_low;

    if(
      imb_valid               &&
      low_price_1 <= imb_high &&
      low_price_1 >= imb_low
    ) return BULLISH;
  }

  return -1;
}

bool CheckBearishImbalancesTrend(ENUM_TIMEFRAMES timeframe, int imbalances_depth, ImbalancePriceType price_check_type, ImbalanceModel &bearish_imbalances[])
{
  ImbalanceModel new_imbalance;
  bool     inside_imbalance  = false;
  int      bearish_imb_total = ArraySize(bearish_imbalances)-1;
  datetime bearish_imb_time  = bearish_imb_total < 0 ? 0 : bearish_imbalances[0].imb_time;
  datetime time_0            = iTime(_Symbol, timeframe, 0);
  double   imb_price_0       = iClose(_Symbol, timeframe, 0);
  double   prev_low          = 0;
  double   prev_high         = 0;
  double   curr_high         = 0;
  double   curr_close        = 0;
  datetime curr_time         = 0;
  double   curr_low          = 0;
  double   next_low          = 0;
  double   next_high         = 0;
  bool     imb_valid         = false;
  double   imb_high          = 0;
  double   imb_low           = 0;

  if(price_check_type == IMB_PRICE_CLOSE) imb_price_0 = iClose(_Symbol, timeframe, 0);
  if(price_check_type == IMB_PRICE_HIGH)  imb_price_0 = iHigh(_Symbol, timeframe, 0);

  // STORE VALID IMBALANCES IN 34 PERIODS
  if(time_0 > bearish_imb_time)
  {
    ArrayResize(bearish_imbalances, 1, 35);
    bearish_imbalances[0].imb_time  = time_0;
    bearish_imbalances[0].imb_high  = 0;
    bearish_imbalances[0].imb_low   = 0;
    bearish_imbalances[0].imb_valid = false;

    for(int i = imbalances_depth; i >= 1; i--)
    {
      prev_low   = iLow(_Symbol, timeframe, i+1);
      prev_high  = iHigh(_Symbol, timeframe, i+1);
      curr_high  = iHigh(_Symbol, timeframe, i);
      curr_close = iClose(_Symbol, timeframe, i);
      curr_time  = iTime(_Symbol, timeframe, i);
      curr_low   = iLow(_Symbol, timeframe, i);
      next_low   = iLow(_Symbol, timeframe, i-1);
      next_high  = iHigh(_Symbol, timeframe, i-1);

      // Detectar imbalance alcista
      if(curr_close < prev_low && next_high < prev_low)
      {
        // Creamos un nuevo imbalance y lo añadimos al array
        new_imbalance.imb_time  = iTime(_Symbol, timeframe, i);
        new_imbalance.imb_high  = prev_high;
        new_imbalance.imb_low   = prev_low;
        new_imbalance.imb_valid = true;
        bearish_imb_total       = ArraySize(bearish_imbalances);
        ArrayResize(bearish_imbalances, bearish_imb_total + 1);  // Expandimos el array
        bearish_imbalances[bearish_imb_total] = new_imbalance;  // Guardamos el imbalance
      }

      // Verificar mitigaciones
      for(int j = ArraySize(bearish_imbalances) - 1; j >= 0; j--)
      {
        // Si el alto de la vela actual toca el bajo del imbalance, se mitiga
        if(curr_time > bearish_imbalances[j].imb_time && curr_high >= bearish_imbalances[j].imb_low && bearish_imbalances[j].imb_valid)
        {
          ArrayRemove(bearish_imbalances, j); // Eliminamos los imbalances mitigados
        }
      }
    }

    bearish_imb_total = ArraySize(bearish_imbalances)-1;
  }

  // LOOP CURRENT CLOSE PRICE ON THE STORED IMBALANCES
  for(int imb_i = 0; imb_i <= bearish_imb_total; imb_i++)
  {
    inside_imbalance = false;
    imb_valid        = bearish_imbalances[imb_i].imb_valid;
    imb_high         = bearish_imbalances[imb_i].imb_high;
    imb_low          = bearish_imbalances[imb_i].imb_low;

    if(
      imb_valid           &&
      imb_price_0 >= imb_low  &&
      imb_price_0 <= imb_high
    ) inside_imbalance = true;

    if(
      imb_valid         &&
      imb_price_0 > imb_high
    ) bearish_imbalances[imb_i].imb_valid = false;
  }

  return inside_imbalance;
}

bool CheckCurrentBullishImbalance(ENUM_TIMEFRAMES timeframe, ImbalancePriceType price_check_type)
{
  double high_2      = iHigh(_Symbol, timeframe, 2);
  double close_1     = iClose(_Symbol, timeframe, 1);
  double imb_price_0 = iClose(_Symbol, timeframe, 0);

  if(price_check_type == IMB_PRICE_CLOSE) imb_price_0 = iClose(_Symbol, timeframe, 0);
  if(price_check_type == IMB_PRICE_LOW)   imb_price_0 = iLow(_Symbol, timeframe, 0);

  if(
    close_1      > high_2 &&
    imb_price_0 <= high_2
  ) return true;

  return false;
}

bool CheckCurrentBearishImbalance(ENUM_TIMEFRAMES timeframe, ImbalancePriceType price_check_type)
{
  double low_2       = iLow(_Symbol, timeframe, 2);
  double close_1     = iClose(_Symbol, timeframe, 1);
  double imb_price_0 = iClose(_Symbol, timeframe, 0);

  if(price_check_type == IMB_PRICE_CLOSE) imb_price_0 = iClose(_Symbol, timeframe, 0);
  if(price_check_type == IMB_PRICE_HIGH)  imb_price_0 = iHigh(_Symbol, timeframe, 0);

  if(
    close_1      < low_2 &&
    imb_price_0 >= low_2
  ) return true;

  return false;
}
*/

//+------------------------------------------------------------------+
//| Detecta y dibuja sólo imbalances alcistas                         |
//+------------------------------------------------------------------+
int CheckBullishImbalancesTrend(ENUM_TIMEFRAMES timeframe)
{
  datetime time_0          = iTime(_Symbol, timeframe, 0);
  double   low_price_0     = iLow (_Symbol, timeframe, 0);
  double   low_price_1     = iLow (_Symbol, timeframe, 1);
  double   running_min_low = DBL_MAX;

  for(int i = 2; i <= 34; i++)
  {
    double   prev_low   = iLow (_Symbol, timeframe, i+1);
    double   prev_high  = iHigh(_Symbol, timeframe, i+1);
    double   curr_close = iClose(_Symbol, timeframe, i);
    datetime curr_time  = iTime (_Symbol, timeframe, i);

    if(curr_close > prev_high && running_min_low > prev_high)
    {
      if(low_price_1 <= prev_high && low_price_1 >= prev_low && low_price_0 >= prev_low)
      {
        //DrawBullishImbalance(timeframe, curr_time, time_0, prev_high, prev_low);
        return(1);
      }
    }

    double next_low = iLow(_Symbol, timeframe, i);
    running_min_low = MathMin(running_min_low, next_low);
  }

  return(0);
}

//+------------------------------------------------------------------+
//| Detecta y dibuja sólo imbalances bajistas                        |
//+------------------------------------------------------------------+
int CheckBearishImbalancesTrend(ENUM_TIMEFRAMES timeframe)
{
  datetime time_0           = iTime(_Symbol, timeframe, 0);
  double   high_price_0     = iHigh(_Symbol, timeframe, 0);
  double   high_price_1     = iHigh(_Symbol, timeframe, 1);
  double   running_max_high = -DBL_MAX;

  for(int i = 2; i <= 34; i++)
  {
    double   prev_low   = iLow (_Symbol, timeframe, i+1);
    double   prev_high  = iHigh(_Symbol, timeframe, i+1);
    double   curr_close = iClose(_Symbol, timeframe, i);
    datetime curr_time  = iTime (_Symbol, timeframe, i);

    if(curr_close < prev_low && running_max_high < prev_low)
    {
      if(high_price_1 >= prev_low && high_price_1 <= prev_high && high_price_0 <= prev_high)
      {
        //DrawBearishImbalance(timeframe, curr_time, time_0, prev_low, prev_high);
        return(1);
      }
    }

    double curr_high = iHigh(_Symbol, timeframe, i);
    running_max_high = MathMax(running_max_high, curr_high);
  }

  return(0);
}

//+------------------------------------------------------------------+
//| Dibuja un imbalance alcista en todos los charts de ese timeframe |
//+------------------------------------------------------------------+
void DrawBullishImbalance(ENUM_TIMEFRAMES timeframe,
                          datetime        time_start,
                          datetime        time_end,
                          double          price_high,
                          double          price_low)
{
  // Nombre único por timeframe, para poder borrarlo luego
  string obj_name = StringFormat("bull_imb_%s", EnumToString(timeframe));
  Print(obj_name, " - ", time_start);

  // Recorremos todos los charts abiertos
  if(ObjectFind(0, obj_name) != -1)
    ObjectDelete(0, obj_name);

  // Creamos el nuevo rectángulo
  ObjectCreate (0, obj_name, OBJ_RECTANGLE, 0,
                time_start, price_high,
                time_end,   price_low);
  ObjectSetInteger(0, obj_name, OBJPROP_COLOR,        C'215,254,160');
  ObjectSetInteger(0, obj_name, OBJPROP_BACK,         true);
  ObjectSetInteger(0, obj_name, OBJPROP_FILL,         true);
}

//+------------------------------------------------------------------+
//| Dibuja un imbalance bajista en todos los charts de ese timeframe |
//+------------------------------------------------------------------+
void DrawBearishImbalance(ENUM_TIMEFRAMES timeframe,
                          datetime        time_start,
                          datetime        time_end,
                          double          price_low,
                          double          price_high)
{
  string obj_name = StringFormat("bear_imb_%s", EnumToString(timeframe));
  Print(obj_name, " - ", time_start);

  // Recorremos todos los charts abiertos
  if(ObjectFind(0, obj_name) != -1)
    ObjectDelete(0, obj_name);

  ObjectCreate (0, obj_name, OBJ_RECTANGLE, 0,
                time_start, price_low,
                time_end,   price_high);
  ObjectSetInteger(0, obj_name, OBJPROP_COLOR,        C'255,224,213');
  ObjectSetInteger(0, obj_name, OBJPROP_BACK,         true);
  ObjectSetInteger(0, obj_name, OBJPROP_FILL,         true);
}
