#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_CONTEXT_REQUIREMENTS_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_CONTEXT_REQUIREMENTS_MQH

#include "../framework.mqh"

bool RunTest_structure_context_requirements_test(string &errors)
{
  errors = "";

  StrategyStructureLayerContext base_ctx = BuildBaseStructureLayerContext();
  if(!base_ctx.enabled)
  {
    errors += "base structure context should be enabled\n";
    return false;
  }

  if(!ContextRequiresStructure(CONTEXT_SLOT_BASE, base_ctx))
    errors += "base context should require structure for structure-trigger entries\n";

  StrategyStructureLayerContext disabled_ctx = BuildDisabledStructureLayerContext();
  if(ContextRequiresStructure(CONTEXT_SLOT_BASE, disabled_ctx))
    errors += "disabled context should not require structure\n";

  return (errors == "");
}

#endif
