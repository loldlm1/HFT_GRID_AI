//+------------------------------------------------------------------+
//| tfxea_ui_helpers.mqh                                             |
//| Helpers comunes de UI (objetos, tipografía, z-order, inputs)     |
//+------------------------------------------------------------------+
#property strict

bool UI_EnsureObject(string name, ENUM_OBJECT type){ if(ObjectFind(0,name)<0) return ObjectCreate(0,name,type,0,0,0); return true; }
void UI_ApplyTypography(string n,int sz){ ObjectSetString(0,n,OBJPROP_FONT,ui_font_family); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz); }
void UI_ApplyZ(string n,int z){ ObjectSetInteger(0,n,OBJPROP_ZORDER,z); }

// Genéricos por nombre (no dependen de macros)
void UI_DeleteObjectByName(string name){ if(ObjectFind(0,name)>=0) ObjectDelete(0,name); }

// Crea/actualiza panel background.
// Nota: si back=false el rectángulo se dibuja por delante del gráfico (mejor contraste).
void UI_SetPanelBackgroundByName(string name, int x,int y,int w,int h, color borderClr, color bgClr, bool back, int z){
  if(!UI_EnsureObject(name,OBJ_RECTANGLE_LABEL)) return;
  ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
  ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
  ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
  ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,name,OBJPROP_BACK, back);   // <- clave: false para PanelSolid
  ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
  ObjectSetInteger(0,name,OBJPROP_COLOR,borderClr);
  ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgClr);
  UI_ApplyZ(name,z);
}

void UI_SetButton(string name,string text,int x,int y,int w,int h,color bg,color fg,int z=110){
  if(!UI_EnsureObject(name,OBJ_BUTTON)) return;
  ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
  ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
  ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
  ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
  ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
  ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
  ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clr_panel_border);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,name,OBJPROP_STATE,false);
  ObjectSetString(0,name,OBJPROP_TEXT,text);
  UI_ApplyTypography(name,ui_font_size_btn); UI_ApplyZ(name,z);
}

void UI_SetLabel(string name,string text,int x,int y,color fg,int z=105,int fs=-1){
  if(!UI_EnsureObject(name,OBJ_LABEL)) return;
  ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
  ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
  ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,name,OBJPROP_BACK,false);
  ObjectSetString(0,name,OBJPROP_TEXT,text);
  UI_ApplyTypography(name,(fs>0?fs:ui_font_size_label)); UI_ApplyZ(name,z);
}

void UI_SetInputBox(string box,int x,int y,int w,int h,bool editing,bool mode_on){
  if(!UI_EnsureObject(box,OBJ_RECTANGLE_LABEL)) return;
  ObjectSetInteger(0,box,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,box,OBJPROP_XDISTANCE,x);
  ObjectSetInteger(0,box,OBJPROP_YDISTANCE,y);
  ObjectSetInteger(0,box,OBJPROP_XSIZE,w);
  ObjectSetInteger(0,box,OBJPROP_YSIZE,h);
  ObjectSetInteger(0,box,OBJPROP_BGCOLOR,clr_edit_bg);
  color brd=(editing||mode_on)? clr_input_border_active: clr_input_border;
  ObjectSetInteger(0,box,OBJPROP_COLOR,brd);
  ObjectSetInteger(0,box,OBJPROP_SELECTABLE,false);
  UI_ApplyZ(box,106);
}

void UI_SetInputTextRaw(string n,string t){ if(ObjectFind(0,n)>=0) ObjectSetString(0,n,OBJPROP_TEXT,t); }
void UI_SetInputText(string name,string text,int x,int y,color fg){
  if(!UI_EnsureObject(name,OBJ_LABEL)) return;
  ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
  ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
  ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
  ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  ObjectSetInteger(0,name,OBJPROP_BACK,false);
  ObjectSetString(0,name,OBJPROP_TEXT,text);
  UI_ApplyTypography(name,ui_font_size_edit);
  UI_ApplyZ(name,107);
}

void UI_GetPanelSize(int &panel_w,int &panel_h){
  int rows=7;
  panel_w=3*button_width + 2*button_gap_x + 2*panel_padding_x;
  int rows_h=(button_height*rows)+(button_gap_y*rows);
  int title_h=26; panel_h=panel_padding_y + title_h + button_gap_y + rows_h + panel_padding_y;
}
void UI_GetPanelOrigin(int &x0,int &y0,int w,int h){
  int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
  int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
  bool right=(panel_corner==CORNER_RIGHT_UPPER||panel_corner==CORNER_RIGHT_LOWER);
  bool lower=(panel_corner==CORNER_LEFT_LOWER ||panel_corner==CORNER_RIGHT_LOWER);
  x0 = right? (cw - w - 6) : 6; if(x0<2) x0=2;
  y0 = lower? (ch - h - 6) : 6; if(y0<2) y0=2;
}
