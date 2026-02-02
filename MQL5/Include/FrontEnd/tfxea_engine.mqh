//+------------------------------------------------------------------+
//| tfxea_engine.mqh                                                 |
//| Motor con modo MANUAL                                            |
//| - MANUAL: no cierra parciales ni mueve stops del servidor        |
//| - SL servidor y TP3 servidor se fijan al abrir                   |
//| - TP virtuales envían mensajes, BE button solo mensaje           |
//+------------------------------------------------------------------+
#property strict

void TFXEA_MarkStateDirty();

// Se usa global manual_mode_enabled (definido en orquestador)

double Engine_ExitPriceForSide(int side){
  double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  return (side==1 ? bid : ask);
}
int Engine_PointsBetween(double a, double b){
  return (int)MathRound(MathAbs(a-b)/_Point);
}
void Engine_FractionsForSplit(int split_count, double &f1, double &f2, double &f3){
  if(split_count<=1){ f1=1.0; f2=0.0; f3=0.0; return; }
  if(split_count==2){ f1=0.5; f2=0.5; f3=0.0; return; }
  f1=1.0/3.0; f2=1.0/3.0; f3=1.0/3.0;
}
string Engine_MakeSignalComment(const int signal_id){ return "TFX-s"+IntegerToString(signal_id); }
void Engine_LabelLine(string name, string label){ if(ObjectFind(0,name)>=0) ObjectSetString(0,name,OBJPROP_TEXT,label); }

bool Engine_ComputeSafeStopsForModify(int side, double desired_sl, double desired_tp, double &sl_out, double &tp_out){
  int stop_level  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  int freeze_lvl  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
  double min_diff = (stop_level + freeze_lvl + 1) * _Point;
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

  if(side==1){
    // BUY: SL < Bid - min_diff, TP > Ask + min_diff
    sl_out = MathMin(desired_sl, bid - min_diff);
    tp_out = MathMax(desired_tp, ask + min_diff);
    if(!(sl_out < bid && tp_out > ask)) return false;
  } else {
    // SELL: SL > Ask + min_diff, TP < Bid - min_diff
    sl_out = MathMax(desired_sl, ask + min_diff);
    tp_out = MathMin(desired_tp, bid - min_diff);
    if(!(sl_out > ask && tp_out < bid)) return false;
  }
  sl_out = NormalizeDouble(sl_out, digits);
  tp_out = NormalizeDouble(tp_out, digits);
  return true;
}

