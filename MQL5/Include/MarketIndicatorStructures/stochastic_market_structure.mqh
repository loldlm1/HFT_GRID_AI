//+------------------------------------------------------------------+
//|                                 oscillador_market_structures.mqh |
//+------------------------------------------------------------------+

// Estructura de precios para niveles de Fibonacci (modo alcista)
struct FibonacciLevelPrices
{
  double entry_level;       // precio del nivel de entrada calculado
  double entry_next_level;  // precio del siguiente nivel (para TP/gestión)

  // DEFAULT CONSTRUCTOR
  FibonacciLevelPrices()
  {
    entry_level      = 0.0;
    entry_next_level = 0.0;
  }

  // COPY CONSTRUCTOR
  FibonacciLevelPrices(const FibonacciLevelPrices &other)
  {
    entry_level      = other.entry_level;
    entry_next_level = other.entry_next_level;
  }
};

// Estructura de un extremo (pico/fondo) del oscilador
struct OscillatorMarketStructure
{
  double   extremum_high;
  double   extremum_low;
  double   extremum_stoch;
  datetime extremum_time;

  // DEFAULT CONSTRUCTOR
  OscillatorMarketStructure()
  {
    extremum_high  = -DBL_MAX;
    extremum_low   =  DBL_MAX;
    extremum_stoch = 0.0;
    extremum_time  = 0;
  }

  // COPY CONSTRUCTOR
  OscillatorMarketStructure(const OscillatorMarketStructure &other)
  {
    extremum_high  = other.extremum_high;
    extremum_low   = other.extremum_low;
    extremum_stoch = other.extremum_stoch;
    extremum_time  = other.extremum_time;
  }
};

// Agregado de estructura estocástica (tipos, niveles y secuencia completa)
struct StochasticMarketStructure
{
	// INDICATOR INFO
	ENUM_TIMEFRAMES indicator_timeframe;
	int 						indicator_period;
  // Tipos de las 6 sub-estructuras (según tu cálculo)
  OscillatorStructureTypes first_structure_type;
  OscillatorStructureTypes second_structure_type;
  OscillatorStructureTypes third_structure_type;
  OscillatorStructureTypes fourth_structure_type;
  OscillatorStructureTypes fifth_structure_type;
  OscillatorStructureTypes six_structure_type;

  // Datos de la primera sub-estructura que guardas explícitamente
  datetime first_structure_time;
  double   first_structure_price;
	datetime second_structure_time;
	double   second_structure_price;
	datetime third_structure_time;
	double   third_structure_price;
	datetime fourth_structure_time;
	double   fourth_structure_price;

  // Niveles de Fibonacci calculados en tu función
  double first_fibonacci_level;
  double second_fibonacci_level;
  double third_fibonacci_level;
  double fourth_fibonacci_level;

  // Secuencia completa de extremos detectados
  OscillatorMarketStructure os_market_structures[];

  // DEFAULT CONSTRUCTOR
  StochasticMarketStructure()
  {
		indicator_timeframe 	= PERIOD_CURRENT;
		indicator_period      = 0;
    first_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    second_structure_type = OSCILLATOR_STRUCTURE_EQ;
    third_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    fourth_structure_type = OSCILLATOR_STRUCTURE_EQ;
    fifth_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    six_structure_type    = OSCILLATOR_STRUCTURE_EQ;

    first_structure_time   = 0;
    first_structure_price  = 0.0;
		second_structure_time  = 0;
		second_structure_price = 0.0;
		third_structure_time   = 0;
		third_structure_price  = 0.0;
		fourth_structure_time  = 0;
		fourth_structure_price = 0.0;

    first_fibonacci_level  = 0.0;
    second_fibonacci_level = 0.0;
    third_fibonacci_level  = 0.0;
		fourth_fibonacci_level = 0.0;
  }

