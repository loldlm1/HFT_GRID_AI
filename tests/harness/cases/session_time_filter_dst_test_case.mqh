#ifndef HFT_GRID_AI_TEST_CASE_SESSION_TIME_FILTER_DST_MQH
#define HFT_GRID_AI_TEST_CASE_SESSION_TIME_FILTER_DST_MQH

#include "../framework.mqh"

bool RunTest_session_time_filter_dst_test(string &errors)
{
  errors = "";

  datetime winter_time = D'2026.01.15 14:30:00';
  datetime summer_time = D'2026.03.15 14:30:00';
  datetime dst_start_time = D'2026.03.08 00:00:00';
  datetime dst_end_time = D'2026.11.01 00:00:00';

  if(ResolveTradingTimeOffsetMinutesForMode(DST_MODE_OFF, 45, winter_time) != 0)
    errors += "off mode should ignore manual offset input\n";

  if(ResolveTradingTimeOffsetMinutesForMode(DST_MODE_MANUAL, 45, winter_time) != 45)
    errors += "manual mode should return configured positive offset\n";

  if(ResolveTradingTimeOffsetMinutesForMode(DST_MODE_MANUAL, -30, winter_time) != -30)
    errors += "manual mode should return configured negative offset\n";

  if(ResolveTradingTimeOffsetMinutesForMode(DST_MODE_AUTO_EXNESS,
                                            0,
                                            winter_time) != 60)
    errors += "exness winter should resolve +60 minutes\n";

  if(ResolveTradingTimeOffsetMinutesForMode(DST_MODE_AUTO_EXNESS,
                                            0,
                                            summer_time) != 0)
    errors += "exness summer should resolve 0 minutes\n";

  if(!ExnessDstActive(dst_start_time))
    errors += "dst should be active from 2026-03-08 00:00:00\n";

  if(ExnessDstActive(dst_end_time))
    errors += "dst should be inactive from 2026-11-01 00:00:00\n";

  if(SessionTimeFilterCurrentMinutesForSettings(winter_time,
                                                DST_MODE_OFF,
                                                120) != (14 * 60 + 30))
    errors += "off mode should preserve current session minutes\n";

  if(SessionTimeFilterCurrentMinutesForSettings(winter_time,
                                                DST_MODE_AUTO_EXNESS,
                                                0) != (13 * 60 + 30))
    errors += "exness winter should shift evaluated minutes back by one hour\n";

  if(SessionTimeFilterCurrentMinutesForSettings(summer_time,
                                                DST_MODE_AUTO_EXNESS,
                                                0) != (14 * 60 + 30))
    errors += "exness summer should preserve evaluated minutes\n";

  if(SessionTimeFilterCurrentMinutesForSettings(winter_time,
                                                DST_MODE_MANUAL,
                                                -30) != (15 * 60))
    errors += "negative manual offset should move evaluated minutes forward\n";

  if(SessionTimeFilterDstStatusSummaryForSettings(DST_MODE_OFF,
                                                  45,
                                                  winter_time) != "OFF (0m)")
    errors += "off summary should stay OFF (0m)\n";

  if(SessionTimeFilterDstStatusSummaryForSettings(DST_MODE_MANUAL,
                                                  -30,
                                                  winter_time) != "MANUAL (-30m)")
    errors += "manual summary should expose signed offset\n";

  if(SessionTimeFilterDstStatusSummaryForSettings(DST_MODE_AUTO_EXNESS,
                                                  0,
                                                  winter_time) != "EXNESS (+60m)")
    errors += "exness winter summary should expose +60m\n";

  if(SessionTimeFilterDstStatusSummaryForSettings(DST_MODE_AUTO_EXNESS,
                                                  0,
                                                  summer_time) != "EXNESS (0m)")
    errors += "exness summer summary should expose 0m\n";

  return (errors == "");
}

#endif
