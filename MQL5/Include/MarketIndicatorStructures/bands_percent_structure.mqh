//+------------------------------------------------------------------+
//|                                      bands_percent_structure.mqh |
//+------------------------------------------------------------------+

struct BandsPercentStructure
{
	// INDICATOR INFO
	ENUM_TIMEFRAMES indicator_timeframe;
	int 						indicator_period;
	// BAND PERCENT VALUES
	double bands_percent_0;
	double bands_percent_1;
	double bands_percent_2;
	double bands_percent_3;
	// BAND PERCENT SIGNALS
	double bands_percent_signal_0;
	double bands_percent_signal_1;
	double bands_percent_signal_2;
	double bands_percent_signal_3;
	// BAND PERCENT SLOPES
	SlopeTypes bands_percent_slope_0;
	SlopeTypes bands_percent_slope_1;
	SlopeTypes bands_percent_slope_2;
	SlopeTypes bands_percent_slope_3;
	// BAND PERCENT SIGNAL SLOPES
	SlopeTypes bands_percent_signal_slope_0;
	SlopeTypes bands_percent_signal_slope_1;
	SlopeTypes bands_percent_signal_slope_2;
	SlopeTypes bands_percent_signal_slope_3;
	// BAND PERCENT PERCENTILS
	PercentilTypes bands_percent_percentil_0;
	PercentilTypes bands_percent_percentil_1;
	PercentilTypes bands_percent_percentil_2;
	PercentilTypes bands_percent_percentil_3;
	// BAND PERCENT SIGNAL PERCENTILS
	PercentilTypes bands_percent_signal_percentil_0;
	PercentilTypes bands_percent_signal_percentil_1;
	PercentilTypes bands_percent_signal_percentil_2;
	PercentilTypes bands_percent_signal_percentil_3;
	// BAND PERCENT TREND
	SignalTypes bands_percent_trend_0;
	SignalTypes bands_percent_trend_1;
	SignalTypes bands_percent_trend_2;
	SignalTypes bands_percent_trend_3;

	// DEFAULT CONSTRUCTOR
	BandsPercentStructure()
	{
		indicator_timeframe 						= PERIOD_CURRENT;
		indicator_period 								= 0;
		bands_percent_0              		= 0.0;
		bands_percent_1              		= 0.0;
		bands_percent_2              		= 0.0;
		bands_percent_3              		= 0.0;
		bands_percent_signal_0       		= 0.0;
		bands_percent_signal_1       		= 0.0;
		bands_percent_signal_2       		= 0.0;
		bands_percent_signal_3       		= 0.0;
		bands_percent_slope_0        		= NO_SLOPE;
		bands_percent_slope_1        		= NO_SLOPE;
		bands_percent_slope_2        		= NO_SLOPE;
		bands_percent_slope_3        		= NO_SLOPE;
		bands_percent_signal_slope_0 		= NO_SLOPE;
		bands_percent_signal_slope_1 		= NO_SLOPE;
		bands_percent_signal_slope_2 		= NO_SLOPE;
		bands_percent_signal_slope_3 		= NO_SLOPE;
		bands_percent_percentil_0     		= PERCENTIL_NULL;
		bands_percent_percentil_1     		= PERCENTIL_NULL;
		bands_percent_percentil_2     		= PERCENTIL_NULL;
		bands_percent_percentil_3     		= PERCENTIL_NULL;
		bands_percent_signal_percentil_0 = PERCENTIL_NULL;
		bands_percent_signal_percentil_1 = PERCENTIL_NULL;
		bands_percent_signal_percentil_2 = PERCENTIL_NULL;
		bands_percent_signal_percentil_3 = PERCENTIL_NULL;
		bands_percent_trend_0        		= NO_SIGNAL;
		bands_percent_trend_1        		= NO_SIGNAL;
		bands_percent_trend_2        		= NO_SIGNAL;
		bands_percent_trend_3        		= NO_SIGNAL;
	}

