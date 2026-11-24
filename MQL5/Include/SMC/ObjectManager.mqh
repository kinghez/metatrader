//+------------------------------------------------------------------+
//|                                                ObjectManager.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_OBJECTMANAGER_MQH__
#define __IMSF_OBJECTMANAGER_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CObjectManager                                             |
//| Decoupled presentation engine managing on-chart graphical        |
//| objects (arrows, structure text, zones, Order Blocks, FVGs, HUD) |
//| with clean teardown and 100% headless bypass.                    |
//+------------------------------------------------------------------+
class CObjectManager
{
private:
   long                 m_chartId;
   string               m_prefix;
   bool                 m_enabled;
   bool                 m_showLabels;
   bool                 m_showPoints;
   bool                 m_showZones;
   bool                 m_showOrderBlocks;
   bool                 m_showFVGs;
   color                m_highColor;
   color                m_lowColor;
   color                m_supplyColor;
   color                m_demandColor;
   color                m_obBullishColor;
   color                m_obBearishColor;
   color                m_fvgBullishColor;
   color                m_fvgBearishColor;
   int                  m_fontSize;

public:
   // Default Constructor
   CObjectManager() :
      m_chartId(0),
      m_prefix(InpObjectNamePrefix),
      m_enabled(true),
      m_showLabels(InpShowSwingLabels),
      m_showPoints(InpShowSwingPoints),
      m_showZones(true),
      m_showOrderBlocks(true),
      m_showFVGs(true),
      m_highColor(InpSwingHighColor),
      m_lowColor(InpSwingLowColor),
      m_supplyColor(C'255,190,190'),
      m_demandColor(C'190,240,190'),
      m_obBullishColor(C'160,220,255'),
      m_obBearishColor(C'255,180,180'),
      m_fvgBullishColor(C'200,240,255'),
      m_fvgBearishColor(C'255,220,220'),
      m_fontSize(InpLabelFontSize)
   {
   }

   // Destructor
   ~CObjectManager()
   {
      DeleteAllObjects();
   }

   // Configuration & Headless Control
   void SetEnabled(const bool enabled)             { m_enabled = enabled; }
   bool IsEnabled() const                          { return m_enabled; }
   void SetPrefix(const string prefix)             { m_prefix = prefix; }
   string GetPrefix() const                        { return m_prefix; }
   void SetChartId(const long chartId)             { m_chartId = chartId; }
   void SetShowZones(const bool show)              { m_showZones = show; }
   void SetShowOrderBlocks(const bool show)        { m_showOrderBlocks = show; }
   void SetShowFVGs(const bool show)               { m_showFVGs = show; }

