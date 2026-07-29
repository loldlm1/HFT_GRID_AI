#ifndef _SERVICES_FRONTEND_EXECUTION_VISUAL_LINES_MQH_
#define _SERVICES_FRONTEND_EXECUTION_VISUAL_LINES_MQH_

void UpdateHorizontalLine(const long chart_id,
                          const string name,
                          const color line_color,
                          const double price,
                          const string label_text = "",
                          const int line_style = STYLE_DASH,
                          const int line_width = 1)
{
  if(!FrontendChartWorkEnabled())
    return;

  if(price <= 0.0)
  {
    if(ObjectFind(chart_id, name) >= 0)
      ObjectDelete(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
  {
    ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
  }

  ObjectSetDouble(chart_id, name, OBJPROP_PRICE, price);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, line_color);
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, line_style);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, line_width);
  string resolved_label = label_text;
  if(resolved_label == "")
    resolved_label = name;
  ObjectSetString(chart_id, name, OBJPROP_TEXT, resolved_label);
}

void UpdateTrackedLine(const long chart_id,
                       const string name,
                       const color line_color,
                       const double price,
                       string &tracked_objects[],
                       const string label_text = "",
                       const int line_style = STYLE_DASH,
                       const int line_width = 1)
{
  UpdateHorizontalLine(chart_id, name, line_color, price, label_text, line_style, line_width);
  if(price <= 0.0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

#endif // _SERVICES_FRONTEND_EXECUTION_VISUAL_LINES_MQH_
