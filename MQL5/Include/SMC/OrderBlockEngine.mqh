//+------------------------------------------------------------------+
//|                                             OrderBlockEngine.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_ORDERBLOCKENGINE_MQH__
#define __IMSF_ORDERBLOCKENGINE_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class COrderBlockEngine                                          |
//| Identifies institutional Order Blocks based on displacement      |
//| candles preceding Fair Value Gaps and tracks mitigation.         |
//+------------------------------------------------------------------+
class COrderBlockEngine
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_atrFilterMultiplier;

public:
   COrderBlockEngine() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_atrFilterMultiplier(0.8)
   {
   }

   COrderBlockEngine(const string symbol, const ENUM_TIMEFRAMES timeframe, const double atrMult = 0.8) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_atrFilterMultiplier(atrMult)
   {
   }

   ~COrderBlockEngine()
   {
   }

   //+------------------------------------------------------------------+
   //| Scans for valid institutional Order Blocks with FVG confirmation  |
   //+------------------------------------------------------------------+
   bool DetectOrderBlocks(CMarketData &marketData, const int maxBars = 300)
   {
      marketData.ClearOrderBlocks();

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, maxBars, rates);
      if(copied < 20)
         return false;

      double atr = CUtilities::CalculateATR(m_symbol, m_timeframe, InpATRPeriod, 1);
      if(atr <= 0.0)
         atr = (rates[0].high - rates[0].low) * 2.0;

      for(int i = copied - 4; i >= 2; i--)
      {
         // 1. Bullish Order Block:
         // Impulsive expansion candle at bar i-1 forming FVG at bar i-2
         bool hasBullishFVG = (rates[i - 2].low > rates[i].high);
         bool isBullishImpulse = (rates[i - 1].close > rates[i - 1].open && 
                                 (rates[i - 1].close - rates[i - 1].open) >= (m_atrFilterMultiplier * atr));

         if(hasBullishFVG && isBullishImpulse)
         {
            int obIndex = i;
            // The Bullish OB is the last down-close (bearish) candle
            if(rates[obIndex].close >= rates[obIndex].open && (obIndex + 1) < copied)
               obIndex = obIndex + 1;

            SOrderBlock ob;
            ob.id         = (ulong)rates[obIndex].time;
            ob.isBullish  = true;
            ob.time       = rates[obIndex].time;
            ob.openPrice  = rates[obIndex].open;
            ob.closePrice = rates[obIndex].close;
            ob.highPrice  = rates[obIndex].high;
            ob.lowPrice   = rates[obIndex].low;
            ob.fvgGapSize = rates[i - 2].low - rates[i].high;
            ob.isMitigated = false;

            // Mitigation check: did subsequent candle close below the OB low?
            for(int b = obIndex - 1; b >= 0; b--)
            {
               if(rates[b].close < ob.lowPrice)
               {
                  ob.isMitigated = true;
                  ob.mitigationTime = rates[b].time;
                  break;
               }
            }

            if(!ob.isMitigated)
               marketData.AddOrderBlock(ob);
         }

         // 2. Bearish Order Block:
         // Impulsive downward candle at bar i-1 forming FVG at bar i-2
         bool hasBearishFVG = (rates[i - 2].high < rates[i].low);
         bool isBearishImpulse = (rates[i - 1].open > rates[i - 1].close && 
                                 (rates[i - 1].open - rates[i - 1].close) >= (m_atrFilterMultiplier * atr));

         if(hasBearishFVG && isBearishImpulse)
         {
            int obIndex = i;
            if(rates[obIndex].close <= rates[obIndex].open && (obIndex + 1) < copied)
               obIndex = obIndex + 1;

            SOrderBlock ob;
            ob.id         = (ulong)rates[obIndex].time;
            ob.isBullish  = false;
            ob.time       = rates[obIndex].time;
            ob.openPrice  = rates[obIndex].open;
            ob.closePrice = rates[obIndex].close;
            ob.highPrice  = rates[obIndex].high;
            ob.lowPrice   = rates[obIndex].low;
            ob.fvgGapSize = rates[i].low - rates[i - 2].high;
            ob.isMitigated = false;

            for(int b = obIndex - 1; b >= 0; b--)
            {
               if(rates[b].close > ob.highPrice)
               {
                  ob.isMitigated = true;
                  ob.mitigationTime = rates[b].time;
                  break;
               }
            }

            if(!ob.isMitigated)
               marketData.AddOrderBlock(ob);
         }
      }

      return (marketData.TotalOrderBlocks() > 0);
   }

   //+------------------------------------------------------------------+
   //| Retrieves nearest active unmitigated Order Block                 |
   //+------------------------------------------------------------------+
   bool GetNearestOrderBlock(const CMarketData &marketData, const double currentPrice, const bool isBullish, SOrderBlock &outOB) const
   {
      double minDistance = DBL_MAX;
      bool found = false;
      int total = marketData.TotalOrderBlocks();

      for(int i = 0; i < total; i++)
      {
         SOrderBlock ob;
         if(marketData.GetOrderBlock(i, ob))
         {
            if(ob.isBullish == isBullish && !ob.isMitigated)
            {
               double midPrice = (ob.highPrice + ob.lowPrice) * 0.5;
               double dist = MathAbs(currentPrice - midPrice);
               if(dist < minDistance)
               {
                  minDistance = dist;
                  outOB = ob;
                  found = true;
               }
            }
         }
      }
      return found;
   }
};

#endif // __IMSF_ORDERBLOCKENGINE_MQH__