// NOTA: usamos EnsureHLineSoft (definido en orquestador) para no pisar arrastre del usuario.
void Engine_SyncLinesWithSignal(SignalInfo &sig){
  color c_sl = ColorFromHex(0xDC2626);
  color c_tp = ColorFromHex(0x10B981);
  double eps = _Point*0.5;

  // En MANUAL: siempre mantener SL visible (aun tras TP1). Nunca mostrar VSL/BE automático.
  bool keep_sl_always = manual_mode_enabled;
  bool show_vsl_after_tp1 = (!manual_mode_enabled && sig.tp_hit_sent[0]);

  // SL
  string nSL = SigObjName(sig.id,"SL");
  if(!sig.tp_hit_sent[0] || keep_sl_always){
    if(ObjectFind(0,nSL)>=0){
      double px=ObjectGetDouble(0,nSL,OBJPROP_PRICE);
      if(px>0 && MathAbs(px - sig.sl) > eps){ sig.sl=px; TFXEA_MarkStateDirty(); }
      EnsureHLineSoft(nSL, sig.sl, c_sl, STYLE_SOLID, 1, 1);
      Engine_LabelLine(nSL, "SL");
    } else {
      EnsureHLineSoft(nSL, sig.sl, c_sl, STYLE_SOLID, 1, 1);
      Engine_LabelLine(nSL, "SL");
    }
  } else {
    DeleteSigLine(sig.id,"SL");
  }

  // VSL/BE solo en NO manual y tras TP1
  string nVSL = SigObjName(sig.id,"VSL");
  if(show_vsl_after_tp1){
    if(ObjectFind(0,nVSL)>=0){
      double px=ObjectGetDouble(0,nVSL,OBJPROP_PRICE);
      if(px>0 && MathAbs(px - sig.virtual_be_level) > eps){ sig.virtual_be_level=px; TFXEA_MarkStateDirty(); }
      EnsureHLineSoft(nVSL, sig.virtual_be_level, c_sl, STYLE_DASHDOT, 1, 1);
      Engine_LabelLine(nVSL, "BE");
    } else {
      EnsureHLineSoft(nVSL, sig.virtual_be_level, c_sl, STYLE_DASHDOT, 1, 1);
      Engine_LabelLine(nVSL, "BE");
    }
  } else {
    DeleteSigLine(sig.id,"VSL");
  }

  // TP1
  string nTP1 = SigObjName(sig.id,"TP1");
  if(!sig.tp_hit_sent[0]){
    if(ObjectFind(0,nTP1)>=0){
      double px=ObjectGetDouble(0,nTP1,OBJPROP_PRICE);
      if(px>0 && MathAbs(px - sig.tp1) > eps){ sig.tp1=px; TFXEA_MarkStateDirty(); }
      EnsureHLineSoft(nTP1, sig.tp1, c_tp, STYLE_DOT, 1, 1);
      Engine_LabelLine(nTP1, "TP1");
    } else {
      EnsureHLineSoft(nTP1, sig.tp1, c_tp, STYLE_DOT, 1, 1);
      Engine_LabelLine(nTP1, "TP1");
    }
  } else DeleteSigLine(sig.id,"TP1");

  // TP2
  string nTP2 = SigObjName(sig.id,"TP2");
  if(!sig.tp_hit_sent[1] && sig.tp2!=0.0){
    if(ObjectFind(0,nTP2)>=0){
      double px=ObjectGetDouble(0,nTP2,OBJPROP_PRICE);
      if(px>0 && MathAbs(px - sig.tp2) > eps){ sig.tp2=px; TFXEA_MarkStateDirty(); }
      EnsureHLineSoft(nTP2, sig.tp2, c_tp, STYLE_DASH, 1, 1);
      Engine_LabelLine(nTP2, "TP2");
    } else {
      EnsureHLineSoft(nTP2, sig.tp2, c_tp, STYLE_DASH, 1, 1);
      Engine_LabelLine(nTP2, "TP2");
    }
  } else DeleteSigLine(sig.id,"TP2");

  // TP3
  string nTP3 = SigObjName(sig.id,"TP3");
  if(!sig.tp_hit_sent[2] && sig.tp3!=0.0){
    if(ObjectFind(0,nTP3)>=0){
      double px=ObjectGetDouble(0,nTP3,OBJPROP_PRICE);
      if(px>0 && MathAbs(px - sig.tp3) > eps){ sig.tp3=px; TFXEA_MarkStateDirty(); }
      EnsureHLineSoft(nTP3, sig.tp3, c_tp, STYLE_SOLID, 1, 1);
      Engine_LabelLine(nTP3, "TP3");
    } else {
      EnsureHLineSoft(nTP3, sig.tp3, c_tp, STYLE_SOLID, 1, 1);
      Engine_LabelLine(nTP3, "TP3");
    }
  } else DeleteSigLine(sig.id,"TP3");
}

void Engine_RebuildAllLines(){
  for(int i=0;i<ArraySize(signals);i++){
    SignalInfo s = signals[i];
    Engine_SyncLinesWithSignal(s);
    signals[i] = s;
  }
  ChartRedraw();
  PrintDebug("Rebuild lines: signals="+IntegerToString(ArraySize(signals)));
}

