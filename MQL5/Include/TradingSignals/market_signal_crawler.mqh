
//+------------------------------------------------------------------+
//|                                       market_signal_scrapper.mqh |
//+------------------------------------------------------------------+

SignalParams running_bullish_signals[];
SignalParams running_bearish_signals[];

void DetectBullishSignal()
{
	if(GuardStochasticSignalDetection(BULLISH)) return;

	SignalParams signal_bullish;

	// SET THE BULLISH SIGNAL PARAMETERS
	signal_bullish.signal_type = BULLISH;
	signal_bullish.entry_price = g_ask;
	signal_bullish.entry_time	 = iTime(_Symbol, PERIOD_CURRENT, 0);

	// SET THE INDICATOR DATA
	SetTFBandsPercentDataToSignalParams(signal_bullish);
	SetTFStochasticDataToSignalParams(signal_bullish);
	SetTFStochasticMarketStructureDataToSignalParams(signal_bullish);

	// OPEN THE BULLISH SIGNAL TO THE MARKET
	// ...

	// ADD THE BULLISH SIGNAL TO THE ARRAY
	AddElementToArray(running_bullish_signals, signal_bullish);
}

void DetectBearishSignal()
{
	if(GuardStochasticSignalDetection(BEARISH)) return;

	SignalParams signal_bearish;

	// SET THE BEARISH SIGNAL PARAMETERS
	signal_bearish.signal_type = BEARISH;
	signal_bearish.entry_price = g_bid;
	signal_bearish.entry_time	 = iTime(_Symbol, PERIOD_CURRENT, 0);

	// SET THE INDICATOR DATA
	SetTFBandsPercentDataToSignalParams(signal_bearish);
	SetTFStochasticDataToSignalParams(signal_bearish);
	SetTFStochasticMarketStructureDataToSignalParams(signal_bearish);

	// OPEN THE BEARISH SIGNAL TO THE MARKET
	// ...

	// ADD THE BEARISH SIGNAL TO THE ARRAY
	AddElementToArray(running_bearish_signals, signal_bearish);
}

// ++ GUARD CONDITIONS TO OPEN THE SIGNALS ++

bool GuardStochasticSignalDetection(const SignalTypes signal_type)
{
	// VERIFY STOCHASTIC SIGNAL CONDITIONS
	StochasticStructure stochastic_data;
	double stochastic_signal_1 = stochastic_data.GetStochasticSignalValue(ExtStochIndicatorsHandle[0], 1);

	if(signal_type == BULLISH && stochastic_signal_1 <= 30.0) return false;
	if(signal_type == BEARISH && stochastic_signal_1 >= 70.0) return false;

	return true;
}

// ++ CLOSE THE SIGNALS ++

void CloseBullishSignal(SignalParams &signal_bullish)
{
	if(Enable_Logs) LogSignalParamsForTF(signal_bullish, PERIOD_M1);

	// MANAGE THE BULLISH SIGNAL STATE
	// if(signal_bullish.signal_state == OPENED) { ... }

	// STORE SIGNAL STATS TO DATABASE
	SaveFullSignalTransaction(signal_bullish);
}

void CloseBearishSignal(SignalParams &signal_bearish)
{
	if(Enable_Logs) LogSignalParamsForTF(signal_bearish, PERIOD_M1);

	// MANAGE THE BULLISH SIGNAL STATE
	// if(signal_bearish.signal_state == OPENED) { ... }

	// STORE SIGNAL STATS TO DATABASE
	SaveFullSignalTransaction(signal_bearish);
}

// SET THE INDICATOR DATA TO THE SIGNAL PARAMS STRUCTURE

void SetTFBandsPercentDataToSignalParams(SignalParams &signal_params)
{
	// Iterate over each timeframe's Bands Percent indicator handle in ExtBPercentIndicatorsHandle
	for(int i = 0; i < ArraySize(ExtBPercentIndicatorsHandle); i++)
	{
		BandsPercentStructure bands_percent_data;
		bands_percent_data = BandsPercentStructure();
		bands_percent_data.InitBandsPercentStructureValues(ExtBPercentIndicatorsHandle[i], 0);
		AddElementToArray(signal_params.bands_percent_data, bands_percent_data);
	}
}

void SetTFStochasticDataToSignalParams(SignalParams &signal_params)
{
	// Iterate over each timeframe's Stochastic indicator handle in ExtStochIndicatorsHandle
	for(int i = 0; i < ArraySize(ExtStochIndicatorsHandle); i++)
	{
		StochasticStructure stochastic_data;
		stochastic_data = StochasticStructure();
		stochastic_data.InitStochasticStructureValues(ExtStochIndicatorsHandle[i], 0);
		AddElementToArray(signal_params.stochastic_data, stochastic_data);
	}
}

void SetTFStochasticMarketStructureDataToSignalParams(SignalParams &signal_params)
{
	// Iterate over each timeframe's Stochastic market structure indicator handle in ExtStructStochIndicatorsHandle
	for(int i = 0; i < ArraySize(ExtStructStochIndicatorsHandle); i++)
	{
		StochasticMarketStructure stoch_market_structure_data;
		stoch_market_structure_data = StochasticMarketStructure();
		stoch_market_structure_data.InitStochMarketStructureValues(ExtStructStochIndicatorsHandle[i]);
		AddElementToArray(signal_params.stoch_market_structure_data, stoch_market_structure_data);
	}
}
