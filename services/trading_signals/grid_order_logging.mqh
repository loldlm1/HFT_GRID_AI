//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... logging      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_

#include "grid_order_helpers.mqh"

string GridStructureTypeToken(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HH:
      return "HH";
    case OSCILLATOR_STRUCTURE_HL:
      return "HL";
    case OSCILLATOR_STRUCTURE_LH:
      return "LH";
    case OSCILLATOR_STRUCTURE_LL:
      return "LL";
    default:
      return "EQ";
  }
}

string GridComposeStructureSequence(const OscillatorStructureTypes first,
                                    const OscillatorStructureTypes second,
                                    const OscillatorStructureTypes third,
                                    const OscillatorStructureTypes fourth)
{
  return StringFormat("%s,%s,%s,%s",
                      GridStructureTypeToken(first),
                      GridStructureTypeToken(second),
                      GridStructureTypeToken(third),
                      GridStructureTypeToken(fourth));
}

string GridResolveCurrentSignalStructureSequence(const SignalParams &signal_params)
{
  StochasticMarketStructure structure;
  if(!ResolveSignalStructureSnapshot(signal_params, structure))
    return "n/a";

  return GridComposeStructureSequence(structure.first_structure_type,
                                      structure.second_structure_type,
                                      structure.third_structure_type,
                                      structure.fourth_structure_type);
}

bool GridResolveRequiredCompoundStructureSequence(const SignalParams &signal_params,
                                                  string &required_sequence_out)
{
  required_sequence_out = "";

  StrategyStructureLayerContext ctx = BuildStructureLayerForContext(signal_params.strategy_context);
  if(!ctx.enabled)
    return false;
  if(!StructureCompoundFilterIsEnabled(ctx.structure_compound_filter))
    return false;

  OscillatorStructureTypes expected_first = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_second = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_third = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_fourth = OSCILLATOR_STRUCTURE_EQ;
  if(!ResolveStructureCompoundCanonicalTemplate(ctx.structure_compound_filter,
                                                expected_first,
                                                expected_second,
                                                expected_third,
                                                expected_fourth))
    return false;

  required_sequence_out = GridComposeStructureSequence(expected_first,
                                                       expected_second,
                                                       expected_third,
                                                       expected_fourth);
  return true;
}

string GridResolveStructureAuditSummary(const SignalParams &signal_params)
{
  string current_sequence = GridResolveCurrentSignalStructureSequence(signal_params);
  string required_sequence = "";
  if(!GridResolveRequiredCompoundStructureSequence(signal_params, required_sequence))
    return current_sequence;

  return current_sequence + "==" + required_sequence;
}

bool GridShouldPrintTerminalEvent(const string label)
{
  return (label == "SIGNAL_INIT" ||
          label == "LEVEL_REACHED" ||
          label == "LEVEL_TP_HIT" ||
          label == "INITIAL_TP_TRAILING_ARMED" ||
          label == "INITIAL_TP_TRAILING_PARTIAL" ||
          label == "INITIAL_TP_TRAILING_SIGNAL_CLOSED" ||
          label == "INITIAL_TP_TRAILING_CLOSE_FAILED" ||
          label == "TRAILING_SL_UPDATE" ||
          label == "TRAILING_TP_UPDATE" ||
          label == "TRAILING_SL_HIT" ||
          label == "TRAILING_TP_HIT" ||
          label == "TRAILING_TP_SIGNAL_CLOSED" ||
          label == "GRID_STOP_LEVEL_LIMIT" ||
          label == "LEVEL_ACTIVATION_FAILED_TARGET_LOT" ||
          label == "LEVEL_ACTIVATION_FAILED_SEND" ||
          label == "LIMIT_EXPIRED_STRUCTURE");
}

void GridLogEvent(const string label,
                  const SignalParams &signal_params,
                  const GridOrderState &order_state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string direction_short = (signal_params.signal_type == BULLISH) ? "B" : "S";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string event_timestamp = TimeToString(TimeCurrent(),
                                        TIME_DATE|TIME_SECONDS);
  string event_timestamp_min = TimeToString(TimeCurrent(),
                                            TIME_DATE|TIME_MINUTES);
  string signal_timestamp = "n/a";
  string signal_timestamp_min = "n/a";
  if(signal_params.entry_time > 0)
  {
    signal_timestamp = TimeToString(signal_params.entry_time,
                                    TIME_DATE|TIME_SECONDS);
    signal_timestamp_min = TimeToString(signal_params.entry_time,
                                        TIME_DATE|TIME_MINUTES);
  }
  string structure_timestamp = "n/a";
  string structure_timestamp_min = "n/a";
  if(signal_params.context_structure_snapshot_time > 0)
  {
    structure_timestamp = TimeToString(signal_params.context_structure_snapshot_time,
                                       TIME_DATE|TIME_SECONDS);
    structure_timestamp_min = TimeToString(signal_params.context_structure_snapshot_time,
                                           TIME_DATE|TIME_MINUTES);
  }
  string structure_audit = GridResolveStructureAuditSummary(signal_params);

  string message = StringFormat("dir=%s|L%d|status=%s|entry_ref=%.5f|next=%.5f|entry=%.5f|stop=%.5f|tp=%.5f|lot=%.2f|event_ts=%s|signal_ts=%s|structure_ts=%s|trail_sl_ts=%s|trail_tp_ts=%s|trail_arm_ts=%s|trail_armed=%s|structure=%s",
                                direction,
                                display_level,
                                EnumToString(order_state.status),
                                order_state.entry_reference_price,
                                order_state.next_level_price,
                                order_state.entry_price,
                                signal_params.trailing_stop_price,
                                order_state.take_profit_price,
                                order_state.lot_size,
                                event_timestamp,
                                signal_timestamp,
                                structure_timestamp,
                                TimeToString(signal_params.trailing_last_sl_structure_time, TIME_DATE|TIME_SECONDS),
                                TimeToString(signal_params.trailing_last_tp_structure_time, TIME_DATE|TIME_SECONDS),
                                TimeToString(signal_params.trailing_structure_arm_time, TIME_DATE|TIME_SECONDS),
                                signal_params.trailing_structure_armed ? "true" : "false",
                                structure_audit);

  if(Enable_File_Logs)
    AppendTimestampedLog("query_debug.txt", label, message);

  if(Enable_Logs && GridShouldPrintTerminalEvent(label))
  {
    PrintFormat("[%s] %s L%d ev=%s sg=%s st=%s",
                label,
                direction_short,
                display_level,
                event_timestamp_min,
                signal_timestamp_min,
                structure_timestamp_min);
    PrintFormat("[STRUCT] %s", structure_audit);
  }
}

void GridLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const string reason)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string message = StringFormat("dir=%s|L%d|status=%s|reason=%s",
                                direction,
                                display_level,
                                EnumToString(order_state.status),
                                reason);
  AppendTimestampedLog("query_debug.txt", label, message);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
