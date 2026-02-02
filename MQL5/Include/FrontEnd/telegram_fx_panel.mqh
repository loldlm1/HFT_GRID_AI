//+------------------------------------------------------------------+
//| telegram_fx_panel.mqh                                            |
//| Orquestador: helpers mínimos + persistencia + motor + UI         |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

// ================== Inputs principales ==================
input int   SL_POINTS_INPUT_1 = 250;
input int   TP_POINTS_INPUT_1 = 250;
input int   SL_POINTS_INPUT_2 = 500;
input int   TP_POINTS_INPUT_2 = 500;
input int   SL_POINTS_INPUT_3 = 1000;
input int   TP_POINTS_INPUT_3 = 1000;

input double LOTS_DEFAULT = 0.10;

enum ERiskRewardMode { RR_TriggerSymmetric = 0, RR_VisualSymmetric = 1 };
input ERiskRewardMode rr_mode = RR_VisualSymmetric;

input double TP2_MULTIPLIER = 2.0;
input double TP3_MULTIPLIER = 3.0;

input int POINTS_PER_PIP = 10;
input int VIRTUAL_BE_TOL_POINTS = 20;
input int STATE_SAVE_MIN_MS = 300;

input long MAGIC_BASE = 98765000;

input bool   TELEGRAM_ENABLED = false;
input string TELEGRAM_BOT_TOKEN = "";
input string TELEGRAM_CHAT_ID   = "";
input string TELEGRAM_PARSE_MODE = "";

input string TPL_OPEN1_BUY  ="SIGNALS\\n🚨BUY {SYMBOL}\\nENTRY: {ENTRY}\\nSL: {SL}\\nTP1:{TP1}\\nTP2:{TP2}\\nTP3:{TP3}";
input string TPL_OPEN1_SELL ="SIGNALS\\n🚨SELL {SYMBOL}\\nENTRY: {ENTRY}\\nSL: {SL}\\nTP1:{TP1}\\nTP2:{TP2}\\nTP3:{TP3}";
input string TPL_OPEN2_BUY  ="..."; input string TPL_OPEN2_SELL ="...";
input string TPL_OPEN3_BUY  ="..."; input string TPL_OPEN3_SELL ="...";

input string TPL_TP1_HIT = "TP1 HIT ✅ + {PIPS} PIPS";
input string TPL_TP2_HIT = "TP2 HIT ✅ + {PIPS} PIPS";
input string TPL_TP3_HIT = "TP3 HIT ✅ + {PIPS} PIPS";
input string TPL_SL_HIT  = "SL HIT ❌ - {PIPS} PIPS";
input string TPL_BE_MOVE = "MOVER POSICIONES A BREAK-EVEN ✅ 💰";
input string TPL_BE_TOUCHED = "SEÑAL FINALIZADA MUCHACHOS ✅";

input string TPL_BE       = "COLOCAR TODAS LAS POSICIONES EN BE ✅";
input string TPL_CLOSEALL = "CERRAR TODAS LAS POSICIONES AHORA MISMO ‼";
input string TPL_ATTENTOS = "ATENTOS BUSCANDO ENTRADA 🎯";
input string TPL_RANGE_BASE = "CON RANGO DE {POINTS} PUNTOS⏳";

// Panel
input ENUM_BASE_CORNER panel_corner = CORNER_RIGHT_UPPER;
enum EPanelStyle { PanelNone = 0, PanelFrame = 1, PanelSolid = 2 };
input EPanelStyle panel_style = PanelNone;
enum EThemeMode { ThemeAuto = 0, ThemeLight = 1, ThemeDark = 2 };
input EThemeMode theme_mode = ThemeAuto;

// ================== Estado global mínimo ==================
CTrade trade;
int    current_trend=0;
double lot_size_value=0.0, percent_size_value=1.00;
bool   percent_mode_enabled=false;
int    open_split_count=1;
bool   be_at_tp1=false, be_at_tp2=false, be_at_tp3=false;
bool   full_tp_call_enabled=true;     // ON por defecto
bool   manual_mode_enabled=true;      // NUEVO: ON por defecto

long   chart_id=0; bool gui_initialized=false;

enum EActiveInput { ActiveNone = 0, ActiveLots = 1, ActivePct = 2 };
EActiveInput active_input=ActiveNone;
string lots_buffer=""; int lots_caret=0;
string pct_buffer="";  int pct_caret=0;
bool   caret_visible=false; ulong caret_last_toggle_us=0;
bool   skip_next_chart_click=false;