bool Engine_GetPositionForSignal(const SignalInfo &sig, ulong &ticket_out, double &vol_out){
  ticket_out=0; vol_out=0.0;
  string want_cmt = Engine_MakeSignalComment(sig.id);
  int total=PositionsTotal();
  for(int i=0;i<total;i++){
    ulong tk=PositionGetTicket(i);
    if(!PositionSelectByTicket(tk)) continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
    if(PositionGetString(POSITION_COMMENT) == want_cmt){
      ticket_out=tk; vol_out=PositionGetDouble(POSITION_VOLUME); return true;
    }
  }
  if(PositionSelect(_Symbol)){
    ticket_out = PositionGetInteger(POSITION_TICKET);
    vol_out    = PositionGetDouble(POSITION_VOLUME);
    return (vol_out>0.0);
  }
  return false;
}

bool Engine_ClosePartialByFraction(const SignalInfo &sig, double fraction){
  if(fraction<=0.0) return true;
  if(manual_mode_enabled) return true; // En manual NO cerramos parciales del servidor

  ulong ticket; double vol; if(!Engine_GetPositionForSignal(sig,ticket,vol) || vol<=0.0) return false;

  double vmin,vstep,vmax; SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,vmin);
  SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,vstep); if(vstep<=0.0) vstep=0.01;
  SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,vmax);

  double to_close = vol * Clamp(fraction,0.0,1.0);
  int steps=(int)MathMax(1, MathRound(to_close / vstep));
  to_close = steps * vstep;
  if(to_close < vmin) to_close = vmin;
  if(to_close > vol)  to_close = vol;

  trade.SetExpertMagicNumber((long)EncodeMagic(sig.id, 9));
  if(trade.PositionClosePartial(ticket, to_close)) return true;

  if(!PositionSelectByTicket(ticket)) return false;
  long type=PositionGetInteger(POSITION_TYPE);
  bool ok=false; if(type==POSITION_TYPE_BUY) ok=trade.Sell(to_close); else ok=trade.Buy(to_close);
  if(!ok) PrintDebug("ClosePartial fallback netting fallo vol="+DoubleToString(to_close,2)+" err="+IntegerToString(_LastError));
  return ok;
}

bool Engine_HitTPn(SignalInfo &sig, int n_tp, int base_tp_points, double frac_to_close, const string &tpl_hit){
  // En manual: solo mensajes y marcadores; no cerrar
  if(manual_mode_enabled){
    int mult=(n_tp==1?1:(n_tp==2?(int)MathRound(TP2_MULTIPLIER):(int)MathRound(TP3_MULTIPLIER)));
    int points_for_tp=(int)MathRound(base_tp_points*(double)mult);
    SendTplPips(tpl_hit, points_for_tp);

    if(n_tp==1){ sig.tp_hit_sent[0]=true; DeleteSigLine(sig.id,"TP1"); /* mantener SL; no BE auto */ }
    if(n_tp==2){ sig.tp_hit_sent[1]=true; DeleteSigLine(sig.id,"TP2"); }
    if(n_tp==3){ sig.tp_hit_sent[2]=true; DeleteSigLine(sig.id,"TP3"); }

    TFXEA_MarkStateDirty();
    return true;
  }

  // Modo normal: cerrar parcial y acciones extra
  if(frac_to_close<=0.0) return false;
  if(!Engine_ClosePartialByFraction(sig, frac_to_close)) return false;

  int mult=(n_tp==1?1:(n_tp==2?(int)MathRound(TP2_MULTIPLIER):(int)MathRound(TP3_MULTIPLIER)));
  int points_for_tp=(int)MathRound(base_tp_points*(double)mult);
  SendTplPips(tpl_hit, points_for_tp);

  if(n_tp==1){
    sig.tp_hit_sent[0]=true; DeleteSigLine(sig.id,"TP1");
    // mover a BE con offset y mensaje BE_MOVE (modo normal)
    double off = PointsToPriceDistance(VIRTUAL_BE_TOL_POINTS);
    sig.virtual_be_level = (sig.side==1 ? (sig.entry + off) : (sig.entry - off));
    DeleteSigLine(sig.id,"SL");
    MoveSigVirtualSLToBE(sig);
    Engine_LabelLine(SigObjName(sig.id,"VSL"), "BE");
    TelegramSendMessage(ExpandEscapes(TPL_BE_MOVE));
  }
  else if(n_tp==2){ sig.tp_hit_sent[1]=true; DeleteSigLine(sig.id,"TP2"); }
  else if(n_tp==3){ sig.tp_hit_sent[2]=true; DeleteSigLine(sig.id,"TP3"); }

  TFXEA_MarkStateDirty();
  return true;
}