	// COPY CONSTRUCTOR
	BandsPercentStructure(const BandsPercentStructure &bands_percent_structure)
	{
		indicator_timeframe 						= bands_percent_structure.indicator_timeframe;
		indicator_period 								= bands_percent_structure.indicator_period;
		bands_percent_0              		= bands_percent_structure.bands_percent_0;
		bands_percent_1              		= bands_percent_structure.bands_percent_1;
		bands_percent_2              		= bands_percent_structure.bands_percent_2;
		bands_percent_3              		= bands_percent_structure.bands_percent_3;
		bands_percent_signal_0       		= bands_percent_structure.bands_percent_signal_0;
		bands_percent_signal_1       		= bands_percent_structure.bands_percent_signal_1;
		bands_percent_signal_2       		= bands_percent_structure.bands_percent_signal_2;
		bands_percent_signal_3       		= bands_percent_structure.bands_percent_signal_3;
		bands_percent_slope_0        		= bands_percent_structure.bands_percent_slope_0;
		bands_percent_slope_1        		= bands_percent_structure.bands_percent_slope_1;
		bands_percent_slope_2        		= bands_percent_structure.bands_percent_slope_2;
		bands_percent_slope_3						= bands_percent_structure.bands_percent_slope_3;
		bands_percent_signal_slope_0 		= bands_percent_structure.bands_percent_signal_slope_0;
		bands_percent_signal_slope_1 		= bands_percent_structure.bands_percent_signal_slope_1;
		bands_percent_signal_slope_2 		= bands_percent_structure.bands_percent_signal_slope_2;
		bands_percent_signal_slope_3 		= bands_percent_structure.bands_percent_signal_slope_3;
		bands_percent_percentil_0     		= bands_percent_structure.bands_percent_percentil_0;
		bands_percent_percentil_1     		= bands_percent_structure.bands_percent_percentil_1;
		bands_percent_percentil_2     		= bands_percent_structure.bands_percent_percentil_2;
		bands_percent_percentil_3     		= bands_percent_structure.bands_percent_percentil_3;
		bands_percent_signal_percentil_0 = bands_percent_structure.bands_percent_signal_percentil_0;
		bands_percent_signal_percentil_1 = bands_percent_structure.bands_percent_signal_percentil_1;
		bands_percent_signal_percentil_2 = bands_percent_structure.bands_percent_signal_percentil_2;
		bands_percent_signal_percentil_3 = bands_percent_structure.bands_percent_signal_percentil_3;
		bands_percent_trend_0        		= bands_percent_structure.bands_percent_trend_0;
		bands_percent_trend_1						= bands_percent_structure.bands_percent_trend_1;
		bands_percent_trend_2        		= bands_percent_structure.bands_percent_trend_2;
		bands_percent_trend_3        		= bands_percent_structure.bands_percent_trend_3;
	}

