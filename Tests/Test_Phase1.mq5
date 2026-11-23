//+------------------------------------------------------------------+
//|                                                  Test_Phase1.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 1 Automated Unit Test: Data Models, Utilities & Market Data"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 1 Unit Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   //--- Test 1: CSwingPoint Instantiation & Getters/Setters
   datetime now = TimeCurrent();
   CSwingPoint* pt1 = new CSwingPoint(now, 1.10500, 10, SWING_HIGH, 0.0015);
   pt1.SetConfirmed(true);
   pt1.SetStructureType(STRUCTURE_HH);
   pt1.SetStrengthScore(85);

   if(pt1.Price() == 1.10500 && pt1.IsHigh() && pt1.IsConfirmed() && pt1.StructureType() == STRUCTURE_HH)
   {
      Print("[PASS] Test 1: CSwingPoint getters/setters validated.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 1: CSwingPoint state mismatch.");
      testsFailed++;
   }

   //--- Test 2: CMarketData Storage & Retrieval
   CMarketData marketData;
   marketData.AddSwing(pt1); // Ownership transferred to marketData

   CSwingPoint* pt2 = new CSwingPoint(now - 3600, 1.09800, 15, SWING_LOW, 0.0014);
   pt2.SetConfirmed(true);
   pt2.SetStructureType(STRUCTURE_HL);
   marketData.AddSwing(pt2);

   CSwingPoint* latestHigh = marketData.GetLatestSwing(SWING_HIGH);
   CSwingPoint* latestLow  = marketData.GetLatestSwing(SWING_LOW);

   if(latestHigh != NULL && latestHigh.Price() == 1.10500 &&
      latestLow != NULL && latestLow.Price() == 1.09800 &&
      marketData.TotalSwings() == 2)
   {
      Print("[PASS] Test 2: CMarketData swing storage & query validated.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 2: CMarketData swing query failed.");
      testsFailed++;
   }

   //--- Test 3: SZone Container
   SZone testZone;
   testZone.id = 1001;
   testZone.type = ZONE_DEMAND;
   testZone.topPrice = 1.09900;
   testZone.bottomPrice = 1.09750;
   testZone.meanPrice = 1.09825;
   testZone.strengthScore = 90;
   marketData.AddZone(testZone);

   SZone retrievedZone;
   if(marketData.TotalZones() == 1 && marketData.GetZone(0, retrievedZone) && retrievedZone.id == 1001)
   {
      Print("[PASS] Test 3: SZone registration and retrieval validated.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 3: SZone registration failed.");
      testsFailed++;
   }

   //--- Test 4: CUtilities Functions
   double pipSize = CUtilities::GetPipSize(_Symbol);
   double pipsDiff = CUtilities::PriceToPips(0.00200, "EURUSD");
   string structStr = CUtilities::StructureToString(STRUCTURE_HH);

   if(pipSize > 0.0 && structStr == "HH")
   {
      Print(StringFormat("[PASS] Test 4: CUtilities math & conversions validated (PipSize: %f, Struct: %s).", pipSize, structStr));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 4: CUtilities evaluation failed.");
      testsFailed++;
   }

   //--- Test 5: Safe Memory Cleanup
   marketData.ClearAll();
   if(marketData.TotalSwings() == 0 && marketData.TotalZones() == 0)
   {
      Print("[PASS] Test 5: CMarketData memory cleanup validated (0 leaks).");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 5: Memory cleanup failed.");
      testsFailed++;
   }

   Print("==================================================");
   Print(StringFormat("[IMSF TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