  // COPY CONSTRUCTOR
  StochasticMarketStructure(const StochasticMarketStructure &other)
  {
		indicator_timeframe    = other.indicator_timeframe;
		indicator_period       = other.indicator_period;
    first_structure_type   = other.first_structure_type;
    second_structure_type  = other.second_structure_type;
    third_structure_type   = other.third_structure_type;
    fourth_structure_type  = other.fourth_structure_type;
    fifth_structure_type   = other.fifth_structure_type;
    six_structure_type     = other.six_structure_type;

    first_structure_time   = other.first_structure_time;
    first_structure_price  = other.first_structure_price;
		second_structure_time  = other.second_structure_time;
		second_structure_price = other.second_structure_price;
		third_structure_time   = other.third_structure_time;
		third_structure_price  = other.third_structure_price;
		fourth_structure_time  = other.fourth_structure_time;
		fourth_structure_price = other.fourth_structure_price;

    first_fibonacci_level  = other.first_fibonacci_level;
    second_fibonacci_level = other.second_fibonacci_level;
    third_fibonacci_level  = other.third_fibonacci_level;
		fourth_fibonacci_level = other.fourth_fibonacci_level;

    ArrayCopy(os_market_structures, other.os_market_structures);
  }

	// INITIALIZE STRUCTURE VALUES
	bool InitStochMarketStructureValues(
		IndicatorsHandleInfo &structure_stoch_indicator_handle
	) {
		// --- buffers del indicador ---
		double indicator_extremum_values[];
		double indicator_peak_values[];
		double indicator_bottom_values[];
		double indicator_stoch_extremum_values[];
		double indicator_main_values[];

		// --- variables de trabajo ---
		int      total_signal_structures = 0;
		int      structure_peaks_index   = 0;
		int      structure_bottoms_index = 0;

		datetime time_1                  = 0;
		double   high_1                  = 0.0;
		double   low_1                   = 0.0;
		double   stoch_1                 = 0.0;

		double   signal_low_price        			= DBL_MAX;
		double   signal_high_price       			= -DBL_MAX;
		datetime signal_time_extremum_bottom  = 0;
		datetime signal_time_extremum_peak    = 0;
		double   signal_stoch_extremum_bottom = DBL_MAX;
		double   signal_stoch_extremum_peak   = -DBL_MAX;
		double   current_extremum_bottom      = DBL_MAX;
		double   current_extremum_peak        = -DBL_MAX;

		bool     initial_struct_peak     = false;
		bool     initial_struct_bottom   = false;

		// --- copiar buffers ---
		int n_ext  = CopyBuffer(structure_stoch_indicator_handle.indicator_handle, 0, 0, 2333, indicator_extremum_values);
		int n_peak = CopyBuffer(structure_stoch_indicator_handle.indicator_handle, 1, 0, 2333, indicator_peak_values);
		int n_bot  = CopyBuffer(structure_stoch_indicator_handle.indicator_handle, 2, 0, 2333, indicator_bottom_values);
		int n_sext = CopyBuffer(structure_stoch_indicator_handle.indicator_handle, 3, 0, 2333, indicator_stoch_extremum_values);
		int n_main = CopyBuffer(structure_stoch_indicator_handle.indicator_handle, 4, 0, 2333, indicator_main_values);

		if(n_ext <= 0 || n_peak <= 0 || n_bot <= 0 || n_sext <= 0 || n_main <= 0)
		{
			PrintFormat("Failed to copy data from the OSCILLATOR STRUCTURE indicator, error code %d", GetLastError());
			TesterStop();
		}

		ArraySetAsSeries(indicator_extremum_values, true);
		ArraySetAsSeries(indicator_peak_values, true);
		ArraySetAsSeries(indicator_bottom_values, true);
		ArraySetAsSeries(indicator_stoch_extremum_values, true);
		ArraySetAsSeries(indicator_main_values, true);

		indicator_timeframe = structure_stoch_indicator_handle.indicator_timeframe;
		indicator_period    = structure_stoch_indicator_handle.indicator_period;

		// --- scan de extremos ---
		for(int i = 1; i < n_ext; i++)
		{
			OscillatorMarketStructure local_os_market_structure;
			OscillatorMarketStructure initial_os_market_structure;

			high_1  = iHigh(_Symbol, indicator_timeframe, i);
			low_1   = iLow(_Symbol, indicator_timeframe, i);
			time_1  = iTime(_Symbol, indicator_timeframe, i);
			stoch_1 = NormalizeDouble(indicator_main_values[i], 2);

			// máximo 13 estructuras
			if(total_signal_structures >= 13) break;

			// extremos actuales si es el primer ciclo
			if(total_signal_structures == 0 && indicator_bottom_values[i] != EMPTY_VALUE) current_extremum_bottom = indicator_bottom_values[i];
			if(total_signal_structures == 0 && indicator_peak_values[i]   != EMPTY_VALUE) current_extremum_peak   = indicator_peak_values[i];

			// iniciales para bottom
			if(total_signal_structures == 0 && low_1 < signal_low_price)
			{
				signal_low_price 						= low_1;
				signal_time_extremum_bottom = time_1;
			}
			if(total_signal_structures == 0 && stoch_1 < signal_stoch_extremum_bottom) signal_stoch_extremum_bottom = stoch_1;

			// iniciales para peak
			if(total_signal_structures == 0 && high_1 > signal_high_price)
			{
				signal_high_price 				= high_1;
				signal_time_extremum_peak = time_1;
			}
			if(total_signal_structures == 0 && stoch_1 > signal_stoch_extremum_peak) signal_stoch_extremum_peak = stoch_1;

			// buscar primer par (peak/bottom)
			if(
				total_signal_structures 		 == 0 					&&
				indicator_extremum_values[i] != EMPTY_VALUE &&
				(indicator_peak_values[i] != EMPTY_VALUE || indicator_bottom_values[i] != EMPTY_VALUE)
			) {
				if(indicator_extremum_values[i] == indicator_peak_values[i])
				{
					// añadir bottom inicial (previo)
					initial_struct_bottom = true;
					initial_os_market_structure.extremum_low   = signal_low_price;
					initial_os_market_structure.extremum_stoch = signal_stoch_extremum_bottom;
					initial_os_market_structure.extremum_time  = signal_time_extremum_bottom;
					total_signal_structures = AddElementToArray(os_market_structures, initial_os_market_structure);

					// añadir peak actual
					local_os_market_structure.extremum_high  = indicator_extremum_values[i];
					local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
					local_os_market_structure.extremum_time  = time_1;
					total_signal_structures = AddElementToArray(os_market_structures, local_os_market_structure);
					continue;
				}

				if(indicator_extremum_values[i] == indicator_bottom_values[i])
				{
					// añadir peak inicial (previo)
					initial_struct_peak = true;
					initial_os_market_structure.extremum_high  = signal_high_price;
					initial_os_market_structure.extremum_stoch = signal_stoch_extremum_peak;
					initial_os_market_structure.extremum_time  = signal_time_extremum_peak;
					total_signal_structures = AddElementToArray(os_market_structures, initial_os_market_structure);

					// añadir bottom actual
					local_os_market_structure.extremum_low   = indicator_extremum_values[i];
					local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
					local_os_market_structure.extremum_time  = time_1;
					total_signal_structures = AddElementToArray(os_market_structures, local_os_market_structure);
					continue;
				}
			}

			// siguiente bottom
			if(
				total_signal_structures 	   >= 2 					&&
				indicator_extremum_values[i] != EMPTY_VALUE &&
				indicator_bottom_values[i]   != EMPTY_VALUE &&
				indicator_extremum_values[i] == indicator_bottom_values[i]
			) {
				local_os_market_structure.extremum_low   = indicator_extremum_values[i];
				local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
				local_os_market_structure.extremum_time  = time_1;
				total_signal_structures = AddElementToArray(os_market_structures, local_os_market_structure);
				continue;
			}

			// siguiente peak
			if(
				total_signal_structures 		 >= 2 					&&
				indicator_extremum_values[i] != EMPTY_VALUE &&
				indicator_peak_values[i]     != EMPTY_VALUE &&
				indicator_extremum_values[i] == indicator_peak_values[i]
			) {
				local_os_market_structure.extremum_high  = indicator_extremum_values[i];
				local_os_market_structure.extremum_stoch = indicator_stoch_extremum_values[i];
				local_os_market_structure.extremum_time  = time_1;
				total_signal_structures = AddElementToArray(os_market_structures, local_os_market_structure);
				continue;
			}
		}

		if(total_signal_structures < 13) return false;

		// índices base para cálculos
		structure_peaks_index   = initial_struct_bottom ? 1 : 0;
		structure_bottoms_index = initial_struct_peak   ? 1 : 0;

		// tipos de estructura + datos individuales
		if(initial_struct_bottom)
		{
			first_structure_type  = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index].extremum_low,      os_market_structures[structure_bottoms_index+2].extremum_low);
			second_structure_type = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index].extremum_high,       os_market_structures[structure_peaks_index+2].extremum_high);
			third_structure_type  = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index+2].extremum_low,    os_market_structures[structure_bottoms_index+4].extremum_low);
			fourth_structure_type = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index+2].extremum_high,      os_market_structures[structure_peaks_index+4].extremum_high);
			fifth_structure_type  = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index+4].extremum_low,    os_market_structures[structure_bottoms_index+6].extremum_low);
			six_structure_type    = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index+4].extremum_high,      os_market_structures[structure_peaks_index+6].extremum_high);

			// EXTREMUM STATS
			first_structure_time   = os_market_structures[structure_bottoms_index].extremum_time;
			first_structure_price  = os_market_structures[structure_bottoms_index].extremum_low;
			second_structure_time  = os_market_structures[structure_bottoms_index+1].extremum_time;
			second_structure_price = os_market_structures[structure_bottoms_index+1].extremum_high;
			third_structure_time   = os_market_structures[structure_bottoms_index+2].extremum_time;
			third_structure_price  = os_market_structures[structure_bottoms_index+2].extremum_low;
			fourth_structure_time  = os_market_structures[structure_bottoms_index+3].extremum_time;
			fourth_structure_price = os_market_structures[structure_bottoms_index+3].extremum_high;

			// FIBONACCI LEVELS
			first_fibonacci_level  = GetBullishFibonacciPercentage(os_market_structures[structure_bottoms_index].extremum_low,    os_market_structures[structure_bottoms_index+1].extremum_high, os_market_structures[structure_bottoms_index+2].extremum_low);
			second_fibonacci_level = GetBearishFibonacciPercentage(os_market_structures[structure_bottoms_index+1].extremum_high, os_market_structures[structure_bottoms_index+2].extremum_low,  os_market_structures[structure_bottoms_index+3].extremum_high);
			third_fibonacci_level  = GetBullishFibonacciPercentage(os_market_structures[structure_bottoms_index+2].extremum_low,  os_market_structures[structure_bottoms_index+3].extremum_high, os_market_structures[structure_bottoms_index+4].extremum_low);
			fourth_fibonacci_level = GetBearishFibonacciPercentage(os_market_structures[structure_bottoms_index+3].extremum_high, os_market_structures[structure_bottoms_index+4].extremum_low,  os_market_structures[structure_bottoms_index+5].extremum_high);

			return true;
		}

		if(initial_struct_peak)
		{
			first_structure_type  = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index].extremum_high,       os_market_structures[structure_peaks_index+2].extremum_high);
			second_structure_type = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index].extremum_low,      os_market_structures[structure_bottoms_index+2].extremum_low);
			third_structure_type  = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index+2].extremum_high,      os_market_structures[structure_peaks_index+4].extremum_high);
			fourth_structure_type = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index+2].extremum_low,    os_market_structures[structure_bottoms_index+4].extremum_low);
			fifth_structure_type  = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, os_market_structures[structure_peaks_index+4].extremum_high,      os_market_structures[structure_peaks_index+6].extremum_high);
			six_structure_type    = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  os_market_structures[structure_bottoms_index+4].extremum_low,    os_market_structures[structure_bottoms_index+6].extremum_low);

			// EXTREMUM STATS
			first_structure_time   = os_market_structures[structure_peaks_index].extremum_time;
			first_structure_price  = os_market_structures[structure_peaks_index].extremum_high;
			second_structure_time  = os_market_structures[structure_peaks_index+1].extremum_time;
			second_structure_price = os_market_structures[structure_peaks_index+1].extremum_low;
			third_structure_time   = os_market_structures[structure_peaks_index+2].extremum_time;
			third_structure_price  = os_market_structures[structure_peaks_index+2].extremum_high;
			fourth_structure_time  = os_market_structures[structure_peaks_index+3].extremum_time;
			fourth_structure_price = os_market_structures[structure_peaks_index+3].extremum_low;

			// FIBONACCI LEVELS
			first_fibonacci_level  = GetBearishFibonacciPercentage(os_market_structures[structure_peaks_index].extremum_high,    os_market_structures[structure_peaks_index+1].extremum_low,  os_market_structures[structure_peaks_index+2].extremum_high);
			second_fibonacci_level = GetBullishFibonacciPercentage(os_market_structures[structure_peaks_index+1].extremum_low,   os_market_structures[structure_peaks_index+2].extremum_high, os_market_structures[structure_peaks_index+3].extremum_low);
			third_fibonacci_level  = GetBearishFibonacciPercentage(os_market_structures[structure_peaks_index+2].extremum_high,  os_market_structures[structure_peaks_index+3].extremum_low,  os_market_structures[structure_peaks_index+4].extremum_high);
			fourth_fibonacci_level = GetBullishFibonacciPercentage(os_market_structures[structure_peaks_index+3].extremum_low,   os_market_structures[structure_peaks_index+4].extremum_high, os_market_structures[structure_peaks_index+5].extremum_low);

			return true;
		}

		return false;
	}
};