	// INITIALIZE STRUCTURE VALUES
	void InitBandsPercentStructureValues(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		indicator_timeframe 					= bands_indicator_handle.indicator_timeframe;
		indicator_period 							= bands_indicator_handle.indicator_period;
		bands_percent_0               = GetBandsPercentValue(bands_indicator_handle, index);
		bands_percent_1               = GetBandsPercentValue(bands_indicator_handle, index+1);
		bands_percent_2               = GetBandsPercentValue(bands_indicator_handle, index+2);
		bands_percent_3               = GetBandsPercentValue(bands_indicator_handle, index+3);

		bands_percent_signal_0        = GetBandsPercentSignalValue(bands_indicator_handle, index);
		bands_percent_signal_1        = GetBandsPercentSignalValue(bands_indicator_handle, index+1);
		bands_percent_signal_2        = GetBandsPercentSignalValue(bands_indicator_handle, index+2);
		bands_percent_signal_3        = GetBandsPercentSignalValue(bands_indicator_handle, index+3);

		bands_percent_slope_0         = GetBandsPercentSlope(bands_indicator_handle, index);
		bands_percent_slope_1         = GetBandsPercentSlope(bands_indicator_handle, index+1);
		bands_percent_slope_2         = GetBandsPercentSlope(bands_indicator_handle, index+2);
		bands_percent_slope_3         = GetBandsPercentSlope(bands_indicator_handle, index+3);

		bands_percent_signal_slope_0  = GetBandsPercentSignalSlope(bands_indicator_handle, index);
		bands_percent_signal_slope_1  = GetBandsPercentSignalSlope(bands_indicator_handle, index+1);
		bands_percent_signal_slope_2  = GetBandsPercentSignalSlope(bands_indicator_handle, index+2);
		bands_percent_signal_slope_3  = GetBandsPercentSignalSlope(bands_indicator_handle, index+3);

		bands_percent_percentil_0      = GetBandsPercentPercentil(bands_indicator_handle, index);
		bands_percent_percentil_1      = GetBandsPercentPercentil(bands_indicator_handle, index+1);
		bands_percent_percentil_2      = GetBandsPercentPercentil(bands_indicator_handle, index+2);
		bands_percent_percentil_3      = GetBandsPercentPercentil(bands_indicator_handle, index+3);

		bands_percent_signal_percentil_0 = GetBandsPercentSignalPercentil(bands_indicator_handle, index);
		bands_percent_signal_percentil_1 = GetBandsPercentSignalPercentil(bands_indicator_handle, index+1);
		bands_percent_signal_percentil_2 = GetBandsPercentSignalPercentil(bands_indicator_handle, index+2);
		bands_percent_signal_percentil_3 = GetBandsPercentSignalPercentil(bands_indicator_handle, index+3);

		bands_percent_trend_0         = GetBandsPercentTrend(bands_indicator_handle, index);
		bands_percent_trend_1         = GetBandsPercentTrend(bands_indicator_handle, index+1);
		bands_percent_trend_2         = GetBandsPercentTrend(bands_indicator_handle, index+2);
		bands_percent_trend_3         = GetBandsPercentTrend(bands_indicator_handle, index+3);
	}

	// ++ BANDS PERCENT INDICATOR FUNCTIONS ++

	double GetBandsPercentValue(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double bands_percent_value[];

		if(CopyBuffer(bands_indicator_handle.indicator_handle, 0, 0, index+1, bands_percent_value) <= 0)
		{
			Print("ERROR READING BANDS PERCENT INDICATOR DATA");
		}

	  ArraySetAsSeries(bands_percent_value, true);

		// ROUNDS TO 2 DECIMALS FOR PERCENTAGE VALUES
		return(NormalizeDouble(bands_percent_value[index], 2));
	}

	double GetBandsPercentSignalValue(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double bands_percent_signal_value[];

		if(CopyBuffer(bands_indicator_handle.indicator_handle, 1, 0, index+1, bands_percent_signal_value) <= 0)
		{
			Print("ERROR READING BANDS PERCENT SIGNAL INDICATOR DATA");
		}

	  ArraySetAsSeries(bands_percent_signal_value, true);

		// ROUNDS TO 2 DECIMALS FOR PERCENTAGE VALUES
		return(NormalizeDouble(bands_percent_signal_value[index], 2));
	}

	SlopeTypes GetBandsPercentSlope(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double current_value  = GetBandsPercentValue(bands_indicator_handle, index);
		double previous_value = GetBandsPercentValue(bands_indicator_handle, index + 1);

		if(current_value > previous_value) return(UP_SLOPE);
		if(current_value < previous_value) return(DOWN_SLOPE);

		return(NO_SLOPE);
	}

	SlopeTypes GetBandsPercentSignalSlope(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double current_value  = GetBandsPercentSignalValue(bands_indicator_handle, index);
		double previous_value = GetBandsPercentSignalValue(bands_indicator_handle, index + 1);

		if(current_value > previous_value) return(UP_SLOPE);
		if(current_value < previous_value) return(DOWN_SLOPE);

		return(NO_SLOPE);
	}

