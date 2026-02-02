//+------------------------------------------------------------------+
//| tfxea_state.mqh                                                  |
//| Persistencia de ajustes del panel y señales (guardar/cargar)     |
//+------------------------------------------------------------------+
#property strict

string TFXEA_StateFileName(){ return "tfxea_state_" + _Symbol + ".txt"; }

string TFXEA_Join3Ulong(ulong a, ulong b, ulong c){ return IntegerToString((long)a)+","+IntegerToString((long)b)+","+IntegerToString((long)c); }
string TFXEA_Join3Bool (bool a, bool b, bool c){ return (a?"1":"0")+","+(b?"1":"0")+","+(c?"1":"0"); }

bool TFXEA_Split3Ulong(const string s, ulong &a, ulong &b, ulong &c){
  string parts[]; int n=StringSplit(s, ',', parts);
  if(n!=3) return false;
  a=(ulong)StringToInteger(parts[0]); b=(ulong)StringToInteger(parts[1]); c=(ulong)StringToInteger(parts[2]);
  return true;
}
bool TFXEA_Split3Bool(const string s, bool &a, bool &b, bool &c){
  string parts[]; int n=StringSplit(s, ',', parts);
  if(n!=3) return false;
  a=(StringToInteger(parts[0])!=0); b=(StringToInteger(parts[1])!=0); c=(StringToInteger(parts[2])!=0);
  return true;
}

#define TFXEA_STATE_VERSION   "v2"
#define TFXEA_FIELDS_PER_ROW  22

void TFXEA_SaveStateToFile(){
  int h = FileOpen(TFXEA_StateFileName(), FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_ANSI);
  if(h==INVALID_HANDLE){ Print("[TFXEA] Persistencia: no se pudo abrir archivo para guardar"); return; }

  FileWriteString(h, TFXEA_STATE_VERSION"|"+_Symbol+"\n");

  // Añadimos manual_mode_enabled como 9no campo
  string ui = StringFormat("%s|%s|%d|%d|%d|%d|%d|%d|%d",
    DoubleToString(lot_size_value,8),
    DoubleToString(percent_size_value,8),
    (int)percent_mode_enabled,
    open_split_count,
    (int)be_at_tp1, (int)be_at_tp2, (int)be_at_tp3,
    (int)full_tp_call_enabled,
    (int)manual_mode_enabled
  );
  FileWriteString(h, ui+"\n");

  FileWriteString(h, IntegerToString(ArraySize(signals))+"|"+IntegerToString(next_signal_id)+"\n");

  for(int i=0;i<ArraySize(signals);i++){
    SignalInfo s = signals[i];
    string line = StringFormat("%d|%d|%d|%d|%.10f|%.10f|%.10f|%.10f|%.10f|%d",
      s.id, s.side, s.sl_points, s.tp_points, s.anchor, s.sl, s.tp1, s.tp2, s.tp3, s.split_count);
    line += "|"+TFXEA_Join3Ulong(s.magic_leg[0], s.magic_leg[1], s.magic_leg[2]);
    line += "|"+TFXEA_Join3Ulong(s.pos_id_leg[0], s.pos_id_leg[1], s.pos_id_leg[2]);
    line += "|"+TFXEA_Join3Bool(s.leg_open[0], s.leg_open[1], s.leg_open[2]);
    line += "|"+TFXEA_Join3Bool(s.tp_hit_sent[0], s.tp_hit_sent[1], s.tp_hit_sent[2]);
    line += "|"+IntegerToString((int)s.sl_hit_sent);
    line += "|"+IntegerToString((int)s.full_tp_call);
    line += "|"+IntegerToString((int)s.virtual_active);
    line += "|"+IntegerToString((int)s.virtual_tp2_sent);
    line += "|"+IntegerToString((int)s.virtual_tp3_sent);
    line += "|"+DoubleToString(s.entry, 10);
    line += "|"+DoubleToString(s.virtual_be_level, 10);
    line += "|"+IntegerToString((long)s.created_at);
    FileWriteString(h, line+"\n");
  }

  FileClose(h);
  Print("[TFXEA] Estado guardado. signals=", IntegerToString(ArraySize(signals)));
}