// ++ OSCILLATOR TYPES SETTER ++

OscillatorStructureTypes GetOscillatorStructureType(OscillatorPricesTypes price_type, double main_price, double past_price)
{
  if(
    price_type == OSCILLATOR_HIGH_PRICES &&
    main_price > past_price
  ) return OSCILLATOR_STRUCTURE_HH;

  if(
    price_type == OSCILLATOR_HIGH_PRICES &&
    main_price < past_price
  ) return OSCILLATOR_STRUCTURE_HL;

  if(
    price_type == OSCILLATOR_LOW_PRICES &&
    main_price > past_price
  ) return OSCILLATOR_STRUCTURE_LH;

  if(
    price_type == OSCILLATOR_LOW_PRICES &&
    main_price < past_price
  ) return OSCILLATOR_STRUCTURE_LL;

  return OSCILLATOR_STRUCTURE_EQ;
}

// ++ FIBONACCI GENERAL DIRECTION CALCULATIONS PERCENTAGES & PRICES ++

// FIRST LOW -> FIRST HIGH -> SECOND LOW
double GetBullishFibonacciPercentage(double signal_entry_bottom_price, double signal_peak_price, double signal_bottom_price)
{
  FibonacciLevelPrices fibonacci_prices;
  double fibonacci_percentage = GetFiboTrendBottomPercent(signal_peak_price, signal_bottom_price, signal_entry_bottom_price);

  GetBullishFibonacciPrices(fibonacci_percentage, fibonacci_prices);

  return fibonacci_prices.entry_level;
}