	PercentilTypes GetBandsPercentPercentil(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double bands_percent_value = GetBandsPercentValue(bands_indicator_handle, index);

		if(bands_percent_value <= 0.0)   															 return(PERCENTIL_MIN);
		if(bands_percent_value >  0.0 && bands_percent_value < 10.0)   return(PERCENTIL_0);
		if(bands_percent_value >= 10.0 && bands_percent_value < 20.0)  return(PERCENTIL_10);
		if(bands_percent_value >= 20.0 && bands_percent_value < 30.0)  return(PERCENTIL_20);
		if(bands_percent_value >= 30.0 && bands_percent_value < 40.0)  return(PERCENTIL_30);
		if(bands_percent_value >= 40.0 && bands_percent_value < 50.0)  return(PERCENTIL_40);
		if(bands_percent_value >= 50.0 && bands_percent_value < 60.0)  return(PERCENTIL_50);
		if(bands_percent_value >= 60.0 && bands_percent_value < 70.0)  return(PERCENTIL_60);
		if(bands_percent_value >= 70.0 && bands_percent_value < 80.0)  return(PERCENTIL_70);
		if(bands_percent_value >= 80.0 && bands_percent_value < 90.0)  return(PERCENTIL_80);
		if(bands_percent_value >= 90.0 && bands_percent_value < 100.0) return(PERCENTIL_90);
		if(bands_percent_value >= 100.0) 															 return(PERCENTIL_MAX);

		return(PERCENTIL_NULL);
	}

	PercentilTypes GetBandsPercentSignalPercentil(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double bands_percent_signal_value = GetBandsPercentSignalValue(bands_indicator_handle, index);

		if(bands_percent_signal_value <= 0.0)   																		 return(PERCENTIL_MIN);
		if(bands_percent_signal_value >  0.0 && bands_percent_signal_value < 10.0)   return(PERCENTIL_0);
		if(bands_percent_signal_value >= 10.0 && bands_percent_signal_value < 20.0)  return(PERCENTIL_10);
		if(bands_percent_signal_value >= 20.0 && bands_percent_signal_value < 30.0)  return(PERCENTIL_20);
		if(bands_percent_signal_value >= 30.0 && bands_percent_signal_value < 40.0)  return(PERCENTIL_30);
		if(bands_percent_signal_value >= 40.0 && bands_percent_signal_value < 50.0)  return(PERCENTIL_40);
		if(bands_percent_signal_value >= 50.0 && bands_percent_signal_value < 60.0)  return(PERCENTIL_50);
		if(bands_percent_signal_value >= 60.0 && bands_percent_signal_value < 70.0)  return(PERCENTIL_60);
		if(bands_percent_signal_value >= 70.0 && bands_percent_signal_value < 80.0)  return(PERCENTIL_70);
		if(bands_percent_signal_value >= 80.0 && bands_percent_signal_value < 90.0)  return(PERCENTIL_80);
		if(bands_percent_signal_value >= 90.0 && bands_percent_signal_value < 100.0) return(PERCENTIL_90);
		if(bands_percent_signal_value >= 100.0) 																		 return(PERCENTIL_MAX);

		return(PERCENTIL_NULL);
	}

	SignalTypes GetBandsPercentTrend(IndicatorsHandleInfo &bands_indicator_handle, int index)
	{
		double bands_percent_value        = GetBandsPercentValue(bands_indicator_handle, index);
		double bands_percent_signal_value = GetBandsPercentSignalValue(bands_indicator_handle, index);

		if(bands_percent_value > bands_percent_signal_value) return(BULLISH);
		if(bands_percent_value < bands_percent_signal_value) return(BEARISH);

		return(NO_SIGNAL);
	}
};
