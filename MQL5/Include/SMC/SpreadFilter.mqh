//+------------------------------------------------------------------+
//|                                                 SpreadFilter.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_SPREADFILTER_MQH__
#define __IMSF_SPREADFILTER_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Class CSpreadFilter                                              |
//| Enforces protection against spread spikes, daily bank rollover   |
//| illiquidity windows (23:45-00:30 server), and Friday night closes|
//+------------------------------------------------------------------+
class CSpreadFilter
{
private:
   double               m_maxSpreadPips;
   bool                 m_useRolloverFilter;
   int                  m_rolloverStartHour;
   int                  m_rolloverStartMin;
   int                  m_rolloverEndHour;
   int                  m_rolloverEndMin;
   bool                 m_closeOnFridayNight;
   int                  m_fridayCloseHour;

public:
   // Default Constructor
   CSpreadFilter() :
      m_maxSpreadPips(InpMaxSpreadPips),
      m_useRolloverFilter(InpRolloverFilter),
      m_rolloverStartHour(23),
      m_rolloverStartMin(45),
      m_rolloverEndHour(0),
      m_rolloverEndMin(30),
      m_closeOnFridayNight(true),
      m_fridayCloseHour(21)
   {
   }

   // Parameterized Constructor
   CSpreadFilter(const double maxSpreadPips,
                 const bool useRollover,
                 const int startHour = 23,
                 const int startMin = 45,
                 const int endHour = 0,
                 const int endMin = 30) :
      m_maxSpreadPips(maxSpreadPips),
      m_useRolloverFilter(useRollover),
      m_rolloverStartHour(startHour),
      m_rolloverStartMin(startMin),
      m_rolloverEndHour(endHour),
      m_rolloverEndMin(endMin),
      m_closeOnFridayNight(true),
      m_fridayCloseHour(21)
   {
   }

   ~CSpreadFilter()
   {
   }

   void SetMaxSpreadPips(const double pips)      { m_maxSpreadPips = pips; }
   void SetRolloverFilter(const bool enabled)    { m_useRolloverFilter = enabled; }

   // Check if current spread exceeds maximum allowable threshold
   bool IsSpreadAcceptable(const string symbol) const
   {
      long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double currentSpreadPips = CUtilities::PointsToPips((double)spreadPoints, symbol);
      return (currentSpreadPips <= m_maxSpreadPips);
   }

   double GetCurrentSpreadPips(const string symbol) const
   {
      long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      return CUtilities::PointsToPips((double)spreadPoints, symbol);
   }

   // Check if currently inside the daily bank rollover blackout window (23:45 - 00:30)
   bool IsInRolloverWindow() const
   {
      if(!m_useRolloverFilter)
         return false;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentMinutes = dt.hour * 60 + dt.min;
      int startMinutes   = m_rolloverStartHour * 60 + m_rolloverStartMin;
      int endMinutes     = m_rolloverEndHour * 60 + m_rolloverEndMin;

      // Rollover window crossing midnight
      if(startMinutes > endMinutes)
      {
         if(currentMinutes >= startMinutes || currentMinutes <= endMinutes)
            return true;
      }
      else
      {
         if(currentMinutes >= startMinutes && currentMinutes <= endMinutes)
            return true;
      }

      return false;
   }

   // Check if approaching Friday market close (prevents weekend gap risk)
   bool IsWeekendCloseWindow() const
   {
      if(!m_closeOnFridayNight)
         return false;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      // 5 = Friday
      if(dt.day_of_week == 5 && dt.hour >= m_fridayCloseHour)
         return true;

      return false;
   }

   // Combined execution safety evaluator
   bool IsExecutionSafe(const string symbol) const
   {
      if(!IsSpreadAcceptable(symbol))
         return false;

      if(IsInRolloverWindow())
         return false;

      if(IsWeekendCloseWindow())
         return false;

      return true;
   }
};

#endif // __IMSF_SPREADFILTER_MQH__
