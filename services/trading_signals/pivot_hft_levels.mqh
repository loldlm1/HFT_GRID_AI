//+------------------------------------------------------------------+
//|                         pivot_hft_levels.mqh                     |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_

const int PIVOT_HFT_LEVEL_SCAN_MAX_BARS = 50000;
const int PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS = 15;

double PivotHftResolveLevelPrice(const PivotHftPivotLevels level,
                                 const PivotHftPivotSnapshot &snapshot)
{
  switch(level)
  {
    case PIVOT_HFT_LEVEL_P:
      return snapshot.pivot;
    case PIVOT_HFT_LEVEL_R1:
      return snapshot.resistance_1;
    case PIVOT_HFT_LEVEL_R2:
      return snapshot.resistance_2;
    case PIVOT_HFT_LEVEL_R3:
      return snapshot.resistance_3;
    case PIVOT_HFT_LEVEL_S1:
      return snapshot.support_1;
    case PIVOT_HFT_LEVEL_S2:
      return snapshot.support_2;
    case PIVOT_HFT_LEVEL_S3:
      return snapshot.support_3;
    case PIVOT_HFT_LEVEL_NONE:
    default:
      return 0.0;
  }
}

bool PivotHftTimeframesValid()
{
  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  int pivot_seconds = PeriodSeconds(Pivot_HFT_Pivot_Timeframe);

  if(micro_seconds <= 0 || pivot_seconds <= 0)
    return false;
  if(micro_seconds > pivot_seconds)
    return false;
  return true;
}

