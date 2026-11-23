//+------------------------------------------------------------------+
//|                                                    Utilities.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_UTILITIES_MQH__
#define __IMSF_UTILITIES_MQH__

#include "Types.mqh"

class CUtilities
{
public:
   //+------------------------------------------------------------------+
   //| Detects when a new bar has opened on a given symbol & timeframe  |
   //+------------------------------------------------------------------+
   static bool IsNewBar(const string symbol, const ENUM_TIMEFRAMES timeframe, datetime &lastBarTime)
   {
      datetime currentBarTime = (datetime)SeriesInfoInteger(symbol, timeframe, SERIES_LASTBAR_DATE);
      if(currentBarTime == 0)
      {
         datetime tempTimes[];
         ArraySetAsSeries(tempTimes, true);
         if(CopyTime(symbol, timeframe, 0, 1, tempTimes) > 0)
            currentBarTime = tempTimes[0];
      }

      if(currentBarTime != 0 && currentBarTime != lastBarTime)
      {
         lastBarTime = currentBarTime;
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Returns accurate pip size accounting for 3/5 digits and metals   |
   //+------------------------------------------------------------------+
   static double GetPipSize(const string symbol)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(digits == 3 || digits == 5)
         return (point * 10.0);
      return point;
   }

   //+------------------------------------------------------------------+
   //| Converts points to pips                                          |
   //+------------------------------------------------------------------+
   static double PointsToPips(const double points, const string symbol)
   {
      double pipSize = GetPipSize(symbol);
      double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pipSize <= 0.0 || point <= 0.0)
         return 0.0;
      return (points * point) / pipSize;
   }

   //+------------------------------------------------------------------+
   //| Converts pips to points                                          |
   //+------------------------------------------------------------------+
   static double PipsToPoints(const double pips, const string symbol)
   {
      double pipSize = GetPipSize(symbol);
      double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return 0.0;
      return (pips * pipSize) / point;
   }

   //+------------------------------------------------------------------+
   //| Converts absolute price difference into pips                     |
   //+------------------------------------------------------------------+
   static double PriceToPips(const double priceDiff, const string symbol)
   {
      double pipSize = GetPipSize(symbol);
      if(pipSize <= 0.0)
         return 0.0;
      return MathAbs(priceDiff) / pipSize;
   }

   //+------------------------------------------------------------------+
   //| Normalized double equality comparison                            |
   //+------------------------------------------------------------------+
   static bool PriceEquals(const double price1, const double price2, const string symbol)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      return (MathAbs(price1 - price2) < (point * 0.5));
   }

   //+------------------------------------------------------------------+
   //| Calculates ATR for any symbol, timeframe and shift               |
   //+------------------------------------------------------------------+
   static double CalculateATR(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift = 0)
   {
      int handle = iATR(symbol, timeframe, period);
      if(handle == INVALID_HANDLE)
         return 0.0;

      double atrValues[];
      ArraySetAsSeries(atrValues, true);
      double result = 0.0;
      if(CopyBuffer(handle, 0, shift, 1, atrValues) > 0)
         result = atrValues[0];

      IndicatorRelease(handle);
      return result;
   }

   //+------------------------------------------------------------------+
   //| Creates unique, deterministic object name                        |
   //+------------------------------------------------------------------+
   static string CreateObjectName(const string prefix, const string tag, const datetime time, const double price)
   {
      return StringFormat("%s%s_%I64d_%.5f", prefix, tag, (long)time, price);
   }

   //+------------------------------------------------------------------+
   //| Converts Structure enum to string                                |
   //+------------------------------------------------------------------+
   static string StructureToString(const ENUM_STRUCTURE_TYPE type)
   {
      switch(type)
      {
         case STRUCTURE_HH: return "HH";
         case STRUCTURE_HL: return "HL";
         case STRUCTURE_LH: return "LH";
         case STRUCTURE_LL: return "LL";
         default:           return "NONE";
      }
   }

   //+------------------------------------------------------------------+
   //| Converts Swing type enum to string                               |
   //+------------------------------------------------------------------+
   static string SwingToString(const ENUM_SWING_TYPE type)
   {
      switch(type)
      {
         case SWING_HIGH: return "HIGH";
         case SWING_LOW:  return "LOW";
         default:         return "NONE";
      }
   }
};

#endif // __IMSF_UTILITIES_MQH__

