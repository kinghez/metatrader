//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, InstitutionalSMC |
//|                             https://github.com/institutional-smc |
//+------------------------------------------------------------------+
#ifndef __IMSF_RISKMANAGER_MQH__
#define __IMSF_RISKMANAGER_MQH__

#include "Types.mqh"
#include "Settings.mqh"
#include "Utilities.mqh"

//+------------------------------------------------------------------+
//| Class CRiskManager                                               |
//| Professional risk & money management engine: dynamic fractional  |
//| lot sizing, broker volume normalization, drawdown circuit breaker|
//| and spread blowout filters.                                      |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double               m_startingDailyBalance;
   datetime             m_currentDay;

   // Helper: Resets daily baseline on calendar day roll
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
   // Constructor
   CRiskManager() :
      m_startingDailyBalance(0.0),
      m_currentDay(0)
   {
      m_startingDailyBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   // Destructor
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

      // Risk monetary amount in account currency
      double riskAmount = balance * (MathMax(0.1, riskPercent) / 100.0);

      // Broker tick specifications
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue <= 0.0 || tickSize <= 0.0)
      {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         tickSize  = (point > 0.0) ? point : 0.00001;
         tickValue = 1.0;
      }

      // Money lost per 1.0 lot for the given stop loss distance
      double lossPerLot = (stopLossDistance / tickSize) * tickValue;
      if(lossPerLot <= 0.0)
         return 0.0;

      double rawLots = riskAmount / lossPerLot;

      // Broker volume constraints
      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(minLot <= 0.0) minLot = 0.01;
      if(maxLot <= 0.0) maxLot = 100.0;
      if(stepLot <= 0.0) stepLot = 0.01;

      // Normalize to broker volume step
      double normalizedLots = MathFloor(rawLots / stepLot) * stepLot;

      // Enforce bounds
      if(normalizedLots < minLot)
         return 0.0; // Risk cannot accommodate even the smallest lot size without exceeding risk %

      if(normalizedLots > maxLot)
         normalizedLots = maxLot;

      // Ensure margin is sufficient for order
      double marginRequired = 0.0;
      if(OrderCalcMargin(ORDER_TYPE_BUY, symbol, normalizedLots, entryPrice, marginRequired))
      {
         double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(marginRequired > (freeMargin * 0.85)) // Max 85% free margin utilization
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
   //| Evaluates spread and daily drawdown circuit-breaker limits       |
   //+------------------------------------------------------------------+
   bool IsTradingPermitted(const string symbol,
                           const double maxSpreadPips = 3.0,
                           const double maxDailyDrawdownPct = 3.0)
   {
      CheckAndResetDailyBaseline();

      // 1. Spread Check
      long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double spreadPips = CUtilities::PointsToPips((double)spreadPoints, symbol);
      if(spreadPips > maxSpreadPips)
      {
         return false; // Spread blowout filter active
      }

      // 2. Daily Loss Circuit-Breaker Check
      if(m_startingDailyBalance > 0.0)
      {
         double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         double dailyDrawdownPct = ((m_startingDailyBalance - currentEquity) / m_startingDailyBalance) * 100.0;

         if(dailyDrawdownPct >= maxDailyDrawdownPct)
         {
            Print(StringFormat("[RISK ALERT] Daily loss limit breached: %.2f%% (Max allowed: %.2f%%). Trading halted.",
                               dailyDrawdownPct, maxDailyDrawdownPct));
            return false;
         }
      }

      return true;
   }
};

#endif // __IMSF_RISKMANAGER_MQH__

