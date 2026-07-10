//+------------------------------------------------------------------+
//|                         extremum_engine_state.mqh                |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXTREMUM_ENGINE_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_EXTREMUM_ENGINE_STATE_MQH_

struct ExtremumEngineRevisionState
{
  bool     valid;
  string   revision_id;
  int      revision_index;
  datetime snapshot_time;
  datetime extremum_time;
  double   extremum_price;
  double   depth_percent_raw;
  double   distance_from_first_points;
  double   distance_from_previous_points;
  double   depth_delta_from_previous_percent;
  int      bars_since_cycle_start;
  int      attempt_count;

  ExtremumEngineRevisionState()
  {
    valid = false;
    revision_id = "";
    revision_index = 0;
    snapshot_time = 0;
    extremum_time = 0;
    extremum_price = 0.0;
    depth_percent_raw = 0.0;
    distance_from_first_points = 0.0;
    distance_from_previous_points = 0.0;
    depth_delta_from_previous_percent = 0.0;
    bars_since_cycle_start = 0;
    attempt_count = 0;
  }

  ExtremumEngineRevisionState(const ExtremumEngineRevisionState &other)
  {
    valid = other.valid;
    revision_id = other.revision_id;
    revision_index = other.revision_index;
    snapshot_time = other.snapshot_time;
    extremum_time = other.extremum_time;
    extremum_price = other.extremum_price;
    depth_percent_raw = other.depth_percent_raw;
    distance_from_first_points = other.distance_from_first_points;
    distance_from_previous_points = other.distance_from_previous_points;
    depth_delta_from_previous_percent = other.depth_delta_from_previous_percent;
    bars_since_cycle_start = other.bars_since_cycle_start;
    attempt_count = other.attempt_count;
  }
};

struct ExtremumEngineCycleState
{
  bool     active;
  string   cycle_id;
  string   cycle_status;
  int      engine_id;
  ENUM_TIMEFRAMES engine_timeframe;
  bool     is_peak;
  datetime first_seen_time;
  datetime finalized_time;
  datetime reference_peak_time;
  double   reference_peak_price;
  datetime reference_bottom_time;
  double   reference_bottom_price;
  double   reference_range_points;
  datetime first_extremum_time;
  double   first_extremum_price;
  datetime final_extremum_time;
  double   final_extremum_price;
  double   final_depth_percent;
  int      revision_count;
  int      attempt_count;
  ExtremumEngineRevisionState current_revision;

  ExtremumEngineCycleState()
  {
    active = false;
    cycle_id = "";
    cycle_status = "";
    engine_id = EXTREMUM_ENGINE_NONE;
    engine_timeframe = PERIOD_CURRENT;
    is_peak = false;
    first_seen_time = 0;
    finalized_time = 0;
    reference_peak_time = 0;
    reference_peak_price = 0.0;
    reference_bottom_time = 0;
    reference_bottom_price = 0.0;
    reference_range_points = 0.0;
    first_extremum_time = 0;
    first_extremum_price = 0.0;
    final_extremum_time = 0;
    final_extremum_price = 0.0;
    final_depth_percent = 0.0;
    revision_count = 0;
    attempt_count = 0;
    current_revision = ExtremumEngineRevisionState();
  }

  ExtremumEngineCycleState(const ExtremumEngineCycleState &other)
  {
    active = other.active;
    cycle_id = other.cycle_id;
    cycle_status = other.cycle_status;
    engine_id = other.engine_id;
    engine_timeframe = other.engine_timeframe;
    is_peak = other.is_peak;
    first_seen_time = other.first_seen_time;
    finalized_time = other.finalized_time;
    reference_peak_time = other.reference_peak_time;
    reference_peak_price = other.reference_peak_price;
    reference_bottom_time = other.reference_bottom_time;
    reference_bottom_price = other.reference_bottom_price;
    reference_range_points = other.reference_range_points;
    first_extremum_time = other.first_extremum_time;
    first_extremum_price = other.first_extremum_price;
    final_extremum_time = other.final_extremum_time;
    final_extremum_price = other.final_extremum_price;
    final_depth_percent = other.final_depth_percent;
    revision_count = other.revision_count;
    attempt_count = other.attempt_count;
    current_revision = other.current_revision;
  }
};

