//+------------------------------------------------------------------+
//|                                                   NewsFilter.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_NEWSFILTER_MQH__
#define __IMSF_NEWSFILTER_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Class CNewsFilter                                                |
//| Interfaces with MT5 native Economic Calendar to halt trading     |
//| before and after high-impact macroeconomic events (CPI, NFP, etc)|
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   bool                 m_enabled;
   int                  m_pauseBeforeMinutes;
   int                  m_pauseAfterMinutes;
   bool                 m_highImpactOnly;

public:
   // Default Constructor
   CNewsFilter() :
      m_enabled(true),
      m_pauseBeforeMinutes(30),
      m_pauseAfterMinutes(30),
      m_highImpactOnly(true)
   {
   }

   // Parameterized Constructor
   CNewsFilter(const bool enabled,
               const int beforeMins = 30,
               const int afterMins = 30,
               const bool highImpactOnly = true) :
      m_enabled(enabled),
      m_pauseBeforeMinutes(beforeMins),
      m_pauseAfterMinutes(afterMins),
      m_highImpactOnly(highImpactOnly)
   {
   }

   ~CNewsFilter()
   {
   }

   void SetEnabled(const bool enabled)             { m_enabled = enabled; }
   bool IsEnabled() const                          { return m_enabled; }
   void SetPauseWindow(const int before, const int after)
   {
      m_pauseBeforeMinutes = before;
      m_pauseAfterMinutes  = after;
   }

   // Detects if current time is within high-impact news blackout window
   bool IsNewsBlackoutActive(const string symbol)
   {
      if(!m_enabled)
         return false;

      datetime now = TimeCurrent();
      datetime fromTime = now - (m_pauseAfterMinutes * 60);
      datetime toTime   = now + (m_pauseBeforeMinutes * 60);

      string baseCurr  = StringSubstr(symbol, 0, 3);
      string quoteCurr = StringSubstr(symbol, 3, 3);

      MqlCalendarValue values[];
      int count = CalendarValueHistory(values, fromTime, toTime);

      if(count > 0)
      {
         for(int i = 0; i < count; i++)
         {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
            {
               MqlCalendarCountry country;
               if(CalendarCountryById(event.country_id, country))
               {
                  if(country.currency == baseCurr || country.currency == quoteCurr)
                  {
                     if(!m_highImpactOnly || event.importance >= CALENDAR_IMPORTANCE_HIGH)
                     {
                        return true; // Blackout active
                     }
                  }
               }
            }
         }
      }

      return false;
   }

   // Diagnostic: Queries if any major event is coming up in next lookahead window
   bool GetUpcomingMajorEvent(const string symbol, string &outEventName, datetime &outEventTime)
   {
      datetime now = TimeCurrent();
      datetime toTime = now + (m_pauseBeforeMinutes * 60);

      MqlCalendarValue values[];
      int count = CalendarValueHistory(values, now, toTime);

      if(count > 0)
      {
         for(int i = 0; i < count; i++)
         {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
            {
               if(event.importance >= CALENDAR_IMPORTANCE_HIGH)
               {
                  outEventName = event.name;
                  outEventTime = values[i].time;
                  return true;
               }
            }
         }
      }
      return false;
   }
};

#endif // __IMSF_NEWSFILTER_MQH__
