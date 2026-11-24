//+------------------------------------------------------------------+
//|                                                    FVGEngine.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_FVGENGINE_MQH__
#define __IMSF_FVGENGINE_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CFVGEngine                                                 |
//| Identifies 3-candle Fair Value Gaps (Imbalances) and tracks      |
//| fill states (UNMITIGATED, 50% Consequent Encroachment, MITIGATED)|
//+------------------------------------------------------------------+
class CFVGEngine
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_minGapAtrRatio;

public:
   CFVGEngine() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_minGapAtrRatio(0.35)
   {
   }

   CFVGEngine(const string symbol, const ENUM_TIMEFRAMES timeframe, const double minGapRatio = 0.35) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_minGapAtrRatio(minGapRatio)
   {
   }

   ~CFVGEngine()
   {
   }

   void SetMinGapAtrRatio(const double ratio) { m_minGapAtrRatio = MathMax(0.1, ratio); }

   //+------------------------------------------------------------------+
   //| Scans rate series for 3-candle Fair Value Gaps and tracks fills   |
   //+------------------------------------------------------------------+
   bool ScanFVGs(CMarketData &marketData, const int maxBars = 300)
   {
      marketData.ClearFVGs();

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, maxBars, rates);
      if(copied < 15)
         return false;

      double atr = CUtilities::CalculateATR(m_symbol, m_timeframe, InpATRPeriod, 1);
      if(atr <= 0.0)
         atr = (rates[0].high - rates[0].low) * 2.0;

      double minGapSize = atr * m_minGapAtrRatio;

      // Scan starting from older closed bars down to bar 1
      for(int i = copied - 3; i >= 1; i--)
      {
         // 3-candle window: Bar i (current), Bar i+1 (impulse candle), Bar i+2 (prior candle)

         // 1. Bullish FVG: Bar i Low > Bar i+2 High
         if(rates[i].low > rates[i + 2].high)
         {
            double gap = rates[i].low - rates[i + 2].high;
            if(gap >= minGapSize)
            {
               SFairValueGap fvg;
               fvg.id          = (ulong)rates[i + 1].time;
               fvg.isBullish   = true;
               fvg.time        = rates[i + 1].time;
               fvg.topPrice    = rates[i].low;
               fvg.bottomPrice = rates[i + 2].high;
               fvg.midPrice    = (fvg.topPrice + fvg.bottomPrice) * 0.5;
               fvg.state       = STATE_UNMITIGATED;
               fvg.fillPercentage = 0.0;

               // Mitigation check from i-1 down to 0
               for(int b = i - 1; b >= 0; b--)
               {
                  if(rates[b].low <= fvg.bottomPrice)
                  {
                     fvg.state = STATE_MITIGATED;
                     fvg.fillPercentage = 100.0;
                     break;
                  }
                  else if(rates[b].low <= fvg.midPrice)
                  {
                     fvg.state = STATE_PARTIAL;
                     fvg.fillPercentage = 50.0;
                  }
               }

               if(fvg.state != STATE_MITIGATED)
                  marketData.AddFVG(fvg);
            }
         }
         // 2. Bearish FVG: Bar i High < Bar i+2 Low
         else if(rates[i].high < rates[i + 2].low)
         {
            double gap = rates[i + 2].low - rates[i].high;
            if(gap >= minGapSize)
            {
               SFairValueGap fvg;
               fvg.id          = (ulong)rates[i + 1].time;
               fvg.isBullish   = false;
               fvg.time        = rates[i + 1].time;
               fvg.topPrice    = rates[i + 2].low;
               fvg.bottomPrice = rates[i].high;
               fvg.midPrice    = (fvg.topPrice + fvg.bottomPrice) * 0.5;
               fvg.state       = STATE_UNMITIGATED;
               fvg.fillPercentage = 0.0;

               for(int b = i - 1; b >= 0; b--)
               {
                  if(rates[b].high >= fvg.topPrice)
                  {
                     fvg.state = STATE_MITIGATED;
                     fvg.fillPercentage = 100.0;
                     break;
                  }
                  else if(rates[b].high >= fvg.midPrice)
                  {
                     fvg.state = STATE_PARTIAL;
                     fvg.fillPercentage = 50.0;
                  }
               }

               if(fvg.state != STATE_MITIGATED)
                  marketData.AddFVG(fvg);
            }
         }
      }

      return (marketData.TotalFVGs() > 0);
   }

   //+------------------------------------------------------------------+
   //| Retrieves nearest active unmitigated FVG                         |
   //+------------------------------------------------------------------+
   bool GetNearestFVG(const CMarketData &marketData, const double currentPrice, const bool isBullish, SFairValueGap &outFVG) const
   {
      double minDistance = DBL_MAX;
      bool found = false;
      int total = marketData.TotalFVGs();

      for(int i = 0; i < total; i++)
      {
         SFairValueGap f;
         if(marketData.GetFVG(i, f))
         {
            if(f.isBullish == isBullish && f.state != STATE_MITIGATED)
            {
               double dist = MathAbs(currentPrice - f.midPrice);
               if(dist < minDistance)
               {
                  minDistance = dist;
                  outFVG = f;
                  found = true;
               }
            }
         }
      }
      return found;
   }
};

#endif // __IMSF_FVGENGINE_MQH__