void TFXEA_LoadStateFromFile(){
  int h = FileOpen(TFXEA_StateFileName(), FILE_COMMON|FILE_READ|FILE_TXT|FILE_ANSI);
  if(h==INVALID_HANDLE) { Print("[TFXEA] Persistencia: no hay estado previo (ok)"); return; }

  string l1 = FileReadString(h);
  string p1[]; int n1 = StringSplit(l1, '|', p1);
  if(n1<2){ FileClose(h); Print("[TFXEA] Estado corrupto (header)"); return; }
  if(p1[0]!=TFXEA_STATE_VERSION){ FileClose(h); Print("[TFXEA] Versión incompatible: ", p1[0]); return; }
  if(p1[1]!=_Symbol){ FileClose(h); Print("[TFXEA] Estado de otro símbolo, ignorado."); return; }

  string l2 = FileReadString(h);
  string u[]; int nu=StringSplit(l2,'|',u);
  if(nu>=8){
    lot_size_value       = StringToDouble(u[0]);
    percent_size_value   = Clamp(StringToDouble(u[1]),0.01,100.0);
    percent_mode_enabled = (StringToInteger(u[2])!=0);
    open_split_count     = (int)StringToInteger(u[3]);
    be_at_tp1            = (StringToInteger(u[4])!=0);
    be_at_tp2            = (StringToInteger(u[5])!=0);
    be_at_tp3            = (StringToInteger(u[6])!=0);
    full_tp_call_enabled = (StringToInteger(u[7])!=0);
    if(nu>=9)
      manual_mode_enabled = (StringToInteger(u[8])!=0);
    else
      manual_mode_enabled = true; // por defecto ON si falta el campo
  }

  string l3 = FileReadString(h);
  string c[]; int nc=StringSplit(l3,'|',c);
  int cnt =(nc>=1? (int)StringToInteger(c[0]):0);
  next_signal_id = (nc>=2? (int)StringToInteger(c[1]):0);

  ArrayResize(signals, 0);
  for(int i=0;i<cnt && !FileIsEnding(h);i++){
    string line = FileReadString(h);
    string f[]; int nf=StringSplit(line,'|',f);
    if(nf < TFXEA_FIELDS_PER_ROW){
      Print("[TFXEA] Registro incompleto: nf=", IntegerToString(nf), " esperado=", IntegerToString(TFXEA_FIELDS_PER_ROW), " line=", line);
      continue;
    }

    SignalInfo s; int idx=0;
    s.id          =(int)StringToInteger(f[idx++]);
    s.side        =(int)StringToInteger(f[idx++]);
    s.sl_points   =(int)StringToInteger(f[idx++]);
    s.tp_points   =(int)StringToInteger(f[idx++]);
    s.anchor      =StringToDouble(f[idx++]);
    s.sl          =StringToDouble(f[idx++]);
    s.tp1         =StringToDouble(f[idx++]);
    s.tp2         =StringToDouble(f[idx++]);
    s.tp3         =StringToDouble(f[idx++]);
    s.split_count =(int)StringToInteger(f[idx++]);

    ulong m0,m1,m2; TFXEA_Split3Ulong(f[idx++], m0,m1,m2);
    s.magic_leg[0]=m0; s.magic_leg[1]=m1; s.magic_leg[2]=m2;

    ulong p0,p1u,p2; TFXEA_Split3Ulong(f[idx++], p0,p1u,p2);
    s.pos_id_leg[0]=p0; s.pos_id_leg[1]=p1u; s.pos_id_leg[2]=p2;

    bool lo0,lo1,lo2; TFXEA_Split3Bool(f[idx++], lo0,lo1,lo2);
    s.leg_open[0]=lo0; s.leg_open[1]=lo1; s.leg_open[2]=lo2;

    bool th0,th1,th2; TFXEA_Split3Bool(f[idx++], th0,th1,th2);
    s.tp_hit_sent[0]=th0; s.tp_hit_sent[1]=th1; s.tp_hit_sent[2]=th2;

    s.sl_hit_sent     =(StringToInteger(f[idx++])!=0);
    s.full_tp_call    =(StringToInteger(f[idx++])!=0);
    s.virtual_active  =(StringToInteger(f[idx++])!=0);
    s.virtual_tp2_sent=(StringToInteger(f[idx++])!=0);
    s.virtual_tp3_sent=(StringToInteger(f[idx++])!=0);
    s.entry           =StringToDouble(f[idx++]);
    s.virtual_be_level=StringToDouble(f[idx++]);
    s.created_at      =(datetime)(long)StringToInteger(f[idx++]);

    int sz=ArraySize(signals); ArrayResize(signals, sz+1); signals[sz]=s;
  }
  FileClose(h);
  Print("[TFXEA] Estado cargado en memoria. signals=", IntegerToString(ArraySize(signals)));
}
