//+------------------------------------------------------------------+
//|                                             InstitutionalSMC.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "0.40"
#property description "Institutional Market Structure Framework (IMSF) - Indicator"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

//--- Include Framework Core
#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/SwingDetector.mqh>
#include <SMC/MarketStructure.mqh>

//--- Global Engine Instances
CMarketData       g_marketData;
CSwingDetector    g_swingDetector;
CMarketStructure  g_marketStructure;
datetime          g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF] Initializing Institutional Market Structure Framework (v0.4.0)...");
   g_marketData.ClearAll();
   g_lastBarTime = 0;

   // 1. Initialize Swing Detection Engine
   if(!g_swingDetector.Init(_Symbol, _Period))
   {
      Print("[IMSF ERROR] Failed to initialize SwingDetector.");
      return(INIT_FAILED);
   }

   // 2. Initial Scan and Market Structure Analysis
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);

   Print(StringFormat("[IMSF] Initialized. Swings: %d | Bias: %s | Structure: %s",
                      g_marketData.TotalSwings(),
                      g_marketStructure.BiasToString(),
                      g_marketStructure.GetSequenceString(g_marketData, 4)));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_swingDetector.Release();
   g_marketData.ClearAll();
   Print("[IMSF] Deinitialized Institutional Market Structure Framework. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < (InpSwingLeftBars + InpSwingRightBars + 20))
      return(0);

   // Event-driven: Execute full market structure analysis on candle close
   if(CUtilities::IsNewBar(_Symbol, _Period, g_lastBarTime))
   {
      // 1. Refresh Swing Points
      g_swingDetector.ScanHistory(g_marketData, 600);

      // 2. Classify Market Structure (HH, HL, LH, LL) and Systemic Bias
      g_marketStructure.Analyze(g_marketData);

      // Visualization will be hooked in Phase 4 (ObjectManager)
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
