//+------------------------------------------------------------------+
//|                                                   ZoneEngine.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_ZONEENGINE_MQH__
#define __IMSF_ZONEENGINE_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CZoneEngine                                                |
//| Clusters nearby swing pivots within ATR tolerance into dynamic   |
//| Supply & Demand zones, tracks mitigation, and computes a         |
//| 100-point institutional quality score.                           |
//+------------------------------------------------------------------+
class CZoneEngine
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_atrClusterMultiplier;
   double               m_zoneWidthAtrRatio;
   int                  m_minScoreToKeep;

   // Helper: Timeframe weight component (0 - 20 pts)
   int GetTimeframeScore(const ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_MN1:
         case PERIOD_W1:
         case PERIOD_D1:  return 20;
         case PERIOD_H4:  return 17;
         case PERIOD_H1:  return 14;
         case PERIOD_M30: return 12;
         case PERIOD_M15: return 10;
         case PERIOD_M5:  return 6;
         default:         return 5;
      }
   }

   // Helper: Recency decay component (0 - 20 pts)
   int GetRecencyScore(const int elapsedBars)
   {
      if(elapsedBars < 50)   return 20;
      if(elapsedBars < 100)  return 16;
      if(elapsedBars < 200)  return 12;
      if(elapsedBars < 400)  return 8;
      return 4;
   }

   // Helper: Touch frequency score (0 - 30 pts)
   int GetTouchScore(const int touches)
   {
      if(touches == 1) return 15;
      if(touches == 2) return 30; // Optimal institutional confirmation
      if(touches == 3) return 25;
      if(touches == 4) return 15;
      return 5; // Exhaustion
   }

   // Helper: Reaction magnitude score (0 - 30 pts)
   int GetReactionScore(const double displacement, const double atr)
   {
      if(atr <= 0.0) return 15;
      double ratio = displacement / atr;
      return (int)MathMin(30.0, MathMax(5.0, ratio * 10.0));
   }

