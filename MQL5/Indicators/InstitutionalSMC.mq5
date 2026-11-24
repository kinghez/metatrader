//+------------------------------------------------------------------+
//|                                             InstitutionalSMC.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "0.70"
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
#include <SMC/ZoneEngine.mqh>
#include <SMC/ObjectManager.mqh>

//--- Global Engine Instances
CMarketData       g_marketData;
CSwingDetector    g_swingDetector;
CMarketStructure  g_marketStructure;
CZoneEngine       g_zoneEngine;
CObjectManager    g_objectManager;
datetime          g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF] Initializing Institutional Market Structure Framework (v0.7.0)...");
   g_marketData.ClearAll();
   g_lastBarTime = 0;

   // 1. Configure Presentation Engine
   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.DeleteAllObjects();

   // 2. Initialize Swing Detection Engine
   if(!g_swingDetector.Init(_Symbol, _Period))
   {
      Print("[IMSF ERROR] Failed to initialize SwingDetector.");
      return(INIT_FAILED);
   }

   // 3. Initial Scan, Structure Classification & Zone Generation
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);

   // 4. Render Visuals (Swings, Zones & HUD)
   g_objectManager.RenderAllZones(g_marketData);
   g_objectManager.RenderAllSwings(g_marketData);
   g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                   g_marketStructure.GetSequenceString(g_marketData, 5),
                                   g_marketData.TotalSwings(),
                                   g_marketData.TotalZones());

   Print(StringFormat("[IMSF] Initialized. Swings: %d | Zones: %d | Bias: %s",
                      g_marketData.TotalSwings(),
                      g_marketData.TotalZones(),
                      g_marketStructure.BiasToString()));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_objectManager.DeleteAllObjects();
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

   // Event-driven: Execute on closed candle
   if(CUtilities::IsNewBar(_Symbol, _Period, g_lastBarTime))
   {
      // 1. Refresh Swings
      g_swingDetector.ScanHistory(g_marketData, 600);

      // 2. Classify Structure & Bias
      g_marketStructure.Analyze(g_marketData);

      // 3. Rebuild & Score Dynamic Zones
      g_zoneEngine.BuildZones(g_marketData, 400);

      // 4. Render Chart Objects
      g_objectManager.RenderAllZones(g_marketData);
      g_objectManager.RenderAllSwings(g_marketData);
      g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                      g_marketStructure.GetSequenceString(g_marketData, 5),
                                      g_marketData.TotalSwings(),
                                      g_marketData.TotalZones());
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
