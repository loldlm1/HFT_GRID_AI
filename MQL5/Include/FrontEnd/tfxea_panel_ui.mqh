//+------------------------------------------------------------------+
//| tfxea_panel_ui.mqh                                               |
//| UI completa: layout, inputs, botones y eventos                   |
//+------------------------------------------------------------------+
#property strict

// Paleta / layout / tipografía
int    panel_padding_x=12, panel_padding_y=14;
int    button_width=128, button_height=26, button_gap_x=10, button_gap_y=10;
string ui_font_family="Segoe UI";
int    ui_font_size_title=13, ui_font_size_btn=12, ui_font_size_label=12, ui_font_size_edit=12;

// Tailwind palette (subset)
color tw_slate_950 = ColorFromHex(0x020617);
color tw_slate_900 = ColorFromHex(0x0F172A);
color tw_slate_800 = ColorFromHex(0x1F2937);
color tw_slate_700 = ColorFromHex(0x334155);
color tw_slate_600 = ColorFromHex(0x475569);
color tw_slate_500 = ColorFromHex(0x64748B);
color tw_slate_400 = ColorFromHex(0x94A3B8);
color tw_slate_300 = ColorFromHex(0xCBD5E1);
color tw_slate_200 = ColorFromHex(0xE2E8F0);
color tw_slate_100 = ColorFromHex(0xF1F5F9);
color tw_slate_50  = ColorFromHex(0xF8FAFC);

color tw_emerald_500=ColorFromHex(0x10B981);
color tw_rose_500   =ColorFromHex(0xF43F5E);
color tw_sky_500    =ColorFromHex(0x0EA5E9);
color tw_red_600    =ColorFromHex(0xDC2626);
color tw_emerald_400 = ColorFromHex(0x34D399);
color tw_rose_400    = ColorFromHex(0xFB7185);

color clr_panel_bg, clr_panel_border, clr_text, clr_label, clr_inactive, clr_buy, clr_sell, clr_be, clr_close, clr_edit_bg, clr_edit_txt, clr_input_border, clr_input_border_active;

// Luma rápida
double UI_LumaFromColor(color c){ int r=(c&0xFF), g=(c>>8)&0xFF, b=(c>>16)&0xFF; return 0.2126*r+0.7152*g+0.0722*b; }

// Tema adaptado a Tailwind y a tu OnInit de colores de chart
void UI_SetupTheme(){
  bool use_light;
  if(theme_mode==ThemeLight) use_light=true;
  else if(theme_mode==ThemeDark) use_light=false;
  else { color bg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND); use_light=(UI_LumaFromColor(bg)>170.0); }

  if(use_light){
    // Fondo claro, texto oscuro
    clr_panel_bg     = tw_slate_100;
    clr_panel_border = tw_slate_300;
    clr_text         = tw_slate_800;
    clr_label        = tw_slate_800;
    clr_inactive     = tw_slate_500;
    clr_buy          = tw_emerald_500;
    clr_sell         = tw_rose_500;
    clr_be           = tw_sky_500;
    clr_close        = tw_red_600;
    clr_edit_bg      = tw_slate_100;
    clr_edit_txt     = tw_slate_900;
    clr_input_border = tw_slate_400;
    clr_input_border_active = tw_sky_500;
  } else {
    // Fondo oscuro, texto claro
    clr_panel_bg     = tw_slate_800;
    clr_panel_border = tw_slate_600;
    clr_text         = tw_slate_100;
    clr_label        = tw_slate_100;
    clr_inactive     = tw_slate_600;
    clr_buy          = tw_emerald_500;
    clr_sell         = tw_rose_500;
    clr_be           = tw_sky_500;
    clr_close        = tw_red_600;
    clr_edit_bg      = tw_slate_700;
    clr_edit_txt     = tw_slate_50;
    clr_input_border = tw_slate_500;
    clr_input_border_active = tw_sky_500;
  }
}

// Helpers UI genéricos
#include "tfxea_ui_helpers.mqh"

