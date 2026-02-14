//+------------------------------------------------------------------+
//|                           structure_compound_modes.mqh          |
//| Compound structure template resolution + parity-aware matching.  |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_STRUCTURE_COMPOUND_MODES_MQH_
#define _SERVICES_TRADING_SIGNALS_STRUCTURE_COMPOUND_MODES_MQH_

const int STRUCTURE_COMPOUND_SLOT_TOTAL = 4;

OscillatorStructureTypes ResolveParityTwinStructureType(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HL:
      return OSCILLATOR_STRUCTURE_HH;
    case OSCILLATOR_STRUCTURE_LL:
      return OSCILLATOR_STRUCTURE_LH;
    case OSCILLATOR_STRUCTURE_HH:
      return OSCILLATOR_STRUCTURE_HL;
    case OSCILLATOR_STRUCTURE_LH:
      return OSCILLATOR_STRUCTURE_LL;
    default:
      return OSCILLATOR_STRUCTURE_EQ;
  }
}

void ResolveParityTwinSlots(const OscillatorStructureTypes first,
                            const OscillatorStructureTypes second,
                            const OscillatorStructureTypes third,
                            const OscillatorStructureTypes fourth,
                            OscillatorStructureTypes &first_out,
                            OscillatorStructureTypes &second_out,
                            OscillatorStructureTypes &third_out,
                            OscillatorStructureTypes &fourth_out)
{
  first_out  = ResolveParityTwinStructureType(first);
  second_out = ResolveParityTwinStructureType(second);
  third_out  = ResolveParityTwinStructureType(third);
  fourth_out = ResolveParityTwinStructureType(fourth);
}

bool ResolveStructureCompoundCanonicalTemplate(const TrendStructureCompoundModes mode,
                                               OscillatorStructureTypes &first_out,
                                               OscillatorStructureTypes &second_out,
                                               OscillatorStructureTypes &third_out,
                                               OscillatorStructureTypes &fourth_out)
{
  first_out  = OSCILLATOR_STRUCTURE_EQ;
  second_out = OSCILLATOR_STRUCTURE_EQ;
  third_out  = OSCILLATOR_STRUCTURE_EQ;
  fourth_out = OSCILLATOR_STRUCTURE_EQ;

  switch(mode)
  {
    case COMPOUND_MODE_TREND_RIDE_BUY:
      first_out  = OSCILLATOR_STRUCTURE_HL;
      second_out = OSCILLATOR_STRUCTURE_HH;
      third_out  = OSCILLATOR_STRUCTURE_HL;
      fourth_out = OSCILLATOR_STRUCTURE_HH;
      return true;
    case COMPOUND_MODE_TREND_RIDE_SELL:
      first_out  = OSCILLATOR_STRUCTURE_LL;
      second_out = OSCILLATOR_STRUCTURE_LH;
      third_out  = OSCILLATOR_STRUCTURE_LL;
      fourth_out = OSCILLATOR_STRUCTURE_LH;
      return true;
    case COMPOUND_MODE_PULLBACK_CONTINUE_BUY:
      first_out  = OSCILLATOR_STRUCTURE_HL;
      second_out = OSCILLATOR_STRUCTURE_HH;
      third_out  = OSCILLATOR_STRUCTURE_LL;
      fourth_out = OSCILLATOR_STRUCTURE_LH;
      return true;
    case COMPOUND_MODE_PULLBACK_CONTINUE_SELL:
      first_out  = OSCILLATOR_STRUCTURE_LL;
      second_out = OSCILLATOR_STRUCTURE_LH;
      third_out  = OSCILLATOR_STRUCTURE_HL;
      fourth_out = OSCILLATOR_STRUCTURE_HH;
      return true;
    case COMPOUND_MODE_REVERSAL_EARLY_BUY:
      first_out  = OSCILLATOR_STRUCTURE_HL;
      second_out = OSCILLATOR_STRUCTURE_LH;
      third_out  = OSCILLATOR_STRUCTURE_LL;
      fourth_out = OSCILLATOR_STRUCTURE_LH;
      return true;
    case COMPOUND_MODE_REVERSAL_EARLY_SELL:
      first_out  = OSCILLATOR_STRUCTURE_LH;
      second_out = OSCILLATOR_STRUCTURE_HL;
      third_out  = OSCILLATOR_STRUCTURE_HH;
      fourth_out = OSCILLATOR_STRUCTURE_HL;
      return true;
    case COMPOUND_MODE_BREAKOUT_READY_BUY:
      first_out  = OSCILLATOR_STRUCTURE_HL;
      second_out = OSCILLATOR_STRUCTURE_HH;
      third_out  = OSCILLATOR_STRUCTURE_EQ;
      fourth_out = OSCILLATOR_STRUCTURE_EQ;
      return true;
    case COMPOUND_MODE_BREAKOUT_READY_SELL:
      first_out  = OSCILLATOR_STRUCTURE_LL;
      second_out = OSCILLATOR_STRUCTURE_LH;
      third_out  = OSCILLATOR_STRUCTURE_EQ;
      fourth_out = OSCILLATOR_STRUCTURE_EQ;
      return true;
    case COMPOUND_MODE_BREAKOUT_FOLLOW_BUY:
      first_out  = OSCILLATOR_STRUCTURE_EQ;
      second_out = OSCILLATOR_STRUCTURE_EQ;
      third_out  = OSCILLATOR_STRUCTURE_HL;
      fourth_out = OSCILLATOR_STRUCTURE_HH;
      return true;
    case COMPOUND_MODE_BREAKOUT_FOLLOW_SELL:
      first_out  = OSCILLATOR_STRUCTURE_EQ;
      second_out = OSCILLATOR_STRUCTURE_EQ;
      third_out  = OSCILLATOR_STRUCTURE_LH;
      fourth_out = OSCILLATOR_STRUCTURE_LL;
      return true;
    case COMPOUND_MODE_CHOP_GUARD:
      first_out  = OSCILLATOR_STRUCTURE_HL;
      second_out = OSCILLATOR_STRUCTURE_LH;
      third_out  = OSCILLATOR_STRUCTURE_HL;
      fourth_out = OSCILLATOR_STRUCTURE_LH;
      return true;
    case COMPOUND_MODE_VOLATILITY_TRAP:
      first_out  = OSCILLATOR_STRUCTURE_LL;
      second_out = OSCILLATOR_STRUCTURE_HH;
      third_out  = OSCILLATOR_STRUCTURE_LL;
      fourth_out = OSCILLATOR_STRUCTURE_HH;
      return true;
    case COMPOUND_MODE_COMPRESSION_WAIT:
      first_out  = OSCILLATOR_STRUCTURE_EQ;
      second_out = OSCILLATOR_STRUCTURE_EQ;
      third_out  = OSCILLATOR_STRUCTURE_EQ;
      fourth_out = OSCILLATOR_STRUCTURE_EQ;
      return true;
    default:
      return false;
  }
}

