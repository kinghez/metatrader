//+------------------------------------------------------------------+
//|                                              LiquidityEngine.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_LIQUIDITYENGINE_MQH__
#define __IMSF_LIQUIDITYENGINE_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CLiquidityEngine                                           |
//| Detects Equal Highs (EQH), Equal Lows (EQL), and captures        |
//| Stop-Run Liquidity Sweeps of confirmed swing points.             |
//+------------------------------------------------------------------+
class CLiquidityEngine
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_eqlTolerancePips;
   SLiquiditySweep      m_latestSweep;
   bool                 m_hasActiveSweep;

public:
   CLiquidityEngine() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_eqlTolerancePips(3.0),
      m_hasActiveSweep(false)
   {
   }

   CLiquidityEngine(const string symbol, const ENUM_TIMEFRAMES timeframe, const double tolerancePips = 3.0) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_eqlTolerancePips(tolerancePips),
      m_hasActiveSweep(false)
   {
   }

   ~CLiquidityEngine()
   {
   }

   bool HasActiveSweep() const              { return m_hasActiveSweep; }
   SLiquiditySweep GetLatestSweep() const   { return m_latestSweep; }

   //+------------------------------------------------------------------+
   //| Scans recent bars for Liquidity Sweeps of confirmed swings        |
   //| (Wick pierces swing extreme, but candle body closes back inside)  |
   //+------------------------------------------------------------------+
   bool DetectSweeps(const CMarketData &marketData, const int lookbackBars = 10)
   {
      m_hasActiveSweep = false;

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, lookbackBars + 5, rates);
      if(copied < lookbackBars)
         return false;

      CSwingPoint* latestHigh = marketData.GetLatestSwing(SWING_HIGH);
      CSwingPoint* latestLow  = marketData.GetLatestSwing(SWING_LOW);

      // Check last closed candles for sweep of latest High or latest Low
      for(int b = 1; b <= lookbackBars; b++)
      {
         // 1. Bearish Liquidity Sweep (Buy-side liquidity run)
         // Wick > Swing High, but candle body (Close & Open) strictly < Swing High
         if(latestHigh != NULL && latestHigh.IsConfirmed() && rates[b].time > latestHigh.Time())
         {
            if(rates[b].high > latestHigh.Price() && 
               rates[b].close < latestHigh.Price() && 
               rates[b].open < latestHigh.Price())
            {
               m_latestSweep.id = (ulong)rates[b].time;
               m_latestSweep.isBullishSweep = false; // Bearish trigger
               m_latestSweep.sweepPrice = latestHigh.Price();
               m_latestSweep.extremeWickPrice = rates[b].high;
               m_latestSweep.time = rates[b].time;
               m_latestSweep.barIndex = b;
               m_hasActiveSweep = true;
               return true;
            }
         }

         // 2. Bullish Liquidity Sweep (Sell-side liquidity run)
         // Wick < Swing Low, but candle body (Close & Open) strictly > Swing Low
         if(latestLow != NULL && latestLow.IsConfirmed() && rates[b].time > latestLow.Time())
         {
            if(rates[b].low < latestLow.Price() && 
               rates[b].close > latestLow.Price() && 
               rates[b].open > latestLow.Price())
            {
               m_latestSweep.id = (ulong)rates[b].time;
               m_latestSweep.isBullishSweep = true; // Bullish trigger
               m_latestSweep.sweepPrice = latestLow.Price();
               m_latestSweep.extremeWickPrice = rates[b].low;
               m_latestSweep.time = rates[b].time;
               m_latestSweep.barIndex = b;
               m_hasActiveSweep = true;
               return true;
            }
         }
      }

      return false;
   }
};

#endif // __IMSF_LIQUIDITYENGINE_MQH__

