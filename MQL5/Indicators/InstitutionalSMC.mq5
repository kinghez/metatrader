//+------------------------------------------------------------------+
//|                                             InstitutionalSMC.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "0.80"
#property description "Institutional Market Structure Framework (IMSF) - SMC Suite"
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
#include <SMC/FVGEngine.mqh>
#include <SMC/OrderBlockEngine.mqh>
#include <SMC/LiquidityEngine.mqh>
#include <SMC/ObjectManager.mqh>

//--- Global Engine Instances
CMarketData       g_marketData;
CSwingDetector    g_swingDetector;
CMarketStructure  g_marketStructure;
CZoneEngine       g_zoneEngine;
CFVGEngine        g_fvgEngine;
COrderBlockEngine g_obEngine;
CLiquidityEngine  g_liqEngine;
CObjectManager    g_objectManager;
datetime          g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF] Initializing Institutional Market Structure Framework (v0.8.0 - SMC Suite)...");
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

   // 3. Initial Scans: Swings, Structure, Zones, OBs, FVGs, Sweeps
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);
   g_fvgEngine.ScanFVGs(g_marketData, 300);
   g_obEngine.DetectOrderBlocks(g_marketData, 300);
   g_liqEngine.DetectSweeps(g_marketData, 10);

   // 4. Render All Visual Layers
   g_objectManager.RenderAllZones(g_marketData);
   g_objectManager.RenderAllOrderBlocks(g_marketData);
   g_objectManager.RenderAllFVGs(g_marketData);
   g_objectManager.RenderAllSwings(g_marketData);

   if(g_liqEngine.HasActiveSweep())
      g_objectManager.DrawSweep(g_liqEngine.GetLatestSweep());

   g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                   g_marketStructure.GetSequenceString(g_marketData, 5),
                                   g_marketData.TotalSwings(),
                                   g_marketData.TotalZones(),
                                   g_marketData.TotalOrderBlocks(),
                                   g_marketData.TotalFVGs());

   Print(StringFormat("[IMSF] Initialized. Swings: %d | Zones: %d | OB: %d | FVG: %d",
                      g_marketData.TotalSwings(),
                      g_marketData.TotalZones(),
                      g_marketData.TotalOrderBlocks(),
                      g_marketData.TotalFVGs()));

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
      // 1. Refresh Core Structural Calculations
      g_swingDetector.ScanHistory(g_marketData, 600);
      g_marketStructure.Analyze(g_marketData);
      g_zoneEngine.BuildZones(g_marketData, 400);
      g_fvgEngine.ScanFVGs(g_marketData, 300);
      g_obEngine.DetectOrderBlocks(g_marketData, 300);
      g_liqEngine.DetectSweeps(g_marketData, 10);

      // 2. Render Full SMC Chart Objects
      g_objectManager.RenderAllZones(g_marketData);
      g_objectManager.RenderAllOrderBlocks(g_marketData);
      g_objectManager.RenderAllFVGs(g_marketData);
      g_objectManager.RenderAllSwings(g_marketData);

      if(g_liqEngine.HasActiveSweep())
         g_objectManager.DrawSweep(g_liqEngine.GetLatestSweep());

      g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                      g_marketStructure.GetSequenceString(g_marketData, 5),
                                      g_marketData.TotalSwings(),
                                      g_marketData.TotalZones(),
                                      g_marketData.TotalOrderBlocks(),
                                      g_marketData.TotalFVGs());
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