// FIRST HIGH -> FIRST LOW -> SECOND HIGH
double GetBearishFibonacciPercentage(double signal_entry_peak_price, double signal_bottom_price, double signal_peak_price)
{
  FibonacciLevelPrices fibonacci_prices;
  double fibonacci_percentage = GetFiboTrendPeakPercent(signal_peak_price, signal_bottom_price, signal_entry_peak_price);

  GetBearishFibonacciPrices(fibonacci_percentage, fibonacci_prices);

  return fibonacci_prices.entry_level;
}

// CALCULATE FIBONACCI PRICES

void GetBullishFibonacciPrices(double entry_level_percentage, FibonacciLevelPrices &fibonacci_prices)
{
  double next_level = 0;

  // LEVELS PERCENTAGES
  fibonacci_prices.entry_level      = GetPreciseEntryLevel(entry_level_percentage, next_level);
  fibonacci_prices.entry_next_level = next_level;
}

void GetBearishFibonacciPrices(double entry_level_percentage, FibonacciLevelPrices &fibonacci_prices)
{
  double next_level = 0;

  // LEVELS PERCENTAGES
  fibonacci_prices.entry_level      = GetPreciseEntryLevel(entry_level_percentage, next_level);
  fibonacci_prices.entry_next_level = next_level;
}

