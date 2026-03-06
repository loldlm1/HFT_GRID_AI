#ifndef _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_LICENSE_FOOTER_MQH_
#define _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_LICENSE_FOOTER_MQH_

const string LICENSE_SHARED_FOOTER_TEXT_OBJECT = "LICENSE_SHARED_FOOTER_TEXT_V1";
const string LICENSE_SHARED_FOOTER_LOGO_OBJECT = "LICENSE_SHARED_FOOTER_LOGO_V1";
const string LICENSE_SHARED_FOOTER_FALLBACK_URL = "https://t.me/loldlm";
const string LICENSE_SHARED_FOOTER_BITMAP_RESOURCE = "::images\\logo_oficial.bmp";
const string LICENSE_SHARED_FOOTER_FONT = "Consolas";
const int LICENSE_SHARED_FOOTER_INSET_X = 12;
const int LICENSE_SHARED_FOOTER_INSET_Y = 12;
const int LICENSE_SHARED_FOOTER_GAP = 8;
const int LICENSE_SHARED_FOOTER_BITMAP_SIZE = 48;
const int LICENSE_SHARED_FOOTER_FONT_SIZE = 8;

string LicenseFooterTrim(const string raw_value)
{
  string value = raw_value;
  StringTrimLeft(value);
  StringTrimRight(value);
  return value;
}

bool LicenseFooterShouldRender()
{
  if(MQLInfoInteger(MQL_OPTIMIZATION) > 0)
    return false;

  if(MQLInfoInteger(MQL_TESTER) > 0 &&
     MQLInfoInteger(MQL_VISUAL_MODE) == 0)
    return false;

  return true;
}

string LicenseFooterResolveDisplayText()
{
  string value = LicenseFooterTrim(LICENSE_SHARED_API_BASE_URL);
  if(value == "")
    return LICENSE_SHARED_FOOTER_FALLBACK_URL;

  StringReplace(value, "\\", "/");

  string lower_value = value;
  StringToLower(lower_value);

  if(StringFind(lower_value, "https://") == 0)
    value = StringSubstr(value, 8);
  else if(StringFind(lower_value, "http://") == 0)
    value = StringSubstr(value, 7);
  else if(StringFind(value, "//") == 0)
    value = StringSubstr(value, 2);

  int separator_at = StringFind(value, "/");
  if(separator_at >= 0)
    value = StringSubstr(value, 0, separator_at);

  separator_at = StringFind(value, "?");
  if(separator_at >= 0)
    value = StringSubstr(value, 0, separator_at);

  separator_at = StringFind(value, "#");
  if(separator_at >= 0)
    value = StringSubstr(value, 0, separator_at);

  separator_at = StringFind(value, ":");
  if(separator_at > 0)
    value = StringSubstr(value, 0, separator_at);

  value = LicenseFooterTrim(value);
  if(value == "")
    return LICENSE_SHARED_FOOTER_FALLBACK_URL;

  return value;
}

color LicenseFooterResolveTextColor(const long chart_id)
{
  long chart_color = 0;
  if(ChartGetInteger(chart_id, CHART_COLOR_FOREGROUND, 0, chart_color))
    return (color)chart_color;

  return clrSilver;
}

void LicenseFooterDeleteObjects(const long chart_id)
{
  ObjectDelete(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT);
  ObjectDelete(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT);
}

bool LicenseFooterEnsureTextObject(const long chart_id,
                                   const string footer_text)
{
  if(ObjectFind(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT) < 0)
  {
    ResetLastError();
    if(!ObjectCreate(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJ_LABEL, 0, 0, 0))
    {
      PrintFormat("[LicenseFooter] Failed to create footer text label (error=%d).",
                  GetLastError());
      return false;
    }
  }

  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
  ObjectSetInteger(chart_id,
                   LICENSE_SHARED_FOOTER_TEXT_OBJECT,
                   OBJPROP_XDISTANCE,
                   LICENSE_SHARED_FOOTER_INSET_X + LICENSE_SHARED_FOOTER_BITMAP_SIZE + LICENSE_SHARED_FOOTER_GAP);
  ObjectSetInteger(chart_id,
                   LICENSE_SHARED_FOOTER_TEXT_OBJECT,
                   OBJPROP_YDISTANCE,
                   LICENSE_SHARED_FOOTER_INSET_Y + LICENSE_SHARED_FOOTER_BITMAP_SIZE / 2);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_ANCHOR, ANCHOR_RIGHT);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_COLOR, LicenseFooterResolveTextColor(chart_id));
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_FONTSIZE, LICENSE_SHARED_FOOTER_FONT_SIZE);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_HIDDEN, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_BACK, false);
  ObjectSetString(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_FONT, LICENSE_SHARED_FOOTER_FONT);
  ObjectSetString(chart_id, LICENSE_SHARED_FOOTER_TEXT_OBJECT, OBJPROP_TEXT, footer_text);
  return true;
}

bool LicenseFooterEnsureLogoObject(const long chart_id)
{
  if(ObjectFind(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT) < 0)
  {
    ResetLastError();
    if(!ObjectCreate(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJ_BITMAP_LABEL, 0, 0, 0))
    {
      PrintFormat("[LicenseFooter] Failed to create footer logo label (error=%d).",
                  GetLastError());
      return false;
    }
  }

  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_XDISTANCE, LICENSE_SHARED_FOOTER_INSET_X);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_YDISTANCE, LICENSE_SHARED_FOOTER_INSET_Y);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_SELECTED, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_HIDDEN, false);
  ObjectSetInteger(chart_id, LICENSE_SHARED_FOOTER_LOGO_OBJECT, OBJPROP_BACK, false);

  ResetLastError();
  if(!ObjectSetString(chart_id,
                      LICENSE_SHARED_FOOTER_LOGO_OBJECT,
                      OBJPROP_BMPFILE,
                      0,
                      LICENSE_SHARED_FOOTER_BITMAP_RESOURCE))
  {
    PrintFormat("[LicenseFooter] Failed to bind footer logo resource (error=%d).",
                GetLastError());
    return false;
  }

  ObjectSetString(chart_id,
                  LICENSE_SHARED_FOOTER_LOGO_OBJECT,
                  OBJPROP_BMPFILE,
                  1,
                  LICENSE_SHARED_FOOTER_BITMAP_RESOURCE);
  return true;
}

void LicenseFooterEnsureVisible()
{
  long chart_id = ChartID();
  if(chart_id <= 0)
    return;

  if(!LicenseFooterShouldRender())
  {
    LicenseFooterDeleteObjects(chart_id);
    return;
  }

  string footer_text = LicenseFooterResolveDisplayText();
  bool text_ok = LicenseFooterEnsureTextObject(chart_id, footer_text);
  bool logo_ok = LicenseFooterEnsureLogoObject(chart_id);

  if(text_ok || logo_ok)
    ChartRedraw(chart_id);
}

void LicenseFooterRemove()
{
  long chart_id = ChartID();
  if(chart_id <= 0)
    return;

  LicenseFooterDeleteObjects(chart_id);
  ChartRedraw(chart_id);
}

#endif // _SERVICES_SHARED_LICENSE_GUARD_V1_CORE_LICENSE_FOOTER_MQH_
