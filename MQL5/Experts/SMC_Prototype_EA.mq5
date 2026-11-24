//+------------------------------------------------------------------+
//|                                           SMC_Prototype_EA.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "1.00"
#property description "Institutional Market Structure Framework (IMSF) - Production Hardened EA"
#property strict

//--- Include Standard Trade Library
#include <Trade\Trade.mqh>

//--- Include Framework Core & Production Safeguards
#include <SMC/Types.mqh>
#include <SMC/Settings.mqh>
#include <SMC/Utilities.mqh>
#include <SMC/MarketData.mqh>
#include <SMC/TimeframeManager.mqh>
#include <SMC/ObjectManager.mqh>
#include <SMC/RiskManager.mqh>
#include <SMC/SpreadFilter.mqh>
#include <SMC/NewsFilter.mqh>

//--- EA Specific Inputs
input group "=== 5. Expert Advisor Execution Parameters ==="
input ulong  InpMagicNumber            = 100101;     // Expert Advisor Magic Number
input string InpTradeComment           = "IMSF_PROD";// Order Comment
input bool   InpEnableVisuals          = true;       // Enable Visual Objects (Set false for Strategy Tester)
input int    InpMaxOpenPositions       = 1;          // Maximum Concurrent Open Positions
input bool   InpRequireMTFConfluence   = true;       // Require 3-Tier MTF Alignment (Macro + Setup + Trigger)
input int    InpMinConfluenceScore     = 65;         // Minimum Confluence Score to Execute (0 - 100)

input group "=== 6. Production Hardening & Overnight Guards ==="
input bool   InpUseNewsFilter          = true;       // Pause Trading During High-Impact News
input int    InpNewsPauseMinutes       = 30;         // News Blackout Buffer (Minutes Before/After)
input bool   InpEnableBreakEven        = true;       // Automatically Move Stop Loss to Break-Even
input double InpBreakEvenAtrMult       = 1.0;        // Break-Even Trigger Distance (ATR Multiple)
input bool   InpEnableTrailingStop     = true;       // Trailing Stop Loss
input double InpTrailingStopAtrMult    = 1.5;        // Trailing Stop Buffer (ATR Multiple)

//--- Global Engine Instances
CTrade            g_trade;
CTimeframeManager g_mtfManager;
CObjectManager    g_objectManager;
CRiskManager      g_riskManager;
CSpreadFilter     g_spreadFilter;
CNewsFilter       g_newsFilter;

datetime          g_lastBarTime = 0;
datetime          g_lastTradedSwingTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF EA] Initializing Production Hardened Expert Advisor (v1.0.0)...");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.SetEnabled(InpEnableVisuals);
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   // Configure Production Safeguards
   g_spreadFilter.SetMaxSpreadPips(InpMaxSpreadPips);
   g_spreadFilter.SetRolloverFilter(InpRolloverFilter);
   g_newsFilter.SetEnabled(InpUseNewsFilter);
   g_newsFilter.SetPauseWindow(InpNewsPauseMinutes, InpNewsPauseMinutes);

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

   Print(StringFormat("[IMSF EA] Production Hardened EA Ready. Confluence: %s", g_mtfManager.GetConfluenceSummary()));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   Print("[IMSF EA] Deinitialized. Reason: ", reason);
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
   double atr = CUtilities::CalculateATR(_Symbol, _Period, InpATRPeriod, 1);

   // 1. Continuous Position Management on every tick: Break-Even and Trailing Stop
   if(CountOpenPositions() > 0 && atr > 0.0)
   {
      if(InpEnableBreakEven || InpEnableTrailingStop)
      {
         g_riskManager.ManageOpenPositions(_Symbol, InpMagicNumber, g_trade, atr,
                                          InpBreakEvenAtrMult, InpTrailingStopAtrMult);
      }
   }

   // 2. Event-Driven: Run new trade evaluations only on candle close
   if(!CUtilities::IsNewBar(_Symbol, _Period, g_lastBarTime))
      return;

   // 3. Synchronize 3-Tier MTF Pipeline (Macro H4, Setup H1, Trigger Current)
   g_mtfManager.SyncAllTiers(400);

   CMarketData* triggerData = g_mtfManager.GetTriggerData();
   if(triggerData == NULL)
      return;

   // 4. Update Visuals if enabled
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

   // 5. Production Hardening Safeguards:
   // Daily Drawdown Circuit Breaker
   if(!g_riskManager.IsTradingPermitted(_Symbol, InpMaxSpreadPips, InpMaxDailyDrawdownPct))
   {
      // If daily loss limit is breached, liquidate positions immediately
      g_riskManager.CloseAllPositions(_Symbol, InpMagicNumber, g_trade);
      return;
   }

   // Spread & Bank Rollover Window Safeguard
   if(!g_spreadFilter.IsExecutionSafe(_Symbol))
   {
      return;
   }

   // High-Impact Economic News Blackout Safeguard
   if(g_newsFilter.IsNewsBlackoutActive(_Symbol))
   {
      Print("[NEWS GUARD] Trading paused due to active high-impact economic news blackout.");
      return;
   }

   // 6. Max Positions Check
   if(CountOpenPositions() >= InpMaxOpenPositions)
      return;

   // 7. Multi-Timeframe Confluence Requirement
   if(InpRequireMTFConfluence && g_mtfManager.GetConfluenceScore() < InpMinConfluenceScore)
      return;

   // 8. Micro Trigger Evaluation
   CSwingPoint* latestSwing = triggerData.GetLatestSwing();
   if(latestSwing == NULL || !latestSwing.IsConfirmed())
      return;

   if(latestSwing.Time() == g_lastTradedSwingTime)
      return;

   MqlTick currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   //--- Bullish Entry Trigger:
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
            Print(StringFormat("[IMSF PROD BUY] Executed Buy #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f | Score=%d/100",
                               g_trade.ResultOrder(), lot, ask, sl, tp, g_mtfManager.GetConfluenceScore()));
            g_lastTradedSwingTime = latestSwing.Time();
         }
      }
   }
   //--- Bearish Entry Trigger:
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
            Print(StringFormat("[IMSF PROD SELL] Executed Sell #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f | Score=%d/100",
                               g_trade.ResultOrder(), lot, bid, sl, tp, g_mtfManager.GetConfluenceScore()));
            g_lastTradedSwingTime = latestSwing.Time();
         }
      }
   }
}
//+------------------------------------------------------------------+