// Nombres de objetos (incluye MANUAL)
#define OBJ_PANEL_BG           "tfxea_panel_bg"
#define OBJ_PANEL_TITLE        "tfxea_title"
#define OBJ_BTN_BUY            "tfxea_btn_buy"
#define OBJ_BTN_SELL           "tfxea_btn_sell"
#define OBJ_BTN_OPEN1          "tfxea_btn_open1"
#define OBJ_BTN_OPEN2          "tfxea_btn_open2"
#define OBJ_BTN_OPEN3          "tfxea_btn_open3"
#define OBJ_BTN_BE             "tfxea_btn_be"
#define OBJ_BTN_CLOSEALL       "tfxea_btn_closeall"
#define OBJ_BTN_X1             "tfxea_btn_x1"
#define OBJ_BTN_X2             "tfxea_btn_x2"
#define OBJ_BTN_X3             "tfxea_btn_x3"
#define OBJ_BTN_BE_TP1         "tfxea_btn_be_tp1"
#define OBJ_BTN_BE_TP2         "tfxea_btn_be_tp2"
#define OBJ_BTN_BE_TP3         "tfxea_btn_be_tp3"
#define OBJ_LABEL_LOTS         "tfxea_label_lots"
#define OBJ_EDIT_LOTS_BOX      "tfxea_edit_lots_box"
#define OBJ_EDIT_LOTS_TXT      "tfxea_edit_lots_txt"
#define OBJ_LABEL_PCT          "tfxea_label_pct"
#define OBJ_EDIT_PCT_BOX       "tfxea_edit_pct_box"
#define OBJ_EDIT_PCT_TXT       "tfxea_edit_pct_txt"
#define OBJ_BTN_PCT_ENABLE     "tfxea_btn_pct_enable"
#define OBJ_BTN_FULLTP         "tfxea_btn_fulltp"
#define OBJ_BTN_MANUAL         "tfxea_btn_manual"
#define OBJ_BTN_ATENTOS        "tfxea_btn_atentos"


string UI_WithCaret(const string &s,int pos,bool on){ if(!on) return s; int len=StringLen(s); if(pos<0)pos=0; if(pos>len)pos=len; return StringSubstr(s,0,pos)+"|"+StringSubstr(s,pos); }

