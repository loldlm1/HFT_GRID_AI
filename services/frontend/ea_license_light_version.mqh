
//+------------------------------------------------------------------+
//|                         ea_license_light_version.mqh            |
//+------------------------------------------------------------------+
#ifndef _SERVICES_FRONTEND_EA_LICENSE_LIGHT_VERSION_MQH_
#define _SERVICES_FRONTEND_EA_LICENSE_LIGHT_VERSION_MQH_

//+------------------------------------------------------------------+
//| Create the License panel                                         |
//+------------------------------------------------------------------+
void CreateLicensePanelLive()
{
  ResetLightweightUiCache();
}

void CreateEATitleBar()
{
  ResetLightweightUiCache();
}

void UpdateEARunningMagic()
{
  ResetLightweightUiCache();
}

int ChartWindowPosition()
{
  int     eas_total   = 1;
  long    chartID      = ChartFirst();

  if(chartID == ChartID()) return 1;

  while(chartID > 0)
  {
    chartID    = ChartNext(chartID);
    eas_total += 1;

    if(chartID == ChartID()) break;
    if(chartID <= 0) break;
  }

  return eas_total;
}

#endif // _SERVICES_FRONTEND_EA_LICENSE_LIGHT_VERSION_MQH_
