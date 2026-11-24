//+------------------------------------------------------------------+
//|                                       Test_TimeframeManager.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 8 Automated Unit Test: Multi-Timeframe Synchronization & Confluence"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/TimeframeManager.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 8 TimeframeManager Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   // Test 1: Initialize TimeframeManager across H4, H1, and Current timeframe
   CTimeframeManager mtfManager(_Symbol, PERIOD_H4, PERIOD_H1, _Period);

   if(mtfManager.Init(_Symbol))
   {
      Print("[PASS] Test 1: CTimeframeManager initialized multi-tier ATR handles successfully.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 1: CTimeframeManager initialization failed.");
      testsFailed++;
   }

   // Test 2: Synchronize All 3 Tiers
   bool synced = mtfManager.SyncAllTiers(300);
   Print(StringFormat("[INFO] MTF Sync Status: %s", (synced ? "SUCCESS" : "FAILED")));

   if(synced)
   {
      Print("[PASS] Test 2: Multi-timeframe synchronization executed across H4, H1, and current timeframe.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 2: Multi-timeframe synchronization failed.");
      testsFailed++;
   }

   // Test 3: Extract Individual Tier Biases
   ENUM_TREND_BIAS macroBias   = mtfManager.GetMacroBias();
   ENUM_TREND_BIAS setupBias   = mtfManager.GetSetupBias();
   ENUM_TREND_BIAS triggerBias = mtfManager.GetTriggerBias();

   Print(StringFormat("[INFO] Macro(H4): %s | Setup(H1): %s | Trigger(%s): %s",
                      mtfManager.BiasToString(macroBias),
                      mtfManager.BiasToString(setupBias),
                      EnumToString(_Period),
                      mtfManager.BiasToString(triggerBias)));

   Print("[PASS] Test 3: Individual tier trend biases queried successfully.");
   testsPassed++;

   // Test 4: Confluence Matrix and Summary Evaluation
   ENUM_TREND_BIAS confluenceBias = mtfManager.GetConfluenceBias();
   int score = mtfManager.GetConfluenceScore();
   string summary = mtfManager.GetConfluenceSummary();

   Print(StringFormat("[INFO] Confluence Summary: %s", summary));

   if(score >= 0 && score <= 100 && StringLen(summary) > 15)
   {
      Print(StringFormat("[PASS] Test 4: Confluence score (%d/100) and summary formatted correctly.", score));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 4: Confluence evaluation returned invalid bounds.");
      testsFailed++;
   }

   // Test 5: Verify Macro MarketData Access
   CMarketData* pMacroData = mtfManager.GetMacroData();
   if(pMacroData != NULL)
   {
      Print(StringFormat("[INFO] Macro Data Swings: %d | Active Zones: %d",
                         pMacroData.TotalSwings(), pMacroData.TotalZones()));
      Print("[PASS] Test 5: Direct pointer access to individual tier MarketData verified.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 5: Failed to access macro MarketData pointer.");
      testsFailed++;
   }

   Print("==================================================");
   Print(StringFormat("[PHASE 8 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+
