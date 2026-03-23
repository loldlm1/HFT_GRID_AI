//+------------------------------------------------------------------+
//|                 trading_management/trailing_structure_context.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_TRAILING_STRUCTURE_CONTEXT_MQH_
#define _SERVICES_TRADING_MANAGEMENT_TRAILING_STRUCTURE_CONTEXT_MQH_

TrailingStructureModes g_trailing_structure_mode_runtime = TRAILING_OFF;
bool g_trailing_structure_mode_runtime_override = false;
double g_trailing_tp_close_percent_runtime = 0.0;
bool g_trailing_tp_close_percent_runtime_override = false;

inline TrailingStructureModes ResolveTrailingStructureModeValue(const TrailingStructureModes mode)
{
  if(mode == TRAILING_BY_STRUCTURE ||
     mode == TRAILING_BY_STRUCTURE_TP_BE ||
     mode == TRAILING_BY_STRUCTURE_WHEN_TP)
  {
    return mode;
  }

  return TRAILING_OFF;
}

inline double ResolveTrailingTpClosePercentValue(const double value)
{
  if(!MathIsValidNumber(value))
    return 0.0;

  if(value < 0.0)
    return 0.0;
  if(value > 100.0)
    return 100.0;

  return value;
}

inline TrailingStructureModes ResolveTrailingStructureMode()
{
  if(g_trailing_structure_mode_runtime_override)
    return ResolveTrailingStructureModeValue(g_trailing_structure_mode_runtime);

  return ResolveTrailingStructureModeValue(Trailing_Structure_Mode);
}

inline double ResolveTrailingTpClosePercent()
{
  if(g_trailing_tp_close_percent_runtime_override)
    return ResolveTrailingTpClosePercentValue(g_trailing_tp_close_percent_runtime);

  return ResolveTrailingTpClosePercentValue(Trailing_TP_Close_Percent);
}

inline bool StructureTrailingEnabled()
{
  return (ResolveTrailingStructureMode() != TRAILING_OFF);
}

inline bool StructureTrailingConfigured()
{
  return StructureTrailingEnabled();
}

inline bool StructureTrailingRequiresInitialTpArm()
{
  return (ResolveTrailingStructureMode() == TRAILING_BY_STRUCTURE_WHEN_TP);
}

inline bool StructureTrailingActivatesImmediately()
{
  TrailingStructureModes mode = ResolveTrailingStructureMode();
  return (mode == TRAILING_BY_STRUCTURE ||
          mode == TRAILING_BY_STRUCTURE_TP_BE);
}

inline bool StructureTrailingTpBeModeEnabled()
{
  return (ResolveTrailingStructureMode() == TRAILING_BY_STRUCTURE_TP_BE);
}

inline bool StructureTrailingTpCloseEnabled()
{
  return (ResolveTrailingTpClosePercent() > 0.0);
}

inline void SetStructureTrailingRuntime(const TrailingStructureModes mode,
                                        const double tp_close_percent)
{
  g_trailing_structure_mode_runtime = mode;
  g_trailing_structure_mode_runtime_override = true;
  g_trailing_tp_close_percent_runtime = tp_close_percent;
  g_trailing_tp_close_percent_runtime_override = true;
}

inline void ClearStructureTrailingRuntimeOverride()
{
  g_trailing_structure_mode_runtime_override = false;
  g_trailing_tp_close_percent_runtime_override = false;
}

#endif // _SERVICES_TRADING_MANAGEMENT_TRAILING_STRUCTURE_CONTEXT_MQH_
