//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_DASHBOARD_MQH__
#define __IMSF_DASHBOARD_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"
#include "TimeframeManager.mqh"
#include "RiskManager.mqh"
#include "SpreadFilter.mqh"
#include "NewsFilter.mqh"

//+------------------------------------------------------------------+
//| Structure to hold all snapshot metrics displayed on HUD         |
//+------------------------------------------------------------------+
struct SDashboardData
{
   // Basic Info
   string               symbol;
   ENUM_TIMEFRAMES      period;
   double               bid;
   double               ask;
   double               spreadPips;
   string               sessionName;
   bool                 isRollover;

   // MTF Bias & Confluence
   ENUM_TREND_BIAS      macroBias;
   ENUM_TREND_BIAS      setupBias;
   ENUM_TREND_BIAS      triggerBias;
   int                  confluenceScore;
   ENUM_TREND_BIAS      confluenceBias;

   // SMC Metrics
   int                  bullishOBCount;
   int                  bearishOBCount;
   double               nearestBullishOBDistPips; // distance in pips to nearest demand OB below price (>= 0 or -1 if none)
   double               nearestBearishOBDistPips; // distance in pips to nearest supply OB above price (>= 0 or -1 if none)
   int                  bullishFVGCount;
   int                  bearishFVGCount;
   double               nearestBullishFVGDistPips;
   double               nearestBearishFVGDistPips;

   // Account & Risk
   double               balance;
   double               equity;
   double               floatingPnL;
   double               todayClosedPnL;
   double               dailyDrawdownPct;
   double               maxDailyDrawdownPct;
   int                  openPositionsCount;

   // Safeguards
   bool                 isSpreadOk;
   bool                 isNewsClear;
   string               newsStatusText;

   // Default Constructor
   SDashboardData()
   {
      symbol = "";
      period = PERIOD_CURRENT;
      bid = 0.0;
      ask = 0.0;
      spreadPips = 0.0;
      sessionName = "UNKNOWN";
      isRollover = false;
      macroBias = BIAS_NEUTRAL;
      setupBias = BIAS_NEUTRAL;
      triggerBias = BIAS_NEUTRAL;
      confluenceScore = 50;
      confluenceBias = BIAS_NEUTRAL;
      bullishOBCount = 0;
      bearishOBCount = 0;
      nearestBullishOBDistPips = -1.0;
      nearestBearishOBDistPips = -1.0;
      bullishFVGCount = 0;
      bearishFVGCount = 0;
      nearestBullishFVGDistPips = -1.0;
      nearestBearishFVGDistPips = -1.0;
      balance = 0.0;
      equity = 0.0;
      floatingPnL = 0.0;
      todayClosedPnL = 0.0;
      dailyDrawdownPct = 0.0;
      maxDailyDrawdownPct = 3.0;
      openPositionsCount = 0;
      isSpreadOk = true;
      isNewsClear = true;
      newsStatusText = "CLEAR";
   }
};