struct SignalInfo{
  int id, side, sl_points, tp_points;
  double anchor, sl, tp1, tp2, tp3;
  ulong magic_leg[3]; ulong pos_id_leg[3]; bool leg_open[3]; bool tp_hit_sent[3];
  bool  sl_hit_sent, full_tp_call, virtual_active, virtual_tp2_sent, virtual_tp3_sent;
  double entry, virtual_be_level; datetime created_at;
  int split_count; // 1/2/3

  SignalInfo(){ id=0; side=0; sl_points=tp_points=0; anchor=sl=tp1=tp2=tp3=0.0;
    for(int i=0;i<3;i++){ magic_leg[i]=0; pos_id_leg[i]=0; leg_open[i]=false; tp_hit_sent[i]=false; }
    sl_hit_sent=false; full_tp_call=true; virtual_active=true; virtual_tp2_sent=false; virtual_tp3_sent=false;
    entry=0.0; virtual_be_level=0.0; created_at=0; split_count=1;
  }
};
SignalInfo signals[]; int next_signal_id=0;
ulong processed_deals[];

// ================== Helpers compartidos ==================
color ColorFromHex(uint h){ uint r=(h>>16)&0xFF, g=(h>>8)&0xFF, b=h&0xFF; return (color)(r+(g<<8)+(b<<16)); }
void  PrintDebug(string msg){ Print("[TFXEA] ",msg); }
int    DigitsForVolumeStep(double step){ if(step<=0) return 2; int d=0; while(step<1.0&&d<8){ step*=10.0; d++; } return d; }
double NormalizeLot(double lot_raw){ double vmin,vstep,vmax; SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,vmin); SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,vstep); SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,vmax);
  if(lot_raw<vmin) lot_raw=vmin; if(lot_raw>vmax) lot_raw=vmax; int digits=DigitsForVolumeStep(vstep);
  double steps=MathRound((lot_raw - vmin)/vstep); double n=vmin + steps*(vstep>0?vstep:0.01); return NormalizeDouble(n,digits); }
double Clamp(double v,double lo,double hi){ if(v<lo) return lo; if(v>hi) return hi; return v; }
int    SafeDistancePoints(int req){ int s=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); int f=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL); int minr=s+f+1; return (req<minr?minr:req); }
double PointsToPriceDistance(int pts){ return pts*_Point; }
string ReplaceAll(string s,const string a,const string b){ int pos=0; int al=StringLen(a); if(al==0) return s; while((pos=StringFind(s,a,pos))!=-1){ s=StringSubstr(s,0,pos)+b+StringSubstr(s,pos+al); pos+=StringLen(b);} return s; }
string ExpandEscapes(string s){ s=ReplaceAll(s,"\\n","\n"); s=ReplaceAll(s,"\\t","\t"); return s; }

string SigObjName(const int sid,const string tag){ return "tfxea_sig_"+IntegerToString(sid)+"_"+tag; }

// No pisar precio al existir (evita rebotes al arrastrar)
bool EnsureHLineSoft(const string name, const double price, color clr, int style=STYLE_DASH, int width=1, int z=1){
  if(ObjectFind(0,name)<0){
    if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price)) return false;
    ObjectSetDouble(0,name,OBJPROP_PRICE,price);
  }
  ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
  ObjectSetInteger(0,name,OBJPROP_STYLE,style);
  ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
  ObjectSetInteger(0,name,OBJPROP_BACK,true);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
  ObjectSetInteger(0,name,OBJPROP_ZORDER,z);
  return true;
}

bool EnsureHLine(const string name, const double price, color clr, int style=STYLE_DASH, int width=1, int z=1){
  if(ObjectFind(0,name)<0){ if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price)) return false; }
  ObjectSetDouble(0,name,OBJPROP_PRICE,price);
  ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
  ObjectSetInteger(0,name,OBJPROP_STYLE,style);
  ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
  ObjectSetInteger(0,name,OBJPROP_BACK,true);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
  ObjectSetInteger(0,name,OBJPROP_ZORDER,z);
  return true;
}
void DeleteSigLine(const int sid, const string tag){ string n=SigObjName(sid,tag); if(ObjectFind(0,n)>=0) ObjectDelete(0,n); }

