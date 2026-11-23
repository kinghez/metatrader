//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_MARKETSTRUCTURE_MQH__
#define __IMSF_MARKETSTRUCTURE_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"

//+------------------------------------------------------------------+
//| Class CMarketStructure                                           |
//| Classifies confirmed swings into HH, HL, LH, LL and computes     |
//| systemic trend bias and structural reversal events.              |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_epsilon;
   ENUM_TREND_BIAS      m_currentBias;
   ENUM_TREND_BIAS      m_previousBias;
   bool                 m_hasBullishReversal;
   bool                 m_hasBearishReversal;

public:
   // Default Constructor
   CMarketStructure() :
      m_symbol(_Symbol),
      m_timeframe(PERIOD_CURRENT),
      m_currentBias(BIAS_NEUTRAL),
      m_previousBias(BIAS_NEUTRAL),
      m_hasBullishReversal(false),
      m_hasBearishReversal(false)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_epsilon = (point > 0.0) ? (point * 0.5) : 0.00001;
   }

   // Parameterized Constructor
   CMarketStructure(const string symbol, const ENUM_TIMEFRAMES timeframe) :
      m_symbol(symbol),
      m_timeframe(timeframe),
      m_currentBias(BIAS_NEUTRAL),
      m_previousBias(BIAS_NEUTRAL),
      m_hasBullishReversal(false),
      m_hasBearishReversal(false)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_epsilon = (point > 0.0) ? (point * 0.5) : 0.00001;
   }

   // Destructor
   ~CMarketStructure()
   {
   }

   //+------------------------------------------------------------------+
   //| Core Analysis: Evaluates all swings in MarketData                |
   //| Classifies HH, HL, LH, LL and sets trend bias                    |
   //+------------------------------------------------------------------+
   bool Analyze(CMarketData &marketData)
   {
      int total = marketData.TotalSwings();
      if(total < 2)
      {
         m_currentBias = BIAS_NEUTRAL;
         marketData.SetTrendBias(m_currentBias);
         return false;
      }

      CSwingPoint* prevHigh = NULL;
      CSwingPoint* prevLow  = NULL;

      m_hasBullishReversal = false;
      m_hasBearishReversal = false;

      // Chronological pass through all swings
      for(int i = 0; i < total; i++)
      {
         CSwingPoint* curr = marketData.GetSwing(i);
         if(CheckPointer(curr) == POINTER_INVALID || !curr.IsConfirmed())
            continue;

         // Handle Swing High classification
         if(curr.SwingType() == SWING_HIGH)
         {
            if(prevHigh == NULL)
            {
               curr.SetStructureType(STRUCTURE_NONE);
            }
            else
            {
               if(curr.Price() > (prevHigh.Price() + m_epsilon))
                  curr.SetStructureType(STRUCTURE_HH);
               else
                  curr.SetStructureType(STRUCTURE_LH);
            }
            prevHigh = curr;
         }
         // Handle Swing Low classification
         else if(curr.SwingType() == SWING_LOW)
         {
            if(prevLow == NULL)
            {
               curr.SetStructureType(STRUCTURE_NONE);
            }
            else
            {
               if(curr.Price() > (prevLow.Price() + m_epsilon))
                  curr.SetStructureType(STRUCTURE_HL);
               else
                  curr.SetStructureType(STRUCTURE_LL);
            }
            prevLow = curr;
         }
      }

      // Determine Systemic Trend Bias based on latest confirmed High and Low
      CSwingPoint* latestHigh = marketData.GetLatestSwing(SWING_HIGH);
      CSwingPoint* latestLow  = marketData.GetLatestSwing(SWING_LOW);

      ENUM_TREND_BIAS newBias = BIAS_NEUTRAL;

      if(latestHigh != NULL && latestLow != NULL)
      {
         bool isBullHigh = (latestHigh.StructureType() == STRUCTURE_HH);
         bool isBearHigh = (latestHigh.StructureType() == STRUCTURE_LH);
         bool isBullLow  = (latestLow.StructureType()  == STRUCTURE_HL);
         bool isBearLow  = (latestLow.StructureType()  == STRUCTURE_LL);

         // Classic Trend Definitions
         if(isBullHigh && isBullLow)
            newBias = BIAS_BULLISH;
         else if(isBearHigh && isBearLow)
            newBias = BIAS_BEARISH;
         else if(isBullHigh && isBearLow)
            newBias = BIAS_NEUTRAL; // Expanding / Megaphone formation
         else if(isBearHigh && isBullLow)
            newBias = BIAS_NEUTRAL; // Symmetrical triangle / Consolidation
         else if(isBullHigh)
            newBias = BIAS_BULLISH;
         else if(isBearLow)
            newBias = BIAS_BEARISH;
         else
            newBias = BIAS_NEUTRAL;
      }

      // Detect Structural Shift / Reversal Events
      if(m_currentBias == BIAS_BEARISH && newBias == BIAS_BULLISH)
         m_hasBullishReversal = true;
      else if(m_currentBias == BIAS_BULLISH && newBias == BIAS_BEARISH)
         m_hasBearishReversal = true;

      m_previousBias = m_currentBias;
      m_currentBias  = newBias;
      marketData.SetTrendBias(m_currentBias);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Status & Query Methods                                           |
   //+------------------------------------------------------------------+
   ENUM_TREND_BIAS CurrentBias() const          { return m_currentBias; }
   ENUM_TREND_BIAS PreviousBias() const         { return m_previousBias; }
   bool IsBullish() const                       { return (m_currentBias == BIAS_BULLISH); }
   bool IsBearish() const                       { return (m_currentBias == BIAS_BEARISH); }
   bool IsNeutral() const                       { return (m_currentBias == BIAS_NEUTRAL); }
   bool HasBullishReversal() const              { return m_hasBullishReversal; }
   bool HasBearishReversal() const              { return m_hasBearishReversal; }

   string BiasToString() const
   {
      switch(m_currentBias)
      {
         case BIAS_BULLISH: return "BULLISH";
         case BIAS_BEARISH: return "BEARISH";
         default:           return "NEUTRAL";
      }
   }

   //+------------------------------------------------------------------+
   //| Formats recent structural sequence into a readable string        |
   //+------------------------------------------------------------------+
   string GetSequenceString(const CMarketData &marketData, const int maxItems = 6) const
   {
      string result = "";
      int count = 0;
      int total = marketData.TotalSwings();

      for(int i = total - 1; i >= 0 && count < maxItems; i--)
      {
         CSwingPoint* pt = marketData.GetSwing(i);
         if(CheckPointer(pt) != POINTER_INVALID && pt.IsConfirmed())
         {
            string label = CUtilities::StructureToString(pt.StructureType());
            if(label == "NONE")
               label = pt.IsHigh() ? "H" : "L";

            if(result == "")
               result = label;
            else
               result = label + " -> " + result;
            count++;
         }
      }
      return (result == "") ? "NO_STRUCTURE" : result;
   }
};

#endif // __IMSF_MARKETSTRUCTURE_MQH__

