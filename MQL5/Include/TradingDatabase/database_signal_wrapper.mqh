// ───────────────────────────────────────────────────────────────────────
// Helpers de formato/escape
// ───────────────────────────────────────────────────────────────────────

// Escapa comillas simples para SQL (' → '')
string SqlEscape(const string input_text)
{
  string escaped = input_text;
  StringReplace(escaped, "'", "''");
  return escaped;
}

// Envolver en comillas simples ya escapado
string SqlQuote(const string input_text)
{
  return "'" + SqlEscape(input_text) + "'";
}

// ───────────────────────────────────────────────────────────────────────
// Helpers de consulta (existencia y recuperación por entry_time)
// ───────────────────────────────────────────────────────────────────────

bool SignalExistsByEntryTimeType(SignalParams &signal_params, long &signal_id)
{
	// Consulta simple para verificar existencia por entry_time y signal_type
  long entry_time_value  = (long)signal_params.entry_time;
	int  signal_type_value = (int)signal_params.signal_type;

  string signal_params_exists_query =
    "SELECT signal_id FROM SignalParamsDB "
    "WHERE entry_time = " + IntegerToString((long)entry_time_value) +
    " AND signal_type = " + IntegerToString(signal_type_value) +
    " LIMIT 1;";

  int statement = DatabasePrepare(Database_Instance, signal_params_exists_query);
  if(statement == INVALID_HANDLE)
  {
    Print("SignalExistsByEntryTimeType: prepare failed: ", GetLastError());
		TesterStop();
    return false;
  }

	if(DatabaseRead(statement))
  {
    DatabaseColumnLong(statement, 0, signal_id);
  }

	DatabaseFinalize(statement);
  return signal_id > 0;
}

// ───────────────────────────────────────────────────────────────────────
// Helpers de dataset (inserción y recuperación de dataset_id)
// ───────────────────────────────────────────────────────────────────────
bool GetDatasetId(string name = "", string symbol = "")
{
  string query =
    "SELECT dataset_id FROM MarketDatasetsDB "
    "WHERE name  = " + SqlQuote(name) +
    " AND symbol = " + SqlQuote(symbol) +
    " LIMIT 1;";

  int statement = DatabasePrepare(Database_Instance, query);
  if(statement == INVALID_HANDLE)
  {
    Print("GetDatasetId: prepare failed: ", GetLastError());
    return false;
  }

  bool ok = false;
  if(DatabaseRead(statement))
  {
    DatabaseColumnText(statement, 0, g_dataset_id);
    ok = (StringLen(g_dataset_id) > 0);
  }
  DatabaseFinalize(statement);

	if(ok) Print("GetDatasetId: dataset_id = ", g_dataset_id);

  return ok;
}

// Inserta el dataset y retorna dataset_id (idempotente). Dos cadenas columns/values.

bool InsertMarketDatasetRecord(const string   name,
                               const string   source,
                               const string   notes,
                               const string   tester_model = "",
                               const string   ea_version   = "")
{
	// Datos del broker/par
  string symbol 			 = _Symbol;
  int    symbol_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  int    spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  int    build         = (int)TerminalInfoInteger(TERMINAL_BUILD);

	// 1) ¿ya existe? (idempotente por clave natural)
  if(GetDatasetId(name, symbol)) return true;

  // Zona horaria local (minutos respecto a UTC)
  int tz_offset_minutes = (int)((long)TimeLocal() - (long)TimeGMT()) / 60;
	datetime date_start   = iTime(_Symbol, PERIOD_CURRENT, 0);
  datetime date_end     = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE);

  // 2) INSERT (dos cadenas)
  string cols =
    "INSERT OR IGNORE INTO MarketDatasetsDB("
    "name, source, notes, symbol, symbol_digits, date_start, date_end, "
    "tester_model, spread_points, timezone_offset, ea_version, build"
    ") ";

  string vals = "VALUES (";
  vals += SqlQuote(name) + ", ";
  vals += SqlQuote(source) + ", ";
  vals += SqlQuote(notes) + ", ";
  vals += SqlQuote(symbol) + ", ";
  vals += IntegerToString(symbol_digits) + ", ";
  vals += IntegerToString((long)date_start) + ", ";
  vals += IntegerToString((long)date_end) + ", ";
  vals += SqlQuote(tester_model) + ", ";
  vals += IntegerToString(spread_points) + ", ";
  vals += IntegerToString(tz_offset_minutes) + ", ";
  vals += SqlQuote(ea_version) + ", ";
  vals += IntegerToString(build);
  vals += ");";

  const string sql = cols + vals;

  if(!DatabaseExecute(Database_Instance, sql))
  {
    Print("InsertMarketDatasetRecord: insert failed: ", GetLastError());
    return false;
  }

  // 3) Recuperar dataset_id (misma conexión/transacción)
  return GetDatasetId(name, symbol);
}

