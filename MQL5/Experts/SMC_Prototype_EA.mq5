//+------------------------------------------------------------------+
//|                                           SMC_Prototype_EA.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "0.80"
#property description "Institutional Market Structure Framework (IMSF) - SMC Confluence EA"
#property strict

//--- Include Standard Trade Library
#include <Trade\Trade.mqh>

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
#include <SMC/RiskManager.mqh>

//--- EA Specific Inputs
input group "=== 5. Expert Advisor Execution Parameters ==="
input ulong  InpMagicNumber            = 100101;     // Expert Advisor Magic Number
input string InpTradeComment           = "IMSF_SMC"; // Order Comment
input bool   InpEnableVisuals          = true;       // Enable Visual Objects (Set false for Strategy Tester)
input int    InpMaxOpenPositions       = 1;          // Maximum Concurrent Open Positions
input bool   InpRequireSMCConfluence   = true;       // Require OB, FVG, or Sweep Confluence

//--- Global Engine Instances
CTrade            g_trade;
CMarketData       g_marketData;
CSwingDetector    g_swingDetector;
CMarketStructure  g_marketStructure;
CZoneEngine       g_zoneEngine;
CFVGEngine        g_fvgEngine;
COrderBlockEngine g_obEngine;
CLiquidityEngine  g_liqEngine;
CObjectManager    g_objectManager;
CRiskManager      g_riskManager;

datetime          g_lastBarTime = 0;
datetime          g_lastTradedSwingTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF EA] Initializing SMC Confluence Expert Advisor (v0.8.0)...");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.SetEnabled(InpEnableVisuals);
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   if(!g_swingDetector.Init(_Symbol, _Period))
   {
      Print("[IMSF EA ERROR] Failed to initialize SwingDetector.");
      return(INIT_FAILED);
   }

   // Initial Scans
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);
   g_fvgEngine.ScanFVGs(g_marketData, 300);
   g_obEngine.DetectOrderBlocks(g_marketData, 300);
   g_liqEngine.DetectSweeps(g_marketData, 10);

   if(InpEnableVisuals)
   {
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

   Print(StringFormat("[IMSF EA] Initialized. Bias: %s | OBs: %d | FVGs: %d | Magic: %I64u",
                      g_marketStructure.BiasToString(),
                      g_marketData.TotalOrderBlocks(),
                      g_marketData.TotalFVGs(),
                      InpMagicNumber));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   g_swingDetector.Release();
   g_marketData.ClearAll();
   Print("[IMSF EA] Deinitialized SMC EA. Reason: ", reason);
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Event-Driven: Run calculations only on bar close
   if(!CUtilities::IsNewBar(_Symbol, _Period, g_lastBarTime))
      return;

   // 2. Refresh Full SMC Structure
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);
   g_fvgEngine.ScanFVGs(g_marketData, 300);
   g_obEngine.DetectOrderBlocks(g_marketData, 300);
   g_liqEngine.DetectSweeps(g_marketData, 10);

   // 3. Visuals update
   if(InpEnableVisuals)
   {
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

   // 4. Spread and Daily Drawdown Safeguards
   if(!g_riskManager.IsTradingPermitted(_Symbol, InpMaxSpreadPips, InpMaxDailyDrawdownPct))
      return;

   // 5. Position Limit Check
   if(CountOpenPositions() >= InpMaxOpenPositions)
      return;

   // 6. Strategy Evaluation
   CSwingPoint* latestSwing = g_marketData.GetLatestSwing();
   if(latestSwing == NULL || !latestSwing.IsConfirmed())
      return;

   if(latestSwing.Time() == g_lastTradedSwingTime)
      return;

   double atr = CUtilities::CalculateATR(_Symbol, _Period, InpATRPeriod, 1);
   if(atr <= 0.0)
      return;

   MqlTick currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   //--- Bullish SMC Entry Trigger:
   // 1. Trend Bias is Bullish AND latest swing is Higher Low (HL)
   // 2. High-confluence: Liquidity Sweep of sell-side liquidity OR proximity to Bullish OB / FVG
   if(g_marketStructure.IsBullish() && latestSwing.StructureType() == STRUCTURE_HL)
   {
      bool smcConfluenceMet = true;
      if(InpRequireSMCConfluence)
      {
         SOrderBlock nearestOB;
         SFairValueGap nearestFVG;
         bool hasOB  = g_obEngine.GetNearestOrderBlock(g_marketData, currentTick.ask, true, nearestOB);
         bool hasFVG = g_fvgEngine.GetNearestFVG(g_marketData, currentTick.ask, true, nearestFVG);
         bool hasSweep = (g_liqEngine.HasActiveSweep() && g_liqEngine.GetLatestSweep().isBullishSweep);

         smcConfluenceMet = (hasOB || hasFVG || hasSweep);
      }

      if(smcConfluenceMet)
      {
         double ask = currentTick.ask;
         double sl  = g_riskManager.CalculateStopLoss(_Symbol, true, latestSwing.Price(), atr, 0.5);
         double tp  = g_riskManager.CalculateTakeProfit(_Symbol, true, ask, sl, InpMinRiskRewardRatio);
         double lot = g_riskManager.CalculateLotSize(_Symbol, ask, sl, InpRiskPercent);

         if(lot > 0.0 && ask > sl)
         {
            if(g_trade.Buy(lot, _Symbol, ask, sl, tp, InpTradeComment))
            {
               Print(StringFormat("[IMSF SMC EA BUY] Executed Buy #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f",
                                  g_trade.ResultOrder(), lot, ask, sl, tp));
               g_lastTradedSwingTime = latestSwing.Time();
            }
         }
      }
   }
   //--- Bearish SMC Entry Trigger:
   // 1. Trend Bias is Bearish AND latest swing is Lower High (LH)
   // 2. High-confluence: Liquidity Sweep of buy-side liquidity OR proximity to Bearish OB / FVG
   else if(g_marketStructure.IsBearish() && latestSwing.StructureType() == STRUCTURE_LH)
   {
      bool smcConfluenceMet = true;
      if(InpRequireSMCConfluence)
      {
         SOrderBlock nearestOB;
         SFairValueGap nearestFVG;
         bool hasOB  = g_obEngine.GetNearestOrderBlock(g_marketData, currentTick.bid, false, nearestOB);
         bool hasFVG = g_fvgEngine.GetNearestFVG(g_marketData, currentTick.bid, false, nearestFVG);
         bool hasSweep = (g_liqEngine.HasActiveSweep() && !g_liqEngine.GetLatestSweep().isBullishSweep);

         smcConfluenceMet = (hasOB || hasFVG || hasSweep);
      }

      if(smcConfluenceMet)
      {
         double bid = currentTick.bid;
         double sl  = g_riskManager.CalculateStopLoss(_Symbol, false, latestSwing.Price(), atr, 0.5);
         double tp  = g_riskManager.CalculateTakeProfit(_Symbol, false, bid, sl, InpMinRiskRewardRatio);
         double lot = g_riskManager.CalculateLotSize(_Symbol, bid, sl, InpRiskPercent);

         if(lot > 0.0 && bid < sl)
         {
            if(g_trade.Sell(lot, _Symbol, bid, sl, tp, InpTradeComment))
            {
               Print(StringFormat("[IMSF SMC EA SELL] Executed Sell #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f",
                                  g_trade.ResultOrder(), lot, bid, sl, tp));
               g_lastTradedSwingTime = latestSwing.Time();
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