double PivotHftPointSize()
{
  double point_size = g_symbol_constraints.point_size;
  if(point_size <= 0.0)
    point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double PivotHftTickSize()
{
  double tick_size = g_symbol_constraints.tick_size;
  if(tick_size <= 0.0)
    tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  if(tick_size <= 0.0)
    tick_size = PivotHftPointSize();
  return tick_size;
}

double PivotHftNormalizePrice(const double price)
{
  if(price <= 0.0)
    return 0.0;

  double tick_size = PivotHftTickSize();
  if(tick_size <= 0.0)
    return price;

  double rounded = MathRound(price / tick_size) * tick_size;
  int digits = _Digits;
  if(digits < 0)
    digits = 0;
  return NormalizeDouble(rounded, digits);
}

double PivotHftDistanceToPrice(const double points)
{
  if(points <= 0.0)
    return 0.0;
  return points * PivotHftPointSize();
}

bool PivotHftReadPreviousMacroBar(datetime &bar_time,
                                  double &bar_high,
                                  double &bar_low,
                                  double &bar_close)
{
  bar_time  = iTime(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_high  = iHigh(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_low   = iLow(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);
  bar_close = iClose(_Symbol, Pivot_HFT_Pivot_Timeframe, 1);

  if(bar_time <= 0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
    return false;
  if(bar_high < bar_low)
    return false;
  return true;
}

bool PivotHftLevelScanTouchesRate(const MqlRates &rate,
                                  const PivotHftPivotSnapshot &snapshot,
                                  ulong &touched_mask)
{
  touched_mask = 0;
  if(rate.time <= 0 || rate.high <= 0.0 || rate.low <= 0.0 ||
     rate.high < rate.low)
    return false;

  for(int i = (int)PIVOT_HFT_LEVEL_P;
      i < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      i++)
  {
    PivotHftPivotLevels level = (PivotHftPivotLevels)i;
    double level_price = PivotHftResolveLevelPrice(level, snapshot);
    if(level_price <= 0.0)
      continue;
    if(rate.low > level_price || rate.high < level_price)
      continue;

    touched_mask |= ((ulong)1 << i);
  }

  return (touched_mask != 0);
}

void PivotHftApplyHistoricalRate(const MqlRates &rate,
                                 const PivotHftPivotSnapshot &snapshot,
                                 ulong &touched_mask)
{
  touched_mask = 0;
  if(!PivotHftLevelScanTouchesRate(rate, snapshot, touched_mask))
    return;

  for(int i = (int)PIVOT_HFT_LEVEL_P;
      i < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      i++)
  {
    if((touched_mask & ((ulong)1 << i)) == 0)
      continue;
    PivotHftMarkHistoricalLevelTouched((PivotHftPivotLevels)i,
                                       rate.time);
  }
}

bool PivotHftApplyCurrentOpenRate(const datetime current_micro_bar,
                                  const PivotHftPivotSnapshot &snapshot)
{
  if(current_micro_bar <= 0)
    return false;

  double bar_high = iHigh(_Symbol, Pivot_HFT_Micro_Timeframe, 0);
  double bar_low  = iLow(_Symbol, Pivot_HFT_Micro_Timeframe, 0);
  if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
    return false;

  MqlRates rate;
  rate.time        = current_micro_bar;
  rate.open        = 0.0;
  rate.high        = bar_high;
  rate.low         = bar_low;
  rate.close       = 0.0;
  rate.tick_volume = 0;
  rate.spread      = 0;
  rate.real_volume = 0;

  ulong touched_mask = 0;
  if(!PivotHftLevelScanTouchesRate(rate, snapshot, touched_mask))
    return true;

  for(int i = (int)PIVOT_HFT_LEVEL_P;
      i < PIVOT_HFT_LEVEL_SLOT_TOTAL;
      i++)
  {
    if((touched_mask & ((ulong)1 << i)) == 0)
      continue;
    PivotHftMarkLevelTouchedInOpenMicroBar((PivotHftPivotLevels)i,
                                           current_micro_bar);
  }
  return true;
}

bool PivotHftLevelScanSeriesReady(string &failure_reason)
{
  failure_reason = "";
  ResetLastError();
  long micro_synchronized = SeriesInfoInteger(_Symbol,
                                              Pivot_HFT_Micro_Timeframe,
                                              SERIES_SYNCHRONIZED);
  int error_code = GetLastError();
  if(micro_synchronized != 1)
  {
    failure_reason = StringFormat("micro_series_unsynchronized|err=%d",
                                  error_code);
    return false;
  }

  ResetLastError();
  long macro_synchronized = SeriesInfoInteger(_Symbol,
                                              Pivot_HFT_Pivot_Timeframe,
                                              SERIES_SYNCHRONIZED);
  error_code = GetLastError();
  if(macro_synchronized != 1)
  {
    failure_reason = StringFormat("macro_series_unsynchronized|err=%d",
                                  error_code);
    return false;
  }
  return true;
}

bool PivotHftScanMissingClosedMicroBars(
  const PivotHftPivotSnapshot &snapshot,
  const datetime activation_bar,
  const datetime current_micro_bar,
  const datetime latest_closed_bar,
  datetime &scanned_through,
  int &scanned_count,
  ulong &scanned_touch_mask,
  string &failure_reason)
{
  scanned_through = PivotHftLevelTestLastClosedBar();
  scanned_count = 0;
  scanned_touch_mask = 0;
  failure_reason = "";

  if(latest_closed_bar <= 0 || latest_closed_bar < activation_bar)
  {
    scanned_through = 0;
    return true;
  }

  int micro_seconds = PeriodSeconds(Pivot_HFT_Micro_Timeframe);
  if(micro_seconds <= 0)
  {
    failure_reason = "invalid_micro_period_seconds";
    return false;
  }

  datetime scan_from = activation_bar;
  if(scanned_through > 0)
  {
    long next_open = (long)scanned_through + 1;
    if(next_open > (long)latest_closed_bar)
      return true;
    scan_from = (datetime)next_open;
  }

  if(scan_from > latest_closed_bar)
    return true;

  long span_seconds = (long)latest_closed_bar - (long)scan_from;
  long expected_bars = span_seconds / (long)micro_seconds + 1;
  if(expected_bars > PIVOT_HFT_LEVEL_SCAN_MAX_BARS)
  {
    failure_reason = StringFormat("history_window_exceeds_limit|expected=%I64d|limit=%d",
                                  expected_bars,
                                  PIVOT_HFT_LEVEL_SCAN_MAX_BARS);
    return false;
  }

  PivotHftAuditLog("LEVEL_SCAN_START",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|from=%I64d|through=%I64d|cursor=%I64d|limit=%d",
                                (long)activation_bar,
                                (long)snapshot.source_bar_time,
                                (long)scan_from,
                                (long)latest_closed_bar,
                                (long)scanned_through,
                                PIVOT_HFT_LEVEL_SCAN_MAX_BARS));

  MqlRates rates[];
  ResetLastError();
  int copied = CopyRates(_Symbol,
                         Pivot_HFT_Micro_Timeframe,
                         scan_from,
                         latest_closed_bar,
                         rates);
  int error_code = GetLastError();
  if(copied <= 0 || copied > PIVOT_HFT_LEVEL_SCAN_MAX_BARS)
  {
    failure_reason = StringFormat("copy_rates|from=%I64d|through=%I64d|copied=%d|err=%d",
                                  (long)scan_from,
                                  (long)latest_closed_bar,
                                  copied,
                                  error_code);
    return false;
  }

  ArraySetAsSeries(rates, false);
  datetime previous_time = 0;
  for(int i = 0; i < copied; i++)
  {
    MqlRates rate;
    rate = rates[i];
    if(rate.time <= previous_time)
      continue;
    previous_time = rate.time;
    if(rate.time < scan_from || rate.time > latest_closed_bar ||
       rate.time >= current_micro_bar)
      continue;
    if(rate.high <= 0.0 || rate.low <= 0.0 || rate.high < rate.low)
    {
      failure_reason = StringFormat("invalid_rate|bar=%I64d|high=%.5f|low=%.5f",
                                    (long)rate.time,
                                    rate.high,
                                    rate.low);
      return false;
    }

    ulong rate_touch_mask = 0;
    PivotHftApplyHistoricalRate(rate, snapshot, rate_touch_mask);
    scanned_touch_mask |= rate_touch_mask;
    scanned_count++;
    scanned_through = rate.time;
  }

  if(scanned_through < latest_closed_bar)
  {
    failure_reason = StringFormat("incomplete_copy|last=%I64d|required=%I64d|copied=%d",
                                  (long)scanned_through,
                                  (long)latest_closed_bar,
                                  copied);
    return false;
  }
  return true;
}

bool PivotHftRefreshLevelTestState()
{
  if(!g_pivot_hft_pivots.valid ||
     g_pivot_hft_last_macro_bar <= 0 ||
     g_pivot_hft_pivots.source_bar_time <= 0)
    return false;

  datetime current_micro_bar = iTime(_Symbol,
                                     Pivot_HFT_Micro_Timeframe,
                                     0);
  if(current_micro_bar <= 0 ||
     current_micro_bar < g_pivot_hft_last_macro_bar)
  {
    PivotHftMarkLevelTestUnavailable("micro_bar_unavailable",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  bool same_context = PivotHftLevelTestContextMatches(
    g_pivot_hft_last_macro_bar,
    g_pivot_hft_pivots.source_bar_time);
  datetime previous_micro_bar = PivotHftLevelTestLastMicroBar();
  if(same_context && PivotHftLevelTestStateReady() &&
     previous_micro_bar == current_micro_bar)
  {
    if(PivotHftApplyCurrentOpenRate(current_micro_bar,
                                    g_pivot_hft_pivots))
      return true;

    PivotHftMarkLevelTestUnavailable("current_micro_bar_unavailable",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  datetime latest_closed_bar = iTime(_Symbol,
                                     Pivot_HFT_Micro_Timeframe,
                                     1);
  if(latest_closed_bar < 0 || latest_closed_bar >= current_micro_bar)
  {
    PivotHftMarkLevelTestUnavailable("closed_micro_bar_unavailable",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  if(same_context && previous_micro_bar > 0 &&
     current_micro_bar > previous_micro_bar)
    PivotHftCommitOpenMicroBar(previous_micro_bar);

  if(!same_context)
    PivotHftPrepareLevelTestContext(g_pivot_hft_last_macro_bar,
                                    g_pivot_hft_pivots.source_bar_time);

  datetime now_time = TimeCurrent();
  if(!PivotHftLevelTestRetryAllowed(now_time) &&
     !PivotHftLevelTestStateReady())
    return false;

  string failure_reason = "";
  if(!PivotHftLevelScanSeriesReady(failure_reason))
  {
    PivotHftMarkLevelTestUnavailable(failure_reason,
                                     now_time +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  datetime scanned_through = PivotHftLevelTestLastClosedBar();
  datetime previous_cursor = scanned_through;
  bool was_ready = PivotHftLevelTestStateReady();
  int scanned_count = 0;
  ulong scanned_touch_mask = 0;
  bool scan_ok = PivotHftScanMissingClosedMicroBars(
    g_pivot_hft_pivots,
    g_pivot_hft_last_macro_bar,
    current_micro_bar,
    latest_closed_bar,
    scanned_through,
    scanned_count,
    scanned_touch_mask,
    failure_reason);
  if(!scan_ok)
  {
    PivotHftMarkLevelTestUnavailable(failure_reason,
                                     now_time +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  if(!PivotHftApplyCurrentOpenRate(current_micro_bar,
                                   g_pivot_hft_pivots))
  {
    PivotHftMarkLevelTestUnavailable("current_micro_bar_unavailable",
                                     now_time +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  PivotHftMarkLevelTestReady(scanned_through, current_micro_bar);
  if(scanned_count > 0 || !same_context ||
     previous_cursor != scanned_through || !was_ready)
    PivotHftAuditLog("LEVEL_SCAN_RESULT",
                     StringFormat("activation_bar=%I64d|source_bar=%I64d|from_cursor=%I64d|through=%I64d|bars=%d|historical_mask=%I64u|burned_mask=%I64u|open_mask=%I64u",
                                  (long)g_pivot_hft_last_macro_bar,
                                  (long)g_pivot_hft_pivots.source_bar_time,
                                  (long)previous_cursor,
                                  (long)scanned_through,
                                  scanned_count,
                                  scanned_touch_mask,
                                  PivotHftLevelTestMask(),
                                  PivotHftLevelOpenTouchMask()));
  return true;
}

bool PivotHftRefreshPivotSnapshot(const bool force_refresh = false)
{
  if(!PivotHftTimeframesValid())
    return false;

  datetime current_macro_bar = iTime(_Symbol, Pivot_HFT_Pivot_Timeframe, 0);
  if(current_macro_bar <= 0)
  {
    PivotHftMarkLevelTestUnavailable("macro_bar_unavailable",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  if(!force_refresh &&
     current_macro_bar == g_pivot_hft_last_macro_bar &&
     g_pivot_hft_pivots.valid)
    return PivotHftRefreshLevelTestState();

  datetime source_bar_time = 0;
  double bar_high = 0.0;
  double bar_low = 0.0;
  double bar_close = 0.0;
  if(!PivotHftReadPreviousMacroBar(source_bar_time,
                                   bar_high,
                                   bar_low,
                                   bar_close))
  {
    PivotHftMarkLevelTestUnavailable("macro_source_ohlc_unavailable",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  double pivot = (bar_high + bar_low + bar_close) / 3.0;
  PivotHftPivotSnapshot snapshot;
  snapshot.source_bar_time = source_bar_time;
  snapshot.pivot           = PivotHftNormalizePrice(pivot);
  snapshot.resistance_1   = PivotHftNormalizePrice(2.0 * pivot - bar_low);
  snapshot.resistance_2   = PivotHftNormalizePrice(pivot + bar_high - bar_low);
  snapshot.resistance_3   = PivotHftNormalizePrice(bar_high + 2.0 * (pivot - bar_low));
  snapshot.support_1      = PivotHftNormalizePrice(2.0 * pivot - bar_high);
  snapshot.support_2      = PivotHftNormalizePrice(pivot - bar_high + bar_low);
  snapshot.support_3      = PivotHftNormalizePrice(bar_low - 2.0 * (bar_high - pivot));
  snapshot.valid           = (snapshot.pivot > 0.0 &&
                             snapshot.resistance_1 > 0.0 &&
                             snapshot.support_1 > 0.0);

  if(!snapshot.valid)
  {
    PivotHftMarkLevelTestUnavailable("pivot_snapshot_invalid",
                                     TimeCurrent() +
                                     PIVOT_HFT_LEVEL_SCAN_RETRY_SECONDS);
    return false;
  }

  if(g_pivot_hft_last_macro_bar > 0 &&
     current_macro_bar != g_pivot_hft_last_macro_bar)
    PivotHftFinalizeLevelTestContext(current_macro_bar);

  g_pivot_hft_pivots = snapshot;
  g_pivot_hft_last_macro_bar = current_macro_bar;
  PivotHftAuditLog("PIVOT_SET_REFRESH",
                   StringFormat("activation_bar=%I64d|source_bar=%I64d|pivot=%.5f|r1=%.5f|r2=%.5f|r3=%.5f|s1=%.5f|s2=%.5f|s3=%.5f",
                                (long)current_macro_bar,
                                (long)source_bar_time,
                                snapshot.pivot,
                                snapshot.resistance_1,
                                snapshot.resistance_2,
                                snapshot.resistance_3,
                                snapshot.support_1,
                                snapshot.support_2,
                                snapshot.support_3));
  if(g_pivot_hft_campaign.status != PIVOT_HFT_CAMPAIGN_IDLE)
    PivotHftResetCampaign();
  return PivotHftRefreshLevelTestState();
}

string PivotHftLevelLabel(const PivotHftPivotLevels level)
{
  switch(level)
  {
    case PIVOT_HFT_LEVEL_P:
      return "P";
    case PIVOT_HFT_LEVEL_R1:
      return "R1";
    case PIVOT_HFT_LEVEL_R2:
      return "R2";
    case PIVOT_HFT_LEVEL_R3:
      return "R3";
    case PIVOT_HFT_LEVEL_S1:
      return "S1";
    case PIVOT_HFT_LEVEL_S2:
      return "S2";
    case PIVOT_HFT_LEVEL_S3:
      return "S3";
    case PIVOT_HFT_LEVEL_NONE:
    default:
      return "NONE";
  }
}

bool PivotHftDirectionAllowed(const SignalTypes direction)
{
  if(direction == BULLISH)
    return (Pivot_HFT_Direction_Mode == BOTH_DIRECTION ||
            Pivot_HFT_Direction_Mode == BULLISH_DIRECTION);
  if(direction == BEARISH)
    return (Pivot_HFT_Direction_Mode == BOTH_DIRECTION ||
            Pivot_HFT_Direction_Mode == BEARISH_DIRECTION);
  return false;
}

bool PivotHftLatestResistanceTouched(const double close_price,
                                     PivotHftPivotLevels &level,
                                     double &level_price)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(!g_pivot_hft_pivots.valid ||
     !PivotHftLevelTestStateReady() ||
     close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_R1,
                                       PIVOT_HFT_LEVEL_R2,
                                       PIVOT_HFT_LEVEL_R3};
  for(int i = 2; i >= 0; i--)
  {
    if(!PivotHftLevelIsAvailable(candidates[i]))
      continue;
    double candidate_price = PivotHftResolveLevelPrice(candidates[i],
                                                       g_pivot_hft_pivots);
    if(candidate_price > 0.0 && close_price >= candidate_price)
    {
      level = candidates[i];
      level_price = candidate_price;
      return true;
    }
  }
  return false;
}

bool PivotHftLatestUnoccupiedResistanceTouched(
  const double close_price,
  const ulong occupied_levels,
  PivotHftPivotLevels &level,
  double &level_price,
  ulong &occupied_mask,
  bool &touched_any)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  occupied_mask = 0;
  touched_any = false;
  if(!g_pivot_hft_pivots.valid ||
     !PivotHftLevelTestStateReady() ||
     close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_R1,
                                       PIVOT_HFT_LEVEL_R2,
                                       PIVOT_HFT_LEVEL_R3};
  for(int i = 2; i >= 0; i--)
  {
    PivotHftPivotLevels candidate = candidates[i];
    if(!PivotHftLevelIsAvailable(candidate))
      continue;

    double candidate_price = PivotHftResolveLevelPrice(
      candidate,
      g_pivot_hft_pivots);
    if(candidate_price <= 0.0 || close_price < candidate_price)
      continue;

    touched_any = true;
    ulong candidate_mask = ((ulong)1 << (int)candidate);
    if((occupied_levels & candidate_mask) != 0)
    {
      occupied_mask |= candidate_mask;
      continue;
    }

    level = candidate;
    level_price = candidate_price;
    return true;
  }
  return false;
}

bool PivotHftLatestSupportTouched(const double close_price,
                                  PivotHftPivotLevels &level,
                                  double &level_price)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  if(!g_pivot_hft_pivots.valid ||
     !PivotHftLevelTestStateReady() ||
     close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_S1,
                                       PIVOT_HFT_LEVEL_S2,
                                       PIVOT_HFT_LEVEL_S3};
  for(int i = 2; i >= 0; i--)
  {
    if(!PivotHftLevelIsAvailable(candidates[i]))
      continue;
    double candidate_price = PivotHftResolveLevelPrice(candidates[i],
                                                       g_pivot_hft_pivots);
    if(candidate_price > 0.0 && close_price <= candidate_price)
    {
      level = candidates[i];
      level_price = candidate_price;
      return true;
    }
  }
  return false;
}

bool PivotHftLatestUnoccupiedSupportTouched(
  const double close_price,
  const ulong occupied_levels,
  PivotHftPivotLevels &level,
  double &level_price,
  ulong &occupied_mask,
  bool &touched_any)
{
  level = PIVOT_HFT_LEVEL_NONE;
  level_price = 0.0;
  occupied_mask = 0;
  touched_any = false;
  if(!g_pivot_hft_pivots.valid ||
     !PivotHftLevelTestStateReady() ||
     close_price <= 0.0)
    return false;

  PivotHftPivotLevels candidates[3] = {PIVOT_HFT_LEVEL_S1,
                                       PIVOT_HFT_LEVEL_S2,
                                       PIVOT_HFT_LEVEL_S3};
  for(int i = 2; i >= 0; i--)
  {
    PivotHftPivotLevels candidate = candidates[i];
    if(!PivotHftLevelIsAvailable(candidate))
      continue;

    double candidate_price = PivotHftResolveLevelPrice(
      candidate,
      g_pivot_hft_pivots);
    if(candidate_price <= 0.0 || close_price > candidate_price)
      continue;

    touched_any = true;
    ulong candidate_mask = ((ulong)1 << (int)candidate);
    if((occupied_levels & candidate_mask) != 0)
    {
      occupied_mask |= candidate_mask;
      continue;
    }

    level = candidate;
    level_price = candidate_price;
    return true;
  }
  return false;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_LEVELS_MQH_
