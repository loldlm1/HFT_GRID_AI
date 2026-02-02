//+------------------------------------------------------------------+
//|                                                         Edit.mqh |
//|                             Copyright 2000-2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "WndObj.mqh"
#include <ChartObjects\ChartObjectsTxtControls.mqh>
//+------------------------------------------------------------------+
//| Class CEditPS                                                      |
//| Usage: control that is displayed by                              |
//|             the CChartObjectEdit object                          |
//+------------------------------------------------------------------+
class CEditPS : public CWndObj
  {
private:
   CChartObjectEdit  m_edit;                // chart object
   //--- parameters of the chart object
   bool              m_read_only;           // "read-only" mode flag
   ENUM_ALIGN_MODE   m_align_mode;          // align mode

public:
                     CEditPS(void);
                    ~CEditPS(void);
   //--- create
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   //--- chart event handler
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   //--- parameters of the chart object
   bool              ReadOnly(void)         const { return(m_read_only);                          }
   bool              ReadOnly(const bool flag);
   ENUM_ALIGN_MODE   TextAlign(void)        const { return(m_align_mode);                         }
   bool              TextAlign(const ENUM_ALIGN_MODE align);
   //--- data access
   string            Text(void)             const { return(m_edit.Description());                 }
   bool              Text(const string value)     { return(CWndObj::Text(value));                 }

protected:
   //--- handlers of object events
   virtual bool      OnObjectEndEdit(void);
   //--- handlers of object settings
   virtual bool      OnSetText(void)              { return(m_edit.Description(m_text));           }
   virtual bool      OnSetColor(void)             { return(m_edit.Color(m_color));                }
   virtual bool      OnSetColorBackground(void)   { return(m_edit.BackColor(m_color_background)); }
   virtual bool      OnSetColorBorder(void)       { return(m_edit.BorderColor(m_color_border));   }
   virtual bool      OnSetFont(void)              { return(m_edit.Font(m_font));                  }
   virtual bool      OnSetFontSize(void)          { return(m_edit.FontSize(m_font_size));         }
   virtual bool      OnSetZOrder(void)            { return(m_edit.Z_Order(m_zorder));             }
   //--- internal event handlers
   virtual bool      OnCreate(void);
   virtual bool      OnShow(void);
   virtual bool      OnHide(void);
   virtual bool      OnMove(void);
   virtual bool      OnResize(void);
   virtual bool      OnChange(void);
   virtual bool      OnClick(void);
  };
//+------------------------------------------------------------------+
//| Common handler of chart events                                   |
//+------------------------------------------------------------------+
bool CEditPS::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(m_name==sparam && id==CHARTEVENT_OBJECT_ENDEDIT)
      return(OnObjectEndEdit());
//--- event was not handled
   return(CWndObj::OnEvent(id,lparam,dparam,sparam));
  }
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEditPS::CEditPS(void) : m_read_only(false),
                     m_align_mode(ALIGN_LEFT)
  {
   m_color           =CONTROLS_EDIT_COLOR;
   m_color_background=CONTROLS_EDIT_COLOR_BG;
   m_color_border    =CONTROLS_EDIT_COLOR_BORDER;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEditPS::~CEditPS(void)
  {
  }
//+------------------------------------------------------------------+
//| Create a control                                                 |
//+------------------------------------------------------------------+
bool CEditPS::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
//--- call method of the parent class
   if(!CWndObj::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
//--- create the chart object
   if(!m_edit.Create(chart,name,subwin,x1,y1,Width(),Height()))
      return(false);
//--- call the settings handler
   return(OnChange());
  }
//+------------------------------------------------------------------+
//| Set parameter                                                    |
//+------------------------------------------------------------------+
bool CEditPS::ReadOnly(const bool flag)
  {
//--- save new value of parameter
   m_read_only=flag;
//--- set up the chart object
   return(m_edit.ReadOnly(flag));
  }
//+------------------------------------------------------------------+
//| Set parameter                                                    |
//+------------------------------------------------------------------+
bool CEditPS::TextAlign(const ENUM_ALIGN_MODE align)
  {
//--- save new value of parameter
   m_align_mode=align;
//--- set up the chart object
   return(m_edit.TextAlign(align));
  }
//+------------------------------------------------------------------+
//| Create object on chart                                           |
//+------------------------------------------------------------------+
bool CEditPS::OnCreate(void)
  {
//--- create the chart object by previously set parameters
   return(m_edit.Create(m_chart_id,m_name,m_subwin,m_rect.left,m_rect.top,m_rect.Width(),m_rect.Height()));
  }
//+------------------------------------------------------------------+
//| Display object on chart                                          |
//+------------------------------------------------------------------+
bool CEditPS::OnShow(void)
  {
   if(m_edit.Name() == "Profit Secured FX Status")
   {
     iso_psfx_logo._Show();
     typo_psfx_logo._Show();
   }

   return(m_edit.Timeframes(OBJ_ALL_PERIODS));
  }
//+------------------------------------------------------------------+
//| Hide object from chart                                           |
//+------------------------------------------------------------------+
bool CEditPS::OnHide(void)
  {
   if(m_edit.Name() == "Profit Secured FX Status")
   {
     iso_psfx_logo._Hide();
     typo_psfx_logo._Hide();
   }

   return(m_edit.Timeframes(OBJ_NO_PERIODS));
  }
//+------------------------------------------------------------------+
//| Absolute movement of the chart object                            |
//+------------------------------------------------------------------+
bool CEditPS::OnMove(void)
  {
//--- position the chart object
   return(m_edit.X_Distance(m_rect.left) && m_edit.Y_Distance(m_rect.top));
  }
//+------------------------------------------------------------------+
//| Resize the chart object                                          |
//+------------------------------------------------------------------+
bool CEditPS::OnResize(void)
  {
//--- resize the chart object
   return(m_edit.X_Size(m_rect.Width()) && m_edit.Y_Size(m_rect.Height()));
  }
//+------------------------------------------------------------------+
//| Set up the chart object                                          |
//+------------------------------------------------------------------+
bool CEditPS::OnChange(void)
  {
//--- set up the chart object
   return(CWndObj::OnChange() && ReadOnly(m_read_only) && TextAlign(m_align_mode));
  }
//+------------------------------------------------------------------+
//| Handler of the "End of editing" event                            |
//+------------------------------------------------------------------+
bool CEditPS::OnObjectEndEdit(void)
  {
//--- send the ON_END_EDIT notification
   EventChartCustom(CONTROLS_SELF_MESSAGE,ON_END_EDIT,m_id,0.0,m_name);
//--- handled
   return(true);
  }
//+------------------------------------------------------------------+
//| Handler of the "click" event                                     |
//+------------------------------------------------------------------+
bool CEditPS::OnClick(void)
  {
//--- if editing is enabled, send the ON_START_EDIT notification
   if(!m_read_only)
     {
      EventChartCustom(CONTROLS_SELF_MESSAGE,ON_START_EDIT,m_id,0.0,m_name);
      //--- handled
      return(true);
     }
//--- else send the ON_CLICK notification
   return(CWnd::OnClick());
  }
//+------------------------------------------------------------------+
