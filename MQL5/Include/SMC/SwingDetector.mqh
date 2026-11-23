//+------------------------------------------------------------------+
//|                                                SwingDetector.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_SWINGDETECTOR_MQH__
#define __IMSF_SWINGDETECTOR_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CSwingDetector                                             |
//| Mathematically rigorous, non-repainting pivot detection engine   |
//| with ATR volatility filtering and minimum bar separation.        |
//+------------------------------------------------------------------+
class CSwingDetector
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   int                  m_leftBars;
   int                  m_rightBars;
   int                  m_minBarsBetween;
   int                  m_atrPeriod;
   double               m_atrMultiplier;
   bool                 m_useAtrFilter;
   int                  m_atrHandle;

   //+------------------------------------------------------------------+
   //| Internal: Calculates composite strength score (0-100)            |
   //+------------------------------------------------------------------+
   int CalculateStrengthScore(const double swingPrice, 
                              const double oppositePrice, 
                              const double atr, 
                              const double open, 
                              const double close, 
                              const double high, 
                              const double low, 
                              const bool isHigh)
   {
      if(atr <= 0.0)
         return 50;

      int score = 25; // Base confirmation points

      // 1. Displacement factor relative to ATR (up to 40 pts)
      double displacement = MathAbs(swingPrice - oppositePrice);
      double atrRatio = displacement / atr;
      int dispPts = (int)MathMin(40.0, atrRatio * 15.0);
      score += dispPts;

      // 2. Rejection wick ratio (up to 35 pts)
      double candleRange = high - low;
      if(candleRange > 0.0)
      {
         double wick = isHigh ? (high - MathMax(open, close)) : (MathMin(open, close) - low);
         double wickRatio = wick / candleRange;
         int wickPts = (int)MathMin(35.0, wickRatio * 50.0);
         score += wickPts;
      }

      return (int)MathMin(100, MathMax(15, score));
   }

public:
   // Default Constructor
   CSwingDetector() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_leftBars(InpSwingLeftBars),
      m_rightBars(InpSwingRightBars),
      m_minBarsBetween(InpMinBarsBetweenSwings),
      m_atrPeriod(InpATRPeriod),
      m_atrMultiplier(InpATRMultiplier),
      m_useAtrFilter(InpFilterNoiseWithATR),
      m_atrHandle(INVALID_HANDLE)
   {
   }

   // Parameterized Constructor
   CSwingDetector(const string symbol,
                  const ENUM_TIMEFRAMES timeframe,
                  const int leftBars,
                  const int rightBars,
                  const int minBarsBetween,
                  const int atrPeriod,
                  const double atrMultiplier,
                  const bool useAtrFilter) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_leftBars(leftBars),
      m_rightBars(rightBars),
      m_minBarsBetween(minBarsBetween),
      m_atrPeriod(atrPeriod),
      m_atrMultiplier(atrMultiplier),
      m_useAtrFilter(useAtrFilter),
      m_atrHandle(INVALID_HANDLE)
   {
   }

   // Destructor
   ~CSwingDetector()
   {
      Release();
   }

   // Initialization
   bool Init(const string symbol = "", const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      if(symbol != "")
         m_symbol = symbol;
      if(timeframe != PERIOD_CURRENT)
         m_timeframe = timeframe;

      Release();
      m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
      return (m_atrHandle != INVALID_HANDLE);
   }

   void Release()
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
   }

   // Dynamic Configuration Setters
   void SetLeftBars(const int bars)          { m_leftBars = MathMax(2, bars); }
   void SetRightBars(const int bars)         { m_rightBars = MathMax(2, bars); }
   void SetMinBarsBetween(const int bars)    { m_minBarsBetween = MathMax(1, bars); }
   void SetATRMultiplier(const double mult)  { m_atrMultiplier = MathMax(0.1, mult); }
   void SetUseATRFilter(const bool useFilter){ m_useAtrFilter = useFilter; }

   //+------------------------------------------------------------------+
   //| Scans historical rates directly using CopyRates                  |
   //| Rebuilds confirmed swings into CMarketData chronologically        |
   //+------------------------------------------------------------------+
   bool ScanHistory(CMarketData &marketData, const int maxBars = 600)
   {
      int fetchBars = MathMax(maxBars, (m_leftBars + m_rightBars + m_minBarsBetween * 2 + 50));
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      int copied = CopyRates(m_symbol, m_timeframe, 0, fetchBars, rates);
      if(copied < (m_leftBars + m_rightBars + 10))
         return false;

      double atrValues[];
      ArraySetAsSeries(atrValues, true);
      if(m_atrHandle == INVALID_HANDLE)
         Init(m_symbol, m_timeframe);

      bool hasAtr = (CopyBuffer(m_atrHandle, 0, 0, copied, atrValues) > 0);

      marketData.ClearSwings();

      // Iterate chronologically from oldest closed candidate to newest closed candidate
      // i is series index (0 = current open bar, 1 = last closed bar)
      // For swing to be confirmed, right bars must be fully closed => i - m_rightBars >= 1 => i >= m_rightBars + 1
      // Left bars must exist in copied array => i + m_leftBars < copied
      int startBar = copied - m_leftBars - 1;
      int endBar   = m_rightBars + 1;

      for(int i = startBar; i >= endBar; i--)
      {
         double currentAtr = hasAtr ? atrValues[i] : (rates[i].high - rates[i].low);

         //--- Check Candidate Swing High
         bool isHigh = true;
         for(int l = 1; l <= m_leftBars; l++)
         {
            if(rates[i].high <= rates[i + l].high)
            {
               isHigh = false;
               break;
            }
         }
         if(isHigh)
         {
            for(int r = 1; r <= m_rightBars; r++)
            {
               if(rates[i].high < rates[i - r].high)
               {
                  isHigh = false;
                  break;
               }
            }
         }

         //--- Check Candidate Swing Low
         bool isLow = true;
         for(int l = 1; l <= m_leftBars; l++)
         {
            if(rates[i].low >= rates[i + l].low)
            {
               isLow = false;
               break;
            }
         }
         if(isLow)
         {
            for(int r = 1; r <= m_rightBars; r++)
            {
               if(rates[i].low > rates[i - r].low)
               {
                  isLow = false;
                  break;
               }
            }
         }

         // Process Swing High
         if(isHigh && !isLow)
         {
            ProcessCandidateSwing(SWING_HIGH, rates[i].high, rates[i].time, i, currentAtr,
                                  rates[i].open, rates[i].close, rates[i].high, rates[i].low, marketData);
         }
         // Process Swing Low
         else if(isLow && !isHigh)
         {
            ProcessCandidateSwing(SWING_LOW, rates[i].low, rates[i].time, i, currentAtr,
                                  rates[i].open, rates[i].close, rates[i].high, rates[i].low, marketData);
         }
         // Rare outside candle: evaluate larger rejection wick
         else if(isHigh && isLow)
         {
            double upperWick = rates[i].high - MathMax(rates[i].open, rates[i].close);
            double lowerWick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
            if(upperWick >= lowerWick)
            {
               ProcessCandidateSwing(SWING_HIGH, rates[i].high, rates[i].time, i, currentAtr,
                                     rates[i].open, rates[i].close, rates[i].high, rates[i].low, marketData);
            }
            else
            {
               ProcessCandidateSwing(SWING_LOW, rates[i].low, rates[i].time, i, currentAtr,
                                     rates[i].open, rates[i].close, rates[i].high, rates[i].low, marketData);
            }
         }
      }

      return (marketData.TotalSwings() > 0);
   }

