//+------------------------------------------------------------------+
//|                                           Test_SwingDetector.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 2 Automated Unit Test: Non-Repainting Swing Detection Engine"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/SwingDetector.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 2 Swing Detector Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   CMarketData marketData;
   CSwingDetector detector(_Symbol, _Period, 5, 5, 8, 14, 1.5, true);

   if(!detector.Init(_Symbol, _Period))
   {
      Print("[FAIL] Test 1: Detector initialization failed.");
      testsFailed++;
      return;
   }
   else
   {
      Print("[PASS] Test 1: CSwingDetector initialized successfully with ATR handle.");
      testsPassed++;
   }

   // Run swing detection scan over historical bars
   bool scanned = detector.ScanHistory(marketData, 500);

   int totalSwings = marketData.TotalSwings();
   Print(StringFormat("[INFO] Historical scan completed. Total confirmed swings found: %d", totalSwings));

   if(scanned && totalSwings >= 2)
   {
      Print("[PASS] Test 2: Historical swing scan successfully identified pivots.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 2: Insufficient swings detected. Check symbol data availability.");
      testsFailed++;
   }

   // Test 3: Validate Alternating Swings & Zero Repainting Invariant
   bool alternatingValid = true;
   bool confirmationValid = true;

   for(int i = 1; i < totalSwings; i++)
   {
      CSwingPoint* prev = marketData.GetSwing(i - 1);
      CSwingPoint* curr = marketData.GetSwing(i);

      if(prev == NULL || curr == NULL)
      {
         alternatingValid = false;
         break;
      }

      // Swings must alternate (HIGH -> LOW -> HIGH -> LOW)
      if(prev.SwingType() == curr.SwingType())
      {
         alternatingValid = false;
         Print(StringFormat("[WARN] Non-alternating swings at index %d and %d.", i - 1, i));
      }

      // All confirmed swings must have IsConfirmed() == true
      if(!curr.IsConfirmed())
      {
         confirmationValid = false;
      }
   }

   if(alternatingValid)
   {
      Print("[PASS] Test 3: Structural alternation invariant verified (High <-> Low).");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 3: Alternating swing invariant failed.");
      testsFailed++;
   }

   if(confirmationValid)
   {
      Print("[PASS] Test 4: Zero-repainting confirmation flag verified across all swings.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 4: Unconfirmed swing found in confirmed repository.");
      testsFailed++;
   }

   // Test 5: Print latest swings for visual verification
   CSwingPoint* latestHigh = marketData.GetLatestSwing(SWING_HIGH);
   CSwingPoint* latestLow  = marketData.GetLatestSwing(SWING_LOW);

   if(latestHigh != NULL && latestLow != NULL)
   {
      Print(StringFormat("[INFO] Latest Confirmed High: Price=%.5f | Bar=%d | Score=%d", 
                         latestHigh.Price(), latestHigh.BarIndex(), latestHigh.StrengthScore()));
      Print(StringFormat("[INFO] Latest Confirmed Low:  Price=%.5f | Bar=%d | Score=%d", 
                         latestLow.Price(), latestLow.BarIndex(), latestLow.StrengthScore()));
      Print("[PASS] Test 5: Latest High and Low queries returned valid points.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 5: Failed to retrieve latest high or low.");
      testsFailed++;
   }

   // Cleanup
   marketData.ClearAll();
   detector.Release();

   Print("==================================================");
   Print(StringFormat("[PHASE 2 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

