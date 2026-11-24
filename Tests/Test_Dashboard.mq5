//+------------------------------------------------------------------+
//|                                               Test_Dashboard.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Phase 10 Unit Tests: Institutional On-Chart Dashboard & GUI"
#property script_show_inputs
#property strict

//--- Include Framework Headers
#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/Dashboard.mqh>

#define ASSERT_TRUE(condition, msg) \
   if(!(condition)) { \
      Print(StringFormat("[ASSERTION FAILED] %s (Line: %d)", msg, __LINE__)); \
      return INIT_FAILED; \
   }

#define ASSERT_EQUAL(val1, val2, msg) \
   if((val1) != (val2)) { \
      Print(StringFormat("[ASSERTION FAILED] %s: Expected %s, Got %s (Line: %d)", msg, (string)(val1), (string)(val2), __LINE__)); \
      return INIT_FAILED; \
   }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
int OnStart()
{
   Print("=== [START] Phase 10: Institutional On-Chart Dashboard & GUI Unit Tests ===");

   CDashboard dashboard;
   string prefix = "TEST_DASH_";

   // -------------------------------------------------------------
   // Test 1: Configuration & DPI Detection
   // -------------------------------------------------------------
   Print("[TEST 1] Testing Configuration & High-DPI Scaling...");
   dashboard.Init(0, prefix, CORNER_LEFT_UPPER, 20, 30, false);
   ASSERT_EQUAL(dashboard.GetPrefix(), prefix, "Dashboard prefix mismatch");
   ASSERT_TRUE(dashboard.GetDpiScale() >= 1.0, "DPI Scale should be at least 1.0");
   ASSERT_TRUE(!dashboard.IsCollapsed(), "Dashboard should start in expanded mode");
   Print(StringFormat(" -> DPI Scale: %.2f (DPI: %d)", dashboard.GetDpiScale(), (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI)));
   Print("[TEST 1] PASSED.");

   // -------------------------------------------------------------
   // Test 2: Populate Data & Render Expanded State
   // -------------------------------------------------------------
   Print("[TEST 2] Testing Dashboard Render in Expanded State...");
   SDashboardData data;
   data.symbol = _Symbol;
   data.period = _Period;
   data.bid = 1.08500;
   data.ask = 1.08510;
   data.spreadPips = 1.0;
   data.sessionName = "London / NY Overlap";
   data.isRollover = false;
   data.macroBias = BIAS_BULLISH;
   data.setupBias = BIAS_BULLISH;
   data.triggerBias = BIAS_BULLISH;
   data.confluenceScore = 85;
   data.confluenceBias = BIAS_BULLISH;
   data.bullishOBCount = 2;
   data.bearishOBCount = 1;
   data.nearestBullishOBDistPips = 8.5;
   data.nearestBearishOBDistPips = 14.0;
   data.bullishFVGCount = 1;
   data.bearishFVGCount = 2;
   data.nearestBullishFVGDistPips = 5.2;
   data.nearestBearishFVGDistPips = 10.5;
   data.balance = 10000.0;
   data.equity = 10150.0;
   data.floatingPnL = 150.0;
   data.todayClosedPnL = 210.0;
   data.dailyDrawdownPct = 0.4;
   data.maxDailyDrawdownPct = 3.0;
   data.openPositionsCount = 1;
   data.isSpreadOk = true;
   data.isNewsClear = true;
   data.newsStatusText = "CLEAR";

   dashboard.Update(data);

   // Verify On-Chart Graphical Objects Exist
   ASSERT_TRUE(ObjectFind(0, prefix + "BG_PANEL") >= 0, "Panel background must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "BG_HEADER") >= 0, "Header background must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "BTN_TOGGLE") >= 0, "Toggle button must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_TITLE") >= 0, "Title label must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_SUBTITLE") >= 0, "Subtitle label must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "SEC_MKT") >= 0, "Market section must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_SPREAD_V") >= 0, "Spread value must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_MACRO_V") >= 0, "Macro value must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_CONF_V") >= 0, "Confluence value must exist");
   ASSERT_TRUE(ObjectFind(0, prefix + "LBL_PNL_V") >= 0, "PnL value must exist");

   // Verify Button Text in Expanded State
   string btnText = ObjectGetString(0, prefix + "BTN_TOGGLE", OBJPROP_TEXT);
   ASSERT_EQUAL(btnText, "[-]", "Expanded toggle button must display '[-]'");

   // Verify Detail Visibility
   long mktTf = ObjectGetInteger(0, prefix + "SEC_MKT", OBJPROP_TIMEFRAMES);
   ASSERT_EQUAL((int)mktTf, (int)OBJ_ALL_PERIODS, "Detail rows must be visible when expanded");
   Print("[TEST 2] PASSED.");

   // -------------------------------------------------------------
   // Test 3: Collapse Mode (Single-Click Minimization)
   // -------------------------------------------------------------
   Print("[TEST 3] Testing Dashboard Collapse Mode...");
   dashboard.ToggleCollapse();
   ASSERT_TRUE(dashboard.IsCollapsed(), "Dashboard should now be collapsed");

   btnText = ObjectGetString(0, prefix + "BTN_TOGGLE", OBJPROP_TEXT);
   ASSERT_EQUAL(btnText, "[+]", "Collapsed toggle button must display '[+]'");

   // Detail objects should be hidden (OBJ_NO_PERIODS)
   mktTf = ObjectGetInteger(0, prefix + "SEC_MKT", OBJPROP_TIMEFRAMES);
   ASSERT_EQUAL((int)mktTf, (int)OBJ_NO_PERIODS, "Detail rows must be hidden when collapsed");

   // Mini label must be visible
   long miniTf = ObjectGetInteger(0, prefix + "LBL_MINI", OBJPROP_TIMEFRAMES);
   ASSERT_EQUAL((int)miniTf, (int)OBJ_ALL_PERIODS, "Mini label must be visible when collapsed");
   Print("[TEST 3] PASSED.");

   // -------------------------------------------------------------
   // Test 4: Interactive OnChartEvent Toggle Simulation
   // -------------------------------------------------------------
   Print("[TEST 4] Simulating Single-Click Chart Event on Toggle Button...");
   long lparam = 0;
   double dparam = 0.0;
   string sparam = prefix + "BTN_TOGGLE";
   dashboard.OnChartEvent(CHARTEVENT_OBJECT_CLICK, lparam, dparam, sparam);
   ASSERT_TRUE(!dashboard.IsCollapsed(), "Dashboard should be expanded after click event");

   btnText = ObjectGetString(0, prefix + "BTN_TOGGLE", OBJPROP_TEXT);
   ASSERT_EQUAL(btnText, "[-]", "Expanded toggle button must display '[-]' after toggle");

   mktTf = ObjectGetInteger(0, prefix + "SEC_MKT", OBJPROP_TIMEFRAMES);
   ASSERT_EQUAL((int)mktTf, (int)OBJ_ALL_PERIODS, "Detail rows must be restored when expanded");
   Print("[TEST 4] PASSED.");

   // -------------------------------------------------------------
   // Test 5: Headless Execution Bypass
   // -------------------------------------------------------------
   Print("[TEST 5] Testing 100% Headless Mode Bypass...");
   dashboard.SetEnabled(false);
   ASSERT_TRUE(!dashboard.IsEnabled(), "Dashboard should be disabled");

   // Calling Update in disabled mode should execute instantly without graphical mutation
   dashboard.Update(data);
   dashboard.SetEnabled(true);
   ASSERT_TRUE(dashboard.IsEnabled(), "Dashboard should be re-enabled");
   Print("[TEST 5] PASSED.");

   // -------------------------------------------------------------
   // Test 6: Clean Deletion & Teardown
   // -------------------------------------------------------------
   Print("[TEST 6] Testing Clean Object Teardown...");
   dashboard.DeleteAllObjects();

   ASSERT_TRUE(ObjectFind(0, prefix + "BG_PANEL") < 0, "Panel background must be deleted");
   ASSERT_TRUE(ObjectFind(0, prefix + "BTN_TOGGLE") < 0, "Toggle button must be deleted");
   ASSERT_TRUE(ObjectFind(0, prefix + "SEC_MKT") < 0, "Detail rows must be deleted");
   Print("[TEST 6] PASSED.");

   Print("=== [ALL TESTS PASSED] Phase 10: Institutional On-Chart Dashboard & GUI Verified Successfully. ===");
   return INIT_SUCCEEDED;
}