// FIBONACCI PERCENTAGE LEVELS

double GetPreciseEntryLevel(double entry_level, double &next_level)
{
  int    fibonacci_levels_total = ArraySize(AllFibonacciLevels)-1;
  double entry_level_plus       = 0;
  double finish_level_plus      = 0;

  for(int i = 0; i < fibonacci_levels_total; i++)
  {
    entry_level_plus = NormalizeDouble(entry_level + 1.0, 1); // ADD A +1 TO COVER INCORRECT DECIMAL ENTRY LEVELS

    if(entry_level_plus >= AllFibonacciLevels[i] && entry_level_plus < AllFibonacciLevels[i+1])
    {
      next_level = AllFibonacciLevels[i+1];
      return AllFibonacciLevels[i];
    }
  }

  return entry_level;
}

double GetFiboRetracementBottomPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = peak_price - ((percentage / 100.0) * diff_prices);

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFiboRetracementPeakPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = bottom_price + ((percentage / 100.0) * diff_prices);

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFiboTrendBottomPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = peak_price - ((percentage / 100.0) * diff_prices); // 0% IS THE PEAK

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFiboTrendPeakPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = ((percentage / 100.0) * diff_prices) + bottom_price; // 0% IS THE BOTTOM

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFiboTrendPeakPercent(double peak_price, double bottom_price, double price)
{
  double percentage = ((price - bottom_price) / (peak_price - bottom_price)) * 100.0; // 100% IS THE PEAK

  return NormalizeDouble(percentage, 1);
}

