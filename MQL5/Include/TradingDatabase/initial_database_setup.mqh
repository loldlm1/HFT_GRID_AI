//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+

int  Database_Instance = INVALID_HANDLE;
bool Database_Initial_Setup;

//+------------------------------------------------------------------+
//| Function to create or open a database                            |
//+------------------------------------------------------------------+
bool OpenStatsDatabase()
{
  string db_filename = Database_System_Name + "_db.sqlite";

  Database_Instance = DatabaseOpen(db_filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
  if(Database_Instance == INVALID_HANDLE)
  {
    Print("Failed to open database: ", db_filename, " with error: ", GetLastError());
    return false;
  }

  // Habilitar WAL
	DatabaseExecute(Database_Instance, "PRAGMA foreign_keys=ON;");
  DatabaseExecute(Database_Instance, "PRAGMA automatic_index=ON;");
  DatabaseExecute(Database_Instance, "PRAGMA journal_mode=WAL;");
  DatabaseExecute(Database_Instance, "PRAGMA synchronous=NORMAL;");
  DatabaseExecute(Database_Instance, "PRAGMA wal_autocheckpoint=1000;"); // más frecuente
  DatabaseExecute(Database_Instance, "PRAGMA busy_timeout=1000;");
  DatabaseExecute(Database_Instance, "PRAGMA cache_size=-64000;");       //-- Use 64MB of cache (negative number means kibibytes)
  DatabaseExecute(Database_Instance, "PRAGMA page_size=4096;");          //-- Optimal page size for most systems

  return true;
}

bool CreateStatisticsTables()
{
	// ── Tabla raíz: datasets de backtest/ingesta
  string create_market_datasets_db =
    "CREATE TABLE IF NOT EXISTS MarketDatasetsDB ("
    "  dataset_id TEXT PRIMARY KEY NOT NULL DEFAULT ("
		"    lower("
		"      hex(randomblob(4)) || '-' || "
		"      hex(randomblob(2)) || '-' || "
		"      '4' || substr(hex(randomblob(2)),2) || '-' || "
		"      substr('89ab', 1 + abs(random()) % 4, 1) || substr(hex(randomblob(2)),2) || '-' || "
		"      hex(randomblob(6))"
		"    )"
		"  ),"
    "  name             TEXT    NOT NULL,"         /* * input local */
    "  source           TEXT    DEFAULT '',"       /* * input local (ej. 'tester', 'live', 'import') */
    "  notes            TEXT    DEFAULT '',"       /* * input local */
    "  symbol           TEXT    NOT NULL,"         /* ** del broker */
    "  symbol_digits    INTEGER NOT NULL,"         /* ** del broker */
    "  date_start       INTEGER NOT NULL,"         /* ** epoch (inicio del backtest) */
    "  date_end         INTEGER NOT NULL,"         /* ** epoch (fin del backtest)  */
    /* +3 campos útiles extra para caracterizar la muestra */
    "  tester_model     TEXT    DEFAULT '',"       /* * p.ej. 'Every tick', '1-minute OHLC' */
    "  spread_points    INTEGER NOT NULL DEFAULT 0,"/* ** spread usado en puntos */
    "  timezone_offset  INTEGER NOT NULL DEFAULT 0,"/* * offset en minutos respecto a UTC */
    "  ea_version       TEXT    DEFAULT '',"       /* * versión del EA/config */
    "  build            INTEGER NOT NULL DEFAULT 0"/* * build del terminal/tester */
    ");";
  if(!DatabaseExecute(Database_Instance, create_market_datasets_db)) return false;

  // Índices útiles (opcionales)
  if(!DatabaseExecute(Database_Instance,
     "CREATE INDEX IF NOT EXISTS idx_dataset_dates ON MarketDatasetsDB(date_start, date_end);")) return false;
  if(!DatabaseExecute(Database_Instance,
     "CREATE INDEX IF NOT EXISTS idx_dataset_symbol ON MarketDatasetsDB(symbol);")) return false;

  // Cabecera de señales
  string create_signal_params_db =
    "CREATE TABLE IF NOT EXISTS SignalParamsDB ("
    "  signal_id    INTEGER PRIMARY KEY AUTOINCREMENT,"
		"  dataset_id   TEXT     NOT NULL,"            /* FK -> MarketDatasetsDB */
    "  signal_type  INTEGER  NOT NULL DEFAULT 0,"   // enum SignalTypes
    "  signal_state INTEGER  NOT NULL DEFAULT 0,"   // enum SignalStates
    "  ticket_id    TEXT     DEFAULT '',"
    "  entry_price  REAL     NOT NULL DEFAULT 0,"
    "  close_price  REAL     NOT NULL DEFAULT 0,"
    "  stop_loss    REAL     NOT NULL DEFAULT 0,"
    "  take_profit  REAL     NOT NULL DEFAULT 0,"
    "  lot_size     REAL     NOT NULL DEFAULT 0,"
    "  raw_profit   REAL     NOT NULL DEFAULT 0,"
    "  entry_time   INTEGER  NOT NULL,"   					// UNIQUE abajo
		"  close_time   INTEGER  NOT NULL DEFAULT 0,"
		"  FOREIGN KEY(dataset_id) REFERENCES MarketDatasetsDB(dataset_id) ON DELETE CASCADE,"
		"  UNIQUE(entry_time, signal_type)"
		");";
  if(!DatabaseExecute(Database_Instance, create_signal_params_db)) return false;

	if(!DatabaseExecute(Database_Instance, "CREATE INDEX IF NOT EXISTS idx_sp_entry_time_type ON SignalParamsDB(entry_time, signal_type);")) return false;

  // ────────────────────────────────────────────────────────────────────
  // Bands por timeframe
  string create_bands_by_tf =
    "CREATE TABLE IF NOT EXISTS BandsPercentDB ("
    "  signal_id                           INTEGER NOT NULL,"
    "  timeframe                           INTEGER NOT NULL,"
    "  period                              INTEGER NOT NULL,"
    "  bands_percent_0                     REAL    DEFAULT 0,"
    "  bands_percent_1                     REAL    DEFAULT 0,"
    "  bands_percent_2                     REAL    DEFAULT 0,"
    "  bands_percent_3                     REAL    DEFAULT 0,"
    "  bands_percent_signal_0              REAL    DEFAULT 0,"
    "  bands_percent_signal_1              REAL    DEFAULT 0,"
    "  bands_percent_signal_2              REAL    DEFAULT 0,"
    "  bands_percent_signal_3              REAL    DEFAULT 0,"
    "  bands_percent_slope_0               INTEGER DEFAULT 0,"
    "  bands_percent_slope_1               INTEGER DEFAULT 0,"
    "  bands_percent_slope_2               INTEGER DEFAULT 0,"
    "  bands_percent_slope_3               INTEGER DEFAULT 0,"
    "  bands_percent_signal_slope_0        INTEGER DEFAULT 0,"
    "  bands_percent_signal_slope_1        INTEGER DEFAULT 0,"
    "  bands_percent_signal_slope_2        INTEGER DEFAULT 0,"
    "  bands_percent_signal_slope_3        INTEGER DEFAULT 0,"
    "  bands_percent_percentil_0           INTEGER DEFAULT 0,"
    "  bands_percent_percentil_1           INTEGER DEFAULT 0,"
    "  bands_percent_percentil_2           INTEGER DEFAULT 0,"
    "  bands_percent_percentil_3           INTEGER DEFAULT 0,"
    "  bands_percent_signal_percentil_0    INTEGER DEFAULT 0,"
    "  bands_percent_signal_percentil_1    INTEGER DEFAULT 0,"
    "  bands_percent_signal_percentil_2    INTEGER DEFAULT 0,"
    "  bands_percent_signal_percentil_3    INTEGER DEFAULT 0,"
    "  bands_percent_trend_0               INTEGER DEFAULT 0,"
    "  bands_percent_trend_1               INTEGER DEFAULT 0,"
    "  bands_percent_trend_2               INTEGER DEFAULT 0,"
    "  bands_percent_trend_3               INTEGER DEFAULT 0,"
    "  PRIMARY KEY (signal_id, timeframe, period),"
    "  FOREIGN KEY(signal_id) REFERENCES SignalParamsDB(signal_id) ON DELETE CASCADE"
    ");";
  if(!DatabaseExecute(Database_Instance, create_bands_by_tf)) return false;

  // Índices sugeridos para filtros frecuentes
  if(!DatabaseExecute(Database_Instance, "CREATE INDEX IF NOT EXISTS idx_bands_tf_p ON BandsPercentDB(timeframe, period);")) return false;

  // ────────────────────────────────────────────────────────────────────
  // Stochastic por timeframe
  string create_stoch_by_tf =
    "CREATE TABLE IF NOT EXISTS StochasticDB ("
    "  signal_id                        INTEGER NOT NULL,"
    "  timeframe                        INTEGER NOT NULL,"
    "  period                           INTEGER NOT NULL,"
    "  stochastic_0                     REAL    DEFAULT 0,"
    "  stochastic_1                     REAL    DEFAULT 0,"
    "  stochastic_2                     REAL    DEFAULT 0,"
    "  stochastic_3                     REAL    DEFAULT 0,"
    "  stochastic_signal_0              REAL    DEFAULT 0,"
    "  stochastic_signal_1              REAL    DEFAULT 0,"
    "  stochastic_signal_2              REAL    DEFAULT 0,"
    "  stochastic_signal_3              REAL    DEFAULT 0,"
    "  stochastic_slope_0               INTEGER DEFAULT 0,"
    "  stochastic_slope_1               INTEGER DEFAULT 0,"
    "  stochastic_slope_2               INTEGER DEFAULT 0,"
    "  stochastic_slope_3               INTEGER DEFAULT 0,"
    "  stochastic_signal_slope_0        INTEGER DEFAULT 0,"
    "  stochastic_signal_slope_1        INTEGER DEFAULT 0,"
    "  stochastic_signal_slope_2        INTEGER DEFAULT 0,"
    "  stochastic_signal_slope_3        INTEGER DEFAULT 0,"
    "  stochastic_percentil_0           INTEGER DEFAULT 0,"
    "  stochastic_percentil_1           INTEGER DEFAULT 0,"
    "  stochastic_percentil_2           INTEGER DEFAULT 0,"
    "  stochastic_percentil_3           INTEGER DEFAULT 0,"
    "  stochastic_signal_percentil_0    INTEGER DEFAULT 0,"
    "  stochastic_signal_percentil_1    INTEGER DEFAULT 0,"
    "  stochastic_signal_percentil_2    INTEGER DEFAULT 0,"
    "  stochastic_signal_percentil_3    INTEGER DEFAULT 0,"
    "  stochastic_trend_0               INTEGER DEFAULT 0,"
    "  stochastic_trend_1               INTEGER DEFAULT 0,"
    "  stochastic_trend_2               INTEGER DEFAULT 0,"
    "  stochastic_trend_3               INTEGER DEFAULT 0,"
    "  PRIMARY KEY (signal_id, timeframe, period),"
    "  FOREIGN KEY(signal_id) REFERENCES SignalParamsDB(signal_id) ON DELETE CASCADE"
    ");";
  if(!DatabaseExecute(Database_Instance, create_stoch_by_tf)) return false;

  if(!DatabaseExecute(Database_Instance, "CREATE INDEX IF NOT EXISTS idx_stoch_tf_p ON StochasticDB(timeframe, period);")) return false;

  // ────────────────────────────────────────────────────────────────────
  // Market Structure por timeframe
  string create_stoch_struct_by_tf =
    "CREATE TABLE IF NOT EXISTS StochasticMarketStructureDB ("
    "  signal_id                 INTEGER NOT NULL,"
    "  timeframe                 INTEGER NOT NULL,"
    "  period                    INTEGER NOT NULL,"
    "  first_structure_type      INTEGER DEFAULT 0,"
    "  second_structure_type     INTEGER DEFAULT 0,"
    "  third_structure_type      INTEGER DEFAULT 0,"
    "  fourth_structure_type     INTEGER DEFAULT 0,"
    "  fifth_structure_type      INTEGER DEFAULT 0,"
    "  six_structure_type        INTEGER DEFAULT 0,"
    "  first_structure_time      INTEGER DEFAULT 0,"
    "  first_structure_price     REAL    DEFAULT 0,"
    "  second_structure_time     INTEGER DEFAULT 0,"
    "  second_structure_price    REAL    DEFAULT 0,"
    "  third_structure_time      INTEGER DEFAULT 0,"
    "  third_structure_price     REAL    DEFAULT 0,"
    "  fourth_structure_time     INTEGER DEFAULT 0,"
    "  fourth_structure_price    REAL    DEFAULT 0,"
    "  first_fibonacci_level     REAL    DEFAULT 0,"
    "  second_fibonacci_level    REAL    DEFAULT 0,"
    "  third_fibonacci_level     REAL    DEFAULT 0,"
    "  fourth_fibonacci_level    REAL    DEFAULT 0,"
    "  PRIMARY KEY (signal_id, timeframe, period),"
    "  FOREIGN KEY(signal_id) REFERENCES SignalParamsDB(signal_id) ON DELETE CASCADE"
    ");";
  if(!DatabaseExecute(Database_Instance, create_stoch_struct_by_tf)) return false;

  if(!DatabaseExecute(Database_Instance, "CREATE INDEX IF NOT EXISTS idx_struct_tf_p ON StochasticMarketStructureDB(timeframe, period);")) return false;

  return true;
}

// Llama esto en OnInit()
bool InitStatsDatabase()
{
  // Si ya está lista y abierta, no hacemos nada
  if(Database_Initial_Setup && Database_Instance != INVALID_HANDLE)
    return true;

  // 1) Abrir/crear DB y aplicar PRAGMAs
  if(!OpenStatsDatabase())
  {
    Print("InitStatsDatabase: OpenStatsDatabase() failed.");
    return false;
  }

  // 2) Crear/verificar tablas e índices
  if(!CreateStatisticsTables())
  {
    Print("InitStatsDatabase: CreateStatisticsTables() failed.");
    // Limpieza defensiva
    if(Database_Instance != INVALID_HANDLE)
    {
      DatabaseClose(Database_Instance);
      Database_Instance = INVALID_HANDLE;
    }
    return false;
  }

  // 3) Marcar setup como listo
  Database_Initial_Setup = true;
  Print("InitStatsDatabase: database is ready.");

	if(Test_Mode) LogDbPath(Database_System_Name + "_db.sqlite", true);

	return true;
}

// Útil para OnDeinit()
void CloseStatsDatabase()
{
  if(Database_Instance != INVALID_HANDLE)
  {
    DatabaseClose(Database_Instance);
    Database_Instance = INVALID_HANDLE;
  }
  Database_Initial_Setup = false;
}