// ───────────────────────────────────────────────────────────────────────
// Insert “create-only” para SignalParamsDB (dos cadenas: columnas/valores)
// ───────────────────────────────────────────────────────────────────────

bool InsertSignalParamsDBRecord(SignalParams &signal_params, long &signal_id)
{
  signal_id = 0;

	// Parte 1: columnas a insertar (orden fijado)
  string query_columns =
    "INSERT OR IGNORE INTO SignalParamsDB("
    "dataset_id, "
    "signal_type, "
    "signal_state, "
    "ticket_id, "
    "entry_price, "
    "close_price, "
    "stop_loss, "
    "take_profit, "
    "lot_size, "
    "raw_profit, "
    "entry_time, "
    "close_time"
    ") ";

  // Parte 2: valores a insertar (usando conversiones explícitas)
  string query_values = "VALUES (";

  // Enums → INTEGER
  query_values += SqlQuote(g_dataset_id) + ", ";
  query_values += IntegerToString((int)signal_params.signal_type) + ", ";
  query_values += IntegerToString((int)signal_params.signal_state) + ", ";

  // TEXT (escapado y entre comillas)
  query_values += SqlQuote(signal_params.ticket_id) + ", ";

  // REAL (usa la precisión que prefieras; aquí precios con _Digits, lotes y profit con 2)
  query_values += DoubleToString(signal_params.entry_price, _Digits) + ", ";
  query_values += DoubleToString(signal_params.close_price, _Digits) + ", ";
  query_values += DoubleToString(signal_params.stop_loss, _Digits) + ", ";
  query_values += DoubleToString(signal_params.take_profit, _Digits) + ", ";
  query_values += DoubleToString(signal_params.lot_size, 2) + ", ";
  query_values += DoubleToString(signal_params.raw_profit, 2) + ", ";

  // INTEGER (epoch seconds)
  query_values += IntegerToString((long)signal_params.entry_time) + ", ";
  query_values += IntegerToString((long)signal_params.close_time);

  // Cierra VALUES
  query_values += ");";

  // Parte 3: unir columnas + valores
  const string insert_sql = query_columns + query_values;

  // Ejecutar
  if(!DatabaseExecute(Database_Instance, insert_sql))
  {
		WriteToFile("query_debug.txt", insert_sql);
		Print("InsertSignalParamsDBRecord: insert failed: ", GetLastError());
		TesterStop();
    return false;
  }

	// Recuperar el signal_id generado (o existente) por entry_time
  if(SignalExistsByEntryTimeType(signal_params, signal_id)) return true;

  // Fallback (poco probable si acabamos de insertar): recuperar por entry_time
  return false;
}

// ───────────────────────────────────────────────────────────────────────
// Inserts hijos (create-only)
// ───────────────────────────────────────────────────────────────────────

