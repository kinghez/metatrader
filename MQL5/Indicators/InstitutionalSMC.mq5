//+------------------------------------------------------------------+
//|                                             InstitutionalSMC.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Institutional Market Structure Framework (IMSF) - MTF Suite"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

//--- Include Framework Core
#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/TimeframeManager.mqh>
#include <SMC/ObjectManager.mqh>

//--- Global Engine Instances
CTimeframeManager g_mtfManager;
CObjectManager    g_objectManager;
datetime          g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF] Initializing Institutional Market Structure Framework (v0.9.0 - MTF Suite)...");
   g_lastBarTime = 0;

   // 1. Configure Presentation Engine
   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.DeleteAllObjects();

   // 2. Initialize 3-Tier Multi-Timeframe Synchronization Engine (H4, H1, Current)
   if(!g_mtfManager.Init(_Symbol))
   {
      Print("[IMSF ERROR] Failed to initialize TimeframeManager ATR handles.");
      return(INIT_FAILED);
   }

   // 3. Initial Synchronization Across All Tiers
   g_mtfManager.SyncAllTiers(400);

   CMarketData* triggerData = g_mtfManager.GetTriggerData();

   // 4. Render Visuals from Active Trigger Chart & HUD
   if(triggerData != NULL)
   {
      g_objectManager.RenderAllZones(*triggerData);
      g_objectManager.RenderAllOrderBlocks(*triggerData);
      g_objectManager.RenderAllFVGs(*triggerData);
      g_objectManager.RenderAllSwings(*triggerData);

      g_objectManager.DrawTrendBiasHUD(g_mtfManager.GetConfluenceBias(),
                                      g_mtfManager.GetConfluenceSummary(),
                                      triggerData.TotalSwings(),
                                      triggerData.TotalZones(),
                                      triggerData.TotalOrderBlocks(),
                                      triggerData.TotalFVGs());
   }

   Print(StringFormat("[IMSF] MTF Suite Initialized. Confluence: %s", g_mtfManager.GetConfluenceSummary()));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_objectManager.DeleteAllObjects();
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
      // 1. Refresh 3-Tier MTF Synchronization Pipeline
      g_mtfManager.SyncAllTiers(400);

      CMarketData* triggerData = g_mtfManager.GetTriggerData();

      // 2. Render Chart Objects & Confluence HUD
      if(triggerData != NULL)
      {
         g_objectManager.RenderAllZones(*triggerData);
         g_objectManager.RenderAllOrderBlocks(*triggerData);
         g_objectManager.RenderAllFVGs(*triggerData);
         g_objectManager.RenderAllSwings(*triggerData);

         g_objectManager.DrawTrendBiasHUD(g_mtfManager.GetConfluenceBias(),
                                         g_mtfManager.GetConfluenceSummary(),
                                         triggerData.TotalSwings(),
                                         triggerData.TotalZones(),
                                         triggerData.TotalOrderBlocks(),
                                         triggerData.TotalFVGs());
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
