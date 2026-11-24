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
//| objects (arrows, HH/HL/LH/LL text, OBJ_RECTANGLE zones, HUD)     |
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
   color                m_highColor;
   color                m_lowColor;
   color                m_supplyColor;
   color                m_demandColor;
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
      m_highColor(InpSwingHighColor),
      m_lowColor(InpSwingLowColor),
      m_supplyColor(C'255,190,190'), // Light translucent crimson
      m_demandColor(C'190,240,190'), // Light translucent forest green
      m_fontSize(InpLabelFontSize)
   {
   }

   // Parameterized Constructor
   CObjectManager(const long chartId,
                  const string prefix,
                  const bool enabled,
                  const bool showLabels,
                  const bool showPoints,
                  const bool showZones,
                  const color highColor,
                  const color lowColor,
                  const int fontSize) :
      m_chartId(chartId),
      m_prefix(prefix),
      m_enabled(enabled),
      m_showLabels(showLabels),
      m_showPoints(showPoints),
      m_showZones(showZones),
      m_highColor(highColor),
      m_lowColor(lowColor),
      m_supplyColor(C'255,190,190'),
      m_demandColor(C'190,240,190'),
      m_fontSize(fontSize)
   {
   }

   // Destructor
   ~CObjectManager()
   {
      DeleteAllObjects();
   }

   // Configuration & Headless Control
   void SetEnabled(const bool enabled)       { m_enabled = enabled; }
   bool IsEnabled() const                    { return m_enabled; }
   void SetPrefix(const string prefix)       { m_prefix = prefix; }
   string GetPrefix() const                  { return m_prefix; }
   void SetChartId(const long chartId)       { m_chartId = chartId; }
   void SetShowZones(const bool show)        { m_showZones = show; }

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

      // 1. Draw Pivot Arrow / Marker
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

      // 2. Draw Structure Text Label (HH, HL, LH, LL)
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

      // Project zone forward into future candles
      long periodSec = PeriodSeconds(PERIOD_CURRENT);
      if(periodSec <= 0) periodSec = 3600;
      datetime futureTime = TimeCurrent() + (periodSec * 20);

      if(ObjectFind(m_chartId, zoneName) < 0)
      {
         ObjectCreate(m_chartId, zoneName, OBJ_RECTANGLE, 0, zone.creationTime, zone.topPrice, futureTime, zone.bottomPrice);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_COLOR, zoneColor);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_BGCOLOR, zoneColor);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(m_chartId, zoneName, OBJPROP_BACK, true); // Render behind price candles
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
   //| Renders all swing points stored in MarketData                    |
   //+------------------------------------------------------------------+
   void RenderAllSwings(const CMarketData &marketData)
   {
      if(!m_enabled)
         return;

      int total = marketData.TotalSwings();
      for(int i = 0; i < total; i++)
      {
         CSwingPoint* swing = marketData.GetSwing(i);
         if(CheckPointer(swing) != POINTER_INVALID)
         {
            DrawSwingPoint(swing);
         }
      }
      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| Renders all active supply and demand zones                       |
   //+------------------------------------------------------------------+
   void RenderAllZones(const CMarketData &marketData)
   {
      if(!m_enabled || !m_showZones)
         return;

      int total = marketData.TotalZones();
      for(int i = 0; i < total; i++)
      {
         SZone z;
         if(marketData.GetZone(i, z))
         {
            DrawZone(z);
         }
      }
      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| On-chart Status HUD displaying Trend Bias and Structure Sequence |
   //+------------------------------------------------------------------+
   void DrawTrendBiasHUD(const ENUM_TREND_BIAS bias, const string sequence, const int swingsCount, const int zonesCount = 0)
   {
      if(!m_enabled)
         return;

      string hudName = m_prefix + "HUD_BIAS";
      string biasStr = (bias == BIAS_BULLISH) ? "BULLISH" : ((bias == BIAS_BEARISH) ? "BEARISH" : "NEUTRAL");
      color  biasClr = (bias == BIAS_BULLISH) ? m_highColor : ((bias == BIAS_BEARISH) ? m_lowColor : clrSilver);

      string text = StringFormat("IMSF Market Structure: [%s] | Swings: %d | Active Zones: %d | Flow: %s",
                                 biasStr, swingsCount, zonesCount, sequence);

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
