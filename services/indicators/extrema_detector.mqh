//+------------------------------------------------------------------+
//|              microservices/indicators/extrema_detector.mqh       |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_EXTREMA_DETECTOR_MQH_
#define _MICROSERVICES_INDICATORS_EXTREMA_DETECTOR_MQH_

const int STRUCTURE_EXTREMA_COPY_DEPTH_MIN = 512;
const int STRUCTURE_EXTREMA_COPY_DEPTH_MAX = 2048;
const int STRUCTURE_EXTREMA_COPY_DEPTH_PERIOD_MULTIPLIER = 24;

int ResolveStructureExtremaCopyDepth(const int max_depth,
                                     const int indicator_period)
{
  int safe_depth = max_depth;
  if(safe_depth < 13)
    safe_depth = 13;

  int safe_period = indicator_period;
  if(safe_period < 3)
    safe_period = 3;

  int copy_depth = safe_depth * safe_period * STRUCTURE_EXTREMA_COPY_DEPTH_PERIOD_MULTIPLIER;
  if(copy_depth < STRUCTURE_EXTREMA_COPY_DEPTH_MIN)
    copy_depth = STRUCTURE_EXTREMA_COPY_DEPTH_MIN;
  if(copy_depth > STRUCTURE_EXTREMA_COPY_DEPTH_MAX)
    copy_depth = STRUCTURE_EXTREMA_COPY_DEPTH_MAX;

  return copy_depth;
}

// Estructura de un extremo (pico/fondo) del oscilador
struct OscillatorMarketStructure
{
  double   extremum_high;
  double   extremum_low;
  double   extremum_stoch;
  datetime extremum_time;

  // NEW: Type indicators for enhanced analysis
  bool     is_peak;         // True if peak, false if bottom
  int      sequence_index;  // Position in sequence (0 = most recent)

  // DEFAULT CONSTRUCTOR
  OscillatorMarketStructure()
  {
    extremum_high  = -DBL_MAX;
    extremum_low   =  DBL_MAX;
    extremum_stoch = 0.0;
    extremum_time  = 0;
    is_peak        = false;
    sequence_index = -1;
  }

  // COPY CONSTRUCTOR
  OscillatorMarketStructure(const OscillatorMarketStructure &other)
  {
    extremum_high  = other.extremum_high;
    extremum_low   = other.extremum_low;
    extremum_stoch = other.extremum_stoch;
    extremum_time  = other.extremum_time;
    is_peak        = other.is_peak;
    sequence_index = other.sequence_index;
  }
};

