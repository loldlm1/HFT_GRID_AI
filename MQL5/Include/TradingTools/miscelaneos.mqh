
//+------------------------------------------------------------------+
//|                                              miscelaneos.mqh     |
//+------------------------------------------------------------------+

// ALL FIBONACCI LEVELS FROM 0.0 TO 2000.0

double AllFibonacciLevels[101] = {
  0.0, 23.6, 38.2, 61.8, 78.6, 100.0,
  123.6, 138.2, 161.8, 178.6, 200.0,
  223.6, 238.2, 261.8, 278.6, 300.0,
  323.6, 338.2, 361.8, 378.6, 400.0,
  423.6, 438.2, 461.8, 478.6, 500.0,
  523.6, 538.2, 561.8, 578.6, 600.0,
  623.6, 638.2, 661.8, 678.6, 700.0,
  723.6, 738.2, 761.8, 778.6, 800.0,
  823.6, 838.2, 861.8, 878.6, 900.0,
  923.6, 938.2, 961.8, 978.6, 1000.0,
  1023.6, 1038.2, 1061.8, 1078.6, 1100.0,
  1123.6, 1138.2, 1161.8, 1178.6, 1200.0,
  1223.6, 1238.2, 1261.8, 1278.6, 1300.0,
  1323.6, 1338.2, 1361.8, 1378.6, 1400.0,
  1423.6, 1438.2, 1461.8, 1478.6, 1500.0,
  1523.6, 1538.2, 1561.8, 1578.6, 1600.0,
  1623.6, 1638.2, 1661.8, 1678.6, 1700.0,
  1723.6, 1738.2, 1761.8, 1778.6, 1800.0,
  1823.6, 1838.2, 1861.8, 1878.6, 1900.0,
  1923.6, 1938.2, 1961.8, 1978.6, 2000.0
};

// Escribe un texto en un archivo (sobrescribe si ya existía).
void WriteToFile(string filename, string text)
{
  int fileHandle = FileOpen(filename, FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_ANSI);
  if(fileHandle != INVALID_HANDLE)
  {
    FileWrite(fileHandle, text);
    FileClose(fileHandle);
    Print("Archivo guardado: ", filename);
  }
  else
  {
    Print("Error al abrir archivo: ", GetLastError());
  }
}

// Devuelve la ruta absoluta donde está (o estaría) la BD.
// - db_filename: p.ej. Database_System_Name + "_db.sqlite"
// - use_common: true si abriste con DATABASE_OPEN_COMMON
string ResolveDbPath(const string db_filename, const bool use_common)
{
  const string base_dir = TerminalInfoString(use_common ? TERMINAL_COMMONDATA_PATH
                                                        : TERMINAL_DATA_PATH);
  // Candidatos (orden de preferencia)
  string candidates[4];
  int n = 0;

  if(use_common)
  {
    candidates[n++] = base_dir + "\\Files\\" + db_filename;
    candidates[n++] = base_dir + "\\Bases\\" + db_filename;
  }
  else
  {
    candidates[n++] = base_dir + "\\MQL5\\Files\\" + db_filename;
    candidates[n++] = base_dir + "\\MQL5\\Bases\\" + db_filename;
  }

  // Si existe en alguno de los candidatos, lo devolvemos
  for(int i = 0; i < n; ++i)
    if(FileIsExist(candidates[i]))
      return candidates[i];

  // Si aún no existe el archivo, devolvemos la ruta "esperada" principal
  return candidates[0];
}

// Helper para imprimir también los archivos WAL/SHM de SQLite
void LogDbPath(const string db_filename, const bool use_common)
{
  const string full_path = ResolveDbPath(db_filename, use_common);
  Print("DB file: ", full_path);
  Print("DB -wal: ", full_path, "-wal");
  Print("DB -shm: ", full_path, "-shm");

  // Además, por si quieres ver las carpetas base:
  Print("Data folder:   ", TerminalInfoString(TERMINAL_DATA_PATH));
  Print("Common folder: ", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
}

// =====================================================
// Defaults simples (ajusta si tus structs usan otros)
// =====================================================
#define DEF_REAL            0.0
#define DEF_EPOCH           0        // datetime 0
#define DEF_PERCENTILE      0        // 0..100
// Ejemplo: enum por defecto (ajusta según tus enums reales)
#define DEF_OSC_STRUCT_TYPE (int)OSCILLATOR_STRUCTURE_EQ

// =====================================================
// Validaciones básicas
// =====================================================
bool IsFiniteNumber(const double v) { return MathIsValidNumber(v); }

// =====================================================
// Formateadores con fallback a DEFAULT (strings SQL)
// =====================================================

// Real genérico (p.ej. profit). Inválido → "0.0"
string SqlRealValue(const double v, const int digits)
{
  return IsFiniteNumber(v) ? DoubleToString(v, digits)
                           : DoubleToString(DEF_REAL, digits);
}

// Precio seguro para SQL: NaN/INF/negativo/fuera de rango → "0.0"
string SqlPriceValue(const double price)
{
  if(!IsFiniteNumber(price)) return DoubleToString(DEF_REAL, _Digits);

  // Normaliza a la precisión del símbolo
  double p = NormalizeDouble(price, _Digits);

  // Revalida tras normalizar y aplica umbral genérico
  if(!IsFiniteNumber(p)) return DoubleToString(DEF_REAL, _Digits);
  if(p <= 0.0)           return DoubleToString(DEF_REAL, _Digits);
  if(MathAbs(p) > 1.0e7) return DoubleToString(DEF_REAL, _Digits); // evita 1e10 & co.

  return DoubleToString(p, _Digits);
}

// Epoch (datetime). Negativos o absurdos → "0"
string SqlEpochValue(const long t)
{
  return (t >= 0) ? IntegerToString(t)
                  : IntegerToString(DEF_EPOCH);
}

// Fibonacci (esperado 0..5000). Fuera de rango/NaN → "0.00"
string SqlFiboValue(const double level)
{
  if(!IsFiniteNumber(level)) return DoubleToString(DEF_REAL, 2);
  if(level < 0.0 || level > 5000.0) return DoubleToString(DEF_REAL, 2);
  return DoubleToString(level, 2);
}

// Percentil (-100..200). Fuera de rango/NaN → "0"
string SqlPercentileValue(const int p)
{
  if(p < -100 || p > 200) return IntegerToString(DEF_PERCENTILE);
  return IntegerToString(p);
}

// Enum genérico: fuera de rango → enum_default
string SqlEnumValue(const int v, const int enum_min, const int enum_max, const int enum_default)
{
  const int out = (v < enum_min || v > enum_max) ? enum_default : v;
  return IntegerToString(out);
}
