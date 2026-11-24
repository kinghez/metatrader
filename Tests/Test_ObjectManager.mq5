//+------------------------------------------------------------------+
//|                                           Test_ObjectManager.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 4 Automated Unit Test: ObjectManager Headless & Visual Tests"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/ObjectManager.mqh>

//+------------------------------------------------------------------+
//| Helper: Count chart objects with specific prefix                 |
//+------------------------------------------------------------------+
int CountObjectsWithPrefix(const long chartId, const string prefix)
{
   int count = 0;
   int total = ObjectsTotal(chartId, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(chartId, i, -1, -1);
      if(StringFind(name, prefix) == 0)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 4 ObjectManager Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   string testPrefix = "IMSF_TEST_";
   CObjectManager objManager(0, testPrefix, true, true, true, clrDodgerBlue, clrOrangeRed, 9);

   // Ensure clean starting slate
   objManager.DeleteAllObjects();

   CMarketData marketData;
   datetime now = TimeCurrent();

   CSwingPoint* h1 = new CSwingPoint(now - 7200, 1.10500, 5, SWING_HIGH, 0.0010);
   h1.SetConfirmed(true);
   h1.SetStructureType(STRUCTURE_HH);
   marketData.AddSwing(h1);

   CSwingPoint* l1 = new CSwingPoint(now - 3600, 1.09800, 2, SWING_LOW, 0.0010);
   l1.SetConfirmed(true);
   l1.SetStructureType(STRUCTURE_HL);
   marketData.AddSwing(l1);

   // Test 1: Rendering Swing Objects
   objManager.RenderAllSwings(marketData);
   objManager.DrawTrendBiasHUD(BIAS_BULLISH, "HL -> HH", 2);

   int objectsCreated = CountObjectsWithPrefix(0, testPrefix);
   Print(StringFormat("[INFO] Objects created on chart with prefix '%s': %d", testPrefix, objectsCreated));

   if(objectsCreated >= 3) // At least 2 swings (arrow/label) + 1 HUD label
   {
      Print("[PASS] Test 1: Visual objects successfully created on chart.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 1: Expected visual objects were not created.");
      testsFailed++;
   }

   // Test 2: Clean Object Deletion (Zero leftover artifacts)
   objManager.DeleteAllObjects();
   int remainingObjects = CountObjectsWithPrefix(0, testPrefix);

   if(remainingObjects == 0)
   {
      Print("[PASS] Test 2: DeleteAllObjects cleanly removed 100% of created objects (0 leaks).");
      testsPassed++;
   }
   else
   {
      Print(StringFormat("[FAIL] Test 2: %d leftover objects found after deletion.", remainingObjects));
      testsFailed++;
   }

   // Test 3: Headless Mode Verification (Zero GDI calls when disabled)
   objManager.SetEnabled(false);
   objManager.RenderAllSwings(marketData);
   objManager.DrawTrendBiasHUD(BIAS_BULLISH, "HL -> HH", 2);

   int headlessObjects = CountObjectsWithPrefix(0, testPrefix);
   if(headlessObjects == 0)
   {
      Print("[PASS] Test 3: Headless mode verified (0 chart objects created when disabled).");
      testsPassed++;
   }
   else
   {
      Print(StringFormat("[FAIL] Test 3: Headless mode violated. %d objects created while disabled.", headlessObjects));
      testsFailed++;
   }

   // Cleanup
   objManager.SetEnabled(true);
   objManager.DeleteAllObjects();
   marketData.ClearAll();

   Print("==================================================");
   Print(StringFormat("[PHASE 4 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

