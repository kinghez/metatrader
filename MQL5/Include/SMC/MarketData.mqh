//+------------------------------------------------------------------+
//|                                                   MarketData.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_MARKETDATA_MQH__
#define __IMSF_MARKETDATA_MQH__

#include "Types.mqh"

//+------------------------------------------------------------------+
//| Class CMarketData                                                |
//| Centralized in-memory repository managing market state, swings,  |
//| dynamic zones, order blocks, and FVGs with zero-leak guarantees. |
//+------------------------------------------------------------------+
class CMarketData
{
private:
   CSwingPoint*         m_swings[];       // Dynamic array of swing point pointers
   int                  m_swingCount;     // Number of active swing points
   int                  m_swingCapacity;  // Allocated array capacity

   SZone                m_zones[];        // Array of dynamic supply/demand zones
   int                  m_zoneCount;

   SOrderBlock          m_orderBlocks[];  // Array of active order blocks
   int                  m_obCount;

   SFairValueGap        m_fvgs[];         // Array of fair value gaps
   int                  m_fvgCount;

   ENUM_TREND_BIAS      m_currentBias;    // Current overall trend bias

   // Internal capacity manager for swing pointers
   void EnsureSwingCapacity()
   {
      if(m_swingCount >= m_swingCapacity)
      {
         m_swingCapacity = (m_swingCapacity == 0) ? 64 : (m_swingCapacity * 2);
         ArrayResize(m_swings, m_swingCapacity);
      }
   }

public:
   // Constructor
   CMarketData() :
      m_swingCount(0),
      m_swingCapacity(0),
      m_zoneCount(0),
      m_obCount(0),
      m_fvgCount(0),
      m_currentBias(BIAS_NEUTRAL)
   {
      ArrayResize(m_swings, 0);
      ArrayResize(m_zones, 0);
      ArrayResize(m_orderBlocks, 0);
      ArrayResize(m_fvgs, 0);
   }

   // Destructor - Clean up all dynamic memory
   ~CMarketData()
   {
      ClearAll();
   }

   //+------------------------------------------------------------------+
   //| Swing Points Management                                          |
   //+------------------------------------------------------------------+
   bool AddSwing(CSwingPoint* swing)
   {
      if(CheckPointer(swing) == POINTER_INVALID)
         return false;

      EnsureSwingCapacity();
      m_swings[m_swingCount] = swing;
      m_swingCount++;
      return true;
   }

   int TotalSwings() const
   {
      return m_swingCount;
   }

   CSwingPoint* GetSwing(const int index) const
   {
      if(index < 0 || index >= m_swingCount)
         return NULL;
      return m_swings[index];
   }

   //+------------------------------------------------------------------+
   //| Retrieves latest confirmed swing point, optionally filtered      |
   //+------------------------------------------------------------------+
   CSwingPoint* GetLatestSwing(const ENUM_SWING_TYPE filterType = SWING_NONE) const
   {
      for(int i = m_swingCount - 1; i >= 0; i--)
      {
         CSwingPoint* pt = m_swings[i];
         if(CheckPointer(pt) != POINTER_INVALID && pt.IsConfirmed())
         {
            if(filterType == SWING_NONE || pt.SwingType() == filterType)
               return pt;
         }
      }
      return NULL;
   }

   //+------------------------------------------------------------------+
   //| Retrieves previous confirmed swing point (skipCount = 1 skips 1) |
   //+------------------------------------------------------------------+
   CSwingPoint* GetPreviousSwing(const ENUM_SWING_TYPE filterType = SWING_NONE, const int skipCount = 1) const
   {
      int skipped = 0;
      for(int i = m_swingCount - 1; i >= 0; i--)
      {
         CSwingPoint* pt = m_swings[i];
         if(CheckPointer(pt) != POINTER_INVALID && pt.IsConfirmed())
         {
            if(filterType == SWING_NONE || pt.SwingType() == filterType)
            {
               if(skipped >= skipCount)
                  return pt;
               skipped++;
            }
         }
      }
      return NULL;
   }

   //+------------------------------------------------------------------+
   //| Deletes all swing points and resets array                        |
   //+------------------------------------------------------------------+
   void ClearSwings()
   {
      for(int i = 0; i < m_swingCount; i++)
      {
         if(CheckPointer(m_swings[i]) != POINTER_INVALID)
         {
            delete m_swings[i];
            m_swings[i] = NULL;
         }
      }
      m_swingCount = 0;
      m_swingCapacity = 0;
      ArrayResize(m_swings, 0);
   }

   //+------------------------------------------------------------------+
   //| Dynamic Zones Management                                         |
   //+------------------------------------------------------------------+
   bool AddZone(const SZone &zone)
   {
      m_zoneCount++;
      ArrayResize(m_zones, m_zoneCount);
      m_zones[m_zoneCount - 1] = zone;
      return true;
   }

   int TotalZones() const { return m_zoneCount; }

   bool GetZone(const int index, SZone &outZone) const
   {
      if(index < 0 || index >= m_zoneCount)
         return false;
      outZone = m_zones[index];
      return true;
   }

   void ClearZones()
   {
      m_zoneCount = 0;
      ArrayResize(m_zones, 0);
   }

   //+------------------------------------------------------------------+
   //| Order Block Management                                           |
   //+------------------------------------------------------------------+
   bool AddOrderBlock(const SOrderBlock &ob)
   {
      m_obCount++;
      ArrayResize(m_orderBlocks, m_obCount);
      m_orderBlocks[m_obCount - 1] = ob;
      return true;
   }

   int TotalOrderBlocks() const { return m_obCount; }

   bool GetOrderBlock(const int index, SOrderBlock &outOB) const
   {
      if(index < 0 || index >= m_obCount)
         return false;
      outOB = m_orderBlocks[index];
      return true;
   }

   void ClearOrderBlocks()
   {
      m_obCount = 0;
      ArrayResize(m_orderBlocks, 0);
   }

   //+------------------------------------------------------------------+
   //| Fair Value Gap (FVG) Management                                  |
   //+------------------------------------------------------------------+
   bool AddFVG(const SFairValueGap &fvg)
   {
      m_fvgCount++;
      ArrayResize(m_fvgs, m_fvgCount);
      m_fvgs[m_fvgCount - 1] = fvg;
      return true;
   }

   int TotalFVGs() const { return m_fvgCount; }

   bool GetFVG(const int index, SFairValueGap &outFVG) const
   {
      if(index < 0 || index >= m_fvgCount)
         return false;
      outFVG = m_fvgs[index];
      return true;
   }

   void ClearFVGs()
   {
      m_fvgCount = 0;
      ArrayResize(m_fvgs, 0);
   }

   //+------------------------------------------------------------------+
   //| Trend Bias Management                                            |
   //+------------------------------------------------------------------+
   void SetTrendBias(const ENUM_TREND_BIAS bias) { m_currentBias = bias; }
   ENUM_TREND_BIAS GetTrendBias() const          { return m_currentBias; }

   //+------------------------------------------------------------------+
   //| Reset all state and free all resources                           |
   //+------------------------------------------------------------------+
   void ClearAll()
   {
      ClearSwings();
      ClearZones();
      m_obCount = 0;
      ArrayResize(m_orderBlocks, 0);
      m_fvgCount = 0;
      ArrayResize(m_fvgs, 0);
      m_currentBias = BIAS_NEUTRAL;
   }
};

#endif // __IMSF_MARKETDATA_MQH__