bool InsertBandsByTF(const long signal_id, BandsPercentStructure &bands_arr[])
{
  int total = ArraySize(bands_arr);
  if(total <= 0) return true;

  for(int i = 0; i < total; ++i)
  {
    BandsPercentStructure band_percent_data = bands_arr[i];

    // Parte 1: columnas
    string query_columns =
      "INSERT OR IGNORE INTO BandsPercentDB("
      "signal_id, "
      "timeframe, "
			"period, "
      "bands_percent_0, bands_percent_1, bands_percent_2, bands_percent_3, "
      "bands_percent_signal_0, bands_percent_signal_1, bands_percent_signal_2, bands_percent_signal_3, "
      "bands_percent_slope_0, bands_percent_slope_1, bands_percent_slope_2, bands_percent_slope_3, "
      "bands_percent_signal_slope_0, bands_percent_signal_slope_1, bands_percent_signal_slope_2, bands_percent_signal_slope_3, "
      "bands_percent_percentil_0, bands_percent_percentil_1, bands_percent_percentil_2, bands_percent_percentil_3, "
      "bands_percent_signal_percentil_0, bands_percent_signal_percentil_1, bands_percent_signal_percentil_2, bands_percent_signal_percentil_3, "
      "bands_percent_trend_0, bands_percent_trend_1, bands_percent_trend_2, bands_percent_trend_3"
      ") ";

    // Parte 2: valores
    string query_values = "VALUES (";
    query_values += IntegerToString((long)signal_id) + ", ";
    query_values += IntegerToString((int)band_percent_data.indicator_timeframe) + ", ";
		query_values += IntegerToString((int)band_percent_data.indicator_period) + ", ";

    query_values += DoubleToString(band_percent_data.bands_percent_0, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_1, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_2, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_3, 2) + ", ";

    query_values += DoubleToString(band_percent_data.bands_percent_signal_0, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_signal_1, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_signal_2, 2) + ", ";
    query_values += DoubleToString(band_percent_data.bands_percent_signal_3, 2) + ", ";

    query_values += IntegerToString((int)band_percent_data.bands_percent_slope_0) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_slope_1) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_slope_2) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_slope_3) + ", ";

    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_slope_0) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_slope_1) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_slope_2) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_slope_3) + ", ";

    query_values += IntegerToString((int)band_percent_data.bands_percent_percentil_0) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_percentil_1) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_percentil_2) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_percentil_3) + ", ";

    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_percentil_0) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_percentil_1) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_percentil_2) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_signal_percentil_3) + ", ";

    query_values += IntegerToString((int)band_percent_data.bands_percent_trend_0) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_trend_1) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_trend_2) + ", ";
    query_values += IntegerToString((int)band_percent_data.bands_percent_trend_3);

    query_values += ");";

    const string insert_sql = query_columns + query_values;

    if(!DatabaseExecute(Database_Instance, insert_sql))
    {
			WriteToFile("query_debug.txt", insert_sql);
			Print("InsertBandsByTF: insert failed: ", GetLastError());
			TesterStop();
      return false;
    }
  }
  return true;
}

bool InsertStochByTF(const long signal_id, StochasticStructure &stoch_arr[])
{
  const int total = ArraySize(stoch_arr);
  if(total <= 0) return true;

  for(int i = 0; i < total; ++i)
  {
    StochasticStructure stochastic_data = stoch_arr[i];

    // Parte 1: columnas
    string query_columns =
      "INSERT OR IGNORE INTO StochasticDB("
      "signal_id, "
      "timeframe, "
			"period, "
      "stochastic_0, stochastic_1, stochastic_2, stochastic_3, "
      "stochastic_signal_0, stochastic_signal_1, stochastic_signal_2, stochastic_signal_3, "
      "stochastic_slope_0, stochastic_slope_1, stochastic_slope_2, stochastic_slope_3, "
      "stochastic_signal_slope_0, stochastic_signal_slope_1, stochastic_signal_slope_2, stochastic_signal_slope_3, "
      "stochastic_percentil_0, stochastic_percentil_1, stochastic_percentil_2, stochastic_percentil_3, "
      "stochastic_signal_percentil_0, stochastic_signal_percentil_1, stochastic_signal_percentil_2, stochastic_signal_percentil_3, "
      "stochastic_trend_0, stochastic_trend_1, stochastic_trend_2, stochastic_trend_3"
      ") ";

    // Parte 2: valores
    string query_values = "VALUES (";
    query_values += IntegerToString((long)signal_id) + ", ";
    query_values += IntegerToString((int)stochastic_data.indicator_timeframe) + ", ";
		query_values += IntegerToString((int)stochastic_data.indicator_period) + ", ";

    query_values += DoubleToString(stochastic_data.stochastic_0, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_1, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_2, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_3, 2) + ", ";

    query_values += DoubleToString(stochastic_data.stochastic_signal_0, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_signal_1, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_signal_2, 2) + ", ";
    query_values += DoubleToString(stochastic_data.stochastic_signal_3, 2) + ", ";

    query_values += IntegerToString((int)stochastic_data.stochastic_slope_0) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_slope_1) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_slope_2) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_slope_3) + ", ";

    query_values += IntegerToString((int)stochastic_data.stochastic_signal_slope_0) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_slope_1) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_slope_2) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_slope_3) + ", ";

    query_values += IntegerToString((int)stochastic_data.stochastic_percentil_0) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_percentil_1) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_percentil_2) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_percentil_3) + ", ";

    query_values += IntegerToString((int)stochastic_data.stochastic_signal_percentil_0) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_percentil_1) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_percentil_2) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_signal_percentil_3) + ", ";

    query_values += IntegerToString((int)stochastic_data.stochastic_trend_0) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_trend_1) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_trend_2) + ", ";
    query_values += IntegerToString((int)stochastic_data.stochastic_trend_3);

    query_values += ");";

    const string insert_sql = query_columns + query_values;

    if(!DatabaseExecute(Database_Instance, insert_sql))
    {
			WriteToFile("query_debug.txt", insert_sql);
			Print("InsertStochByTF: insert failed: ", GetLastError());
			TesterStop();
      return false;
    }
  }
  return true;
}

