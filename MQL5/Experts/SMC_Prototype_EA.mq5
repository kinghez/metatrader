//+------------------------------------------------------------------+
//|                                           SMC_Prototype_EA.mq5 |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, InstitutionalSMC"
#property link        "https://github.com/institutional-smc"
#property version     "0.70"
#property description "Institutional Market Structure Framework (IMSF) - Prototype EA with Zone Confluence"
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
#include <SMC/ObjectManager.mqh>
#include <SMC/RiskManager.mqh>

//--- EA Specific Inputs
input group "=== 5. Expert Advisor Execution Parameters ==="
input ulong  InpMagicNumber            = 100101;     // Expert Advisor Magic Number
input string InpTradeComment           = "IMSF_EA";  // Order Comment
input bool   InpEnableVisuals          = true;       // Enable Visual Objects (Set false for Strategy Tester)
input int    InpMaxOpenPositions       = 1;          // Maximum Concurrent Open Positions

//--- Global Engine Instances
CTrade            g_trade;
CMarketData       g_marketData;
CSwingDetector    g_swingDetector;
CMarketStructure  g_marketStructure;
CZoneEngine       g_zoneEngine;
CObjectManager    g_objectManager;
CRiskManager      g_riskManager;

datetime          g_lastBarTime = 0;
datetime          g_lastTradedSwingTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[IMSF EA] Initializing SMC Prototype Expert Advisor (v0.7.0)...");

   // 1. Setup Trade Execution Parameters
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   // 2. Setup Object Manager (Headless if visuals disabled)
   g_objectManager.SetChartId(0);
   g_objectManager.SetPrefix(InpObjectNamePrefix);
   g_objectManager.SetEnabled(InpEnableVisuals);
   if(InpEnableVisuals)
      g_objectManager.DeleteAllObjects();

   // 3. Initialize Swing Detection Engine
   if(!g_swingDetector.Init(_Symbol, _Period))
   {
      Print("[IMSF EA ERROR] Failed to initialize SwingDetector.");
      return(INIT_FAILED);
   }

   // 4. Initial Historical Scan, Structure & Zones
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);

   if(InpEnableVisuals)
   {
      g_objectManager.RenderAllZones(g_marketData);
      g_objectManager.RenderAllSwings(g_marketData);
      g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                      g_marketStructure.GetSequenceString(g_marketData, 5),
                                      g_marketData.TotalSwings(),
                                      g_marketData.TotalZones());
   }

   Print(StringFormat("[IMSF EA] Initialized. Bias: %s | Active Zones: %d | Magic: %I64u",
                      g_marketStructure.BiasToString(), g_marketData.TotalZones(), InpMagicNumber));
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
   Print("[IMSF EA] Deinitialized SMC Prototype EA. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Helper: Count active positions with our Magic Number             |
//+------------------------------------------------------------------+
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
   // 1. Event-Driven Execution: Run strategy evaluations on closed bar
   if(!CUtilities::IsNewBar(_Symbol, _Period, g_lastBarTime))
      return;

   // 2. Refresh Market Structure & Dynamic Zones
   g_swingDetector.ScanHistory(g_marketData, 600);
   g_marketStructure.Analyze(g_marketData);
   g_zoneEngine.BuildZones(g_marketData, 400);

   // 3. Update Visuals if enabled
   if(InpEnableVisuals)
   {
      g_objectManager.RenderAllZones(g_marketData);
      g_objectManager.RenderAllSwings(g_marketData);
      g_objectManager.DrawTrendBiasHUD(g_marketStructure.CurrentBias(),
                                      g_marketStructure.GetSequenceString(g_marketData, 5),
                                      g_marketData.TotalSwings(),
                                      g_marketData.TotalZones());
   }

   // 4. Production Safeguards: Spread check & daily loss circuit-breaker
   if(!g_riskManager.IsTradingPermitted(_Symbol, InpMaxSpreadPips, InpMaxDailyDrawdownPct))
      return;

   // 5. Position Limit Check
   if(CountOpenPositions() >= InpMaxOpenPositions)
      return;

   // 6. Strategy Evaluation
   CSwingPoint* latestSwing = g_marketData.GetLatestSwing();
   if(latestSwing == NULL || !latestSwing.IsConfirmed())
      return;

   // Avoid entering multiple trades on the same confirmed swing pivot
   if(latestSwing.Time() == g_lastTradedSwingTime)
      return;

   double atr = CUtilities::CalculateATR(_Symbol, _Period, InpATRPeriod, 1);
   if(atr <= 0.0)
      return;

   MqlTick currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   //--- Bullish Entry Trigger:
   // Trend is Bullish AND latest confirmed swing is a Higher Low (HL)
   // Optional confluence: Price is within proximity of a valid Demand Zone
   if(g_marketStructure.IsBullish() && latestSwing.StructureType() == STRUCTURE_HL)
   {
      SZone demandZone;
      bool hasDemand = g_zoneEngine.GetNearestZone(g_marketData, currentTick.ask, ZONE_DEMAND, demandZone);

      double ask = currentTick.ask;
      // Invalidation strictly placed below swing low / demand zone bottom
      double slBase = hasDemand ? MathMin(latestSwing.Price(), demandZone.bottomPrice) : latestSwing.Price();
      double sl     = g_riskManager.CalculateStopLoss(_Symbol, true, slBase, atr, 0.5);
      double tp     = g_riskManager.CalculateTakeProfit(_Symbol, true, ask, sl, InpMinRiskRewardRatio);
      double lot    = g_riskManager.CalculateLotSize(_Symbol, ask, sl, InpRiskPercent);

      if(lot > 0.0 && ask > sl)
      {
         if(g_trade.Buy(lot, _Symbol, ask, sl, tp, InpTradeComment))
         {
            Print(StringFormat("[IMSF EA BUY] Executed Buy #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f",
                               g_trade.ResultOrder(), lot, ask, sl, tp));
            g_lastTradedSwingTime = latestSwing.Time();
         }
         else
         {
            Print(StringFormat("[IMSF EA BUY FAILED] Retcode: %d | %s",
                               g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
         }
      }
   }
   //--- Bearish Entry Trigger:
   // Trend is Bearish AND latest confirmed swing is a Lower High (LH)
   // Optional confluence: Price is within proximity of a valid Supply Zone
   else if(g_marketStructure.IsBearish() && latestSwing.StructureType() == STRUCTURE_LH)
   {
      SZone supplyZone;
      bool hasSupply = g_zoneEngine.GetNearestZone(g_marketData, currentTick.bid, ZONE_SUPPLY, supplyZone);

      double bid = currentTick.bid;
      // Invalidation strictly placed above swing high / supply zone top
      double slBase = hasSupply ? MathMax(latestSwing.Price(), supplyZone.topPrice) : latestSwing.Price();
      double sl     = g_riskManager.CalculateStopLoss(_Symbol, false, slBase, atr, 0.5);
      double tp     = g_riskManager.CalculateTakeProfit(_Symbol, false, bid, sl, InpMinRiskRewardRatio);
      double lot    = g_riskManager.CalculateLotSize(_Symbol, bid, sl, InpRiskPercent);

      if(lot > 0.0 && bid < sl)
      {
         if(g_trade.Sell(lot, _Symbol, bid, sl, tp, InpTradeComment))
         {
            Print(StringFormat("[IMSF EA SELL] Executed Sell #%I64u: Lot=%.2f | Price=%.5f | SL=%.5f | TP=%.5f",
                               g_trade.ResultOrder(), lot, bid, sl, tp));
            g_lastTradedSwingTime = latestSwing.Time();
         }
         else
         {
            Print(StringFormat("[IMSF EA SELL FAILED] Retcode: %d | %s",
                               g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
         }
      }
   }
}
//+------------------------------------------------------------------+
