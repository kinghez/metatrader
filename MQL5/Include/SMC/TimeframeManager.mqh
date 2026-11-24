//+------------------------------------------------------------------+
//|                                             TimeframeManager.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_TIMEFRAMEMANAGER_MQH__
#define __IMSF_TIMEFRAMEMANAGER_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"
#include "MarketData.mqh"
#include "SwingDetector.mqh"
#include "MarketStructure.mqh"
#include "ZoneEngine.mqh"
#include "FVGEngine.mqh"
#include "OrderBlockEngine.mqh"
#include "LiquidityEngine.mqh"

//+------------------------------------------------------------------+
//| Class CTimeframeManager                                          |
//| Coordinates multi-timeframe synchronization (Macro, Setup, and   |
//| Trigger tiers), eliminates async data lag, and calculates a      |
//| multi-tier confluence score and systemic directional bias.       |
//+------------------------------------------------------------------+
class CTimeframeManager
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_macroTF;   // Tier 1: Macro Trend & Major Liquidity (e.g. H4/D1)
   ENUM_TIMEFRAMES      m_setupTF;   // Tier 2: Intermediate Setup & Retracements (e.g. H1)
   ENUM_TIMEFRAMES      m_triggerTF; // Tier 3: Micro Trigger & Execution (e.g. M15/M5/Current)

   CMarketData          m_macroData;
   CMarketData          m_setupData;
   CMarketData          m_triggerData;

   CSwingDetector       m_macroDetector;
   CSwingDetector       m_setupDetector;
   CSwingDetector       m_triggerDetector;

   CMarketStructure     m_macroStructure;
   CMarketStructure     m_setupStructure;
   CMarketStructure     m_triggerStructure;

   CZoneEngine          m_macroZoneEngine;
   CZoneEngine          m_setupZoneEngine;

   COrderBlockEngine    m_macroOBEngine;
   CFVGEngine           m_macroFVGEngine;

   CLiquidityEngine     m_setupLiqEngine;
   CLiquidityEngine     m_triggerLiqEngine;

   ENUM_TREND_BIAS      m_confluenceBias;
   int                  m_confluenceScore;

   // Internal: Checks and initiates background server synchronization for secondary timeframe
   bool EnsureHistorySynchronized(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      if(!SeriesInfoInteger(symbol, tf, SERIES_SYNCHRONIZED))
      {
         datetime temp[];
         ArraySetAsSeries(temp, true);
         CopyTime(symbol, tf, 0, 1, temp);
         return false;
      }
      return true;
   }