bool InsertStochStructByTF(const long signal_id, StochasticMarketStructure &ms_arr[])
{
  const int total = ArraySize(ms_arr);
  if(total <= 0) return true;

  for(int i = 0; i < total; ++i)
  {
    StochasticMarketStructure market_stoch_data = ms_arr[i];

    // Parte 1: columnas
    string query_columns =
      "INSERT OR IGNORE INTO StochasticMarketStructureDB("
      "signal_id, "
      "timeframe, "
			"period, "
      "first_structure_type, second_structure_type, third_structure_type, "
      "fourth_structure_type, fifth_structure_type, six_structure_type, "
      "first_structure_time, first_structure_price, "
      "second_structure_time, second_structure_price, "
      "third_structure_time, third_structure_price, "
      "fourth_structure_time, fourth_structure_price, "
      "first_fibonacci_level, second_fibonacci_level, third_fibonacci_level, fourth_fibonacci_level"
      ") ";

    // Parte 2: valores
    string query_values = "VALUES (";
    query_values += IntegerToString((long)signal_id) + ", ";
    query_values += IntegerToString((int)market_stoch_data.indicator_timeframe) + ", ";
		query_values += IntegerToString((int)market_stoch_data.indicator_period) + ", ";

    // Estructuras (ajusta min/max según tu enum)
		query_values += SqlEnumValue((int)market_stoch_data.first_structure_type,  0, 6, DEF_OSC_STRUCT_TYPE) + ", ";
		query_values += SqlEnumValue((int)market_stoch_data.second_structure_type, 0, 6, DEF_OSC_STRUCT_TYPE) + ", ";
		query_values += SqlEnumValue((int)market_stoch_data.third_structure_type,  0, 6, DEF_OSC_STRUCT_TYPE) + ", ";
		query_values += SqlEnumValue((int)market_stoch_data.fourth_structure_type, 0, 6, DEF_OSC_STRUCT_TYPE) + ", ";
		query_values += SqlEnumValue((int)market_stoch_data.fifth_structure_type,  0, 6, DEF_OSC_STRUCT_TYPE) + ", ";
		query_values += SqlEnumValue((int)market_stoch_data.six_structure_type,    0, 6, DEF_OSC_STRUCT_TYPE) + ", ";

		// Tiempos y precios
		query_values += SqlEpochValue((long)market_stoch_data.first_structure_time)   + ", ";
		query_values += SqlPriceValue(market_stoch_data.first_structure_price)        + ", ";
		query_values += SqlEpochValue((long)market_stoch_data.second_structure_time)  + ", ";
		query_values += SqlPriceValue(market_stoch_data.second_structure_price)       + ", ";
		query_values += SqlEpochValue((long)market_stoch_data.third_structure_time)   + ", ";
		query_values += SqlPriceValue(market_stoch_data.third_structure_price)        + ", ";
		query_values += SqlEpochValue((long)market_stoch_data.fourth_structure_time)  + ", ";
		query_values += SqlPriceValue(market_stoch_data.fourth_structure_price)       + ", ";

		// Fibo levels (0..100)
		query_values += SqlFiboValue(market_stoch_data.first_fibonacci_level)  + ", ";
		query_values += SqlFiboValue(market_stoch_data.second_fibonacci_level) + ", ";
		query_values += SqlFiboValue(market_stoch_data.third_fibonacci_level)  + ", ";
		query_values += SqlFiboValue(market_stoch_data.fourth_fibonacci_level);

    query_values += ");";

    const string insert_sql = query_columns + query_values;

    if(!DatabaseExecute(Database_Instance, insert_sql))
    {
			WriteToFile("query_debug.txt", insert_sql);
			Print("InsertStochStructByTF: insert failed: ", GetLastError());
			TesterStop();
      return false;
    }
  }
  return true;
}

