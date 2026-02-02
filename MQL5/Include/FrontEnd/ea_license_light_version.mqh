
//+------------------------------------------------------------------+
//| Create the License panel                                         |
//+------------------------------------------------------------------+
void CreateLicensePanelLive()
{
  CreateEATitleBar();
}

void CreateEATitleBar()
{
  string ea_running = g_ea_running ? "Enabled" : "Disabled";

  Comment(ea_running + "   /   Magic: " + (string)g_magic_number);
}

void UpdateEARunningMagic()
{
  string ea_running     = g_ea_running ? "Enabled" : "Disabled";
  string running_text   = ea_running + "   /   Magic: " + (string)g_magic_number;

  Comment(running_text);
}

int ChartWindowPosition()
{
	int  	 eas_total	 = 1;
	long 	 chartID 		 = ChartFirst();

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