bool StructureCompoundSlotMatches(const OscillatorStructureTypes expected,
                                  const OscillatorStructureTypes actual)
{
  if(expected == OSCILLATOR_STRUCTURE_EQ)
    return (actual == OSCILLATOR_STRUCTURE_EQ);

  if(actual == OSCILLATOR_STRUCTURE_EQ)
    return false;

  return (actual == expected);
}

bool StructureCompoundTemplateMatches(const OscillatorStructureTypes actual_first,
                                      const OscillatorStructureTypes actual_second,
                                      const OscillatorStructureTypes actual_third,
                                      const OscillatorStructureTypes actual_fourth,
                                      const OscillatorStructureTypes expected_first,
                                      const OscillatorStructureTypes expected_second,
                                      const OscillatorStructureTypes expected_third,
                                      const OscillatorStructureTypes expected_fourth)
{
  return StructureCompoundSlotMatches(expected_first, actual_first)   &&
         StructureCompoundSlotMatches(expected_second, actual_second) &&
         StructureCompoundSlotMatches(expected_third, actual_third)   &&
         StructureCompoundSlotMatches(expected_fourth, actual_fourth);
}

bool ResolveStructureCompoundSnapshotSlots(const StochasticMarketStructure &structure,
                                           OscillatorStructureTypes &first_out,
                                           OscillatorStructureTypes &second_out,
                                           OscillatorStructureTypes &third_out,
                                           OscillatorStructureTypes &fourth_out)
{
  first_out  = OSCILLATOR_STRUCTURE_EQ;
  second_out = OSCILLATOR_STRUCTURE_EQ;
  third_out  = OSCILLATOR_STRUCTURE_EQ;
  fourth_out = OSCILLATOR_STRUCTURE_EQ;

  if(ArraySize(structure.os_market_structures) < STRUCTURE_COMPOUND_SLOT_TOTAL)
    return false;

  first_out  = structure.first_structure_type;
  second_out = structure.second_structure_type;
  third_out  = structure.third_structure_type;
  fourth_out = structure.fourth_structure_type;
  return true;
}

bool EvaluateStructureCompoundMode(const StochasticMarketStructure &structure,
                                   const TrendStructureCompoundModes mode)
{
  if(mode == COMPOUND_MODE_OFF)
    return true;

  OscillatorStructureTypes actual_first = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes actual_second = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes actual_third = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes actual_fourth = OSCILLATOR_STRUCTURE_EQ;
  if(!ResolveStructureCompoundSnapshotSlots(structure,
                                            actual_first,
                                            actual_second,
                                            actual_third,
                                            actual_fourth))
    return false;

  OscillatorStructureTypes expected_first = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_second = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_third = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_fourth = OSCILLATOR_STRUCTURE_EQ;
  if(!ResolveStructureCompoundCanonicalTemplate(mode,
                                                expected_first,
                                                expected_second,
                                                expected_third,
                                                expected_fourth))
    return false;

  if(StructureCompoundTemplateMatches(actual_first,
                                      actual_second,
                                      actual_third,
                                      actual_fourth,
                                      expected_first,
                                      expected_second,
                                      expected_third,
                                      expected_fourth))
    return true;

  OscillatorStructureTypes twin_first = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes twin_second = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes twin_third = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes twin_fourth = OSCILLATOR_STRUCTURE_EQ;
  ResolveParityTwinSlots(expected_first,
                         expected_second,
                         expected_third,
                         expected_fourth,
                         twin_first,
                         twin_second,
                         twin_third,
                         twin_fourth);

  return StructureCompoundTemplateMatches(actual_first,
                                          actual_second,
                                          actual_third,
                                          actual_fourth,
                                          twin_first,
                                          twin_second,
                                          twin_third,
                                          twin_fourth);
}

#endif // _SERVICES_TRADING_SIGNALS_STRUCTURE_COMPOUND_MODES_MQH_
