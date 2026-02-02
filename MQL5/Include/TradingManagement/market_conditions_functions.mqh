
bool IsMarketOpen(bool last_check_execution = true)
{
  static datetime lastCheckTime = 0;
  static bool lastResult = false;

  datetime currentTime = TimeCurrent();

  // Solo verificamos una vez por hora
  if(currentTime - lastCheckTime < 60)
    return lastResult;

  lastCheckTime = currentTime;

  string symbol = _Symbol;
  MqlDateTime nowStruct;
  TimeToStruct(currentTime, nowStruct);

  // El índice de día de la semana en MQL5 va de 0 (domingo) a 6 (sábado)
  ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)nowStruct.day_of_week;

  // Cada símbolo puede tener varias sesiones por día. Asumimos máximo 2 por día.
  datetime from_time, to_time;

  for(int session=0; session < 3; session++)
  {
    if(SymbolInfoSessionTrade(symbol, dayOfWeek, session, from_time, to_time))
    {
      // Verificamos si la hora actual está dentro del rango de la sesión
      datetime today_from, today_to;
      today_from = StructToTime(nowStruct) - nowStruct.hour*3600 - nowStruct.min*60 - nowStruct.sec + from_time;
      today_to   = StructToTime(nowStruct) - nowStruct.hour*3600 - nowStruct.min*60 - nowStruct.sec + to_time;

      // Corrección si el rango pasa por la medianoche
      if(today_to < today_from)
        today_to += 24 * 3600;

      if(currentTime > (today_from+(1*60)) && currentTime < (today_to-(1*60)))
      {
        lastResult = true;
        return true;
      }
    }
  }

  lastResult = false;
  return false;
}