void UI_LayoutPanel(){
  UI_SetupTheme();

  int pw,ph; UI_GetPanelSize(pw,ph);
  int x0,y0; UI_GetPanelOrigin(x0,y0,pw,ph);

  if(panel_style==PanelNone){
    UI_DeleteObjectByName(OBJ_PANEL_BG);
  } else {
    color bg=(panel_style==PanelSolid? clr_panel_bg : (color)ChartGetInteger(0,CHART_COLOR_BACKGROUND));
    UI_SetPanelBackgroundByName(OBJ_PANEL_BG, x0,y0,pw,ph, clr_panel_border, bg, false, 100);
  }

  int x=x0+panel_padding_x, y=y0+panel_padding_y;

  UI_SetLabel(OBJ_PANEL_TITLE,"Telegram FX EA",x,y,clr_label,105,ui_font_size_title); y+=26;

  // Fila superior: BUY, SELL, ATENTOS
  UI_SetButton(OBJ_BTN_BUY, "BUY",  x, y, button_width, button_height, (current_trend==1?clr_buy:clr_inactive), ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_SELL,"SELL", x+button_width+button_gap_x, y, button_width, button_height, (current_trend==-1?clr_sell:clr_inactive), ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_ATENTOS,"ATENTOS", x+2*(button_width+button_gap_x), y, button_width, button_height, tw_sky_500, ColorFromHex(0xFFFFFF), 110);
  y += button_height + button_gap_y;

  color open_c =(current_trend==0? clr_inactive:(current_trend==1? clr_buy:clr_sell));
  UI_SetButton(OBJ_BTN_OPEN1,"Open (x)", x, y, button_width, button_height, open_c, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_OPEN2,"Open (x)", x+button_width+button_gap_x, y, button_width, button_height, open_c, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_OPEN3,"Open (x)", x+2*(button_width+button_gap_x), y, button_width, button_height, open_c, ColorFromHex(0xFFFFFF), 110);
  y += button_height + button_gap_y;

  // x1/x2/x3 + FULL CALL + MANUAL
  color c1=(open_split_count==1?tw_emerald_500:clr_inactive), c2=(open_split_count==2?tw_emerald_500:clr_inactive), c3=(open_split_count==3?tw_emerald_500:clr_inactive);
  int miniw=(button_width-(2*6))/3;
  UI_SetButton(OBJ_BTN_X1,"x1", x, y, miniw, button_height, c1, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_X2,"x2", x+miniw+6, y, miniw, button_height, c2, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_X3,"x3", x+2*(miniw+6), y, miniw, button_height, c3, ColorFromHex(0xFFFFFF), 110);

  string ft_text = full_tp_call_enabled ? "FULL CALL: ON" : "FULL CALL: OFF";
  color  ft_bg   = full_tp_call_enabled ? tw_emerald_500 : clr_inactive;
  UI_SetButton(OBJ_BTN_FULLTP, ft_text, x + button_width + button_gap_x, y, button_width, button_height, ft_bg, ColorFromHex(0xFFFFFF), 110);

  string man_text = manual_mode_enabled ? "MANUAL: ON" : "MANUAL: OFF";
  color  man_bg   = manual_mode_enabled ? tw_emerald_500 : clr_inactive;
  UI_SetButton(OBJ_BTN_MANUAL, man_text, x + 2*(button_width + button_gap_x), y, button_width, button_height, man_bg, ColorFromHex(0xFFFFFF), 110);

  y += button_height + button_gap_y;

  UI_SetButton(OBJ_BTN_BE,"BE", x, y, button_width, button_height, clr_be, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_CLOSEALL,"CLOSE", x+button_width+button_gap_x, y, button_width*2+button_gap_x, button_height, clr_close, ColorFromHex(0xFFFFFF), 110);
  y += button_height + button_gap_y;

  // --- Botones de rango (antes BE@TP1/2/3) ---
  int r1 = SafeDistancePoints(SL_POINTS_INPUT_1);
  int r2 = SafeDistancePoints(SL_POINTS_INPUT_2);
  int r3 = SafeDistancePoints(SL_POINTS_INPUT_3);

  string rng1="RANGO "+IntegerToString(r1);
  string rng2="RANGO "+IntegerToString(r2);
  string rng3="RANGO "+IntegerToString(r3);

  // Color dinámico según tendencia
  color range_base;
  if(current_trend==1)      range_base = tw_emerald_400;
  else if(current_trend==-1)range_base = tw_rose_400;
  else                      range_base = clr_inactive; // neutro

  UI_SetButton(OBJ_BTN_BE_TP1, rng1, x, y, button_width, button_height, range_base, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_BE_TP2, rng2, x+button_width+button_gap_x, y, button_width, button_height, range_base, ColorFromHex(0xFFFFFF), 110);
  UI_SetButton(OBJ_BTN_BE_TP3, rng3, x+2*(button_width+button_gap_x), y, button_width, button_height, range_base, ColorFromHex(0xFFFFFF), 110);
  y += button_height + button_gap_y;

  // Inputs
  bool lots_editing=(active_input==ActiveLots), pct_editing=(active_input==ActivePct);

  UI_SetLabel(OBJ_LABEL_LOTS,"Lot size:", x, y+5, clr_label, 105, ui_font_size_label);
  UI_SetInputBox(OBJ_EDIT_LOTS_BOX, x+84, y, button_width, button_height, lots_editing, !percent_mode_enabled);
  string lots_base=DoubleToString(lot_size_value,2);
  string lots_shown=lots_editing? UI_WithCaret(lots_buffer,lots_caret,caret_visible):lots_base;
  UI_SetInputText(OBJ_EDIT_LOTS_TXT, lots_shown, x+84+6, y+5, clr_edit_txt);
  y += button_height + button_gap_y;

  UI_SetLabel(OBJ_LABEL_PCT,"Percent size:", x, y+5, clr_label, 105, ui_font_size_label);
  UI_SetInputBox(OBJ_EDIT_PCT_BOX, x+100, y, button_width-16, button_height, pct_editing, percent_mode_enabled);
  string pct_base=DoubleToString(percent_size_value,2);
  string pct_shown=pct_editing? UI_WithCaret(pct_buffer,pct_caret,caret_visible):pct_base;
  UI_SetInputText(OBJ_EDIT_PCT_TXT, pct_shown, x+100+6, y+5, clr_edit_txt);
  string pct_btn_text=percent_mode_enabled?"% ON":"% OFF";
  UI_SetButton(OBJ_BTN_PCT_ENABLE,pct_btn_text,x+100+button_width-16+6,y,60,button_height,(percent_mode_enabled?tw_emerald_500:clr_inactive),ColorFromHex(0xFFFFFF),110);

  // Ajusta textos de Open con tendencia
  string trend=(current_trend==1?"BUY":(current_trend==-1?"SELL":""));
  int s1=SafeDistancePoints(SL_POINTS_INPUT_1), s2=SafeDistancePoints(SL_POINTS_INPUT_2), s3=SafeDistancePoints(SL_POINTS_INPUT_3);
  string t1=(trend==""? "Open ("+IntegerToString(s1)+")" : "Open "+trend+" ("+IntegerToString(s1)+")");
  string t2=(trend==""? "Open ("+IntegerToString(s2)+")" : "Open "+trend+" ("+IntegerToString(s2)+")");
  string t3=(trend==""? "Open ("+IntegerToString(s3)+")" : "Open "+trend+" ("+IntegerToString(s3)+")");
  ObjectSetString(0,OBJ_BTN_OPEN1,OBJPROP_TEXT,t1);
  ObjectSetString(0,OBJ_BTN_OPEN2,OBJPROP_TEXT,t2);
  ObjectSetString(0,OBJ_BTN_OPEN3,OBJPROP_TEXT,t3);
}