//+------------------------------------------------------------------+
//| Detect market extrema from Stochastic Structure indicator        |
//| Returns: true if minimum extrema detected, false otherwise       |
//+------------------------------------------------------------------+
bool DetectMarketExtrema(
  IndicatorsHandleInfo &indicator_handle,
  OscillatorMarketStructure &extrema_array[],
  bool &initial_is_bottom,
  bool &initial_is_peak,
  ENUM_TIMEFRAMES &timeframe,
  int &period,
  int max_depth = 13,
  bool required = true
) {
  // --- buffers del indicador ---
  double indicator_extremum_values[];
  double indicator_peak_values[];
  double indicator_bottom_values[];
  double indicator_stoch_extremum_values[];
  double indicator_main_values[];

  // --- variables de trabajo ---
  int      total_signal_structures = 0;

  datetime time_1                  = 0;
  double   high_1                  = 0.0;
  double   low_1                   = 0.0;
  double   stoch_1                 = 0.0;

  double   signal_low_price                = DBL_MAX;
  double   signal_high_price               = -DBL_MAX;
  datetime signal_time_extremum_bottom     = 0;
  datetime signal_time_extremum_peak       = 0;
  double   signal_stoch_extremum_bottom    = DBL_MAX;
  double   signal_stoch_extremum_peak      = -DBL_MAX;
  double   current_extremum_bottom         = DBL_MAX;
  double   current_extremum_peak           = -DBL_MAX;

  initial_is_peak     = false;
  initial_is_bottom   = false;

  // --- copiar buffers ---
  int copy_depth = ResolveStructureExtremaCopyDepth(max_depth,
                                                    indicator_handle.indicator_period);
  int n_ext  = CopyBuffer(indicator_handle.indicator_handle, 0, 0, copy_depth, indicator_extremum_values);
  int n_peak = CopyBuffer(indicator_handle.indicator_handle, 1, 0, copy_depth, indicator_peak_values);
  int n_bot  = CopyBuffer(indicator_handle.indicator_handle, 2, 0, copy_depth, indicator_bottom_values);
  int n_sext = CopyBuffer(indicator_handle.indicator_handle, 3, 0, copy_depth, indicator_stoch_extremum_values);
  int n_main = CopyBuffer(indicator_handle.indicator_handle, 4, 0, copy_depth, indicator_main_values);

  if(n_ext <= 0 || n_peak <= 0 || n_bot <= 0 || n_sext <= 0 || n_main <= 0)
  {
    if(required)
    {
      PrintFormat("Failed to copy data from the OSCILLATOR STRUCTURE indicator, error code %d", GetLastError());
      TesterStop();
    }
    return false;
  }

  ArraySetAsSeries(indicator_extremum_values, true);
  ArraySetAsSeries(indicator_peak_values, true);
  ArraySetAsSeries(indicator_bottom_values, true);
  ArraySetAsSeries(indicator_stoch_extremum_values, true);
  ArraySetAsSeries(indicator_main_values, true);

  timeframe = indicator_handle.indicator_timeframe;
  period    = indicator_handle.indicator_period;

  // --- scan de extremos ---
  for(int i = 1; i < n_ext; i++)
  {
    OscillatorMarketStructure local_os_market_structure;
    OscillatorMarketStructure initial_os_market_structure;

    // maximo estructuras configurables
    if(total_signal_structures >= max_depth) break;

    bool has_peak = (indicator_peak_values[i] != EMPTY_VALUE);
    bool has_bottom = (indicator_bottom_values[i] != EMPTY_VALUE);
    bool has_extremum = (indicator_extremum_values[i] != EMPTY_VALUE &&
                         (has_peak || has_bottom));
    bool initial_scan_active = (total_signal_structures == 0);
    if(!initial_scan_active && !has_extremum)
      continue;

    high_1  = iHigh(_Symbol, timeframe, i);
    low_1   = iLow(_Symbol, timeframe, i);
    time_1  = iTime(_Symbol, timeframe, i);
    stoch_1 = NormalizeDouble(indicator_main_values[i], 2);

    // extremos actuales si es el primer ciclo
    if(total_signal_structures == 0 && has_bottom) current_extremum_bottom = indicator_bottom_values[i];
    if(total_signal_structures == 0 && has_peak) current_extremum_peak = indicator_peak_values[i];

    // iniciales para bottom
    if(total_signal_structures == 0 && low_1 < signal_low_price)
    {
      signal_low_price            = low_1;
      signal_time_extremum_bottom = time_1;
    }
    if(total_signal_structures == 0 && stoch_1 < signal_stoch_extremum_bottom) signal_stoch_extremum_bottom = stoch_1;

    // iniciales para peak
    if(total_signal_structures == 0 && high_1 > signal_high_price)
    {
      signal_high_price          = high_1;
      signal_time_extremum_peak = time_1;
    }
    if(total_signal_structures == 0 && stoch_1 > signal_stoch_extremum_peak) signal_stoch_extremum_peak = stoch_1;

    // buscar primer par (peak/bottom)
    if(
      total_signal_structures      == 0           &&
      indicator_extremum_values[i] != EMPTY_VALUE &&
      (has_peak || has_bottom)
    ) {
      if(indicator_extremum_values[i] == indicator_peak_values[i])
      {
        // añadir bottom inicial (previo)
        initial_is_bottom = true;
        initial_os_market_structure.extremum_low   = signal_low_price;
        initial_os_market_structure.extremum_stoch = signal_stoch_extremum_bottom;
        initial_os_market_structure.extremum_time  = signal_time_extremum_bottom;
        initial_os_market_structure.is_peak        = false;
        initial_os_market_structure.sequence_index = total_signal_structures;
        total_signal_structures = AddElementToArray(extrema_array, initial_os_market_structure);

        // añadir peak actual
        local_os_market_structure.extremum_high  = indicator_extremum_values[i];
        local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
        local_os_market_structure.extremum_time  = time_1;
        local_os_market_structure.is_peak        = true;
        local_os_market_structure.sequence_index = total_signal_structures;
        total_signal_structures = AddElementToArray(extrema_array, local_os_market_structure);
        continue;
      }

      if(indicator_extremum_values[i] == indicator_bottom_values[i])
      {
        // añadir peak inicial (previo)
        initial_is_peak = true;
        initial_os_market_structure.extremum_high  = signal_high_price;
        initial_os_market_structure.extremum_stoch = signal_stoch_extremum_peak;
        initial_os_market_structure.extremum_time  = signal_time_extremum_peak;
        initial_os_market_structure.is_peak        = true;
        initial_os_market_structure.sequence_index = total_signal_structures;
        total_signal_structures = AddElementToArray(extrema_array, initial_os_market_structure);

        // añadir bottom actual
        local_os_market_structure.extremum_low   = indicator_extremum_values[i];
        local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
        local_os_market_structure.extremum_time  = time_1;
        local_os_market_structure.is_peak        = false;
        local_os_market_structure.sequence_index = total_signal_structures;
        total_signal_structures = AddElementToArray(extrema_array, local_os_market_structure);
        continue;
      }
    }

    // siguiente bottom
    if(
      total_signal_structures      >= 2           &&
      indicator_extremum_values[i] != EMPTY_VALUE &&
      has_bottom &&
      indicator_extremum_values[i] == indicator_bottom_values[i]
    ) {
      local_os_market_structure.extremum_low   = indicator_extremum_values[i];
      local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
      local_os_market_structure.extremum_time  = time_1;
      local_os_market_structure.is_peak        = false;
      local_os_market_structure.sequence_index = total_signal_structures;
      total_signal_structures = AddElementToArray(extrema_array, local_os_market_structure);
      continue;
    }

    // siguiente peak
    if(
      total_signal_structures      >= 2           &&
      indicator_extremum_values[i] != EMPTY_VALUE &&
      has_peak &&
      indicator_extremum_values[i] == indicator_peak_values[i]
    ) {
      local_os_market_structure.extremum_high  = indicator_extremum_values[i];
      local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
      local_os_market_structure.extremum_time  = time_1;
      local_os_market_structure.is_peak        = true;
      local_os_market_structure.sequence_index = total_signal_structures;
      total_signal_structures = AddElementToArray(extrema_array, local_os_market_structure);
      continue;
    }
  }

  return (total_signal_structures >= max_depth);
}

#endif // _MICROSERVICES_INDICATORS_EXTREMA_DETECTOR_MQH_
