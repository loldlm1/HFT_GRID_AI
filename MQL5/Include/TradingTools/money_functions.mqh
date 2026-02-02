
//+------------------------------------------------------------------+
//|                                              money_functions.mqh |
//+------------------------------------------------------------------+

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