void UI_RedrawInputs(){
  bool lots_editing = (active_input==ActiveLots);
  bool pct_editing  = (active_input==ActivePct);
  string lots_base = DoubleToString(lot_size_value, 2);
  string pct_base  = DoubleToString(percent_size_value, 2);
  string lots_shown = lots_editing ? UI_WithCaret(lots_buffer, lots_caret, caret_visible) : lots_base;
  string pct_shown  = pct_editing  ? UI_WithCaret(pct_buffer , pct_caret , caret_visible) : pct_base;
  UI_SetInputTextRaw(OBJ_EDIT_LOTS_TXT, lots_shown);
  UI_SetInputTextRaw(OBJ_EDIT_PCT_TXT , pct_shown);
  ObjectSetInteger(0,OBJ_EDIT_LOTS_BOX,OBJPROP_COLOR,(lots_editing||!percent_mode_enabled)?clr_input_border_active:clr_input_border);
  ObjectSetInteger(0,OBJ_EDIT_PCT_BOX ,OBJPROP_COLOR,(pct_editing||percent_mode_enabled)?clr_input_border_active:clr_input_border);
  string pct_btn_text = percent_mode_enabled? "% ON" : "% OFF";
  ObjectSetString(0,OBJ_BTN_PCT_ENABLE,OBJPROP_TEXT,pct_btn_text);
  ObjectSetInteger(0,OBJ_BTN_PCT_ENABLE,OBJPROP_BGCOLOR, (percent_mode_enabled? tw_emerald_500 : clr_inactive));
}

void UI_UpdateOnTick(){
  if(active_input!=ActiveNone){
    ulong now=GetMicrosecondCount();
    if(now - caret_last_toggle_us >= 400000){
      caret_visible=!caret_visible; caret_last_toggle_us=now;
      UI_RedrawInputs(); ChartRedraw();
    }
  }
  color open_c =(current_trend==0? clr_inactive:(current_trend==1? clr_buy:clr_sell));
  if(ObjectFind(0,OBJ_BTN_OPEN1)>=0) ObjectSetInteger(0,OBJ_BTN_OPEN1,OBJPROP_BGCOLOR,open_c);
  if(ObjectFind(0,OBJ_BTN_OPEN2)>=0) ObjectSetInteger(0,OBJ_BTN_OPEN2,OBJPROP_BGCOLOR,open_c);
  if(ObjectFind(0,OBJ_BTN_OPEN3)>=0) ObjectSetInteger(0,OBJ_BTN_OPEN3,OBJPROP_BGCOLOR,open_c);
}

