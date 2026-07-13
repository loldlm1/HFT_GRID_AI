#ifndef _MICROSERVICES_FRONTEND_CHART_PANEL_UTILS_MQH_
#define _MICROSERVICES_FRONTEND_CHART_PANEL_UTILS_MQH_

void DeleteChartObjectIfExists(const long chart_id,
                               const string name)
{
  if(ObjectFind(chart_id, name) >= 0)
    ObjectDelete(chart_id, name);
}

void UpdateCornerRectangleLabel(const long chart_id,
                                const string name,
                                const int corner,
                                const int x_distance,
                                const int y_distance,
                                const int x_size,
                                const int y_size,
                                const color background_color,
                                const color border_color)
{
  if(x_size <= 0 || y_size <= 0)
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

  ObjectSetInteger(chart_id, name, OBJPROP_CORNER, corner);
  ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x_distance);
  ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y_distance);
  ObjectSetInteger(chart_id, name, OBJPROP_XSIZE, x_size);
  ObjectSetInteger(chart_id, name, OBJPROP_YSIZE, y_size);
  ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR, background_color);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, border_color);
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, STYLE_SOLID);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedCornerRectangleLabel(const long chart_id,
                                       const string name,
                                       const int corner,
                                       const int x_distance,
                                       const int y_distance,
                                       const int x_size,
                                       const int y_size,
                                       const color background_color,
                                       const color border_color,
                                       string &tracked_objects[])
{
  UpdateCornerRectangleLabel(chart_id,
                             name,
                             corner,
                             x_distance,
                             y_distance,
                             x_size,
                             y_size,
                             background_color,
                             border_color);
  if(x_size <= 0 || y_size <= 0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

void UpdateCornerLabel(const long chart_id,
                       const string name,
                       const int corner,
                       const int x_distance,
                       const int y_distance,
                       const string text,
                       const string font_name,
                       const int font_size,
                       const color text_color)
{
  if(text == "")
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_LABEL, 0, 0, 0);

  ObjectSetInteger(chart_id, name, OBJPROP_CORNER, corner);
  ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x_distance);
  ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y_distance);
  ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
  ObjectSetString(chart_id, name, OBJPROP_FONT, font_name);
  ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, font_size);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, text_color);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedCornerLabel(const long chart_id,
                              const string name,
                              const int corner,
                              const int x_distance,
                              const int y_distance,
                              const string text,
                              const string font_name,
                              const int font_size,
                              const color text_color,
                              string &tracked_objects[])
{
  UpdateCornerLabel(chart_id,
                    name,
                    corner,
                    x_distance,
                    y_distance,
                    text,
                    font_name,
                    font_size,
                    text_color);
  if(text == "")
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

void UpdateTimePriceRectangle(const long chart_id,
                              const string name,
                              const datetime time_start,
                              const double price_high,
                              const datetime time_end,
                              const double price_low,
                              const color fill_color,
                              const int line_style = STYLE_SOLID,
                              const int line_width = 1)
{
  if(time_start <= 0 || time_end <= 0 || price_high <= 0.0 || price_low <= 0.0)
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_RECTANGLE, 0, time_start, price_high, time_end, price_low);

  ObjectMove(chart_id, name, 0, time_start, price_high);
  ObjectMove(chart_id, name, 1, time_end, price_low);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, fill_color);
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, line_style);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, line_width);
  ObjectSetInteger(chart_id, name, OBJPROP_FILL, true);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedTimePriceRectangle(const long chart_id,
                                     const string name,
                                     const datetime time_start,
                                     const double price_high,
                                     const datetime time_end,
                                     const double price_low,
                                     const color fill_color,
                                     string &tracked_objects[],
                                     const int line_style = STYLE_SOLID,
                                     const int line_width = 1)
{
  UpdateTimePriceRectangle(chart_id,
                           name,
                           time_start,
                           price_high,
                           time_end,
                           price_low,
                           fill_color,
                           line_style,
                           line_width);
  if(time_start <= 0 || time_end <= 0 || price_high <= 0.0 || price_low <= 0.0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

void UpdateTimePriceText(const long chart_id,
                         const string name,
                         const datetime label_time,
                         const double label_price,
                         const string text,
                         const string font_name,
                         const int font_size,
                         const color text_color)
{
  if(label_time <= 0 || label_price <= 0.0 || text == "")
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_TEXT, 0, label_time, label_price);

  ObjectMove(chart_id, name, 0, label_time, label_price);
  ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
  ObjectSetString(chart_id, name, OBJPROP_FONT, font_name);
  ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, font_size);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, text_color);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedTimePriceText(const long chart_id,
                                const string name,
                                const datetime label_time,
                                const double label_price,
                                const string text,
                                const string font_name,
                                const int font_size,
                                const color text_color,
                                string &tracked_objects[])
{
  UpdateTimePriceText(chart_id,
                      name,
                      label_time,
                      label_price,
                      text,
                      font_name,
                      font_size,
                      text_color);
  if(label_time <= 0 || label_price <= 0.0 || text == "")
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

void UpdateTimePriceArrow(const long chart_id,
                          const string name,
                          const datetime arrow_time,
                          const double arrow_price,
                          const int arrow_code,
                          const color arrow_color,
                          const int arrow_width = 1)
{
  if(arrow_time <= 0 || arrow_price <= 0.0)
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_ARROW, 0, arrow_time, arrow_price);

  ObjectMove(chart_id, name, 0, arrow_time, arrow_price);
  ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, arrow_code);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, arrow_color);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, arrow_width);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedTimePriceArrow(const long chart_id,
                                 const string name,
                                 const datetime arrow_time,
                                 const double arrow_price,
                                 const int arrow_code,
                                 const color arrow_color,
                                 string &tracked_objects[],
                                 const int arrow_width = 1)
{
  UpdateTimePriceArrow(chart_id,
                       name,
                       arrow_time,
                       arrow_price,
                       arrow_code,
                       arrow_color,
                       arrow_width);
  if(arrow_time <= 0 || arrow_price <= 0.0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

void UpdateTimePriceSegment(const long chart_id,
                            const string name,
                            const datetime time_start,
                            const double price_start,
                            const datetime time_end,
                            const double price_end,
                            const color line_color,
                            const int line_style = STYLE_DOT,
                            const int line_width = 1)
{
  if(time_start <= 0 || time_end <= 0 || price_start <= 0.0 || price_end <= 0.0)
  {
    DeleteChartObjectIfExists(chart_id, name);
    return;
  }

  if(ObjectFind(chart_id, name) < 0)
    ObjectCreate(chart_id, name, OBJ_TREND, 0, time_start, price_start, time_end, price_end);

  ObjectMove(chart_id, name, 0, time_start, price_start);
  ObjectMove(chart_id, name, 1, time_end, price_end);
  ObjectSetInteger(chart_id, name, OBJPROP_COLOR, line_color);
  ObjectSetInteger(chart_id, name, OBJPROP_STYLE, line_style);
  ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, line_width);
  ObjectSetInteger(chart_id, name, OBJPROP_RAY_RIGHT, false);
  ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
}

void UpdateTrackedTimePriceSegment(const long chart_id,
                                   const string name,
                                   const datetime time_start,
                                   const double price_start,
                                   const datetime time_end,
                                   const double price_end,
                                   const color line_color,
                                   string &tracked_objects[],
                                   const int line_style = STYLE_DOT,
                                   const int line_width = 1)
{
  UpdateTimePriceSegment(chart_id,
                         name,
                         time_start,
                         price_start,
                         time_end,
                         price_end,
                         line_color,
                         line_style,
                         line_width);
  if(time_start <= 0 || time_end <= 0 || price_start <= 0.0 || price_end <= 0.0)
    return;
  if(!ContainsObjectName(tracked_objects, name))
    PushObjectName(tracked_objects, name);
}

#endif // _MICROSERVICES_FRONTEND_CHART_PANEL_UTILS_MQH_
