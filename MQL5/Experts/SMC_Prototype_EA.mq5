//+------------------------------------------------------------------+
//|                                           SMC_Prototype_EA.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Institutional Market Structure Framework (IMSF) - 3-Tier MTF Confluence EA"
#property strict

//--- Include Standard Trade Library
#include <Trade\Trade.mqh>

//--- Include Framework Core
#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/TimeframeManager.mqh>
#include <SMC/ObjectManager.mqh>
#include <SMC/RiskManager.mqh>

//--- EA Specific Inputs
input group "=== 5. Expert Advisor Execution Parameters ==="
input ulong  InpMagicNumber            = 100101;     // Expert Advisor Magic Number
input string InpTradeComment           = "IMSF_MTF"; // Order Comment
input bool   InpEnableVisuals          = true;       // Enable Visual Objects (Set false for Strategy Tester)
input int    InpMaxOpenPositions       = 1;          // Maximum Concurrent Open Positions
input bool   InpRequireMTFConfluence   = true;       // Require 3-Tier MTF Alignment (Macro + Setup + Trigger)
input int    InpMinConfluenceScore     = 65;         // Minimum Confluence Score to Execute (0 - 100)

//--- Global Engine Instances
CTrade            g_trade;
CTimeframeManager g_mtfManager;
CObjectManager    g_objectManager;
CRiskManager      g_riskManager;

datetime          g_lastBarTime = 0;
datetime          g_lastTradedSwingTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF EA] Initializing 3-Tier MTF Confluence Expert Advisor (v0.9.0)...");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.SetEnabled(InpEnableVisuals);
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   if(!g_mtfManager.Init(_Symbol))
   {
      Print("[IMSF EA ERROR] Failed to initialize TimeframeManager.");
      return(INIT_FAILED);
   }

   // Initial MTF Synchronization
   g_mtfManager.SyncAllTiers(400);

   CMarketData* triggerData = g_mtfManager.GetTriggerData();

   if(InpEnableVisuals && triggerData != NULL)
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

   Print(StringFormat("[IMSF EA] Initialized. MTF Confluence: %s", g_mtfManager.GetConfluenceSummary()));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   Print("[IMSF EA] Deinitialized MTF EA. Reason: ", reason);
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

   // 2. Synchronize 3-Tier MTF Pipeline (Macro H4, Setup H1, Trigger Current)
   g_mtfManager.SyncAllTiers(400);

   CMarketData* triggerData = g_mtfManager.GetTriggerData();
   if(triggerData == NULL)
      return;

   // 3. Update Visuals if enabled
   if(InpEnableVisuals)
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

   // 4. Spread and Daily Drawdown Safeguards
   if(!g_riskManager.IsTradingPermitted(_Symbol, InpMaxSpreadPips, InpMaxDailyDrawdownPct))
      return;

   // 5. Position Limit Check
   if(CountOpenPositions() >= InpMaxOpenPositions)
      return;

   // 6. Multi-Timeframe Alignment Checks
   if(InpRequireMTFConfluence && g_mtfManager.GetConfluenceScore() < InpMinConfluenceScore)
      return;

   // 7. Micro Trigger Evaluation
   CSwingPoint* latestSwing = triggerData.GetLatestSwing();
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

   //--- Bullish 3-Tier Entry Trigger:
   // 1. Confluence Bias is Bullish (Macro + Setup Bullish)
   // 2. Trigger timeframe confirms Higher Low (HL)
   if(g_mtfManager.IsBullishConfluence() && latestSwing.StructureType() == STRUCTURE_HL)
   {
      double ask = currentTick.ask;
      double sl  = g_riskManager.CalculateStopLoss(_Symbol, true, latestSwing.Price(), atr, 0.5);
      double tp  = g_riskManager.CalculateTakeProfit(_Symbol, true, ask, sl, InpMinRiskRewardRatio);
      double lot = g_riskManager.CalculateLotSize(_Symbol, ask, sl, InpRiskPercent);

      if(lot > 0.0 && ask > sl)
      {
         if(g_trade.Buy(lot, _Symbol, ask, sl, tp, InpTradeComment))
         {
            Print(StringFormat("[IMSF MTF BUY] Executed Buy #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f | Score=%d/100",
                               g_trade.ResultOrder(), lot, ask, sl, tp, g_mtfManager.GetConfluenceScore()));
            g_lastTradedSwingTime = latestSwing.Time();
         }
      }
   }
   //--- Bearish 3-Tier Entry Trigger:
   // 1. Confluence Bias is Bearish (Macro + Setup Bearish)
   // 2. Trigger timeframe confirms Lower High (LH)
   else if(g_mtfManager.IsBearishConfluence() && latestSwing.StructureType() == STRUCTURE_LH)
   {
      double bid = currentTick.bid;
      double sl  = g_riskManager.CalculateStopLoss(_Symbol, false, latestSwing.Price(), atr, 0.5);
      double tp  = g_riskManager.CalculateTakeProfit(_Symbol, false, bid, sl, InpMinRiskRewardRatio);
      double lot = g_riskManager.CalculateLotSize(_Symbol, bid, sl, InpRiskPercent);

      if(lot > 0.0 && bid < sl)
      {
         if(g_trade.Sell(lot, _Symbol, bid, sl, tp, InpTradeComment))
         {
            Print(StringFormat("[IMSF MTF SELL] Executed Sell #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f | Score=%d/100",
                               g_trade.ResultOrder(), lot, bid, sl, tp, g_mtfManager.GetConfluenceScore()));
            g_lastTradedSwingTime = latestSwing.Time();
         }
      }
   }
}
//+------------------------------------------------------------------+