public:
   // Default Constructor
   CZoneEngine() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_atrClusterMultiplier(1.0),
      m_zoneWidthAtrRatio(0.5),
      m_minScoreToKeep(30)
   {
   }

   // Parameterized Constructor
   CZoneEngine(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const double atrClusterMultiplier = 1.0,
               const double zoneWidthAtrRatio = 0.5,
               const int minScore = 30) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_atrClusterMultiplier(atrClusterMultiplier),
      m_zoneWidthAtrRatio(zoneWidthAtrRatio),
      m_minScoreToKeep(minScore)
   {
   }

   // Destructor
   ~CZoneEngine()
   {
   }

   void SetClusterMultiplier(const double mult) { m_atrClusterMultiplier = MathMax(0.2, mult); }
   void SetZoneWidthRatio(const double ratio)   { m_zoneWidthAtrRatio = MathMax(0.1, ratio); }
   void SetMinScore(const int score)            { m_minScoreToKeep = score; }

   //+------------------------------------------------------------------+
   //| Core Engine: Builds, clusters, and grades institutional zones    |
   //+------------------------------------------------------------------+
   bool BuildZones(CMarketData &marketData, const int maxHistoryBars = 400)
   {
      int totalSwings = marketData.TotalSwings();
      if(totalSwings < 2)
         return false;

      marketData.ClearZones();

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, maxHistoryBars, rates);
      if(copied < 50)
         return false;

      double atr = CUtilities::CalculateATR(m_symbol, m_timeframe, InpATRPeriod, 1);
      if(atr <= 0.0)
         atr = (rates[0].high - rates[0].low) * 2.0;

      double clusterTolerance = atr * m_atrClusterMultiplier;
      double defaultZoneWidth = atr * m_zoneWidthAtrRatio;

      // Temporary dynamic array for raw candidate zones
      SZone rawZones[];
      int rawCount = 0;

      // Step 1: Generate initial raw zones from confirmed swing points
      for(int i = 0; i < totalSwings; i++)
      {
         CSwingPoint* pt = marketData.GetSwing(i);
         if(CheckPointer(pt) == POINTER_INVALID || !pt.IsConfirmed())
            continue;

         SZone zone;
         zone.id           = (ulong)pt.Time();
         zone.creationTime = pt.Time();
         zone.timeframe    = m_timeframe;
         zone.touchCount   = 1;
         zone.mitigationState = STATE_UNMITIGATED;

         if(pt.IsHigh())
         {
            zone.type        = ZONE_SUPPLY;
            zone.topPrice    = pt.Price();
            zone.bottomPrice = pt.Price() - defaultZoneWidth;
            zone.meanPrice   = (zone.topPrice + zone.bottomPrice) * 0.5;
         }
         else // pt.IsLow()
         {
            zone.type        = ZONE_DEMAND;
            zone.bottomPrice = pt.Price();
            zone.topPrice    = pt.Price() + defaultZoneWidth;
            zone.meanPrice   = (zone.topPrice + zone.bottomPrice) * 0.5;
         }

         rawCount++;
         ArrayResize(rawZones, rawCount);
         rawZones[rawCount - 1] = zone;
      }

      if(rawCount == 0)
         return false;

      // Step 2: Cluster & Merge overlapping / adjacent zones
      SZone clusteredZones[];
      int clusterCount = 0;
      bool mergedFlags[];
      ArrayResize(mergedFlags, rawCount);
      ArrayInitialize(mergedFlags, false);

      for(int i = 0; i < rawCount; i++)
      {
         if(mergedFlags[i])
            continue;

         SZone primary = rawZones[i];

         for(int j = i + 1; j < rawCount; j++)
         {
            if(mergedFlags[j] || rawZones[j].type != primary.type)
               continue;

            // Check distance between zone mean prices
            double dist = MathAbs(rawZones[j].meanPrice - primary.meanPrice);
            if(dist <= clusterTolerance)
            {
               // Merge zone j into primary
               primary.topPrice    = MathMax(primary.topPrice, rawZones[j].topPrice);
               primary.bottomPrice = MathMin(primary.bottomPrice, rawZones[j].bottomPrice);
               primary.meanPrice   = (primary.topPrice + primary.bottomPrice) * 0.5;
               primary.touchCount += rawZones[j].touchCount;
               primary.creationTime = MathMin(primary.creationTime, rawZones[j].creationTime);
               mergedFlags[j] = true;
            }
         }

         clusterCount++;
         ArrayResize(clusteredZones, clusterCount);
         clusteredZones[clusterCount - 1] = primary;
      }

      // Step 3: Mitigation tracking & Touch counting against historical candle closes
      for(int z = 0; z < clusterCount; z++)
      {
         int touches = clusteredZones[z].touchCount;
         bool isMitigated = false;
         double maxDisplacement = 0.0;
         int elapsedBars = 0;

         // Traverse bars forward from zone creation time
         for(int b = copied - 1; b >= 0; b--)
         {
            if(rates[b].time >= clusteredZones[z].creationTime)
            {
               elapsedBars = b;

               if(clusteredZones[z].type == ZONE_DEMAND)
               {
                  // Candle close below demand bottomPrice confirms broken/mitigated zone
                  if(rates[b].close < clusteredZones[z].bottomPrice)
                  {
                     isMitigated = true;
                     clusteredZones[z].mitigationState = STATE_MITIGATED;
                  }
                  // Touch: low enters zone without closing below
                  else if(rates[b].low <= clusteredZones[z].topPrice && rates[b].low >= clusteredZones[z].bottomPrice)
                  {
                     touches++;
                     double disp = rates[b].high - clusteredZones[z].topPrice;
                     if(disp > maxDisplacement) maxDisplacement = disp;
                  }
               }
               else // ZONE_SUPPLY
               {
                  // Candle close above supply topPrice confirms broken/mitigated zone
                  if(rates[b].close > clusteredZones[z].topPrice)
                  {
                     isMitigated = true;
                     clusteredZones[z].mitigationState = STATE_MITIGATED;
                  }
                  // Touch: high enters zone without closing above
                  else if(rates[b].high >= clusteredZones[z].bottomPrice && rates[b].high <= clusteredZones[z].topPrice)
                  {
                     touches++;
                     double disp = clusteredZones[z].bottomPrice - rates[b].low;
                     if(disp > maxDisplacement) maxDisplacement = disp;
                  }
               }
            }
         }

         clusteredZones[z].touchCount = MathMin(touches, 6);

         // Step 4: Calculate 100-point composite score
         int sTF       = GetTimeframeScore(m_timeframe);
         int sRecency  = GetRecencyScore(elapsedBars);
         int sTouch    = GetTouchScore(clusteredZones[z].touchCount);
         int sReaction = GetReactionScore(maxDisplacement, atr);

         int totalScore = sTF + sRecency + sTouch + sReaction;
         if(isMitigated)
            totalScore = (int)(totalScore * 0.3); // Severe penalty for mitigated zones

         clusteredZones[z].strengthScore = MathMin(100, MathMax(0, totalScore));

         // Only retain active, unmitigated zones meeting the minimum score threshold
         if(!isMitigated && clusteredZones[z].strengthScore >= m_minScoreToKeep)
         {
            marketData.AddZone(clusteredZones[z]);
         }
      }

      return (marketData.TotalZones() > 0);
   }

   //+------------------------------------------------------------------+
   //| Retrieves nearest active unmitigated zone                        |
   //+------------------------------------------------------------------+
   bool GetNearestZone(const CMarketData &marketData, const double currentPrice, const ENUM_ZONE_TYPE type, SZone &outZone) const
   {
      double minDistance = DBL_MAX;
      bool found = false;
      int total = marketData.TotalZones();

      for(int i = 0; i < total; i++)
      {
         SZone z;
         if(marketData.GetZone(i, z))
         {
            if(z.type == type && z.mitigationState != STATE_MITIGATED)
            {
               double dist = MathAbs(currentPrice - z.meanPrice);
               if(dist < minDistance)
               {
                  minDistance = dist;
                  outZone = z;
                  found = true;
               }
            }
         }
      }
      return found;
   }
};

#endif // __IMSF_ZONEENGINE_MQH__