bool Engine_HitVirtualSL(SignalInfo &sig, bool send_msg){
  // En manual no evaluamos VSL (no se usa)
  if(manual_mode_enabled) return false;

  ulong ticket; double vol;
  if(Engine_GetPositionForSignal(sig,ticket,vol) && vol>0.0){
    trade.SetExpertMagicNumber((long)EncodeMagic(sig.id, 9));
    if(!trade.PositionClose(ticket)) PrintDebug("Close total fallo ticket="+IntegerToString(ticket)+" err="+IntegerToString(_LastError));
  }
  if(send_msg) TelegramSendMessage(ExpandEscapes(TPL_BE_TOUCHED));
  DeleteAllSignalLines(sig.id);
  TFXEA_MarkStateDirty();
  return true;
}

void Engine_StepSignal(int idx){
  if(idx<0 || idx>=ArraySize(signals)) return;
  SignalInfo sig=signals[idx];

  Engine_SyncLinesWithSignal(sig);

  ulong tk; double vol; bool have_pos=Engine_GetPositionForSignal(sig,tk,vol);
  double px_exit=Engine_ExitPriceForSide(sig.side);
  double f1,f2,f3; Engine_FractionsForSplit(sig.split_count,f1,f2,f3);

  bool changed=false;

  // SL: en MANUAL mandamos mensaje y dejamos que el servidor cierre; en normal cerramos.
  bool hit_sl = (sig.side==1 ? (px_exit <= sig.sl) : (px_exit >= sig.sl));
  if(have_pos && hit_sl){
    int sl_points_eff = Engine_PointsBetween(sig.entry, sig.sl);
    SendTplPips(TPL_SL_HIT, sl_points_eff);

    if(!manual_mode_enabled){
      trade.SetExpertMagicNumber((long)EncodeMagic(sig.id, 9));
      if(!trade.PositionClose(tk)) PrintDebug("Close por SL fallo. ticket="+IntegerToString(tk)+" err="+IntegerToString(_LastError));
    }
    DeleteAllSignalLines(sig.id);
    RemoveSignalByIndex(idx);
    TFXEA_MarkStateDirty();
    return;
  }

  // TP virtuales (mensajes siempre; cierres parciales solo si NO manual)
  if(!sig.tp_hit_sent[0]){
    bool h=(sig.side==1 ? (px_exit >= sig.tp1) : (px_exit <= sig.tp1));
    if(h){ Engine_HitTPn(sig,1,sig.tp_points,f1,TPL_TP1_HIT); changed=true; }
  } else if(!sig.tp_hit_sent[1] && sig.tp2!=0.0){
    bool h=(sig.side==1 ? (px_exit >= sig.tp2) : (px_exit <= sig.tp2));
    if(h){ Engine_HitTPn(sig,2,sig.tp_points,f2,TPL_TP2_HIT); changed=true; }
  } else if(!sig.tp_hit_sent[2] && sig.tp3!=0.0){
    bool h=(sig.side==1 ? (px_exit >= sig.tp3) : (px_exit <= sig.tp3));
    if(h){ Engine_HitTPn(sig,3,sig.tp_points,f3,TPL_TP3_HIT); changed=true; }
  }

  // VSL/BE: no se evalúa en MANUAL; en normal solo tras TP1 (ya implementado en Engine_HitVirtualSL pathway)
  if(!have_pos){
    DeleteAllSignalLines(sig.id);
    RemoveSignalByIndex(idx);
    TFXEA_MarkStateDirty();
    return;
  }

  signals[idx]=sig;
  if(changed) TFXEA_MarkStateDirty();
}

void Engine_OnTick(){ for(int i=ArraySize(signals)-1;i>=0;i--) Engine_StepSignal(i); }