// Mejora: al mover BE, nómbralo como "BE" (no "VSL") para el usuario
void MoveSigVirtualSLToBE(const SignalInfo &sig){
  string n=SigObjName(sig.id,"VSL");
  if(ObjectFind(0,n)<0){
    EnsureHLine(n, sig.virtual_be_level, ColorFromHex(0xDC2626), STYLE_DASHDOT, 1, 1);
  } else {
    ObjectSetDouble(0,n,OBJPROP_PRICE,sig.virtual_be_level);
  }
  ObjectSetString(0,n,OBJPROP_TEXT,"BE");
  ChartRedraw();
}

// Mantén DeleteAllSignalLines como está (incluye SL y TPn)
void DeleteAllSignalLines(const int sid){ string t[]={"SL","VSL","TP1","TP2","TP3"}; for(int i=0;i<ArraySize(t);i++) DeleteSigLine(sid,t[i]); }
double PriceForRRMode(int side){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); return (rr_mode==RR_TriggerSymmetric? (side==1?bid:ask) : (side==1?ask:bid)); }

// Magic por símbolo
long SymbolHash32(const string sym){
  ulong h=2166136261;
  for(int i=0;i<StringLen(sym);i++){ uchar c=(uchar)StringGetCharacter(sym,i); h ^= c; h *= 16777619; }
  return (long)(h & 0x7FFFFFFF);
}
ulong EncodeMagic(int signal_id,int leg){
  long sym_part = SymbolHash32(_Symbol) % 100000;
  ulong base = (ulong)(sym_part)*1000000ULL;
  return base + (ulong)(signal_id*10 + leg);
}
void  RemoveSignalByIndex(int idx){ if(idx<0||idx>=ArraySize(signals)) return; for(int i=idx;i<ArraySize(signals)-1;i++) signals[i]=signals[i+1]; ArrayResize(signals,ArraySize(signals)-1); }

// Volumen / Telegram (como ya lo tenías)
double ComputeLotsFromPercentBySL(double pct, int sl_points){ /* igual a tu versión previa */ double balance=AccountInfoDouble(ACCOUNT_BALANCE);
  double risk_money = balance * (Clamp(pct,0.01,100.0)/100.0);
  double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  double tvp=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
  double tv=(tvp>0.0?tvp:SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
  if(tick_size>0.0 && tv>0.0){ double money_per_point=tv*(_Point/tick_size); double risk_per_lot=sl_points*money_per_point; if(risk_per_lot>0.0) return NormalizeLot(risk_money/risk_per_lot); }
  double contract=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); if(contract<=0.0) contract=100000.0;
  double price=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(price<=0) price=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(price<=0) price=1.0;
  double risk_per_lot_fb = sl_points * ((contract*_Point)/price);
  if(risk_per_lot_fb<=0.0){ double vmin; SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,vmin); return vmin; }
  return NormalizeLot(risk_money / risk_per_lot_fb);
}
double GetTotalLotsToUse(int sl_points){ if(percent_mode_enabled) return ComputeLotsFromPercentBySL(percent_size_value,sl_points); return NormalizeLot(lot_size_value); }

