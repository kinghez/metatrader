//+------------------------------------------------------------------+
//|                                             Test_ZoneEngine.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 6 Automated Unit Test: ZoneEngine Clustering, Mitigation & Scoring"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/ZoneEngine.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 6 ZoneEngine Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   CMarketData marketData;
   CZoneEngine zoneEngine(_Symbol, _Period, 1.0, 0.5, 20);

   datetime now = TimeCurrent();

   // Seed Swings into MarketData:
   // High 1 (1.1050), Low 1 (1.0950), High 2 (1.1055 - close to High 1, should cluster!), Low 2 (1.0960)
   CSwingPoint* h1 = new CSwingPoint(now - 3600*10, 1.10500, 10, SWING_HIGH, 0.0015); h1.SetConfirmed(true); marketData.AddSwing(h1);
   CSwingPoint* l1 = new CSwingPoint(now - 3600*8,  1.09500, 8,  SWING_LOW,  0.0015); l1.SetConfirmed(true); marketData.AddSwing(l1);
   CSwingPoint* h2 = new CSwingPoint(now - 3600*6,  1.10550, 6,  SWING_HIGH, 0.0015); h2.SetConfirmed(true); marketData.AddSwing(h2);
   CSwingPoint* l2 = new CSwingPoint(now - 3600*4,  1.09600, 4,  SWING_LOW,  0.0015); l2.SetConfirmed(true); marketData.AddSwing(l2);

   // Test 1: Zone Building
   bool built = zoneEngine.BuildZones(marketData, 200);
   int totalZones = marketData.TotalZones();
   Print(StringFormat("[INFO] Zone building complete. Total zones registered: %d", totalZones));

   if(built && totalZones > 0)
   {
      Print("[PASS] Test 1: Zone building executed successfully.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 1: Zone building failed or zero zones generated.");
      testsFailed++;
   }

   // Test 2: Clustering Verification
   // High 1 (1.1050) and High 2 (1.1055) are only 5 pips apart (less than 1.0*ATR), so they should merge!
   int supplyZonesCount = 0;
   for(int i = 0; i < totalZones; i++)
   {
      SZone z;
      if(marketData.GetZone(i, z) && z.type == ZONE_SUPPLY)
         supplyZonesCount++;
   }

   if(supplyZonesCount == 1)
   {
      Print("[PASS] Test 2: Adjacent supply swings successfully clustered into 1 consolidated zone.");
      testsPassed++;
   }
   else
   {
      Print(StringFormat("[FAIL] Test 2: Clustering failed. Expected 1 consolidated supply zone, got %d.", supplyZonesCount));
      testsFailed++;
   }

   // Test 3: Nearest Zone Query
   SZone nearestDemand;
   bool foundDemand = zoneEngine.GetNearestZone(marketData, 1.09800, ZONE_DEMAND, nearestDemand);

   if(foundDemand && nearestDemand.type == ZONE_DEMAND && nearestDemand.strengthScore >= 20)
   {
      Print(StringFormat("[PASS] Test 3: Nearest demand zone located: Top=%.5f, Bottom=%.5f, Score=%d/100.",
                         nearestDemand.topPrice, nearestDemand.bottomPrice, nearestDemand.strengthScore));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 3: Failed to query nearest demand zone.");
      testsFailed++;
   }

   // Cleanup
   marketData.ClearAll();

   Print("==================================================");
   Print(StringFormat("[PHASE 6 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