bool Engine_OpenSignal(int side, int split_count, int sl_points, int tp_points, int btn_index){
  double lots_total=GetTotalLotsToUse(sl_points);
  if(lots_total<=0){ PrintDebug("Lotaje inválido."); return false; }
  sl_points=SafeDistancePoints(sl_points); tp_points=SafeDistancePoints(tp_points);

  double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  ENUM_ORDER_TYPE type=(side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL);

  double anchor=(rr_mode==RR_TriggerSymmetric?(side==1?bid:ask):(side==1?ask:bid));
  double dsl=PointsToPriceDistance(sl_points), dtp=PointsToPriceDistance(tp_points);
  double sl,tp1,tp2,tp3;
  if(side==1){ sl=anchor-dsl; tp1=anchor+dtp; tp2=anchor+dtp*TP2_MULTIPLIER; tp3=anchor+dtp*TP3_MULTIPLIER; }
  else       { sl=anchor+dsl; tp1=anchor-dtp; tp2=anchor-dtp*TP2_MULTIPLIER; tp3=anchor-dtp*TP3_MULTIPLIER; }

  string cmt="TFX-s"+IntegerToString(next_signal_id+1);
  trade.SetExpertMagicNumber((long)EncodeMagic(next_signal_id+1, 9));
  bool ok=(type==ORDER_TYPE_BUY)? trade.Buy(lots_total,NULL,0.0,0.0,0.0,cmt)
                                : trade.Sell(lots_total,NULL,0.0,0.0,0.0,cmt);
  if(!ok){ PrintDebug("No se pudo abrir la posición. Err="+IntegerToString(_LastError)); return false; }

  SignalInfo sig;
  sig.id=++next_signal_id; sig.side=side;
  sig.sl_points=sl_points; sig.tp_points=tp_points;
  sig.anchor=anchor; sig.sl=sl; sig.tp1=tp1; sig.tp2=tp2; sig.tp3=tp3;
  sig.entry=(side==1?ask:bid);
  sig.virtual_be_level=sig.entry;
  sig.full_tp_call=true; sig.virtual_active=true; sig.created_at=TimeCurrent();
  sig.split_count=(split_count<1?1:(split_count>3?3:split_count));
  sig.tp_hit_sent[0]=sig.tp_hit_sent[1]=sig.tp_hit_sent[2]=false; sig.sl_hit_sent=false;

  Engine_SyncLinesWithSignal(sig);

  int sz=ArraySize(signals); ArrayResize(signals,sz+1); signals[sz]=sig;

  // MANUAL: fijar SL del servidor y TP del servidor en TP3 en la POSICIÓN RECIÉN ABIERTA
  if(manual_mode_enabled){
    ulong tk; double vol;
    if(Engine_GetPositionForSignal(sig, tk, vol)){
      double desired_sl = sl;
      double desired_tp = (tp3!=0.0 ? tp3 : tp1);
      double safe_sl, safe_tp;
      if(Engine_ComputeSafeStopsForModify(sig.side, desired_sl, desired_tp, safe_sl, safe_tp)){
        trade.SetExpertMagicNumber((long)EncodeMagic(sig.id, 9));
        if(!trade.PositionModify(tk, safe_sl, safe_tp)){
          PrintDebug("MANUAL modify failed: ticket="+IntegerToString(tk)+
                     " sl="+DoubleToString(safe_sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS))+
                     " tp="+DoubleToString(safe_tp,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS))+
                     " err="+IntegerToString(_LastError));
        }
      } else {
        PrintDebug("MANUAL compute stops invalid for side="+IntegerToString(sig.side)+
                   " desired_sl="+DoubleToString(desired_sl, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS))+
                   " desired_tp="+DoubleToString(desired_tp, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));
      }
    } else {
      PrintDebug("MANUAL: no se halló la posición recién abierta para aplicar SL/TP");
    }
  }

  TFXEA_MarkStateDirty();
  SendTelegramOpen(btn_index, side, lots_total, sl_points, tp_points, sig.entry, sl, tp1, tp2, tp3);
  return true;
}