// Telegram helpers (igual)
string UrlEncodeUtf8(const string text){ uchar b[]; StringToCharArray(text,b,0,WHOLE_ARRAY,CP_UTF8); string o=""; for(int i=0;i<ArraySize(b);i++){ uchar c=b[i]; bool u=((c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'||c=='~'); if(u) o+=(string)StringFormat("%c",(int)c); else if(c==' ') o+="%20"; else o+="%"+StringFormat("%02X",(int)c);} return o; }
bool TelegramSendMessage(const string text_raw){
  if(!TELEGRAM_ENABLED) return false; if(TELEGRAM_BOT_TOKEN==""||TELEGRAM_CHAT_ID=="") return false;
  string url="https://api.telegram.org/bot"+TELEGRAM_BOT_TOKEN+"/sendMessage"; string headers="Content-Type: application/x-www-form-urlencoded\r\n";
  string body="chat_id="+TELEGRAM_CHAT_ID+"&text="+UrlEncodeUtf8(ExpandEscapes(text_raw))+"&disable_web_page_preview=true";
  if(TELEGRAM_PARSE_MODE!="") body+="&parse_mode="+TELEGRAM_PARSE_MODE;
  uchar send[]; StringToCharArray(body,send,0,WHOLE_ARRAY,CP_UTF8);
  uchar result[]; string result_headers; int code=WebRequest("POST",url,headers,5000,send,result,result_headers);
  return (code==200);
}
string BuildOpenTemplate(int b,int side){ if(b==1) return (side==1?TPL_OPEN1_BUY:TPL_OPEN1_SELL); if(b==2) return (side==1?TPL_OPEN2_BUY:TPL_OPEN2_SELL); return (side==1?TPL_OPEN3_BUY:TPL_OPEN3_SELL); }
bool SendTelegramOpen(int b,int side,double lots,int slp,int tpp,double entry,double sl,double tp1,double tp2,double tp3){
  string tpl=BuildOpenTemplate(b,side); string msg=tpl; int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
  msg=ReplaceAll(msg,"{SYMBOL}",_Symbol); msg=ReplaceAll(msg,"{SIDE}",(side==1?"BUY":"SELL"));
  msg=ReplaceAll(msg,"{LOTS}",DoubleToString(lots,2)); msg=ReplaceAll(msg,"{SL_POINTS}",IntegerToString(slp)); msg=ReplaceAll(msg,"{TP_POINTS}",IntegerToString(tpp));
  msg=ReplaceAll(msg,"{ENTRY}",DoubleToString(entry,d)); msg=ReplaceAll(msg,"{SL}",DoubleToString(sl,d));
  msg=ReplaceAll(msg,"{TP1}",DoubleToString(tp1,d)); msg=ReplaceAll(msg,"{TP2}",DoubleToString(tp2,d)); msg=ReplaceAll(msg,"{TP3}",DoubleToString(tp3,d));
  return TelegramSendMessage(msg);
}
bool SendTplPips(const string tpl,int points){ int pips=(POINTS_PER_PIP>0?(int)MathRound((double)points/(double)POINTS_PER_PIP):points); return TelegramSendMessage(ReplaceAll(tpl,"{PIPS}",IntegerToString(pips))); }

// Limpieza masiva de líneas
bool IsSignalLineObj(const string &name){ return StringFind(name,"tfxea_sig_")==0; }
void PurgeAllSignalLinesByScan(){ int total=(int)ObjectsTotal(0,0,-1); for(int i=total-1;i>=0;i--){ string nm=ObjectName(0,i); if(IsSignalLineObj(nm)) ObjectDelete(0,nm); } }

// Estado de persistencia reactiva
bool  g_state_dirty=false;
ulong g_state_last_save_us=0;

void TFXEA_MarkStateDirty(){ g_state_dirty=true; }

void TFXEA_FlushStateIfNeeded(){
  if(!g_state_dirty) return;
  ulong now=GetMicrosecondCount();
  if(g_state_last_save_us==0 || (now - g_state_last_save_us) >= (ulong)STATE_SAVE_MIN_MS*1000ULL){
    TFXEA_SaveStateToFile();
    g_state_dirty=false;
    g_state_last_save_us=now;
  }
}

// Persistencia + Motor + UI
#include "tfxea_state.mqh"
#include "tfxea_engine.mqh"
#include "tfxea_panel_ui.mqh"

// Hooks para UI
void Orchestrator_SendAttentos(){
  TelegramSendMessage(ExpandEscapes(TPL_ATTENTOS));
  PrintDebug("ATENTOS enviado.");
}
void Orchestrator_SendRangeMessage(int idx){
  int pts=0;
  if(idx==1) pts = SafeDistancePoints(SL_POINTS_INPUT_1);
  else if(idx==2) pts = SafeDistancePoints(SL_POINTS_INPUT_2);
  else if(idx==3) pts = SafeDistancePoints(SL_POINTS_INPUT_3);
  if(pts<=0){ PrintDebug("Rango sin puntos válido idx="+IntegerToString(idx)); return; }

  string msg = ReplaceAll(TPL_RANGE_BASE,"{POINTS}", IntegerToString(pts));
	msg += " — " + _Symbol;
  TelegramSendMessage(ExpandEscapes(msg));
  PrintDebug("Mensaje de rango enviado: "+msg);
}

void Orchestrator_OpenPreset(int presetIndex){
  if(current_trend==0){ PrintDebug("Seleccione BUY o SELL"); return; }
  if(presetIndex==1) Engine_OpenSignal(current_trend, open_split_count, SL_POINTS_INPUT_1, TP_POINTS_INPUT_1, 1);
  else if(presetIndex==2) Engine_OpenSignal(current_trend, open_split_count, SL_POINTS_INPUT_2, TP_POINTS_INPUT_2, 2);
  else if(presetIndex==3) Engine_OpenSignal(current_trend, open_split_count, SL_POINTS_INPUT_3, TP_POINTS_INPUT_3, 3);
}
void Orchestrator_ApplyBE(){
  // En MANUAL: solo mensaje, no mover stops ni dibujar BE
  if(manual_mode_enabled){
    TelegramSendMessage(ExpandEscapes(TPL_BE));
    PrintDebug("BE (manual): solo mensaje");
    return;
  }

  int total=PositionsTotal();
  int stop_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
  double min_diff=stop_level*_Point;
  for(int i=0;i<total;i++){
    ulong ticket=PositionGetTicket(i);
    if(!PositionSelectByTicket(ticket)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    long type=PositionGetInteger(POSITION_TYPE);
    double po=PositionGetDouble(POSITION_PRICE_OPEN);
    double tp=PositionGetDouble(POSITION_TP);
    double new_sl=po;
    if(type==POSITION_TYPE_BUY){ if((po-new_sl)<min_diff) new_sl=po-min_diff; trade.PositionModify(ticket,new_sl,tp); }
    else if(type==POSITION_TYPE_SELL){ if((new_sl-po)<min_diff) new_sl=po+min_diff; trade.PositionModify(ticket,new_sl,tp); }
  }
  TelegramSendMessage(ExpandEscapes(TPL_BE));
  PrintDebug("Break-even aplicado (modo normal).");
}
void Orchestrator_CloseAll(){
  int total=PositionsTotal();
  for(int i=total-1;i>=0;i--){
    ulong ticket=PositionGetTicket(i);
    if(!PositionSelectByTicket(ticket)) continue;
    if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
    if(!trade.PositionClose(ticket)) PrintDebug("Error cerrando ticket "+IntegerToString(ticket));
  }
  for(int s=0;s<ArraySize(signals);s++) DeleteAllSignalLines(signals[s].id);
  ArrayResize(signals,0);
  TelegramSendMessage(ExpandEscapes(TPL_CLOSEALL));
  PrintDebug("Cierre + limpieza ejecutado.");
}

// Ciclo de vida (estas funciones las llamas desde tu EA .mq5)
bool InitGui(){
  chart_id=ChartID();
  lot_size_value=NormalizeLot(LOTS_DEFAULT);
  lots_buffer=DoubleToString(lot_size_value,2); lots_caret=StringLen(lots_buffer);
  pct_buffer =DoubleToString(percent_size_value,2); pct_caret =StringLen(pct_buffer);
  active_input=ActiveNone; caret_visible=true; caret_last_toggle_us=GetMicrosecondCount();
  ArrayResize(signals,0); ArrayResize(processed_deals,0);

  PurgeAllSignalLinesByScan();
  TFXEA_LoadStateFromFile();
  PrintDebug("InitGui: signals loaded = "+IntegerToString(ArraySize(signals)));

  Engine_RebuildAllLines(); // re-dibuja de inmediato
  UI_Init();

  gui_initialized=true;
  return true;
}

void DestroyGui(){
  // Guardado explícito al salir
  TFXEA_SaveStateToFile();
  g_state_dirty=false; g_state_last_save_us=GetMicrosecondCount();

  PurgeAllSignalLinesByScan();
  UI_Destroy();
  gui_initialized=false;
}

void UpdateGuiOnTick(){ UI_UpdateOnTick(); }

// Llama el motor y “flush” del estado sucio
void Orchestrator_OnTick(){
  Engine_OnTick();
  TFXEA_FlushStateIfNeeded();
}

void HandleChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam){ if(!gui_initialized) return; UI_HandleChartEvent(id,lparam,dparam,sparam); }
void HandleTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &r,const MqlTradeResult &res){ /* opcional */ }

// Delegación de eventos para tu EA (.mq5):
// int OnInit(){ InitGui(); return(INIT_SUCCEEDED); }
// void OnDeinit(const int reason){ DestroyGui(); }
// void OnTick(){ UpdateGuiOnTick(); Orchestrator_OnTick(); }
// void OnChartEvent(const int id,const long &l,const double &d,const string &s){ HandleChartEvent(id,l,d,s); }
// void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &r,const MqlTradeResult &res){ HandleTradeTransaction(t,r,res); }