//+------------------------------------------------------------------+
//| Class CDashboard                                                 |
//| High-DPI compatible, collapsible on-chart institutional HUD       |
//| displaying real-time MTF structure, SMC liquidity targets,        |
//| spread, sessions, risk metrics, and overnight safety guards.     |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   long                 m_chartId;
   string               m_prefix;
   bool                 m_enabled;
   bool                 m_collapsed;
   ENUM_BASE_CORNER     m_corner;
   int                  m_xDist;
   int                  m_yDist;
   double               m_dpiScale;

   // Color Palette (Dark Institutional Slate Theme)
   color                m_clrBg;
   color                m_clrBgHeader;
   color                m_clrBorder;
   color                m_clrTitle;
   color                m_clrSubtitle;
   color                m_clrSecHeader;
   color                m_clrLabel;
   color                m_clrValNeutral;
   color                m_clrValBullish;
   color                m_clrValBearish;
   color                m_clrValWarning;
   color                m_clrValProfitPos;
   color                m_clrValProfitNeg;
   color                m_clrBtnBg;
   color                m_clrBtnText;

   // Cached Last Data for Immediate Re-renders on Event
   SDashboardData       m_lastData;
   bool                 m_hasData;

   // Scaler Helpers for High-DPI Displays (1080p, 1440p, 4K, 8K)
   int Scale(const int val) const
   {
      return (int)MathRound(val * m_dpiScale);
   }

   int GetScaledFontSize(const int basePt) const
   {
      int size = (int)MathRound(basePt * m_dpiScale);
      return (size < 6) ? 6 : size;
   }

   //+------------------------------------------------------------------+
   //| Low-level Object Creation & Update Wrappers                      |
   //+------------------------------------------------------------------+
   void SetRectLabel(const string subName, const int x, const int y,
                     const int width, const int height,
                     const color bgColor, const color borderColor)
   {
      string fullName = m_prefix + subName;
      if(ObjectFind(m_chartId, fullName) < 0)
      {
         ObjectCreate(m_chartId, fullName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTED, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_BACK, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      }
      ObjectSetInteger(m_chartId, fullName, OBJPROP_XDISTANCE, m_xDist + x);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_YDISTANCE, m_yDist + y);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_YSIZE, height);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   void SetLabel(const string subName, const string text, const int x, const int y,
                 const color clr, const int fontSize, const bool bold = false,
                 const bool visible = true)
   {
      string fullName = m_prefix + subName;
      if(ObjectFind(m_chartId, fullName) < 0)
      {
         ObjectCreate(m_chartId, fullName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTED, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_BACK, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
      ObjectSetInteger(m_chartId, fullName, OBJPROP_XDISTANCE, m_xDist + x);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_YDISTANCE, m_yDist + y);
      ObjectSetString(m_chartId, fullName, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
      ObjectSetInteger(m_chartId, fullName, OBJPROP_FONTSIZE, GetScaledFontSize(fontSize));
      ObjectSetString(m_chartId, fullName, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   }

   void SetButton(const string subName, const string text, const int x, const int y,
                  const int width, const int height,
                  const color bgColor, const color textColor)
   {
      string fullName = m_prefix + subName;
      if(ObjectFind(m_chartId, fullName) < 0)
      {
         ObjectCreate(m_chartId, fullName, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_CORNER, m_corner);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_SELECTED, false);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chartId, fullName, OBJPROP_BORDER_COLOR, m_clrBorder);
      }
      ObjectSetInteger(m_chartId, fullName, OBJPROP_XDISTANCE, m_xDist + x);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_YDISTANCE, m_yDist + y);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_YSIZE, height);
      ObjectSetString(m_chartId, fullName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(m_chartId, fullName, OBJPROP_FONTSIZE, GetScaledFontSize(8));
      ObjectSetString(m_chartId, fullName, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_STATE, false);
      ObjectSetInteger(m_chartId, fullName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   //+------------------------------------------------------------------+
   //| Internal Layout Rendering Engine                                 |
   //+------------------------------------------------------------------+
   void Render(const SDashboardData &data)
   {
      if(!m_enabled)
         return;

      int expWidth   = Scale(280);
      int expHeight  = Scale(390);
      int colWidth   = Scale(330);
      int colHeight  = Scale(30);
      int hdrHeight  = Scale(30);

      if(m_collapsed)
      {
         // 1. Collapsed Mode: Single compact pill badge
         SetRectLabel("BG_PANEL", 0, 0, colWidth, colHeight, m_clrBg, m_clrBorder);
         SetRectLabel("BG_HEADER", 0, 0, colWidth, colHeight, m_clrBgHeader, m_clrBorder);

         // Hide expanded title and subtitle
         SetLabel("LBL_TITLE", "", 0, 0, clrNONE, 9, true, false);
         SetLabel("LBL_SUBTITLE", "", 0, 0, clrNONE, 7, false, false);

         // Render compact summary line
         string biasStr = CUtilities::BiasToString(data.confluenceBias);
         color  biasClr = (data.confluenceBias == BIAS_BULLISH) ? m_clrValBullish :
                          ((data.confluenceBias == BIAS_BEARISH) ? m_clrValBearish : m_clrValNeutral);

         string miniText = StringFormat("IMSF | %s %s | %s (%d%%) | Spr: %.1fp",
                                        data.symbol,
                                        CUtilities::PeriodToString(data.period),
                                        biasStr,
                                        data.confluenceScore,
                                        data.spreadPips);

         SetLabel("LBL_MINI", miniText, Scale(8), Scale(7), biasClr, 8, true, true);

         // Expand Button [+]
         SetButton("BTN_TOGGLE", "[+]", colWidth - Scale(26), Scale(5), Scale(20), Scale(20), m_clrBtnBg, m_clrBtnText);

         // Hide all detailed rows
         HideDetailRows();
      }
      else
      {
         // 2. Expanded Mode: Full institutional grid layout
         SetRectLabel("BG_PANEL", 0, 0, expWidth, expHeight, m_clrBg, m_clrBorder);
         SetRectLabel("BG_HEADER", 0, 0, expWidth, hdrHeight, m_clrBgHeader, m_clrBorder);

         // Hide collapsed mini label
         SetLabel("LBL_MINI", "", 0, 0, clrNONE, 8, false, false);

         // Header Branding
         SetLabel("LBL_TITLE", "INSTITUTIONAL SMC", Scale(10), Scale(5), m_clrTitle, 9, true, true);
         string subStr = StringFormat("%s %s | MTF Suite", data.symbol, CUtilities::PeriodToString(data.period));
         SetLabel("LBL_SUBTITLE", subStr, Scale(10), Scale(18), m_clrSubtitle, 7, false, true);

         // Collapse Button [-]
         SetButton("BTN_TOGGLE", "[-]", expWidth - Scale(26), Scale(5), Scale(20), Scale(20), m_clrBtnBg, m_clrBtnText);

         int colKey = Scale(12);
         int colVal = Scale(140);

         // --- Section 1: Market & Sessions ---
         SetLabel("SEC_MKT", "── MARKET & SESSIONS ──", Scale(10), Scale(36), m_clrSecHeader, 7, true, true);

         // Spread
         color spreadClr = (data.spreadPips <= InpMaxSpreadPips) ? m_clrValProfitPos : m_clrValWarning;
         SetLabel("LBL_SPREAD_K", "Live Spread:", colKey, Scale(50), m_clrLabel, 8, false, true);
         SetLabel("LBL_SPREAD_V", StringFormat("%.1f pips", data.spreadPips), colVal, Scale(50), spreadClr, 8, true, true);

         // Session
         SetLabel("LBL_SESS_K", "Active Session:", colKey, Scale(66), m_clrLabel, 8, false, true);
         SetLabel("LBL_SESS_V", data.sessionName, colVal, Scale(66), m_clrValNeutral, 8, false, true);

         // Rollover Guard
         color rollClr = data.isRollover ? m_clrValBearish : m_clrValProfitPos;
         string rollTxt = data.isRollover ? "FREEZE (BLACKOUT)" : "ACTIVE";
         SetLabel("LBL_ROLL_K", "Rollover Guard:", colKey, Scale(82), m_clrLabel, 8, false, true);
         SetLabel("LBL_ROLL_V", rollTxt, colVal, Scale(82), rollClr, 8, true, true);

         // --- Section 2: MTF Structure Matrix ---
         SetLabel("SEC_MTF", "── MTF STRUCTURE MATRIX ──", Scale(10), Scale(102), m_clrSecHeader, 7, true, true);

         // Macro H4
         color macroClr = (data.macroBias == BIAS_BULLISH) ? m_clrValBullish : ((data.macroBias == BIAS_BEARISH) ? m_clrValBearish : m_clrValNeutral);
         SetLabel("LBL_MACRO_K", "Macro Tier (H4):", colKey, Scale(116), m_clrLabel, 8, false, true);
         SetLabel("LBL_MACRO_V", CUtilities::BiasToString(data.macroBias), colVal, Scale(116), macroClr, 8, true, true);

         // Setup H1
         color setupClr = (data.setupBias == BIAS_BULLISH) ? m_clrValBullish : ((data.setupBias == BIAS_BEARISH) ? m_clrValBearish : m_clrValNeutral);
         SetLabel("LBL_SETUP_K", "Setup Tier (H1):", colKey, Scale(132), m_clrLabel, 8, false, true);
         SetLabel("LBL_SETUP_V", CUtilities::BiasToString(data.setupBias), colVal, Scale(132), setupClr, 8, true, true);

         // Trigger Chart
         color trigClr = (data.triggerBias == BIAS_BULLISH) ? m_clrValBullish : ((data.triggerBias == BIAS_BEARISH) ? m_clrValBearish : m_clrValNeutral);
         string trigKey = StringFormat("Trigger (%s):", CUtilities::PeriodToString(data.period));
         SetLabel("LBL_TRIG_K", trigKey, colKey, Scale(148), m_clrLabel, 8, false, true);
         SetLabel("LBL_TRIG_V", CUtilities::BiasToString(data.triggerBias), colVal, Scale(148), trigClr, 8, true, true);

         // Confluence Score
         color confClr = (data.confluenceScore >= 75) ? m_clrValProfitPos : ((data.confluenceScore >= 50) ? m_clrValWarning : m_clrValBearish);
         string confRating = (data.confluenceScore >= 75) ? "HIGH" : ((data.confluenceScore >= 50) ? "MODERATE" : "LOW");
         SetLabel("LBL_CONF_K", "MTF Confluence:", colKey, Scale(164), m_clrLabel, 8, false, true);
         SetLabel("LBL_CONF_V", StringFormat("%d/100 [%s]", data.confluenceScore, confRating), colVal, Scale(164), confClr, 8, true, true);

         // --- Section 3: SMC Targets & Distance ---
         SetLabel("SEC_SMC", "── SMC TARGETS & DISTANCE ──", Scale(10), Scale(184), m_clrSecHeader, 7, true, true);

         // Active OBs
         SetLabel("LBL_OB_K", "Active Order Blocks:", colKey, Scale(198), m_clrLabel, 8, false, true);
         SetLabel("LBL_OB_V", StringFormat("%d Bull | %d Bear", data.bullishOBCount, data.bearishOBCount), colVal, Scale(198), m_clrValNeutral, 8, false, true);

         // Nearest Demand / Supply OB Distance
         string nearBullOB = (data.nearestBullishOBDistPips >= 0.0) ? StringFormat("-%.1fp", data.nearestBullishOBDistPips) : "--";
         string nearBearOB = (data.nearestBearishOBDistPips >= 0.0) ? StringFormat("+%.1fp", data.nearestBearishOBDistPips) : "--";
         SetLabel("LBL_OBDIST_K", "Nearest Dem / Sup:", colKey, Scale(214), m_clrLabel, 8, false, true);
         SetLabel("LBL_OBDIST_V", StringFormat("%s / %s", nearBullOB, nearBearOB), colVal, Scale(214), m_clrValNeutral, 8, false, true);

         // Active FVGs
         SetLabel("LBL_FVG_K", "Fair Value Gaps:", colKey, Scale(230), m_clrLabel, 8, false, true);
         SetLabel("LBL_FVG_V", StringFormat("%d Bull | %d Bear", data.bullishFVGCount, data.bearishFVGCount), colVal, Scale(230), m_clrValNeutral, 8, false, true);

         // Nearest FVG Distance
         string nearBullFVG = (data.nearestBullishFVGDistPips >= 0.0) ? StringFormat("-%.1fp", data.nearestBullishFVGDistPips) : "--";
         string nearBearFVG = (data.nearestBearishFVGDistPips >= 0.0) ? StringFormat("+%.1fp", data.nearestBearishFVGDistPips) : "--";
         SetLabel("LBL_FVGDIST_K", "Nearest FVG Dist:", colKey, Scale(246), m_clrLabel, 8, false, true);
         SetLabel("LBL_FVGDIST_V", StringFormat("%s / %s", nearBullFVG, nearBearFVG), colVal, Scale(246), m_clrValNeutral, 8, false, true);

         // --- Section 4: Risk & Performance ---
         SetLabel("SEC_RISK", "── RISK & PERFORMANCE ──", Scale(10), Scale(266), m_clrSecHeader, 7, true, true);

         // Balance / Equity
         SetLabel("LBL_EQ_K", "Equity / Balance:", colKey, Scale(280), m_clrLabel, 8, false, true);
         SetLabel("LBL_EQ_V", StringFormat("$%.0f / $%.0f", data.equity, data.balance), colVal, Scale(280), m_clrValNeutral, 8, false, true);

         // Floating PnL
         color fltClr = (data.floatingPnL >= 0.0) ? m_clrValProfitPos : m_clrValProfitNeg;
         SetLabel("LBL_PNL_K", "Floating PnL:", colKey, Scale(296), m_clrLabel, 8, false, true);
         SetLabel("LBL_PNL_V", StringFormat("%s$%.2f", data.floatingPnL >= 0.0 ? "+" : "", data.floatingPnL), colVal, Scale(296), fltClr, 8, true, true);

         // Today Closed PnL
         color todayClr = (data.todayClosedPnL >= 0.0) ? m_clrValProfitPos : m_clrValProfitNeg;
         SetLabel("LBL_TODAY_K", "Today Closed PnL:", colKey, Scale(312), m_clrLabel, 8, false, true);
         SetLabel("LBL_TODAY_V", StringFormat("%s$%.2f", data.todayClosedPnL >= 0.0 ? "+" : "", data.todayClosedPnL), colVal, Scale(312), todayClr, 8, true, true);

         // Daily Drawdown
         color ddClr = (data.dailyDrawdownPct >= data.maxDailyDrawdownPct * 0.8) ? m_clrValProfitNeg : m_clrValProfitPos;
         SetLabel("LBL_DD_K", "Daily DD / Limit:", colKey, Scale(328), m_clrLabel, 8, false, true);
         SetLabel("LBL_DD_V", StringFormat("%.2f%% / %.1f%%", data.dailyDrawdownPct, data.maxDailyDrawdownPct), colVal, Scale(328), ddClr, 8, false, true);

         // Open Positions Count
         SetLabel("LBL_POS_K", "Open Positions:", colKey, Scale(344), m_clrLabel, 8, false, true);
         SetLabel("LBL_POS_V", IntegerToString(data.openPositionsCount), colVal, Scale(344), m_clrValNeutral, 8, false, true);

         // Macro News Guard
         color newsClr = data.isNewsClear ? m_clrValProfitPos : m_clrValBearish;
         SetLabel("LBL_NEWS_K", "Macro News Guard:", colKey, Scale(360), m_clrLabel, 8, false, true);
         SetLabel("LBL_NEWS_V", data.newsStatusText, colVal, Scale(360), newsClr, 8, true, true);
      }

      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| Hides all detail rows when collapsed                             |
   //+------------------------------------------------------------------+
   void HideDetailRows()
   {
      string detailNames[] = {
         "SEC_MKT", "LBL_SPREAD_K", "LBL_SPREAD_V", "LBL_SESS_K", "LBL_SESS_V", "LBL_ROLL_K", "LBL_ROLL_V",
         "SEC_MTF", "LBL_MACRO_K", "LBL_MACRO_V", "LBL_SETUP_K", "LBL_SETUP_V", "LBL_TRIG_K", "LBL_TRIG_V",
         "LBL_CONF_K", "LBL_CONF_V", "SEC_SMC", "LBL_OB_K", "LBL_OB_V", "LBL_OBDIST_K", "LBL_OBDIST_V",
         "LBL_FVG_K", "LBL_FVG_V", "LBL_FVGDIST_K", "LBL_FVGDIST_V", "SEC_RISK", "LBL_EQ_K", "LBL_EQ_V",
         "LBL_PNL_K", "LBL_PNL_V", "LBL_TODAY_K", "LBL_TODAY_V", "LBL_DD_K", "LBL_DD_V", "LBL_POS_K", "LBL_POS_V",
         "LBL_NEWS_K", "LBL_NEWS_V"
      };

      int count = ArraySize(detailNames);
      for(int i = 0; i < count; i++)
      {
         string fullName = m_prefix + detailNames[i];
         if(ObjectFind(m_chartId, fullName) >= 0)
         {
            ObjectSetInteger(m_chartId, fullName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Default Constructor                                              |
   //+------------------------------------------------------------------+
   CDashboard() :
      m_chartId(0),
      m_prefix("IMSF_DASH_"),
      m_enabled(true),
      m_collapsed(false),
      m_corner(CORNER_LEFT_UPPER),
      m_xDist(15),
      m_yDist(25),
      m_dpiScale(1.0),
      m_clrBg(C'16,21,29'),
      m_clrBgHeader(C'25,33,46'),
      m_clrBorder(C'42,54,74'),
      m_clrTitle(clrDeepSkyBlue),
      m_clrSubtitle(C'160,175,190'),
      m_clrSecHeader(C'110,135,170'),
      m_clrLabel(C'160,170,185'),
      m_clrValNeutral(clrWhite),
      m_clrValBullish(C'60,150,255'),
      m_clrValBearish(C'255,90,90'),
      m_clrValWarning(clrGold),
      m_clrValProfitPos(C'60,220,100'),
      m_clrValProfitNeg(C'255,70,70'),
      m_clrBtnBg(C'32,44,62'),
      m_clrBtnText(clrWhite),
      m_hasData(false)
   {
      UpdateDpiScale();
   }

   // Destructor
   ~CDashboard()
   {
      DeleteAllObjects();
   }

   //+------------------------------------------------------------------+
   //| Automatic High-DPI Detection (Supports 1080p, 1440p, 4K, 8K)     |
   //+------------------------------------------------------------------+
   void UpdateDpiScale()
   {
      int dpi = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
      if(dpi <= 0) dpi = 96;
      m_dpiScale = (double)dpi / 96.0;
      if(m_dpiScale < 1.0)
         m_dpiScale = 1.0;
   }

   double GetDpiScale() const { return m_dpiScale; }

   //+------------------------------------------------------------------+
   //| Initialization & Configuration                                   |
   //+------------------------------------------------------------------+
   void Init(const long chartId = 0, const string prefix = "IMSF_DASH_",
             const ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
             const int xDist = 15, const int yDist = 25,
             const bool startCollapsed = false)
   {
      m_chartId = chartId;
      m_prefix = prefix;
      m_corner = corner;
      m_xDist = xDist;
      m_yDist = yDist;
      m_collapsed = startCollapsed;
      UpdateDpiScale();
   }

   void SetEnabled(const bool enabled)             { m_enabled = enabled; }
   bool IsEnabled() const                          { return m_enabled; }
   void SetPrefix(const string prefix)             { m_prefix = prefix; }
   string GetPrefix() const                        { return m_prefix; }
   void SetChartId(const long chartId)             { m_chartId = chartId; }
   void SetCorner(const ENUM_BASE_CORNER corner)   { m_corner = corner; }
   void SetPosition(const int x, const int y)      { m_xDist = x; m_yDist = y; }
   void SetCollapsed(const bool collapsed)         { m_collapsed = collapsed; }
   bool IsCollapsed() const                        { return m_collapsed; }

   //+------------------------------------------------------------------+
   //| Toggles between Expanded and Collapsed View                      |
   //+------------------------------------------------------------------+
   void ToggleCollapse()
   {
      m_collapsed = !m_collapsed;
      if(m_hasData)
         Render(m_lastData);
   }

   //+------------------------------------------------------------------+
   //| Cleans up all dashboard graphical objects on target chart        |
   //+------------------------------------------------------------------+
   void DeleteAllObjects()
   {
      if(m_chartId >= 0)
      {
         ObjectsDeleteAll(m_chartId, m_prefix);
         ChartRedraw(m_chartId);
      }
   }

   //+------------------------------------------------------------------+
   //| Chart Event Handler (Processes Single-Click Collapse/Expand)     |
   //+------------------------------------------------------------------+
   void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_enabled)
         return;

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         string btnName    = m_prefix + "BTN_TOGGLE";
         string headerName = m_prefix + "BG_HEADER";
         string titleName  = m_prefix + "LBL_TITLE";
         string miniName   = m_prefix + "LBL_MINI";

         if(sparam == btnName || sparam == headerName || sparam == titleName || sparam == miniName)
         {
            ToggleCollapse();
            ObjectSetInteger(m_chartId, btnName, OBJPROP_STATE, false);
            ChartRedraw(m_chartId);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Direct Update using Populated SDashboardData Struct              |
   //+------------------------------------------------------------------+
   void Update(const SDashboardData &data)
   {
      if(!m_enabled)
         return;

      m_lastData = data;
      m_hasData = true;

      Render(data);
   }

   //+------------------------------------------------------------------+
   //| Session Calculation Helper (Based on UTC / TimeGMT)              |
   //+------------------------------------------------------------------+
   static string GetMarketSession()
   {
      MqlDateTime gmt;
      TimeToStruct(TimeGMT(), gmt);
      int hour = gmt.hour;

      if(hour >= 13 && hour < 16)
         return "London / NY Overlap";
      if(hour >= 8 && hour < 16)
         return "London Session";
      if(hour >= 16 && hour < 21)
         return "New York Session";
      if(hour >= 0 && hour < 8)
         return "Asian Session";
      return "Pacific / Sydney";
   }

   //+------------------------------------------------------------------+
   //| Today's Closed PnL Calculation Helper                            |
   //+------------------------------------------------------------------+
   static double GetTodayClosedPnL(const string symbol)
   {
      datetime todayStart = iTime(symbol, PERIOD_D1, 0);
      if(todayStart <= 0)
         return 0.0;

      if(!HistorySelect(todayStart, TimeCurrent()))
         return 0.0;

      double totalProfit = 0.0;
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
            {
               totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
               totalProfit += HistoryDealGetDouble(ticket, DEAL_SWAP);
               totalProfit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
         }
      }
      return totalProfit;
   }

   //+------------------------------------------------------------------+
   //| Nearest Order Block Distance Calculator                          |
   //+------------------------------------------------------------------+
   static void CalculateNearestOBDist(const CMarketData &marketData, const double currentPrice, const double pipSize,
                                      int &bullCount, int &bearCount,
                                      double &nearBullDist, double &nearBearDist)
   {
      bullCount = 0;
      bearCount = 0;
      nearBullDist = -1.0;
      nearBearDist = -1.0;

      if(pipSize <= 0.0) return;

      int total = marketData.TotalOrderBlocks();
      for(int i = 0; i < total; i++)
      {
         SOrderBlock ob;
         if(marketData.GetOrderBlock(i, ob))
         {
            if(!ob.isMitigated)
            {
               if(ob.isBullish)
               {
                  bullCount++;
                  if(currentPrice >= ob.highPrice)
                  {
                     double dist = (currentPrice - ob.highPrice) / pipSize;
                     if(nearBullDist < 0.0 || dist < nearBullDist)
                        nearBullDist = dist;
                  }
               }
               else
               {
                  bearCount++;
                  if(currentPrice <= ob.lowPrice)
                  {
                     double dist = (ob.lowPrice - currentPrice) / pipSize;
                     if(nearBearDist < 0.0 || dist < nearBearDist)
                        nearBearDist = dist;
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Nearest Fair Value Gap Distance Calculator                       |
   //+------------------------------------------------------------------+
   static void CalculateNearestFVGDist(const CMarketData &marketData, const double currentPrice, const double pipSize,
                                       int &bullCount, int &bearCount,
                                       double &nearBullDist, double &nearBearDist)
   {
      bullCount = 0;
      bearCount = 0;
      nearBullDist = -1.0;
      nearBearDist = -1.0;

      if(pipSize <= 0.0) return;

      int total = marketData.TotalFVGs();
      for(int i = 0; i < total; i++)
      {
         SFairValueGap fvg;
         if(marketData.GetFVG(i, fvg))
         {
            if(fvg.state != STATE_MITIGATED)
            {
               if(fvg.isBullish)
               {
                  bullCount++;
                  if(currentPrice >= fvg.topPrice)
                  {
                     double dist = (currentPrice - fvg.topPrice) / pipSize;
                     if(nearBullDist < 0.0 || dist < nearBullDist)
                        nearBullDist = dist;
                  }
               }
               else
               {
                  bearCount++;
                  if(currentPrice <= fvg.bottomPrice)
                  {
                     double dist = (fvg.bottomPrice - currentPrice) / pipSize;
                     if(nearBearDist < 0.0 || dist < nearBearDist)
                        nearBearDist = dist;
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Automated Update from Live Framework Engines                     |
   //+------------------------------------------------------------------+
   void UpdateFromEngines(const string symbol, const ENUM_TIMEFRAMES period,
                          const CTimeframeManager &mtf, const CMarketData &marketData,
                          CRiskManager *riskMgr = NULL,
                          const CSpreadFilter *spreadFilter = NULL,
                          CNewsFilter *newsFilter = NULL,
                          const int openPositions = 0)
   {
      if(!m_enabled)
         return;

      SDashboardData data;
      data.symbol = symbol;
      data.period = period;
      data.bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      data.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double pipSize = CUtilities::GetPipSize(symbol);
      data.spreadPips = (pipSize > 0.0) ? (data.ask - data.bid) / pipSize : 0.0;
      data.sessionName = GetMarketSession();

      if(spreadFilter != NULL)
      {
         data.isRollover = spreadFilter.IsRolloverWindow();
         data.isSpreadOk = spreadFilter.IsSpreadPermissible(symbol);
      }
      else
      {
         data.isRollover = false;
         data.isSpreadOk = true;
      }

      // MTF Confluence
      data.macroBias = mtf.GetBias(PERIOD_H4);
      data.setupBias = mtf.GetBias(PERIOD_H1);
      data.triggerBias = mtf.GetBias(period);
      data.confluenceScore = mtf.GetConfluenceScore();
      data.confluenceBias = mtf.GetConfluenceBias();

      // SMC Distances
      CalculateNearestOBDist(marketData, data.bid, pipSize,
                             data.bullishOBCount, data.bearishOBCount,
                             data.nearestBullishOBDistPips, data.nearestBearishOBDistPips);

      CalculateNearestFVGDist(marketData, data.bid, pipSize,
                              data.bullishFVGCount, data.bearishFVGCount,
                              data.nearestBullishFVGDistPips, data.nearestBearishFVGDistPips);

      // Account & Risk
      data.balance = AccountInfoDouble(ACCOUNT_BALANCE);
      data.equity = AccountInfoDouble(ACCOUNT_EQUITY);
      data.floatingPnL = AccountInfoDouble(ACCOUNT_PROFIT);
      data.todayClosedPnL = GetTodayClosedPnL(symbol);
      data.openPositionsCount = openPositions;

      if(riskMgr != NULL)
      {
         data.dailyDrawdownPct = riskMgr.GetCurrentDailyLossPct();
         data.maxDailyDrawdownPct = InpMaxDailyDrawdownPct;
      }
      else
      {
         data.dailyDrawdownPct = (data.balance > 0.0) ? MathMax(0.0, (data.balance - data.equity) / data.balance * 100.0) : 0.0;
         data.maxDailyDrawdownPct = InpMaxDailyDrawdownPct;
      }

      // News Filter
      if(newsFilter != NULL)
      {
         data.isNewsClear = newsFilter.IsNewsClear(symbol);
         data.newsStatusText = data.isNewsClear ? "CLEAR" : "NEWS BLACKOUT";
      }
      else
      {
         data.isNewsClear = true;
         data.newsStatusText = "CLEAR";
      }

      Update(data);
   }
};

#endif // __IMSF_DASHBOARD_MQH__
