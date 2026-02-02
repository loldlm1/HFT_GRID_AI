
//+------------------------------------------------------------------+
//|                                         signal_params_struct.mqh |
//+------------------------------------------------------------------+

#include <MarketIndicatorStructures/bands_percent_structure.mqh>
#include <MarketIndicatorStructures/stochastic_structure.mqh>
#include <MarketIndicatorStructures/stochastic_market_structure.mqh>

// TRADING SIGNALS STRUCTURES
struct SignalParams
{
	SignalTypes 							signal_type;
	SignalStates 							signal_state;
	string   	  							ticket_id;
	double   									entry_price;
	double   									close_price;
	double   									stop_loss;
	double   									take_profit;
	double   									lot_size;
	double   									raw_profit;
	datetime 									entry_time;
	datetime 									close_time;
	BandsPercentStructure 		bands_percent_data[];
	StochasticStructure   		stochastic_data[];
	StochasticMarketStructure stoch_market_structure_data[];

	// DEFAULT CONSTRUCTOR
	SignalParams()
	{
		signal_type 			 = NO_SIGNAL;
		signal_state 			 = WAITING;
		ticket_id   			 = "";
		entry_price 			 = 0.0;
		close_price 			 = 0.0;
		stop_loss   			 = 0.0;
		take_profit 			 = 0.0;
		lot_size    			 = 0.0;
		raw_profit				 = 0.0;
		entry_time  			 = 0;
		close_time  			 = 0;
	}

	// COPY CONSTRUCTOR
	SignalParams(const SignalParams &signal_params)
	{
		signal_type 			 	 = signal_params.signal_type;
		signal_state 			 	 = signal_params.signal_state;
		ticket_id   			 	 = signal_params.ticket_id;
		entry_price 			 	 = signal_params.entry_price;
		close_price 			 	 = signal_params.close_price;
		stop_loss   			 	 = signal_params.stop_loss;
		take_profit 			 	 = signal_params.take_profit;
		lot_size    			 	 = signal_params.lot_size;
		raw_profit				 	 = signal_params.raw_profit;
		entry_time  			 	 = signal_params.entry_time;
		close_time  			 	 = signal_params.close_time;
		
		// DEEP COPY OF ARRAYS
		ArrayCopy(bands_percent_data, 				 signal_params.bands_percent_data);
		ArrayCopy(stochastic_data,    	  		 signal_params.stochastic_data);
		// FIXME: Copying array of structures might need a custom deep copy function
		// ArrayCopy(stoch_market_structure_data, signal_params.stoch_market_structure_data);
	}
};
