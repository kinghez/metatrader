//+------------------------------------------------------------------+
//|                                         Test_MarketStructure.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 3 Automated Unit Test: Market Structure Classification (HH/HL/LH/LL)"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/MarketStructure.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 3 Market Structure Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   CMarketData marketData;
   CMarketStructure structureAnalyzer("EURUSD", PERIOD_H1);

   datetime baseTime = TimeCurrent() - (86400 * 5);

   // Construct simulated Bullish Structure:
   // L1(1.0800) -> H1(1.0900) -> L2(1.0850, HL) -> H2(1.1000, HH) -> L3(1.0920, HL) -> H3(1.1080, HH)
   CSwingPoint* l1 = new CSwingPoint(baseTime + 3600*1, 1.08000, 20, SWING_LOW, 0.0010);  l1.SetConfirmed(true); marketData.AddSwing(l1);
   CSwingPoint* h1 = new CSwingPoint(baseTime + 3600*2, 1.09000, 16, SWING_HIGH, 0.0010); h1.SetConfirmed(true); marketData.AddSwing(h1);
   CSwingPoint* l2 = new CSwingPoint(baseTime + 3600*3, 1.08500, 12, SWING_LOW, 0.0010);  l2.SetConfirmed(true); marketData.AddSwing(l2);
   CSwingPoint* h2 = new CSwingPoint(baseTime + 3600*4, 1.10000, 8,  SWING_HIGH, 0.0010); h2.SetConfirmed(true); marketData.AddSwing(h2);
   CSwingPoint* l3 = new CSwingPoint(baseTime + 3600*5, 1.09200, 4,  SWING_LOW, 0.0010);  l3.SetConfirmed(true); marketData.AddSwing(l3);
   CSwingPoint* h3 = new CSwingPoint(baseTime + 3600*6, 1.10800, 1,  SWING_HIGH, 0.0010); h3.SetConfirmed(true); marketData.AddSwing(h3);

   bool analyzed = structureAnalyzer.Analyze(marketData);

   // Test 1: Analysis Execution
   if(analyzed && marketData.TotalSwings() == 6)
   {
      Print("[PASS] Test 1: Market structure analysis executed successfully.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 1: Analysis failed.");
      testsFailed++;
   }

   // Test 2: Verify HH and HL Classifications
   if(h2.StructureType() == STRUCTURE_HH && 
      l2.StructureType() == STRUCTURE_HL && 
      h3.StructureType() == STRUCTURE_HH && 
      l3.StructureType() == STRUCTURE_HL)
   {
      Print(StringFormat("[PASS] Test 2: Bullish classifications verified (H2=%s, L2=%s, H3=%s, L3=%s).",
                         CUtilities::StructureToString(h2.StructureType()),
                         CUtilities::StructureToString(l2.StructureType()),
                         CUtilities::StructureToString(h3.StructureType()),
                         CUtilities::StructureToString(l3.StructureType())));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 2: Incorrect structure classification in uptrend.");
      testsFailed++;
   }

   // Test 3: Systemic Bullish Bias
   if(structureAnalyzer.IsBullish() && structureAnalyzer.CurrentBias() == BIAS_BULLISH)
   {
      Print(StringFormat("[PASS] Test 3: Systemic Bias correctly identified as %s.", structureAnalyzer.BiasToString()));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 3: Systemic bias detection failed.");
      testsFailed++;
   }

   // Test 4: Bearish Structural Shift & Reversal Detection
   // Append: L4(1.0750, LL) -> H4(1.0880, LH)
   CSwingPoint* l4 = new CSwingPoint(baseTime + 3600*7, 1.07500, 0, SWING_LOW, 0.0010);  l4.SetConfirmed(true); marketData.AddSwing(l4);
   CSwingPoint* h4 = new CSwingPoint(baseTime + 3600*8, 1.08800, 0, SWING_HIGH, 0.0010); h4.SetConfirmed(true); marketData.AddSwing(h4);

   structureAnalyzer.Analyze(marketData);

   if(l4.StructureType() == STRUCTURE_LL && 
      h4.StructureType() == STRUCTURE_LH && 
      structureAnalyzer.IsBearish() && 
      structureAnalyzer.HasBearishReversal())
   {
      Print(StringFormat("[PASS] Test 4: Bearish Reversal successfully triggered (L4=%s, H4=%s, New Bias=%s).",
                         CUtilities::StructureToString(l4.StructureType()),
                         CUtilities::StructureToString(h4.StructureType()),
                         structureAnalyzer.BiasToString()));
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 4: Bearish reversal detection failed.");
      testsFailed++;
   }

   // Test 5: Structural Sequence String
   string sequence = structureAnalyzer.GetSequenceString(marketData, 6);
   Print(StringFormat("[INFO] Structural Sequence: %s", sequence));
   if(StringLen(sequence) > 10)
   {
      Print("[PASS] Test 5: Structure sequence string representation validated.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 5: Structure sequence string invalid.");
      testsFailed++;
   }

   // Cleanup
   marketData.ClearAll();

   Print("==================================================");
   Print(StringFormat("[PHASE 3 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