   //+------------------------------------------------------------------+
   //| Cleanly deletes all framework objects on the target chart        |
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
   //| Renders a single swing point (Arrow + Structure Label)           |
   //+------------------------------------------------------------------+
   void DrawSwingPoint(const CSwingPoint* swing)
   {
      if(!m_enabled || swing == NULL || !swing.IsConfirmed())
         return;

      string timeStr = IntegerToString((long)swing.Time());

      // 1. Draw Pivot Arrow
      if(m_showPoints)
      {
         string arrowName = m_prefix + (swing.IsHigh() ? "ARW_H_" : "ARW_L_") + timeStr;
         ENUM_OBJECT arrowType = swing.IsHigh() ? OBJ_ARROW_DOWN : OBJ_ARROW_UP;

         if(ObjectFind(m_chartId, arrowName) < 0)
         {
            ObjectCreate(m_chartId, arrowName, arrowType, 0, swing.Time(), swing.Price());
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_COLOR, swing.IsHigh() ? m_highColor : m_lowColor);
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_BACK, false);
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_HIDDEN, true);
            ObjectSetInteger(m_chartId, arrowName, OBJPROP_ANCHOR, swing.IsHigh() ? ANCHOR_BOTTOM : ANCHOR_TOP);
         }
         else
         {
            ObjectMove(m_chartId, arrowName, 0, swing.Time(), swing.Price());
         }
      }

      // 2. Draw Structure Text Label
      if(m_showLabels && swing.StructureType() != STRUCTURE_NONE)
      {
         if((swing.StructureType() == STRUCTURE_HH && !InpShowHH) ||
            (swing.StructureType() == STRUCTURE_HL && !InpShowHL) ||
            (swing.StructureType() == STRUCTURE_LH && !InpShowLH) ||
            (swing.StructureType() == STRUCTURE_LL && !InpShowLL))
         {
            return;
         }

         string textName = m_prefix + "LBL_" + timeStr;
         string textLabel = CUtilities::StructureToString(swing.StructureType());

         if(ObjectFind(m_chartId, textName) < 0)
         {
            ObjectCreate(m_chartId, textName, OBJ_TEXT, 0, swing.Time(), swing.Price());
            ObjectSetString(m_chartId, textName, OBJPROP_TEXT, textLabel);
            ObjectSetString(m_chartId, textName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(m_chartId, textName, OBJPROP_FONTSIZE, m_fontSize);
            ObjectSetInteger(m_chartId, textName, OBJPROP_COLOR, swing.IsHigh() ? m_highColor : m_lowColor);
            ObjectSetInteger(m_chartId, textName, OBJPROP_ANCHOR, swing.IsHigh() ? ANCHOR_LOWER : ANCHOR_UPPER);
            ObjectSetInteger(m_chartId, textName, OBJPROP_BACK, false);
            ObjectSetInteger(m_chartId, textName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(m_chartId, textName, OBJPROP_HIDDEN, true);
         }
         else
         {
            ObjectSetString(m_chartId, textName, OBJPROP_TEXT, textLabel);
            ObjectMove(m_chartId, textName, 0, swing.Time(), swing.Price());
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Renders an institutional Supply or Demand Zone rectangle         |
   //+------------------------------------------------------------------+
   void DrawZone(const SZone &zone)
   {
      if(!m_enabled || !m_showZones || zone.mitigationState == STATE_MITIGATED)
         return;

      string zoneName = m_prefix + "ZONE_" + ((zone.type == ZONE_SUPPLY) ? "SUP_" : "DEM_") + IntegerToString((long)zone.id);
      color  zoneColor = (zone.type == ZONE_SUPPLY) ? m_supplyColor : m_demandColor;

      long periodSec = PeriodSeconds(PERIOD_CURRENT);
      if(periodSec <= 0) periodSec = 3600;
      datetime futureTime = TimeCurrent() + (periodSec * 20);

      if(ObjectFind(m_chartId, zoneName) < 0)
      {
         ObjectCreate(m_chartId, zoneName, OBJ_RECTANGLE, 0, zone.creationTime, zone.topPrice, futureTime, zone.bottomPrice);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_COLOR, zoneColor);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_BGCOLOR, zoneColor);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetDouble(m_chartId, zoneName, OBJPROP_PRICE, 0, zone.topPrice);
         ObjectSetDouble(m_chartId, zoneName, OBJPROP_PRICE, 1, zone.bottomPrice);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_TIME, 1, futureTime);
      }
   }

   //+------------------------------------------------------------------+
   //| Renders an institutional Order Block (OB)                        |
   //+------------------------------------------------------------------+
   void DrawOrderBlock(const SOrderBlock &ob)
   {
      if(!m_enabled || !m_showOrderBlocks || ob.isMitigated)
         return;

      string obName = m_prefix + "OB_" + (ob.isBullish ? "BULL_" : "BEAR_") + IntegerToString((long)ob.id);
      color  obColor = ob.isBullish ? m_obBullishColor : m_obBearishColor;

      long periodSec = PeriodSeconds(PERIOD_CURRENT);
      if(periodSec <= 0) periodSec = 3600;
      datetime futureTime = TimeCurrent() + (periodSec * 15);

      if(ObjectFind(m_chartId, obName) < 0)
      {
         ObjectCreate(m_chartId, obName, OBJ_RECTANGLE, 0, ob.time, ob.highPrice, futureTime, ob.lowPrice);
         ObjectSetInteger(m_chartId, obName, OBJPROP_COLOR, obColor);
         ObjectSetInteger(m_chartId, obName, OBJPROP_BGCOLOR, obColor);
         ObjectSetInteger(m_chartId, obName, OBJPROP_FILL, true);
         ObjectSetInteger(m_chartId, obName, OBJPROP_BACK, true);
         ObjectSetInteger(m_chartId, obName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, obName, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetDouble(m_chartId, obName, OBJPROP_PRICE, 0, ob.highPrice);
         ObjectSetDouble(m_chartId, obName, OBJPROP_PRICE, 1, ob.lowPrice);
         ObjectSetInteger(m_chartId, obName, OBJPROP_TIME, 1, futureTime);
      }
   }

   //+------------------------------------------------------------------+
   //| Renders a 3-candle Fair Value Gap (FVG)                          |
   //+------------------------------------------------------------------+
   void DrawFVG(const SFairValueGap &fvg)
   {
      if(!m_enabled || !m_showFVGs || fvg.state == STATE_MITIGATED)
         return;

      string fvgName = m_prefix + "FVG_" + (fvg.isBullish ? "BULL_" : "BEAR_") + IntegerToString((long)fvg.id);
      color  fvgColor = fvg.isBullish ? m_fvgBullishColor : m_fvgBearishColor;

      long periodSec = PeriodSeconds(PERIOD_CURRENT);
      if(periodSec <= 0) periodSec = 3600;
      datetime futureTime = TimeCurrent() + (periodSec * 10);

      if(ObjectFind(m_chartId, fvgName) < 0)
      {
         ObjectCreate(m_chartId, fvgName, OBJ_RECTANGLE, 0, fvg.time, fvg.topPrice, futureTime, fvg.bottomPrice);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_BGCOLOR, fvgColor);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_FILL, true);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_BACK, true);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetDouble(m_chartId, fvgName, OBJPROP_PRICE, 0, fvg.topPrice);
         ObjectSetDouble(m_chartId, fvgName, OBJPROP_PRICE, 1, fvg.bottomPrice);
         ObjectSetInteger(m_chartId, fvgName, OBJPROP_TIME, 1, futureTime);
      }
   }

   //+------------------------------------------------------------------+
   //| Renders a Liquidity Sweep alert marker                           |
   //+------------------------------------------------------------------+
   void DrawSweep(const SLiquiditySweep &sweep)
   {
      if(!m_enabled || sweep.time == 0)
         return;

      string sweepName = m_prefix + "SWEEP_" + IntegerToString((long)sweep.id);
      string sweepText = sweep.isBullishSweep ? "▲ LIQ SWEEP (SELL-SIDE)" : "▼ LIQ SWEEP (BUY-SIDE)";
      color  sweepColor = sweep.isBullishSweep ? m_highColor : m_lowColor;

      if(ObjectFind(m_chartId, sweepName) < 0)
      {
         ObjectCreate(m_chartId, sweepName, OBJ_TEXT, 0, sweep.time, sweep.extremeWickPrice);
         ObjectSetString(m_chartId, sweepName, OBJPROP_TEXT, sweepText);
         ObjectSetString(m_chartId, sweepName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(m_chartId, sweepName, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(m_chartId, sweepName, OBJPROP_COLOR, sweepColor);
         ObjectSetInteger(m_chartId, sweepName, OBJPROP_ANCHOR, sweep.isBullishSweep ? ANCHOR_UPPER : ANCHOR_LOWER);
         ObjectSetInteger(m_chartId, sweepName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, sweepName, OBJPROP_HIDDEN, true);
      }
   }

   //+------------------------------------------------------------------+
   //| Rendering Loops                                                  |
   //+------------------------------------------------------------------+
   void RenderAllSwings(const CMarketData &marketData)
   {
      if(!m_enabled) return;
      int total = marketData.TotalSwings();
      for(int i = 0; i < total; i++)
      {
         CSwingPoint* swing = marketData.GetSwing(i);
         if(CheckPointer(swing) != POINTER_INVALID)
            DrawSwingPoint(swing);
      }
      ChartRedraw(m_chartId);
   }

   void RenderAllZones(const CMarketData &marketData)
   {
      if(!m_enabled || !m_showZones) return;
      int total = marketData.TotalZones();
      for(int i = 0; i < total; i++)
      {
         SZone z;
         if(marketData.GetZone(i, z))
            DrawZone(z);
      }
      ChartRedraw(m_chartId);
   }

   void RenderAllOrderBlocks(const CMarketData &marketData)
   {
      if(!m_enabled || !m_showOrderBlocks) return;
      int total = marketData.TotalOrderBlocks();
      for(int i = 0; i < total; i++)
      {
         SOrderBlock ob;
         if(marketData.GetOrderBlock(i, ob))
            DrawOrderBlock(ob);
      }
      ChartRedraw(m_chartId);
   }

   void RenderAllFVGs(const CMarketData &marketData)
   {
      if(!m_enabled || !m_showFVGs) return;
      int total = marketData.TotalFVGs();
      for(int i = 0; i < total; i++)
      {
         SFairValueGap f;
         if(marketData.GetFVG(i, f))
            DrawFVG(f);
      }
      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| On-chart Status HUD displaying Trend Bias and Full SMC Metrics   |
   //+------------------------------------------------------------------+
   void DrawTrendBiasHUD(const ENUM_TREND_BIAS bias, const string sequence, 
                         const int swingsCount, const int zonesCount, 
                         const int obCount, const int fvgCount)
   {
      if(!m_enabled) return;

      string hudName = m_prefix + "HUD_BIAS";
      string biasStr = (bias == BIAS_BULLISH) ? "BULLISH" : ((bias == BIAS_BEARISH) ? "BEARISH" : "NEUTRAL");
      color  biasClr = (bias == BIAS_BULLISH) ? m_highColor : ((bias == BIAS_BEARISH) ? m_lowColor : clrSilver);

      string text = StringFormat("IMSF SMC: [%s] | Swings: %d | Zones: %d | OB: %d | FVG: %d | Flow: %s",
                                 biasStr, swingsCount, zonesCount, obCount, fvgCount, sequence);

      if(ObjectFind(m_chartId, hudName) < 0)
      {
         ObjectCreate(m_chartId, hudName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_chartId, hudName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(m_chartId, hudName, OBJPROP_XDISTANCE, 15);
         ObjectSetInteger(m_chartId, hudName, OBJPROP_YDISTANCE, 20);
         ObjectSetString(m_chartId, hudName, OBJPROP_FONT, "Segoe UI Semibold");
         ObjectSetInteger(m_chartId, hudName, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(m_chartId, hudName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, hudName, OBJPROP_HIDDEN, true);
      }

      ObjectSetString(m_chartId, hudName, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartId, hudName, OBJPROP_COLOR, biasClr);
      ChartRedraw(m_chartId);
   }
};

#endif // __IMSF_OBJECTMANAGER_MQH__