bool UI_IsButtonName(const string &n){
  return (n==OBJ_BTN_BUY||n==OBJ_BTN_SELL||n==OBJ_BTN_ATENTOS||  // <--- añadido
          n==OBJ_BTN_OPEN1||n==OBJ_BTN_OPEN2||n==OBJ_BTN_OPEN3||
          n==OBJ_BTN_BE||n==OBJ_BTN_CLOSEALL||n==OBJ_BTN_X1||n==OBJ_BTN_X2||n==OBJ_BTN_X3||
          n==OBJ_BTN_FULLTP||n==OBJ_BTN_MANUAL||
          n==OBJ_BTN_BE_TP1||n==OBJ_BTN_BE_TP2||n==OBJ_BTN_BE_TP3||n==OBJ_BTN_PCT_ENABLE);
}
bool UI_IsLotsInputObject(const string &n){ return (n==OBJ_EDIT_LOTS_BOX||n==OBJ_EDIT_LOTS_TXT); }
bool UI_IsPctInputObject (const string &n){ return (n==OBJ_EDIT_PCT_BOX ||n==OBJ_EDIT_PCT_TXT ); }
bool UI_IsSignalLineObj(const string &name){ return StringFind(name,"tfxea_sig_")==0; }

void UI_ToggleTrend(int dir){ current_trend=(current_trend==dir?0:dir); UI_LayoutPanel(); ChartRedraw(); }

// Orquestador la expone
void TFXEA_MarkStateDirty();

// En commits/acciones que alteran estado persistido:
void UI_CommitLotsInput(){
  active_input=ActiveNone;
  double v=StringToDouble(lots_buffer); if(v<=0) v=LOTS_DEFAULT;
  lot_size_value=NormalizeLot(v); lots_buffer=DoubleToString(lot_size_value,2);
  caret_visible=false; UI_RedrawInputs(); ChartRedraw();
  TFXEA_MarkStateDirty();
}
void UI_CommitPctInput(){
  active_input=ActiveNone;
  double v=Clamp(StringToDouble(pct_buffer),0.01,100.0);
  percent_size_value=v; pct_buffer=DoubleToString(percent_size_value,2);
  caret_visible=false; UI_RedrawInputs(); ChartRedraw();
  TFXEA_MarkStateDirty();
}

void UI_ActivateLotsInput(){ active_input=ActiveLots; lots_buffer=DoubleToString(lot_size_value,2); lots_caret=StringLen(lots_buffer); caret_visible=true; caret_last_toggle_us=GetMicrosecondCount(); UI_RedrawInputs(); ChartRedraw(); }
void UI_ActivatePctInput(){ active_input=ActivePct; pct_buffer=DoubleToString(percent_size_value,2); pct_caret=StringLen(pct_buffer); caret_visible=true; caret_last_toggle_us=GetMicrosecondCount(); UI_RedrawInputs(); ChartRedraw(); }

string UI_RemoveAt(string s,int pos){ int len=StringLen(s); if(pos<0||pos>=len) return s; return StringSubstr(s,0,pos)+StringSubstr(s,pos+1); }
string UI_InsertAt(string s,int pos,string ch){ int len=StringLen(s); if(pos<0)pos=0; if(pos>len)pos=len; return StringSubstr(s,0,pos)+ch+StringSubstr(s,pos); }
bool UI_IsDigitVK(int k){ return (k>=48&&k<=57)||(k>=96&&k<=105); }
bool UI_IsDecimalVK(int k){ return (k==190||k==110||k==188); }