public:
   // Default Constructor
   CTimeframeManager() :
      m_symbol(_Symbol),
      m_macroTF(PERIOD_H4),
      m_setupTF(PERIOD_H1),
      m_triggerTF(PERIOD_CURRENT),
      m_confluenceBias(BIAS_NEUTRAL),
      m_confluenceScore(50)
   {
   }

   // Parameterized Constructor
   CTimeframeManager(const string symbol,
                     const ENUM_TIMEFRAMES macroTF = PERIOD_H4,
                     const ENUM_TIMEFRAMES setupTF = PERIOD_H1,
                     const ENUM_TIMEFRAMES triggerTF = PERIOD_CURRENT) :
      m_symbol(symbol),
      m_macroTF(macroTF),
      m_setupTF(setupTF),
      m_triggerTF(triggerTF),
      m_confluenceBias(BIAS_NEUTRAL),
      m_confluenceScore(50)
   {
   }

   // Destructor
   ~CTimeframeManager()
   {
      m_macroData.ClearAll();
      m_setupData.ClearAll();
      m_triggerData.ClearAll();
   }

   // Initialize detector ATR handles
   bool Init(const string symbol = "")
   {
      if(symbol != "")
         m_symbol = symbol;

      bool okMacro   = m_macroDetector.Init(m_symbol, m_macroTF);
      bool okSetup   = m_setupDetector.Init(m_symbol, m_setupTF);
      bool okTrigger = m_triggerDetector.Init(m_symbol, m_triggerTF);

      return (okMacro && okSetup && okTrigger);
   }

   // Dynamic timeframe configuration
   void SetTimeframes(const ENUM_TIMEFRAMES macroTF,
                      const ENUM_TIMEFRAMES setupTF,
                      const ENUM_TIMEFRAMES triggerTF)
   {
      m_macroTF   = macroTF;
      m_setupTF   = setupTF;
      m_triggerTF = triggerTF;
      Init(m_symbol);
   }

   //+------------------------------------------------------------------+
   //| Core MTF Pipeline: Synchronizes and processes all 3 tiers        |
   //+------------------------------------------------------------------+
   bool SyncAllTiers(const int maxBars = 400)
   {
      EnsureHistorySynchronized(m_symbol, m_macroTF);
      EnsureHistorySynchronized(m_symbol, m_setupTF);
      EnsureHistorySynchronized(m_symbol, m_triggerTF);

      // 1. Tier 1: Macro Processing (H4/D1)
      m_macroDetector.ScanHistory(m_macroData, maxBars);
      m_macroStructure.Analyze(m_macroData);
      m_macroZoneEngine.BuildZones(m_macroData, maxBars);
      m_macroOBEngine.DetectOrderBlocks(m_macroData, maxBars);
      m_macroFVGEngine.ScanFVGs(m_macroData, maxBars);

      // 2. Tier 2: Intermediate Setup Processing (H1)
      m_setupDetector.ScanHistory(m_setupData, maxBars);
      m_setupStructure.Analyze(m_setupData);
      m_setupZoneEngine.BuildZones(m_setupData, maxBars);
      m_setupLiqEngine.DetectSweeps(m_setupData, 10);

      // 3. Tier 3: Micro Trigger Processing (M15/M5/Current)
      m_triggerDetector.ScanHistory(m_triggerData, maxBars);
      m_triggerStructure.Analyze(m_triggerData);
      m_triggerLiqEngine.DetectSweeps(m_triggerData, 8);

      // 4. Compute 3-Tier Confluence Matrix
      CalculateConfluence();

      return true;
   }

   //+------------------------------------------------------------------+
   //| Computes Confluence Score (0 - 100) and Directional Bias         |
   //+------------------------------------------------------------------+
   void CalculateConfluence()
   {
      ENUM_TREND_BIAS macroBias   = m_macroStructure.CurrentBias();
      ENUM_TREND_BIAS setupBias   = m_setupStructure.CurrentBias();
      ENUM_TREND_BIAS triggerBias = m_triggerStructure.CurrentBias();

      int score = 40; // Base score

      // Component 1: Multi-Tier Trend Harmony (up to 50 pts)
      if(macroBias == setupBias && macroBias != BIAS_NEUTRAL)
      {
         score += 35;
         if(triggerBias == macroBias)
            score += 15; // Full 3-tier confluence!
      }
      else if(macroBias != BIAS_NEUTRAL && setupBias == BIAS_NEUTRAL)
      {
         score += 15;
      }
      else if(macroBias != setupBias && macroBias != BIAS_NEUTRAL && setupBias != BIAS_NEUTRAL)
      {
         score -= 25; // Conflict between Macro and Intermediate setup
      }

      // Component 2: SMC Setup Confluence (Liquidity Run or OB retest) (+10 pts)
      if(m_setupLiqEngine.HasActiveSweep() || m_triggerLiqEngine.HasActiveSweep())
         score += 10;

      m_confluenceScore = MathMin(100, MathMax(0, score));

      // Determine Combined Confluence Bias
      if(macroBias == BIAS_BULLISH && setupBias == BIAS_BULLISH && m_confluenceScore >= 65)
         m_confluenceBias = BIAS_BULLISH;
      else if(macroBias == BIAS_BEARISH && setupBias == BIAS_BEARISH && m_confluenceScore >= 65)
         m_confluenceBias = BIAS_BEARISH;
      else
         m_confluenceBias = BIAS_NEUTRAL;
   }

   // Getters & Status Queries
   ENUM_TREND_BIAS GetMacroBias() const          { return m_macroStructure.CurrentBias(); }
   ENUM_TREND_BIAS GetSetupBias() const          { return m_setupStructure.CurrentBias(); }
   ENUM_TREND_BIAS GetTriggerBias() const        { return m_triggerStructure.CurrentBias(); }
   ENUM_TREND_BIAS GetConfluenceBias() const      { return m_confluenceBias; }
   int             GetConfluenceScore() const     { return m_confluenceScore; }

   ENUM_TREND_BIAS GetBias(const ENUM_TIMEFRAMES tf) const
   {
      if(tf == m_macroTF) return GetMacroBias();
      if(tf == m_setupTF) return GetSetupBias();
      return GetTriggerBias();
   }

   bool IsBullishConfluence() const               { return (m_confluenceBias == BIAS_BULLISH); }
   bool IsBearishConfluence() const               { return (m_confluenceBias == BIAS_BEARISH); }

   ENUM_TIMEFRAMES MacroTimeframe() const         { return m_macroTF; }
   ENUM_TIMEFRAMES SetupTimeframe() const         { return m_setupTF; }
   ENUM_TIMEFRAMES TriggerTimeframe() const       { return m_triggerTF; }

   CMarketData* GetMacroData()                    { return &m_macroData; }
   CMarketData* GetSetupData()                    { return &m_setupData; }
   CMarketData* GetTriggerData()                  { return &m_triggerData; }

   string BiasToString(const ENUM_TREND_BIAS b) const
   {
      switch(b)
      {
         case BIAS_BULLISH: return "BULL";
         case BIAS_BEARISH: return "BEAR";
         default:           return "NEUT";
      }
   }

   string GetConfluenceSummary() const
   {
      return StringFormat("[%s (%d/100)] Macro(%s): %s | Setup(%s): %s | Trigger(%s): %s",
                          (m_confluenceBias == BIAS_BULLISH ? "BULLISH" : (m_confluenceBias == BIAS_BEARISH ? "BEARISH" : "NEUTRAL")),
                          m_confluenceScore,
                          EnumToString(m_macroTF), BiasToString(GetMacroBias()),
                          EnumToString(m_setupTF), BiasToString(GetSetupBias()),
                          EnumToString(m_triggerTF), BiasToString(GetTriggerBias()));
   }
};

#endif // __IMSF_TIMEFRAMEMANAGER_MQH__