double GetFiboTrendBottomPercent(double peak_price, double bottom_price, double price)
{
  double percentage = ((peak_price - price) / (peak_price - bottom_price)) * 100.0; // 100% IS THE BOTTOM

  return NormalizeDouble(percentage, 1);
}

// ++ FIBONACCI EXPANSION LOGIC ++

double GetFETrendBottomPrice(double peak_price, double bottom_price, double correction_peak_hh, double percentage)
{
  double diff_prices      = peak_price - bottom_price; // A -> B
  double percentage_price = correction_peak_hh - ((percentage / 100.0) * diff_prices); // SUBSTRACT (C) PEAK HH

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFETrendPeakPrice(double peak_price, double bottom_price, double correction_bottom_ll, double percentage)
{
  double diff_prices      = peak_price - bottom_price; // B -> A
  double percentage_price = correction_bottom_ll + ((percentage / 100.0) * diff_prices); // PLUS (C) BOTTOM LL

  return NormalizeDouble(percentage_price, _Digits);
}

double GetFETrendBottomPercentage(double peak_price, double bottom_price, double correction_peak_hh, double price)
{
  double diff_prices = peak_price - bottom_price;  // Movimiento A -> B
  double percentage  = ((correction_peak_hh - price) / diff_prices) * 100.0; // PEAK PRICE (C) IS 0%

  return NormalizeDouble(percentage, 1); // Retorna el porcentaje con 2 decimales
}

double GetFETrendPeakPercentage(double peak_price, double bottom_price, double correction_bottom_ll, double price)
{
  double diff_prices = peak_price - bottom_price;  // Movimiento B -> A
  double percentage  = ((price - correction_bottom_ll) / diff_prices) * 100.0; // BOTTOM PRICE (C) IS 0%

  return NormalizeDouble(percentage, 1); // Retorna el porcentaje con 2 decimales
}
