#ifndef HFT_GRID_AI_TEST_CASE_STRUCTURE_SNAPSHOT_TIME_MQH
#define HFT_GRID_AI_TEST_CASE_STRUCTURE_SNAPSHOT_TIME_MQH

#include "../framework.mqh"

bool RunTest_structure_snapshot_time_test(string &errors)
{
  errors = "";

  StochasticMarketStructure s;
  s.first_structure_time = D'2026.02.03 00:00';
  s.second_structure_time = D'2026.02.03 01:00';

  datetime resolved = 0;
  if(!ResolveStructureSnapshotTimeForContext(CONTEXT_SLOT_BASE, s, resolved))
  {
    errors += "resolve snapshot time\n";
    return false;
  }

  if(resolved != s.second_structure_time)
    errors += "expected second structure time\n";

  return (errors == "");
}

#endif