bool UI_EditBufferOnKey(string &buf, int &car, int key_code, int modifiers){
  bool changed=false, caret_moved=false;
  int len=StringLen(buf);
  if(key_code==37){ if(car>0){ car--; caret_moved=true; } }
  else if(key_code==39){ if(car<len){ car++; caret_moved=true; } }
  else if(key_code==36){ if(car!=0){ car=0; caret_moved=true; } }
  else if(key_code==35){ if(car!=len){ car=len; caret_moved=true; } }
  else if(key_code==8){ if(car>0){ buf=UI_RemoveAt(buf,car-1); car--; changed=true; caret_moved=true; } }
  else if(key_code==46){ if(car<len){ buf=UI_RemoveAt(buf,car); changed=true; } }
  else if(UI_IsDigitVK(key_code)||UI_IsDecimalVK(key_code)){
    string ch;
    if(UI_IsDigitVK(key_code)){ if(key_code>=96&&key_code<=105) ch=IntegerToString(key_code-96); else ch=IntegerToString(key_code-48);
      if(!(car==0&&len==1&&buf=="0"&&ch=="0")){ buf=UI_InsertAt(buf,car,ch); car++; changed=true; caret_moved=true; } }
    else { if(StringFind(buf,".")==-1){ if(buf==""){ buf="0"; car=1; changed=true; } buf=UI_InsertAt(buf,car,"."); car++; changed=true; caret_moved=true; } }
  }
  if(changed||caret_moved){ caret_visible=true; caret_last_toggle_us=GetMicrosecondCount(); }
  return (changed||caret_moved);
}

void UI_HandleKeyDown(int key_code,int modifiers){
  if(active_input==ActiveNone) return;
  if(key_code==27){ if(active_input==ActiveLots) UI_CommitLotsInput(); else UI_CommitPctInput(); return; }
  if(key_code==13){ if(active_input==ActiveLots) UI_CommitLotsInput(); else UI_CommitPctInput(); return; }
  bool redraw=false;
  if(active_input==ActiveLots) redraw=UI_EditBufferOnKey(lots_buffer,lots_caret,key_code,modifiers);
  else if(active_input==ActivePct) redraw=UI_EditBufferOnKey(pct_buffer,pct_caret,key_code,modifiers);
  if(redraw){ UI_RedrawInputs(); ChartRedraw(); }
}

void UI_HandleButtonClick(string name){
  if(UI_IsButtonName(name) && ObjectFind(0,name)>=0){
    ObjectSetInteger(0,name,OBJPROP_STATE,false);
    ChartRedraw();
  }

  if(name==OBJ_BTN_BUY) UI_ToggleTrend(1);
  else if(name==OBJ_BTN_SELL) UI_ToggleTrend(-1);
  else if(name==OBJ_BTN_ATENTOS) { Orchestrator_SendAttentos(); }
  else if(name==OBJ_BTN_OPEN1) Orchestrator_OpenPreset(1);
  else if(name==OBJ_BTN_OPEN2) Orchestrator_OpenPreset(2);
  else if(name==OBJ_BTN_OPEN3) Orchestrator_OpenPreset(3);
  else if(name==OBJ_BTN_BE) Orchestrator_ApplyBE();
  else if(name==OBJ_BTN_CLOSEALL) Orchestrator_CloseAll();
  else if(name==OBJ_BTN_X1 || name==OBJ_BTN_X2 || name==OBJ_BTN_X3){
    open_split_count = (name==OBJ_BTN_X1?1:(name==OBJ_BTN_X2?2:3));
    UI_LayoutPanel(); ChartRedraw(); TFXEA_MarkStateDirty();
  }
  else if(name==OBJ_BTN_FULLTP){
    full_tp_call_enabled = !full_tp_call_enabled; UI_LayoutPanel(); ChartRedraw(); TFXEA_MarkStateDirty();
  }
  else if(name==OBJ_BTN_MANUAL){
    manual_mode_enabled = !manual_mode_enabled; UI_LayoutPanel(); ChartRedraw(); TFXEA_MarkStateDirty();
  }
  else if(name==OBJ_BTN_PCT_ENABLE){
    percent_mode_enabled = !percent_mode_enabled;
    if(percent_mode_enabled && active_input==ActiveLots) UI_CommitLotsInput();
    if(!percent_mode_enabled && active_input==ActivePct) UI_CommitPctInput();
    UI_RedrawInputs(); ChartRedraw(); TFXEA_MarkStateDirty();
  }
  // NUEVOS: rangos (ex BE@TPn)
  else if(name==OBJ_BTN_BE_TP1){ Orchestrator_SendRangeMessage(1); }
  else if(name==OBJ_BTN_BE_TP2){ Orchestrator_SendRangeMessage(2); }
  else if(name==OBJ_BTN_BE_TP3){ Orchestrator_SendRangeMessage(3); }
}

