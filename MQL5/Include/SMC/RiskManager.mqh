//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_RISKMANAGER_MQH__
#define __IMSF_RISKMANAGER_MQH__

#include <Trade\Trade.mqh>
#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Class CRiskManager                                               |
//| Hardened institutional risk management: dynamic lot sizing,      |
//| daily drawdown circuit breaker, Break-Even & Trailing Stop engine|
//| and emergency position liquidation.                              |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double               m_startingDailyBalance;
   datetime             m_currentDay;

   void CheckAndResetDailyBaseline()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));

      if(today != m_currentDay)
      {
         m_currentDay = today;
         m_startingDailyBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      }
   }

public:
   CRiskManager() :
      m_startingDailyBalance(0.0),
      m_currentDay(0)
   {
      m_startingDailyBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   ~CRiskManager()
   {
   }

   //+------------------------------------------------------------------+
   //| Calculates dynamic lot size strictly from risk % and SL distance  |
   //+------------------------------------------------------------------+
   double CalculateLotSize(const string symbol,
                          const double entryPrice,
                          const double stopLossPrice,
                          const double riskPercent = 1.0)
   {
      double stopLossDistance = MathAbs(entryPrice - stopLossPrice);
      if(stopLossDistance <= 0.0)
         return 0.0;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0.0)
         balance = AccountInfoDouble(ACCOUNT_EQUITY);

      if(balance <= 0.0)
         return 0.0;

      double riskAmount = balance * (MathMax(0.1, riskPercent) / 100.0);

      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue <= 0.0 || tickSize <= 0.0)
      {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         tickSize  = (point > 0.0) ? point : 0.00001;
         tickValue = 1.0;
      }

      double lossPerLot = (stopLossDistance / tickSize) * tickValue;
      if(lossPerLot <= 0.0)
         return 0.0;

      double rawLots = riskAmount / lossPerLot;

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(minLot <= 0.0) minLot = 0.01;
      if(maxLot <= 0.0) maxLot = 100.0;
      if(stepLot <= 0.0) stepLot = 0.01;

      double normalizedLots = MathFloor(rawLots / stepLot) * stepLot;

      if(normalizedLots < minLot)
         return 0.0;

      if(normalizedLots > maxLot)
         normalizedLots = maxLot;

      // Free margin check
      double marginRequired = 0.0;
      if(OrderCalcMargin(ORDER_TYPE_BUY, symbol, normalizedLots, entryPrice, marginRequired))
      {
         double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(marginRequired > (freeMargin * 0.85))
         {
            double safeRatio = (freeMargin * 0.80) / marginRequired;
            normalizedLots = MathFloor((normalizedLots * safeRatio) / stepLot) * stepLot;
            if(normalizedLots < minLot)
               return 0.0;
         }
      }

      return NormalizeDouble(normalizedLots, 2);
   }

   //+------------------------------------------------------------------+
   //| Computes Stop Loss price with ATR buffer                         |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(const string symbol,
                            const bool isBuy,
                            const double swingPrice,
                            const double atr,
                            const double bufferMultiplier = 0.5)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double buffer = (atr > 0.0) ? (atr * bufferMultiplier) : (CUtilities::GetPipSize(symbol) * 10.0);

      double sl = isBuy ? (swingPrice - buffer) : (swingPrice + buffer);
      return NormalizeDouble(sl, digits);
   }

   //+------------------------------------------------------------------+
   //| Computes Take Profit based on minimum Risk:Reward ratio           |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(const string symbol,
                              const bool isBuy,
                              const double entryPrice,
                              const double stopLossPrice,
                              const double riskRewardRatio = 2.0)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double riskDistance = MathAbs(entryPrice - stopLossPrice);
      double rewardDistance = riskDistance * MathMax(1.0, riskRewardRatio);

      double tp = isBuy ? (entryPrice + rewardDistance) : (entryPrice - rewardDistance);
      return NormalizeDouble(tp, digits);
   }

   //+------------------------------------------------------------------+
   //| Evaluates daily drawdown circuit-breaker limits                  |
   //+------------------------------------------------------------------+
   bool IsTradingPermitted(const string symbol,
                           const double maxSpreadPips = 3.0,
                           const double maxDailyDrawdownPct = 3.0)
   {
      CheckAndResetDailyBaseline();

      // Daily Drawdown Circuit Breaker
      if(m_startingDailyBalance > 0.0)
      {
         double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         double dailyDrawdownPct = ((m_startingDailyBalance - currentEquity) / m_startingDailyBalance) * 100.0;

         if(dailyDrawdownPct >= maxDailyDrawdownPct)
         {
            Print(StringFormat("[RISK ALERT] Daily loss circuit breaker breached: %.2f%% (Max: %.2f%%). Trading halted.",
                               dailyDrawdownPct, maxDailyDrawdownPct));
            return false;
         }
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Production Hardening: Break-Even and Trailing Stop Engine        |
   //+------------------------------------------------------------------+
   void ManageOpenPositions(const string symbol,
                            const ulong magicNumber,
                            CTrade &trade,
                            const double atr,
                            const double breakEvenAtrMultiplier = 1.0,
                            const double trailAtrMultiplier = 1.5)
   {
      if(atr <= 0.0) return;

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = CUtilities::GetPipSize(symbol);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == (long)magicNumber)
         {
            ulong ticket        = PositionGetInteger(POSITION_TICKET);
            long  posType       = PositionGetInteger(POSITION_TYPE);
            double openPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL    = PositionGetDouble(POSITION_SL);
            double currentTP    = PositionGetDouble(POSITION_TP);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

            //--- 1. BUY Position Management
            if(posType == POSITION_TYPE_BUY)
            {
               double profitDistance = currentPrice - openPrice;

               // Break-Even Condition: Profit >= 1.0 * ATR and SL still below entry
               if(profitDistance >= (breakEvenAtrMultiplier * atr))
               {
                  double breakEvenSL = NormalizeDouble(openPrice + (pipSize * 1.0), digits); // Entry + 1 pip buffer
                  if(currentSL < breakEvenSL)
                  {
                     trade.PositionModify(ticket, breakEvenSL, currentTP);
                     Print(StringFormat("[RISK MANAGER] Ticket #%I64u moved to Break-Even (SL: %.5f)", ticket, breakEvenSL));
                     continue;
                  }
               }

               // Trailing Stop Condition: Profit >= 2.0 * ATR
               if(profitDistance >= (trailAtrMultiplier * atr * 1.33))
               {
                  double newSL = NormalizeDouble(currentPrice - (trailAtrMultiplier * atr), digits);
                  if(newSL > currentSL + (point * 10))
                  {
                     trade.PositionModify(ticket, newSL, currentTP);
                     Print(StringFormat("[RISK MANAGER] Ticket #%I64u Trailing Stop updated to %.5f", ticket, newSL));
                  }
               }
            }
            //--- 2. SELL Position Management
            else if(posType == POSITION_TYPE_SELL)
            {
               double profitDistance = openPrice - currentPrice;

               // Break-Even Condition
               if(profitDistance >= (breakEvenAtrMultiplier * atr))
               {
                  double breakEvenSL = NormalizeDouble(openPrice - (pipSize * 1.0), digits);
                  if(currentSL == 0.0 || currentSL > breakEvenSL)
                  {
                     trade.PositionModify(ticket, breakEvenSL, currentTP);
                     Print(StringFormat("[RISK MANAGER] Ticket #%I64u moved to Break-Even (SL: %.5f)", ticket, breakEvenSL));
                     continue;
                  }
               }

               // Trailing Stop Condition
               if(profitDistance >= (trailAtrMultiplier * atr * 1.33))
               {
                  double newSL = NormalizeDouble(currentPrice + (trailAtrMultiplier * atr), digits);
                  if(currentSL == 0.0 || newSL < currentSL - (point * 10))
                  {
                     trade.PositionModify(ticket, newSL, currentTP);
                     Print(StringFormat("[RISK MANAGER] Ticket #%I64u Trailing Stop updated to %.5f", ticket, newSL));
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Emergency Liquidation: Closes all positions if hard stop reached |
   //+------------------------------------------------------------------+
   void CloseAllPositions(const string symbol, const ulong magicNumber, CTrade &trade)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == (long)magicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
            Print(StringFormat("[CIRCUIT BREAKER] Emergency close for ticket #%I64u", ticket));
         }
      }
   }
};

#endif // __IMSF_RISKMANAGER_MQH__