// ───────────────────────────────────────────────────────────────────────
// Insert completo con transacción (SignalParamsDB + hijos)							 |
// ───────────────────────────────────────────────────────────────────────
bool SaveFullSignalTransaction(SignalParams &signal_params)
{
  long signal_id = 0;

  // Iniciar transacción
  if(!DatabaseExecute(Database_Instance, "BEGIN IMMEDIATE TRANSACTION;"))
  {
    Print("SaveFullSignalTransaction: BEGIN failed: ", GetLastError());
		TesterStop();
    return false;
  }

	// Early return si ya existe (evitar duplicados y lógica innecesaria)
  if(SignalExistsByEntryTimeType(signal_params, signal_id))
	{
		Log_Custom("Signal [EXISTS] in DB with signal_id: " + IntegerToString(signal_id) +
									 ", entry_time: " + TimeToString(signal_params.entry_time, TIME_DATE|TIME_SECONDS) +
									 ", type: " + EnumToString(signal_params.signal_type) +
									 ", state: " + EnumToString(signal_params.signal_state) +
									 ", ticket_id: " + signal_params.ticket_id);
		DatabaseExecute(Database_Instance, "ROLLBACK;");
		return true; // Ya existe, no hacer nada
	}

  bool inserted_signal_params = InsertSignalParamsDBRecord(signal_params, signal_id);

  // Si devuelve false pero ya tenemos signal_id > 0, la fila ya existía: continuamos.
  if(!inserted_signal_params && signal_id <= 0)
  {
    Print("SaveFullSignalTransaction: inserted_signal_params failed and no existing id.");
		TesterStop();
    DatabaseExecute(Database_Instance, "ROLLBACK;");
    return false;
  }

  bool signal_data_stored = true;
  signal_data_stored = signal_data_stored && InsertBandsByTF(signal_id, signal_params.bands_percent_data);
  signal_data_stored = signal_data_stored && InsertStochByTF(signal_id, signal_params.stochastic_data);
  signal_data_stored = signal_data_stored && InsertStochStructByTF(signal_id, signal_params.stoch_market_structure_data);

  if(signal_data_stored)
  {
    if(!DatabaseExecute(Database_Instance, "COMMIT;"))
    {
      Print("SaveFullSignalTransaction: COMMIT failed: ", GetLastError());
			TesterStop();
      return false;
    }

		Log_Custom("Signal [STORED] to DB with signal_id: " + IntegerToString(signal_id) +
									 ", entry_time: " + TimeToString(signal_params.entry_time, TIME_DATE|TIME_SECONDS) +
									 ", type: " + EnumToString(signal_params.signal_type) +
									 ", state: " + EnumToString(signal_params.signal_state) +
									 ", ticket_id: " + signal_params.ticket_id);
    return true;
  }

  DatabaseExecute(Database_Instance, "ROLLBACK;");
  return false;
}