private:
   //+------------------------------------------------------------------+
   //| Internal: Filters and appends verified swing point to MarketData |
   //+------------------------------------------------------------------+
   void ProcessCandidateSwing(const ENUM_SWING_TYPE swingType,
                              const double price,
                              const datetime time,
                              const int barIndex,
                              const double atr,
                              const double open,
                              const double close,
                              const double high,
                              const double low,
                              CMarketData &marketData)
   {
      CSwingPoint* lastSwing = marketData.GetLatestSwing();

      if(lastSwing == NULL)
      {
         // First swing point established
         CSwingPoint* pt = new CSwingPoint(time, price, barIndex, swingType, atr);
         pt.SetConfirmed(true);
         pt.SetStrengthScore(50);
         marketData.AddSwing(pt);
         return;
      }

      // Case 1: Same type consecutive swing (Consecutive Highs or Consecutive Lows)
      if(lastSwing.SwingType() == swingType)
      {
         int barDistance = MathAbs(lastSwing.BarIndex() - barIndex);

         if(swingType == SWING_HIGH)
         {
            // Update to higher high if within cluster or more extreme
            if(price > lastSwing.Price())
            {
               lastSwing.SetPrice(price);
               lastSwing.SetTime(time);
               lastSwing.SetBarIndex(barIndex);
               lastSwing.SetAtr(atr);
            }
         }
         else // SWING_LOW
         {
            // Update to lower low if within cluster or more extreme
            if(price < lastSwing.Price())
            {
               lastSwing.SetPrice(price);
               lastSwing.SetTime(time);
               lastSwing.SetBarIndex(barIndex);
               lastSwing.SetAtr(atr);
            }
         }
         return;
      }

      // Case 2: Opposite type swing (High -> Low or Low -> High)
      // Enforce Minimum Bar Distance Filter
      int distance = MathAbs(lastSwing.BarIndex() - barIndex);
      if(distance < m_minBarsBetween)
         return;

      // Enforce ATR Volatility Filter
      double priceDelta = MathAbs(price - lastSwing.Price());
      if(m_useAtrFilter && atr > 0.0)
      {
         double requiredDelta = m_atrMultiplier * atr;
         if(priceDelta < requiredDelta)
            return; // Noise rejection
      }

      // Calculate institutional quality score
      int score = CalculateStrengthScore(price, lastSwing.Price(), atr, open, close, high, low, (swingType == SWING_HIGH));

      CSwingPoint* newPoint = new CSwingPoint(time, price, barIndex, swingType, atr);
      newPoint.SetConfirmed(true);
      newPoint.SetStrengthScore(score);
      marketData.AddSwing(newPoint);
   }
};

#endif // __IMSF_SWINGDETECTOR_MQH__