ExtremumEngineCycleState g_extremum_engine_cycle;
ExtremumEngineCycleState g_extremum_engine_finalized_cycle;
bool g_extremum_engine_finalized_pending = false;

ulong ExtremumEngineIdentityHash(const string value)
{
  ulong hash = 1469598103934665603;
  int total = StringLen(value);
  for(int i = 0; i < total; i++)
  {
    hash ^= (ulong)StringGetCharacter(value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string ExtremumEngineCycleId(const bool is_peak,
                             const datetime first_seen_time,
                             const datetime extremum_time,
                             const double extremum_price)
{
  int digits = Digits();
  if(digits <= 0)
    digits = 5;
  string raw = StringFormat("%s|%s|%d|%s|%d|%d|%s",
                            ExtremumEngineLabel(EXTREMUM_ENGINE_V1),
                            _Symbol,
                            (int)EXTREMUM_ENGINE_TIMEFRAME,
                            is_peak ? "PEAK" : "BOTTOM",
                            (int)first_seen_time,
                            (int)extremum_time,
                            DoubleToString(NormalizeDouble(extremum_price, digits), digits));
  return StringFormat("C_%I64u", ExtremumEngineIdentityHash(raw));
}

bool ExtremumEngineResolveFrozenAnchors(const StochasticMarketStructure &structure,
                                        const bool developing_peak,
                                        datetime &peak_time_out,
                                        double &peak_price_out,
                                        datetime &bottom_time_out,
                                        double &bottom_price_out,
                                        double &range_points_out)
{
  peak_time_out = 0;
  peak_price_out = 0.0;
  bottom_time_out = 0;
  bottom_price_out = 0.0;
  range_points_out = 0.0;

  if(ArraySize(structure.os_market_structures) < 3)
    return false;

  OscillatorMarketStructure slot_1 = structure.os_market_structures[1];
  OscillatorMarketStructure slot_2 = structure.os_market_structures[2];
  if(slot_1.extremum_time <= 0 || slot_2.extremum_time <= 0)
    return false;

  if(developing_peak)
  {
    if(slot_1.is_peak || !slot_2.is_peak)
      return false;
    bottom_time_out = slot_1.extremum_time;
    bottom_price_out = slot_1.extremum_low;
    peak_time_out = slot_2.extremum_time;
    peak_price_out = slot_2.extremum_high;
  }
  else
  {
    if(!slot_1.is_peak || slot_2.is_peak)
      return false;
    peak_time_out = slot_1.extremum_time;
    peak_price_out = slot_1.extremum_high;
    bottom_time_out = slot_2.extremum_time;
    bottom_price_out = slot_2.extremum_low;
  }

  if(peak_price_out <= bottom_price_out ||
     peak_price_out == -DBL_MAX || bottom_price_out == DBL_MAX)
    return false;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    return false;

  range_points_out = (peak_price_out - bottom_price_out) / point_size;
  return MathIsValidNumber(range_points_out) && range_points_out > 0.0;
}

bool ExtremumEngineCalculateDepth(const ExtremumEngineCycleState &cycle,
                                  const double extremum_price,
                                  double &depth_percent_out)
{
  depth_percent_out = 0.0;
  double price_range = cycle.reference_peak_price - cycle.reference_bottom_price;
  if(price_range <= 0.0 || extremum_price <= 0.0)
    return false;

  if(cycle.is_peak)
    depth_percent_out = (extremum_price - cycle.reference_bottom_price) / price_range * 100.0;
  else
    depth_percent_out = (cycle.reference_peak_price - extremum_price) / price_range * 100.0;

  return MathIsValidNumber(depth_percent_out);
}

int ExtremumEngineBarsSince(const datetime first_seen_time,
                            const datetime snapshot_time)
{
  int seconds = PeriodSeconds(EXTREMUM_ENGINE_TIMEFRAME);
  if(seconds <= 0 || first_seen_time <= 0 || snapshot_time <= first_seen_time)
    return 0;
  return (int)((snapshot_time - first_seen_time) / seconds);
}

bool ExtremumEngineAddRevision(const DeterministicExtremumSnapshot &extremum,
                               const datetime snapshot_time)
{
  if(!g_extremum_engine_cycle.active || !extremum.valid)
    return false;

  double depth_percent = 0.0;
  if(!ExtremumEngineCalculateDepth(g_extremum_engine_cycle,
                                   extremum.extremum_price,
                                   depth_percent))
    return false;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    return false;

  ExtremumEngineRevisionState previous = g_extremum_engine_cycle.current_revision;
  ExtremumEngineRevisionState revision;
  revision.valid = true;
  revision.revision_index = g_extremum_engine_cycle.revision_count + 1;
  revision.revision_id = g_extremum_engine_cycle.cycle_id + "_R" +
                         IntegerToString(revision.revision_index);
  revision.snapshot_time = snapshot_time;
  revision.extremum_time = extremum.extremum_time;
  revision.extremum_price = extremum.extremum_price;
  revision.depth_percent_raw = depth_percent;
  revision.distance_from_first_points =
    MathAbs(extremum.extremum_price - g_extremum_engine_cycle.first_extremum_price) / point_size;
  revision.bars_since_cycle_start = ExtremumEngineBarsSince(g_extremum_engine_cycle.first_seen_time,
                                                            snapshot_time);

  if(previous.valid)
  {
    revision.distance_from_previous_points =
      MathAbs(extremum.extremum_price - previous.extremum_price) / point_size;
    revision.depth_delta_from_previous_percent =
      depth_percent - previous.depth_percent_raw;
  }

  g_extremum_engine_cycle.current_revision = revision;
  g_extremum_engine_cycle.revision_count = revision.revision_index;
  g_extremum_engine_cycle.final_extremum_time = extremum.extremum_time;
  g_extremum_engine_cycle.final_extremum_price = extremum.extremum_price;
  g_extremum_engine_cycle.final_depth_percent = depth_percent;
  return true;
}

bool ExtremumEngineStartCycle(const StochasticMarketStructure &structure,
                              const DeterministicExtremumSnapshot &extremum,
                              const datetime snapshot_time)
{
  datetime peak_time = 0;
  double peak_price = 0.0;
  datetime bottom_time = 0;
  double bottom_price = 0.0;
  double range_points = 0.0;
  if(!ExtremumEngineResolveFrozenAnchors(structure,
                                        extremum.is_peak,
                                        peak_time,
                                        peak_price,
                                        bottom_time,
                                        bottom_price,
                                        range_points))
    return false;

  g_extremum_engine_cycle = ExtremumEngineCycleState();
  g_extremum_engine_cycle.active = true;
  g_extremum_engine_cycle.cycle_status = "OPEN";
  g_extremum_engine_cycle.engine_id = EXTREMUM_ENGINE_V1;
  g_extremum_engine_cycle.engine_timeframe = EXTREMUM_ENGINE_TIMEFRAME;
  g_extremum_engine_cycle.is_peak = extremum.is_peak;
  g_extremum_engine_cycle.first_seen_time = snapshot_time;
  g_extremum_engine_cycle.reference_peak_time = peak_time;
  g_extremum_engine_cycle.reference_peak_price = peak_price;
  g_extremum_engine_cycle.reference_bottom_time = bottom_time;
  g_extremum_engine_cycle.reference_bottom_price = bottom_price;
  g_extremum_engine_cycle.reference_range_points = range_points;
  g_extremum_engine_cycle.first_extremum_time = extremum.extremum_time;
  g_extremum_engine_cycle.first_extremum_price = extremum.extremum_price;
  g_extremum_engine_cycle.cycle_id = ExtremumEngineCycleId(extremum.is_peak,
                                                          snapshot_time,
                                                          extremum.extremum_time,
                                                          extremum.extremum_price);
  return ExtremumEngineAddRevision(extremum, snapshot_time);
}

void ExtremumEngineFinalizeCycle(const string status,
                                 const datetime finalized_time)
{
  if(!g_extremum_engine_cycle.active)
    return;

  g_extremum_engine_cycle.active = false;
  g_extremum_engine_cycle.cycle_status = status;
  g_extremum_engine_cycle.finalized_time = finalized_time;
  g_extremum_engine_finalized_cycle = g_extremum_engine_cycle;
  g_extremum_engine_finalized_pending = true;
}

bool ExtremumEngineObserve(const StochasticMarketStructure &structure,
                           const DeterministicExtremumSnapshot &extremum,
                           bool &cycle_started_out,
                           bool &revision_created_out,
                           bool &cycle_finalized_out)
{
  cycle_started_out = false;
  revision_created_out = false;
  cycle_finalized_out = false;
  if(!extremum.valid)
    return false;

  datetime snapshot_time = iTime(_Symbol, EXTREMUM_ENGINE_TIMEFRAME, 0);
  if(snapshot_time <= 0)
    snapshot_time = TimeCurrent();

  if(!g_extremum_engine_cycle.active)
  {
    cycle_started_out = ExtremumEngineStartCycle(structure, extremum, snapshot_time);
    revision_created_out = cycle_started_out;
    return cycle_started_out;
  }

  if(g_extremum_engine_cycle.is_peak != extremum.is_peak)
  {
    ExtremumEngineFinalizeCycle("FINALIZED", snapshot_time);
    cycle_finalized_out = true;
    cycle_started_out = ExtremumEngineStartCycle(structure, extremum, snapshot_time);
    revision_created_out = cycle_started_out;
    return cycle_started_out;
  }

  ExtremumEngineRevisionState current = g_extremum_engine_cycle.current_revision;
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0000001;
  bool changed = !current.valid ||
                 current.extremum_time != extremum.extremum_time ||
                 MathAbs(current.extremum_price - extremum.extremum_price) > point_size;
  if(!changed)
    return true;

  revision_created_out = ExtremumEngineAddRevision(extremum, snapshot_time);
  return revision_created_out;
}

bool ExtremumEngineAssignAttemptIdentity(SignalParams &signal_params)
{
  if(!g_extremum_engine_cycle.active ||
     !g_extremum_engine_cycle.current_revision.valid)
    return false;

  g_extremum_engine_cycle.attempt_count++;
  g_extremum_engine_cycle.current_revision.attempt_count++;

  signal_params.extremum_cycle_id = g_extremum_engine_cycle.cycle_id;
  signal_params.extremum_revision_id = g_extremum_engine_cycle.current_revision.revision_id;
  signal_params.extremum_revision_index = g_extremum_engine_cycle.current_revision.revision_index;
  signal_params.cycle_attempt_index = g_extremum_engine_cycle.attempt_count;
  signal_params.revision_attempt_index = g_extremum_engine_cycle.current_revision.attempt_count;
  signal_params.extremum_attempt_id = signal_params.extremum_cycle_id + "_A" +
                                      IntegerToString(signal_params.cycle_attempt_index);
  signal_params.candidate_depth_percent =
    g_extremum_engine_cycle.current_revision.depth_percent_raw;
  signal_params.reference_range_points = g_extremum_engine_cycle.reference_range_points;
  signal_params.distance_from_first_revision_points =
    g_extremum_engine_cycle.current_revision.distance_from_first_points;
  signal_params.distance_from_previous_revision_points =
    g_extremum_engine_cycle.current_revision.distance_from_previous_points;
  signal_params.depth_delta_from_previous_percent =
    g_extremum_engine_cycle.current_revision.depth_delta_from_previous_percent;
  signal_params.bars_since_cycle_start =
    g_extremum_engine_cycle.current_revision.bars_since_cycle_start;
  return true;
}

void ResetExtremumEngineState()
{
  g_extremum_engine_cycle = ExtremumEngineCycleState();
  g_extremum_engine_finalized_cycle = ExtremumEngineCycleState();
  g_extremum_engine_finalized_pending = false;
}

#endif // _SERVICES_TRADING_SIGNALS_EXTREMUM_ENGINE_STATE_MQH_