void UI_RecreateIfDeleted(string name){
  if(name==OBJ_PANEL_BG||name==OBJ_PANEL_TITLE||name==OBJ_BTN_BUY||name==OBJ_BTN_SELL||name==OBJ_BTN_ATENTOS||  // <--- añadido
     name==OBJ_BTN_OPEN1||name==OBJ_BTN_OPEN2||name==OBJ_BTN_OPEN3||name==OBJ_BTN_BE||name==OBJ_BTN_CLOSEALL||
     name==OBJ_BTN_X1||name==OBJ_BTN_X2||name==OBJ_BTN_X3||name==OBJ_BTN_FULLTP||name==OBJ_BTN_MANUAL||
     name==OBJ_BTN_BE_TP1||name==OBJ_BTN_BE_TP2||name==OBJ_BTN_BE_TP3||
     name==OBJ_LABEL_LOTS||name==OBJ_EDIT_LOTS_BOX||name==OBJ_EDIT_LOTS_TXT||
     name==OBJ_LABEL_PCT||name==OBJ_EDIT_PCT_BOX||name==OBJ_EDIT_PCT_TXT||name==OBJ_BTN_PCT_ENABLE) { UI_LayoutPanel(); }
}

// API UI
bool UI_Init(){ UI_LayoutPanel(); return true; }
void UI_Destroy(){
  string objs[]={ OBJ_PANEL_BG, OBJ_PANEL_TITLE, OBJ_BTN_BUY, OBJ_BTN_SELL, OBJ_BTN_ATENTOS,  // <--- añadido
                  OBJ_BTN_OPEN1, OBJ_BTN_OPEN2, OBJ_BTN_OPEN3,
                  OBJ_BTN_X1, OBJ_BTN_X2, OBJ_BTN_X3, OBJ_BTN_FULLTP, OBJ_BTN_MANUAL, OBJ_BTN_BE, OBJ_BTN_CLOSEALL,
                  OBJ_BTN_BE_TP1, OBJ_BTN_BE_TP2, OBJ_BTN_BE_TP3, OBJ_LABEL_LOTS, OBJ_EDIT_LOTS_BOX, OBJ_EDIT_LOTS_TXT,
                  OBJ_LABEL_PCT, OBJ_EDIT_PCT_BOX, OBJ_EDIT_PCT_TXT, OBJ_BTN_PCT_ENABLE };
  for(int i=0;i<ArraySize(objs);i++){ if(ObjectFind(0,objs[i])>=0) ObjectDelete(0,objs[i]); }
}

void UI_HandleChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam){
  switch(id){
    case CHARTEVENT_OBJECT_CLICK:
      if(UI_IsSignalLineObj(sparam)) return;
      skip_next_chart_click=true;
      if(UI_IsLotsInputObject(sparam)){ UI_ActivateLotsInput(); return; }
      if(UI_IsPctInputObject(sparam)){ UI_ActivatePctInput(); return; }
      if(active_input==ActiveLots) UI_CommitLotsInput();
      if(active_input==ActivePct)  UI_CommitPctInput();
      UI_HandleButtonClick(sparam);
      return;
    case CHARTEVENT_CLICK:
      if(skip_next_chart_click){ skip_next_chart_click=false; return; }
      if(active_input==ActiveLots) UI_CommitLotsInput();
      if(active_input==ActivePct)  UI_CommitPctInput();
      return;
    case CHARTEVENT_KEYDOWN: UI_HandleKeyDown((int)lparam,(int)dparam); return;
    case CHARTEVENT_CHART_CHANGE: UI_LayoutPanel(); return;
    case CHARTEVENT_OBJECT_DELETE: UI_RecreateIfDeleted(sparam); return;
  }
}
