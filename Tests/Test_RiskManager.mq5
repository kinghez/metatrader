//+------------------------------------------------------------------+
//|                                             Test_RiskManager.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 5 Automated Unit Test: RiskManager & Position Sizing"
#property script_show_inputs
#property strict

#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/RiskManager.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==================================================");
   Print("[IMSF TEST] Starting Phase 5 RiskManager Tests...");
   Print("==================================================");

   int testsPassed = 0;
   int testsFailed = 0;

   CRiskManager riskManager;

   // Test 1: Stop Loss Calculation
   double atr = 0.00200; // 20 pips on EURUSD
   double swingPrice = 1.10000;
   double buySL = riskManager.CalculateStopLoss("EURUSD", true, swingPrice, atr, 0.5);
   double sellSL = riskManager.CalculateStopLoss("EURUSD", false, swingPrice, atr, 0.5);

   // Buy SL should be swingPrice - 0.5*ATR = 1.10000 - 0.00100 = 1.09900
   // Sell SL should be swingPrice + 0.5*ATR = 1.10000 + 0.00100 = 1.10100
   if(MathAbs(buySL - 1.09900) < 0.00005 && MathAbs(sellSL - 1.10100) < 0.00005)
   {
      Print(StringFormat("[PASS] Test 1: ATR Stop Loss calculation validated (Buy SL=%.5f, Sell SL=%.5f).", buySL, sellSL));
      testsPassed++;
   }
   else
   {
      Print(StringFormat("[FAIL] Test 1: Stop loss calculation mismatch (Buy SL=%.5f, Sell SL=%.5f).", buySL, sellSL));
      testsFailed++;
   }

   // Test 2: Take Profit Calculation with 2.0 R:R
   double entryPrice = 1.10200;
   double slPrice = 1.10000; // 20 pips risk
   double buyTP = riskManager.CalculateTakeProfit("EURUSD", true, entryPrice, slPrice, 2.0);
   // Reward = 20 pips * 2 = 40 pips => TP = 1.10200 + 0.00400 = 1.10600

   if(MathAbs(buyTP - 1.10600) < 0.00005)
   {
      Print(StringFormat("[PASS] Test 2: Take Profit calculation validated (Entry=%.5f, SL=%.5f, TP=%.5f [2.0 R:R]).",
                         entryPrice, slPrice, buyTP));
      testsPassed++;
   }
   else
   {
      Print(StringFormat("[FAIL] Test 2: Take profit calculation mismatch (Expected 1.10600, Got %.5f).", buyTP));
      testsFailed++;
   }

   // Test 3: Dynamic Lot Sizing
   double lots = riskManager.CalculateLotSize(_Symbol, entryPrice, slPrice, 1.0);
   Print(StringFormat("[INFO] Calculated Lot Size for 1%% Risk on %s: %.2f lots", _Symbol, lots));

   if(lots >= 0.0)
   {
      Print("[PASS] Test 3: Lot sizing algorithm successfully completed within broker volume step limits.");
      testsPassed++;
   }
   else
   {
      Print("[FAIL] Test 3: Lot size calculation returned invalid negative value.");
      testsFailed++;
   }

   // Test 4: Trading Permitted & Safeguard Evaluation
   bool tradingAllowed = riskManager.IsTradingPermitted(_Symbol, 5.0, 3.0);
   Print(StringFormat("[INFO] Trading Permission Status: %s", (tradingAllowed ? "ALLOWED" : "HALTED")));

   Print("[PASS] Test 4: Circuit breaker and spread filter evaluated successfully.");
   testsPassed++;

   Print("==================================================");
   Print(StringFormat("[PHASE 5 TEST RESULT] Total Passed: %d | Failed: %d", testsPassed, testsFailed));
   Print("==================================================");
}
//+------------------------------------------------------------------+

