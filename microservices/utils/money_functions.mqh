//+------------------------------------------------------------------+
//|                        microservices/utils/money_functions.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_MONEY_FUNCTIONS_MQH_
#define _MICROSERVICES_UTILS_MONEY_FUNCTIONS_MQH_

#include "../core/enums.mqh"

// Funciones relacionadas con cálculos monetarios y de volumen en trading

// Devuelve el profit crudo (sin comisiones ni swaps) usando OrderCalcProfit.
// Si la divisa de tu cuenta es USD, el resultado estará en dólares.
double RawProfitUsd(SignalTypes signal_type,
                    double entry_price,
                    double close_price)
{
  string use_symbol = _Symbol;

  // Lote "más común": 1.0, ajustado a min/max/step del símbolo
  double volume = CommonVolume(use_symbol);
  bool   is_buy = (signal_type == BULLISH);

  ENUM_ORDER_TYPE order_type = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

  double profit_usd = 0.0;
  if(OrderCalcProfit(order_type, use_symbol, volume, entry_price, close_price, profit_usd))
    return profit_usd;

  // Fallback simple si OrderCalcProfit falla por alguna razón
  double tick_size  = SymbolInfoDouble(use_symbol, SYMBOL_TRADE_TICK_SIZE);
  double tick_value = SymbolInfoDouble(use_symbol, SYMBOL_TRADE_TICK_VALUE);
  if(tick_size <= 0.0)
    return 0.0;

  double ticks = (close_price - entry_price) / tick_size;
  double dir   = is_buy ? 1.0 : -1.0;
  return ticks * tick_value * volume * dir;
}

// Lote "típico" = 1.0 normalizado a los límites y step del símbolo
double CommonVolume(string symbol)
{
  double min_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  double max_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  double step_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

  double volume = 1.0;
  if(volume < min_vol) volume = min_vol;
  if(volume > max_vol) volume = max_vol;

  if(step_vol > 0.0)
  {
    volume = MathFloor((volume + 1e-12) / step_vol) * step_vol;
    // Normaliza los decimales del volumen según el step
    int vol_digits = (int)MathMax(0.0, MathRound(-MathLog10(step_vol)));
    volume = NormalizeDouble(volume, vol_digits);
  }

  return volume;
}

double NormalizeVolumeForSymbol(const string symbol, const double volume)
{
  double min_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  double max_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  double step_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

  double normalized = volume;

  if(min_vol > 0.0 && normalized < min_vol)
    normalized = min_vol;
  if(max_vol > 0.0 && normalized > max_vol)
    normalized = max_vol;

  if(step_vol > 0.0)
  {
    double steps = MathFloor((normalized + 1e-12) / step_vol);
    normalized   = steps * step_vol;
    int vol_digits = 0;
    if(step_vol < 1.0)
    {
      vol_digits = (int)MathRound(-MathLog10(step_vol));
      if(vol_digits < 0)
        vol_digits = 0;
    }
    normalized = NormalizeDouble(normalized, vol_digits);
  }

  return normalized;
}

double ConvertAmountToLots(const string symbol,
                           const double amount,
                           const double movement_points)
{
  if(amount <= 0.0 || movement_points <= 0.0)
    return 0.0;

  double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);

  if(tick_value <= 0.0 || tick_size <= 0.0 || point_size <= 0.0)
    return 0.0;

  double point_value = tick_value * (point_size / tick_size);
  if(point_value <= 0.0)
    return 0.0;

  double lots = amount / (point_value * movement_points);
  if(lots <= 0.0)
    return 0.0;

  return NormalizeVolumeForSymbol(symbol, lots);
}

double ConvertLotsToAmount(const string symbol,
                           const double lots,
                           const double movement_points)
{
  if(lots <= 0.0 || movement_points <= 0.0)
    return 0.0;

  double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);

  if(tick_value <= 0.0 || tick_size <= 0.0 || point_size <= 0.0)
    return 0.0;

  double point_value = tick_value * (point_size / tick_size);
  if(point_value <= 0.0)
    return 0.0;

  return lots * point_value * movement_points;
}

#endif // _MICROSERVICES_UTILS_MONEY_FUNCTIONS_MQH_
