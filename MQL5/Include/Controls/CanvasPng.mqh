//+------------------------------------------------------------------+
//|                                                         Edit.mqh |
//|                             Copyright 2000-2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "WndObj.mqh"
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <Canvas\png.mqh>
#include <Canvas\iCanvas_CB.mqh> // https://www.mql5.com/ru/code/22164
#resource "//Images//perfil_completo.png" as uchar psfx_completo_data[]
//+------------------------------------------------------------------+
//| Class CCanvasPng                                                      |
//| Usage: control that is displayed by                              |
//|             the CChartObjectEdit object                          |
//+------------------------------------------------------------------+
class CCanvasPng : public CWndObj
  {
private:
   CPng logo_completo(psfx_completo_data); // Get the PNG from the resource, unpack it into a bitmap array bmp[] and don't create the canvas yet
   //--- parameters of the chart object
   bool              m_read_only;           // "read-only" mode flag
   ENUM_ALIGN_MODE   m_align_mode;          // align mode

public:
                     CCanvasPng(void);
                    ~CCanvasPng(void);
   //--- create
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   //--- chart event handler
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   //--- parameters of the chart object

protected:
   //--- internal event handlers
   virtual bool      OnCreate(void);
   virtual bool      OnShow(void);
   virtual bool      OnHide(void);
   virtual bool      OnMove(void);
  };
//+------------------------------------------------------------------+
//| Common handler of chart events                                   |
//+------------------------------------------------------------------+
bool CCanvasPng::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   return(CWndObj::OnEvent(id,lparam,dparam,sparam));
  }
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCanvasPng::CCanvasPng(void) : m_read_only(false)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCanvasPng::~CCanvasPng(void)
  {
  }
//+------------------------------------------------------------------+
//| Create a control                                                 |
//+------------------------------------------------------------------+
bool CCanvasPng::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
//--- call method of the parent class
   if(!CWndObj::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
//--- create the chart object
   if(!logo_completo._CreateCanvas(chart,name,subwin,x1,y1))
      return(false);
//--- call the settings handler
   return(OnChange());
  }

//+------------------------------------------------------------------+
//| Create object on chart                                           |
//+------------------------------------------------------------------+
bool CCanvasPng::OnCreate(void)
  {
//--- create the chart object by previously set parameters
   return(logo_completo._CreateCanvas(m_chart_id,m_name,m_subwin,m_rect.left,m_rect.top));
  }
//+------------------------------------------------------------------+
//| Display object on chart                                          |
//+------------------------------------------------------------------+
bool CCanvasPng::OnShow(void)
  {
   return(logo_completo._Show());
  }
//+------------------------------------------------------------------+
//| Hide object from chart                                           |
//+------------------------------------------------------------------+
bool CCanvasPng::OnHide(void)
  {
   return(logo_completo._Hide());
  }
//+------------------------------------------------------------------+
//| Absolute movement of the chart object                            |
//+------------------------------------------------------------------+
bool CCanvasPng::OnMove(void)
  {
//--- position the chart object
   return(logo_completo._MoveCanvas(m_rect.left, m_rect.top));
  }
//+------------------------------------------------------------------+
